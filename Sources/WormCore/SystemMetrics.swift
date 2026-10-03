import Foundation
import IOKit
import IOKit.ps
import Darwin

/// Live system metrics for the Status view. All reads are bounded and never
/// block the main thread.
public enum SystemMetrics {

    public struct Disk: Sendable {
        public let totalBytes: Int64
        public let usedBytes: Int64
        public let freeBytes: Int64
        public var usedFraction: Double { totalBytes > 0 ? Double(usedBytes) / Double(totalBytes) : 0 }
    }

    public struct Memory: Sendable {
        public let totalBytes: Int64
        public let usedBytes: Int64
        public let cachedBytes: Int64
        public var usedFraction: Double { totalBytes > 0 ? Double(usedBytes) / Double(totalBytes) : 0 }
        /// macOS wants free + purgeable memory to cover the wired footprint.
        /// Reporting a raw "used" number makes a healthy Mac look full.
        public var pressureFraction: Double {
            let pressure = usedBytes - cachedBytes
            return totalBytes > 0 ? Double(max(pressure, 0)) / Double(totalBytes) : 0
        }
    }

    public struct Battery: Sendable {
        public let percent: Int?
        public let isCharging: Bool
        public let timeToEmptyMinutes: Int?
    }

    /// GPU utilisation and identity, read from IOKit without requiring root.
    public struct GPU: Sendable {
        public let usagePercent: Double   // 0–100
        public let temperatureCelsius: Int?
        public let rendererUtilization: Double
        public let tilerUtilization: Double
        public let name: String           // e.g. "M5"
    }

    /// Fan telemetry from IOKit, when available.
    public struct Fan: Sendable {
        public let rpm: Int
        public let loadPercent: Double    // 0–100
    }

    public struct Snapshot: Sendable {
        public let disk: Disk
        public let memory: Memory
        public let battery: Battery
        public let uptimeSeconds: TimeInterval
        public let loadAverage: [Double]
        public let topCPU: [(pid: Int32, name: String, cpu: Double)]
        /// Bytes per second, differenced from the previous sample.
        public let networkRate: (rx: Int64, tx: Int64)
        /// Battery condition and cycle count, when the machine reports them.
        public let batteryHealth: (healthPercent: Int, cycles: Int)?
        public let gpu: GPU?
        public let fan: Fan?
        public let cpuTemperatureCelsius: Int?
        public let timestamp: Date
    }

    /// Facts about the machine itself, shown as chips in the menu bar panel.
    ///
    /// Cached because none of it changes while the app is running, and reading it
    /// costs a `sysctl` walk.
    public struct Machine: Sendable {
        public let chip: String
        public let cores: Int
        public let osVersion: String

        public static var current: Machine {
            cached.cached() ?? {
                let value = Machine(chip: readChip(), cores: ProcessInfo.processInfo.processorCount,
                                    osVersion: readOSVersion())
                cached.store(value)
                return value
            }()
        }

        private static let cached = LivenessProbe.ProbeCache<Machine>(ttl: 3600)

        /// Marketing name, e.g. "Apple M5". `machdep.cpu.brand_string` carries it on
        /// Intel; Apple silicon hides it under a `hw.model`-style key, so fall back
        /// to the machine identifier rather than printing nothing.
        private static func readChip() -> String {
            for key in ["machdep.cpu.brand_string", "hw.model"] {
                var size = 0
                guard sysctlbyname(key, nil, &size, nil, 0) == 0, size > 0 else { continue }
                var value = [CChar](repeating: 0, count: size)
                guard sysctlbyname(key, &value, &size, nil, 0) == 0 else { continue }
                let text = String(decoding: value.prefix { $0 != 0 }.map { UInt8(bitPattern: $0) },
                                  as: UTF8.self)
                    .trimmingCharacters(in: .whitespaces)
                if !text.isEmpty { return text }
            }
            return "This Mac"
        }

        private static func readOSVersion() -> String {
            let version = ProcessInfo.processInfo.operatingSystemVersion
            return "macOS \(version.majorVersion).\(version.minorVersion).\(version.patchVersion)"
        }
    }

    public static func disk() -> Disk {
        var stat = statfs()
        guard statfs("/", &stat) == 0 else {
            return Disk(totalBytes: 0, usedBytes: 0, freeBytes: 0)
        }
        let blockSize = Int64(stat.f_bsize)
        let total = Int64(stat.f_blocks) * blockSize
        let free = Int64(stat.f_bavail) * blockSize
        let used = total - Int64(stat.f_bfree) * blockSize
        return Disk(totalBytes: total, usedBytes: used, freeBytes: free)
    }

    public static func memory() -> Memory {
        var stats = vm_statistics64()
        var count = mach_msg_type_number_t(
            MemoryLayout<vm_statistics64_data_t>.size / MemoryLayout<integer_t>.size)
        // host_statistics64 wants a buffer of integer_t, so the vm_statistics64
        // struct has to be rebound rather than passed directly.
        let kr: kern_return_t = withUnsafeMutablePointer(to: &stats) { pointer -> kern_return_t in
            pointer.withMemoryRebound(to: integer_t.self,
                                      capacity: Int(count)) { rebound in
                host_statistics64(mach_host_self(), HOST_VM_INFO64, rebound, &count)
            }
        }
        guard kr == KERN_SUCCESS else {
            return Memory(totalBytes: 0, usedBytes: 0, cachedBytes: 0)
        }

        // getpagesize() rather than the `vm_kernel_page_size` global, which is
        // a mutable symbol and therefore unsafe to read under strict
        // concurrency. Both report the same value.
        let pageSize = Int64(getpagesize())
        let total = Int64(ProcessInfo.processInfo.physicalMemory)
        let free = Int64(stats.free_count) * pageSize
        let active = Int64(stats.active_count) * pageSize
        let wired = Int64(stats.wire_count) * pageSize
        let compressed = Int64(stats.compressor_page_count) * pageSize
        let purgeable = Int64(stats.purgeable_count) * pageSize

        // Count App memory as active + wired + compressed, then subtract
        // reclaimable purgeable so the number reflects real pressure.
        let used = max(active + wired + compressed - purgeable, 0)
        let cached = free + purgeable

        return Memory(totalBytes: total, usedBytes: used, cachedBytes: cached)
    }

    public static func battery() -> Battery {
        var out = Battery(percent: nil, isCharging: false, timeToEmptyMinutes: nil)
        guard let blob = IOPSCopyPowerSourcesInfo()?.takeRetainedValue() else { return out }
        guard let sources = IOPSCopyPowerSourcesList(blob)?.takeRetainedValue() as? [CFTypeRef],
              !sources.isEmpty else { return out }

        for source in sources {
            guard let desc = IOPSGetPowerSourceDescription(blob, source)?.takeUnretainedValue()
                    as? [String: Any] else { continue }
            if let capacity = desc[kIOPSCurrentCapacityKey] as? Int,
               let max = desc[kIOPSMaxCapacityKey] as? Int, max > 0 {
                out = Battery(
                    percent: capacity * 100 / max,
                    isCharging: (desc[kIOPSIsChargingKey] as? Bool) ?? false,
                    timeToEmptyMinutes: desc[kIOPSTimeToEmptyKey] as? Int)
                return out
            }
        }
        return Battery(percent: nil, isCharging: false, timeToEmptyMinutes: nil)
    }

    public static func uptime() -> TimeInterval {
        var boot = timeval()
        var size: Int = MemoryLayout<timeval>.size
        var name = [CTL_KERN, KERN_BOOTTIME]
        let status = name.withUnsafeMutableBufferPointer { pointer in
            sysctl(pointer.baseAddress, UInt32(pointer.count), &boot, &size, nil, 0)
        }
        guard status == 0 else { return 0 }
        let bootDate = Date(timeIntervalSince1970: Double(boot.tv_sec))
        return Date().timeIntervalSince(bootDate)
    }

    public static func loadAverage() -> [Double] {
        var averages = [Double](repeating: 0, count: 3)
        averages.withUnsafeMutableBufferPointer { buffer in
            _ = getloadavg(buffer.baseAddress, 3)
        }
        return averages
    }

    /// Top CPU consumers, by process.
    ///
    /// Sampling needs two reads a moment apart: CPU time is cumulative, so a
    /// single read yields process age rather than current usage.
    public static func topProcesses(limit: Int = 8) -> [(pid: Int32, name: String, cpu: Double)] {
        let first = sampleCPUTime()
        Thread.sleep(forTimeInterval: 0.35)
        let second = sampleCPUTime()

        let elapsed = Date().timeIntervalSince(first.stamp)
        guard elapsed > 0 else { return [] }

        var topDeltas: [(pid: Int32, cpu: Double)] = []
        for (pid, start) in first.times {
            guard let end = second.times[pid], end > start else { continue }
            let fraction = Double(end - start) / 1_000_000_000.0 / elapsed * 100.0
            guard fraction >= 0.05 else { continue }
            topDeltas.append((pid: pid, cpu: fraction))
        }

        topDeltas.sort { $0.cpu > $1.cpu }
        let topSlice = topDeltas.prefix(limit)

        var results: [(pid: Int32, name: String, cpu: Double)] = []
        for item in topSlice {
            results.append((pid: item.pid, name: name(for: item.pid).name, cpu: item.cpu))
        }

        // If fewer than limit were actively burning CPU in the 350ms window,
        // backfill with top active processes by memory so the list always has rich telemetry
        if results.count < limit {
            let memoryTop = topByMemory(limit: limit)
            let existingPids = Set(results.map { $0.pid })
            for item in memoryTop {
                if !existingPids.contains(item.pid) {
                    results.append((pid: item.pid, name: item.name, cpu: 0.0))
                    if results.count >= limit { break }
                }
            }
        }

        return Array(results.prefix(limit))
    }

    /// Resident memory per process, so the panel can show a Memory column beside
    /// CPU instead of leaving the user to guess which app is heavy.
    public static func topByMemory(limit: Int = 8) -> [(pid: Int32, name: String, rss: Int64)] {
        let stride = MemoryLayout<pid_t>.stride
        let byteCount = proc_listpids(UInt32(PROC_ALL_PIDS), 0, nil, 0)
        var pids = [pid_t](repeating: 0, count: Int(byteCount) / stride + 64)
        let filled = pids.withUnsafeMutableBufferPointer { buffer -> Int in
            Int(proc_listpids(UInt32(PROC_ALL_PIDS), 0, buffer.baseAddress,
                              Int32(buffer.count * stride))) / stride
        }
        let pidCount = min(max(filled, 0), pids.count)
        guard pidCount > 0 else { return [] }

        var results: [(pid: Int32, name: String, rss: Int64)] = []
        for index in 0..<pidCount {
            let pid = pids[index]
            guard pid > 0 else { continue }
            var info = proc_taskinfo()
            let strideInfo = Int32(MemoryLayout<proc_taskinfo>.stride)
            guard proc_pidinfo(pid, PROC_PIDTASKINFO, 0, &info, strideInfo) == strideInfo,
                  info.pti_resident_size > 0 else { continue }
            results.append((pid, name(for: pid).name, Int64(info.pti_resident_size)))
        }
        return Array(results.sorted { $0.rss > $1.rss }.prefix(limit))
    }

    /// Cumulative bytes sent and received, so the caller can difference two
    /// samples into a rate. `if_data` counters wrap and reset on link changes, so
    /// a negative delta is reported as 0 rather than as a huge negative spike.
    public static func networkTotals() -> (rx: Int64, tx: Int64) {
        var rx: Int64 = 0, tx: Int64 = 0
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0, let first = ifaddr else { return (0, 0) }
        defer { freeifaddrs(ifaddr) }
        var cursor: UnsafeMutablePointer<ifaddrs>? = first
        while let entry = cursor {
            defer { cursor = entry.pointee.ifa_next }
            let flags = Int32(entry.pointee.ifa_flags)
            guard flags & IFF_UP == IFF_UP, flags & IFF_LOOPBACK == 0,
                  let data = entry.pointee.ifa_data else { continue }
            let stats = data.assumingMemoryBound(to: if_data.self)
            rx += Int64(stats.pointee.ifi_ibytes)
            tx += Int64(stats.pointee.ifi_obytes)
        }
        return (rx, tx)
    }

    /// Display name for a pid.
    ///
    /// `proc_name` reports success on this SDK while leaving the buffer empty, so
    /// every process came back as a blank row in the panel. `proc_pidpath` is the
    /// supported route; the last path component is the name, and the full path is
    /// kept for a tooltip.
    private static func name(for pid: pid_t) -> (name: String, path: String) {
        var buffer = [CChar](repeating: 0, count: Int(MAXPATHLEN) + 1)
        let length = proc_pidpath(pid, &buffer, UInt32(MAXPATHLEN))
        guard length > 0 else {
            return ("pid \(pid)", "")
        }
        let path = String(decoding: buffer.prefix { $0 != 0 }.map { UInt8(bitPattern: $0) },
                          as: UTF8.self)
        // A helper binary reports as ".../Contents/MacOS/Foo"; "Foo" is the name
        // a user recognises.
        let last = (path as NSString).lastPathComponent
        return (last.isEmpty ? "pid \(pid)" : last, path)
    }

    private static func sampleCPUTime() -> (times: [pid_t: UInt64],
                                           stamp: Date) {
        let stride = MemoryLayout<pid_t>.stride
        let byteCount = proc_listpids(UInt32(PROC_ALL_PIDS), 0, nil, 0)
        var pids = [pid_t](repeating: 0, count: Int(byteCount) / stride + 64)
        let filled = pids.withUnsafeMutableBufferPointer { buffer -> Int in
            Int(proc_listpids(UInt32(PROC_ALL_PIDS), 0, buffer.baseAddress,
                              Int32(buffer.count * stride))) / stride
        }
        let pidCount = min(max(filled, 0), pids.count)
        guard pidCount > 0 else { return ([:], Date()) }

        var times: [pid_t: UInt64] = [:]
        times.reserveCapacity(pidCount)

        for index in 0..<pidCount {
            let pid = pids[index]
            guard pid > 0 else { continue }
            var info = proc_taskinfo()
            let strideInfo = Int32(MemoryLayout<proc_taskinfo>.stride)
            guard proc_pidinfo(pid, PROC_PIDTASKINFO, 0, &info, strideInfo) == strideInfo else {
                continue
            }
            times[pid] = info.pti_total_user &+ info.pti_total_system
        }
        return (times, Date())
    }

    /// Previous network counters, so successive calls can produce a rate.
    private static let lastNet = LivenessProbe.ProbeCache<(rx: Int64, tx: Int64)>(ttl: 1)

    // MARK: – GPU (IOKit, no root required)

    /// GPU utilisation read from IOKit `IOAccelerator` performance statistics.
    ///
    /// On Apple Silicon the GPU perf-state is published under the accelerator
    /// node as `PerformanceStatistics`. The key `Device Utilization %` gives
    /// a 0–100 number for the overall GPU busy fraction.
    public static func gpu() -> GPU? {
        let chipName: String
        let raw = Machine.current.chip
        chipName = raw.hasPrefix("Apple ") ? String(raw.dropFirst(6)) : raw

        let matching = IOServiceMatching("IOAccelerator")
        var iter: io_iterator_t = 0
        guard IOServiceGetMatchingServices(kIOMainPortDefault, matching, &iter) == KERN_SUCCESS else {
            return GPU(usagePercent: 0, temperatureCelsius: nil,
                       rendererUtilization: 0, tilerUtilization: 0, name: chipName)
        }
        defer { IOObjectRelease(iter) }

        var bestUsage: Double = 0
        var renderer: Double = 0
        var tiler: Double = 0

        var service = IOIteratorNext(iter)
        while service != 0 {
            defer { IOObjectRelease(service); service = IOIteratorNext(iter) }
            var props: Unmanaged<CFMutableDictionary>?
            guard IORegistryEntryCreateCFProperties(service, &props,
                                                   kCFAllocatorDefault, 0) == KERN_SUCCESS,
                  let dict = props?.takeRetainedValue() as? [String: Any],
                  let stats = dict["PerformanceStatistics"] as? [String: Any] else { continue }

            let util = (stats["Device Utilization %"] as? Double)
                       ?? (stats["GPU Activity(%)"] as? Double)
                       ?? 0
            let r = (stats["Renderer Utilization %"] as? Double) ?? 0
            let t = (stats["Tiler Utilization %"] as? Double) ?? 0
            if util > bestUsage { bestUsage = util; renderer = r; tiler = t }
        }

        return GPU(usagePercent: min(100, bestUsage),
                   temperatureCelsius: nil,
                   rendererUtilization: renderer,
                   tilerUtilization: tiler,
                   name: chipName)
    }

    // MARK: – Fan (IORegistry, no root required)

    /// Fan RPM from IORegistry fan service nodes.
    ///
    /// Returns nil when no fan data is available (fanless Macs, or macOS
    /// versions that don't publish this key).
    public static func fan() -> Fan? {
        // Walk the IORegistry for fan service nodes on Apple Silicon / Intel.
        for serviceName in ["AppleFan", "AppleHPMFan"] {
            let matching = IOServiceNameMatching(serviceName)
            var iter: io_iterator_t = 0
            guard IOServiceGetMatchingServices(kIOMainPortDefault, matching, &iter) == KERN_SUCCESS else { continue }
            defer { IOObjectRelease(iter) }
            var service = IOIteratorNext(iter)
            while service != 0 {
                defer { IOObjectRelease(service); service = IOIteratorNext(iter) }
                var props: Unmanaged<CFMutableDictionary>?
                guard IORegistryEntryCreateCFProperties(service, &props,
                                                       kCFAllocatorDefault, 0) == KERN_SUCCESS,
                      let dict = props?.takeRetainedValue() as? [String: Any] else { continue }
                for key in ["FAN_SPEED", "fan-speed", "CurrentSpeed", "RPM"] {
                    let raw = (dict[key] as? Double).map(Int.init) ?? (dict[key] as? Int)
                    if let rpm = raw, rpm > 0 {
                        let load = min(100.0, Double(rpm) / 6000.0 * 100.0)
                        return Fan(rpm: rpm, loadPercent: load)
                    }
                }
            }
        }
        return nil
    }

    // MARK: – CPU Temperature (IORegistry, no root required)

    /// CPU-adjacent temperature from IORegistry.
    ///
    /// Most Macs don't expose a raw CPU die temperature without `powermetrics`
    /// (which requires root). Returns nil when unavailable (e.g. desktops).
    public static func cpuTemperature() -> Int? {
        for serviceClass in ["AppleSmartBatteryPack", "AppleSmartBattery"] {
            let matching = IOServiceMatching(serviceClass)
            var iter: io_iterator_t = 0
            guard IOServiceGetMatchingServices(kIOMainPortDefault, matching, &iter) == KERN_SUCCESS else {
                continue
            }
        defer { IOObjectRelease(iter) }
        var service = IOIteratorNext(iter)
        while service != 0 {
            defer { IOObjectRelease(service); service = IOIteratorNext(iter) }
            var props: Unmanaged<CFMutableDictionary>?
            guard IORegistryEntryCreateCFProperties(service, &props,
                                                   kCFAllocatorDefault, 0) == KERN_SUCCESS,
                  let dict = props?.takeRetainedValue() as? [String: Any] else { continue }
            
            let batteryData = dict["BatteryData"] as? [String: Any]
            for candidateDict in [dict, batteryData ?? [:]] {
                for key in ["Temperature", "PackTemperature", "VirtualTemperature"] {
                    if let raw = candidateDict[key] as? Int, raw > 0 {
                        // Temperature is often reported in tenths of degree Celsius (e.g. 3620 = 36.2°C)
                        // or in 256ths on older models.
                        var celsius = 0
                        if raw > 2000 && raw < 10000 {
                            celsius = raw / 100 // e.g. 3620 -> 36°C
                        } else if raw >= 10000 {
                            celsius = Int(Double(raw) / 256.0)
                        } else {
                            celsius = raw
                        }
                        if celsius > 15 && celsius < 120 { return celsius }
                    }
                }
            }
        }
        }
        return nil
    }

    // MARK: – Snapshot

    /// A fast initial snapshot populated with instantaneous, non-blocking metrics
    /// so the view renders immediately with actual values without waiting for CPU sampling.
    /// A snapshot with no measurements in it.
    ///
    /// Deliberately does **no I/O at all** — no disk walk, no `sysctl`, no
    /// IOKit, and no subprocess. This is called from a SwiftUI property
    /// initializer (`MenuBarPanel`), which runs inside the view-graph update
    /// pass; blocking there re-enters the update and aborts the process with an
    /// `AG::Graph::value_set` precondition failure as soon as a second view is
    /// rendering from the same store.
    ///
    /// It previously called `batteryHealth()`, which spawns `ioreg` with a
    /// two-second timeout, plus `gpu()`, `fan()` and `cpuTemperature()`. The
    /// "empty" snapshot was doing more I/O than the expensive `snapshot()` it
    /// was written to avoid. Real values arrive from `.task` moments later.
    public static func emptySnapshot() -> Snapshot {
        Snapshot(
            disk: Disk(totalBytes: 0, usedBytes: 0, freeBytes: 0),
            memory: Memory(totalBytes: 0, usedBytes: 0, cachedBytes: 0),
            battery: Battery(percent: nil, isCharging: false, timeToEmptyMinutes: nil),
            uptimeSeconds: 0,
            loadAverage: [],
            topCPU: [],
            networkRate: (0, 0),
            batteryHealth: nil,
            gpu: nil,
            fan: nil,
            cpuTemperatureCelsius: nil,
            timestamp: Date())
    }

    /// Human label for the active primary network interface.
    ///
    /// Read from the default route: `en0` is Wi-Fi on a MacBook, other `en*` is
    /// usually Ethernet, and `utun*` is a tunnel.
    ///
    /// Cached for a minute because it costs a `/sbin/route` subprocess, and
    /// `Paths.run` blocks its caller in `waitUntilExit`. This was previously a
    /// computed property read straight from `MenuBarPanel.body`, so every render
    /// of the panel's Telemetry mode spawned a subprocess on the main thread —
    /// which is how the panel segfaulted during a clean, when progress updates
    /// made it re-render continuously.
    ///
    /// Callers must still prefer the panel's cached copy: even a cache hit is a
    /// lock, and a view body should not be doing this work at all.
    public static func networkInterfaceLabel() -> String {
        if let cached = networkLabelCache.cached() { return cached }
        let value = readNetworkInterfaceLabel()
        networkLabelCache.store(value)
        return value
    }

    private static let networkLabelCache = LivenessProbe.ProbeCache<String>(ttl: 60)

    private static func readNetworkInterfaceLabel() -> String {
        guard let out = try? Paths.run("/sbin/route", ["-n", "get", "default"], timeout: 2),
              out.status == 0 else { return "Network" }
        for line in out.stdout.split(separator: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard trimmed.hasPrefix("interface:") else { continue }
            let iface = trimmed.replacingOccurrences(of: "interface:", with: "")
                .trimmingCharacters(in: .whitespaces)
            if iface.hasPrefix("en") { return iface == "en0" ? "Wi-Fi" : "Ethernet" }
            if iface.hasPrefix("utun") || iface.hasPrefix("ipsec") { return "VPN" }
            if iface.hasPrefix("bridge") { return "Bridge" }
            return iface
        }
        return "Network"
    }

    public static func snapshot() -> Snapshot {
        let net = networkTotals()
        var rate: (rx: Int64, tx: Int64) = (0, 0)
        if let previous = lastNet.cached(), net.rx >= previous.rx, net.tx >= previous.tx {
            rate = (net.rx - previous.rx, net.tx - previous.tx)
        }
        lastNet.store(net)

        return Snapshot(
            disk: disk(),
            memory: memory(),
            battery: battery(),
            uptimeSeconds: uptime(),
            loadAverage: loadAverage(),
            topCPU: topProcesses(limit: 50),
            networkRate: rate,
            batteryHealth: batteryHealth(),
            gpu: gpu(),
            fan: fan(),
            cpuTemperatureCelsius: cpuTemperature(),
            timestamp: Date())
    }

    /// Battery wear and cycle count.
    ///
    /// Read through `ioreg`, the only route that needs no helper daemon. This
    /// hardware publishes no `Condition` key, so wear is derived from full
    /// charge against nominal capacity — the same figure the system shows as
    /// "Battery Health". Absent on a desktop, which is why it is optional.
    public static func batteryHealth() -> (healthPercent: Int, cycles: Int)? {
        guard let out = try? Paths.run("/usr/sbin/ioreg",
                                       ["-r", "-c", "AppleSmartBattery", "-l"],
                                       timeout: 2),
              out.status == 0 else { return nil }

        // `String.range(of:)` matches literally unless asked otherwise, so a
        // pattern containing `\s` needs `.regularExpression` — without it this
        // silently matched nothing and reported no battery at all.
        func integer(_ key: String) -> Int? {
            let pattern = "\"\\(key)\"\\s*=\\s*(-?[0-9]+)"
            guard let _ = out.stdout.range(of: pattern,
                                               options: .regularExpression),
                  let match = try? NSRegularExpression(pattern: pattern)
                      .firstMatch(in: out.stdout, range: NSRange(out.stdout.startIndex..., in: out.stdout)),
                  let numberRange = Range(match.range(at: 1), in: out.stdout)
            else { return nil }
            return Int(out.stdout[numberRange])
        }

        guard let cycles = integer("CycleCount"),
              let full = integer("FullChargeCapacity"),
              let nominal = integer("NominalChargeCapacity"),
              nominal > 0 else { return nil }
        return (min(100, Int((Double(full) / Double(nominal) * 100).rounded())), cycles)
    }
}

// MARK: – Read-only health checks

/// Read-only health checks. Each returns a finding with the reason it matters
/// and what to do, rather than a bare pass/fail.
public struct HealthCheck: Identifiable, Sendable {
    public let id = UUID()
    public let title: String
    public let detail: String
    public let severity: Severity

    public enum Severity: Int, Sendable, Comparable {
        case good, notice, warning

        public static func < (lhs: Self, rhs: Self) -> Bool { lhs.rawValue < rhs.rawValue }
        public var title: String {
            switch self {
            case .good: return "OK"
            case .notice: return "Notice"
            case .warning: return "Action needed"
            }
        }
    }
}

public enum Health {

    public static func checks() -> [HealthCheck] {
        var results: [HealthCheck] = []
        let d = SystemMetrics.disk()

        if d.totalBytes > 0 {
            let freeGB = Double(d.freeBytes) / 1_073_741_824
            if d.usedFraction > 0.92 {
                results.append(HealthCheck(
                    title: "Disk is nearly full",
                    detail: String(format: "%.1f GB free of %.0f GB. macOS needs working space to swap and update; clean soon.",
                                   freeGB, Double(d.totalBytes) / 1_073_741_824),
                    severity: .warning))
            } else if d.usedFraction > 0.85 {
                results.append(HealthCheck(
                    title: "Disk is getting full",
                    detail: String(format: "%.1f GB free. Cleaning caches now keeps macOS responsive.",
                                   freeGB),
                    severity: .notice))
            } else {
                results.append(HealthCheck(
                    title: "Disk space",
                    detail: String(format: "%.1f GB free of %.0f GB.",
                                   freeGB, Double(d.totalBytes) / 1_073_741_824),
                    severity: .good))
            }
        }

        let m = SystemMetrics.memory()
        if m.totalBytes > 0 {
            let usedGB = Double(m.usedBytes) / 1_073_741_824
            let totalGB = Double(m.totalBytes) / 1_073_741_824
            if m.pressureFraction > 0.92 {
                results.append(HealthCheck(
                    title: "Memory pressure is high",
                    detail: String(format: "%.1f GB of %.1f GB in use with little reclaimable. Quit apps you are not using.", usedGB, totalGB),
                    severity: .warning))
            } else {
                results.append(HealthCheck(
                    title: "Memory",
                    detail: String(format: "%.1f GB of %.1f GB in use.", usedGB, totalGB),
                    severity: .good))
            }
        }

        if let backupDisabled = timeMachineDisabled() {
            results.append(backupDisabled)
        }

        results.append(HealthCheck(
            title: "Time since restart",
            detail: formatUptime(SystemMetrics.uptime()),
            severity: SystemMetrics.uptime() > 14 * 86_400 ? .notice : .good))

        return results
    }

    /// Time Machine state. Read via `defaults` on the system domain rather
    /// than `tmutil`, which is slow and prompts for a destination lookup.
    static func timeMachineDisabled() -> HealthCheck? {
        guard let out = try? Paths.run("/usr/bin/defaults", [
            "read", "/Library/Preferences/com.apple.TimeMachine", "AutoBackup"
        ], timeout: 4), out.status == 0 else { return nil }

        let enabled = out.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
        if enabled == "1" {
            return HealthCheck(title: "Time Machine",
                               detail: "Automatic backups are on.",
                               severity: .good)
        }
        if enabled == "0" {
            return HealthCheck(title: "Time Machine is off",
                               detail: "Automatic backups are disabled. Cleaning is one-way; a backup makes it recoverable.",
                               severity: .warning)
        }
        return nil
    }

    public static func formatUptime(_ seconds: TimeInterval) -> String {
        let days = Int(seconds) / 86_400
        let hours = (Int(seconds) % 86_400) / 3_600
        if days > 0 { return "\(days) day\(days == 1 ? "" : "s"), \(hours) hours" }
        let minutes = (Int(seconds) % 3_600) / 60
        return "\(hours) hours, \(minutes) minutes"
    }
}