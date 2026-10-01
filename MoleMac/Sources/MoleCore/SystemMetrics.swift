import Foundation
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

    public struct Snapshot: Sendable {
        public let disk: Disk
        public let memory: Memory
        public let battery: Battery
        public let uptimeSeconds: TimeInterval
        public let loadAverage: [Double]
        public let topCPU: [(pid: Int32, name: String, cpu: Double)]
        public let timestamp: Date
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

        var results: [(pid: Int32, name: String, cpu: Double)] = []
        for (pid, name) in first.names {
            guard let start = first.times[pid], let end = second.times[pid], end > start else {
                continue
            }
            // cpu_time_ns delta over wall-clock delta is the per-core
            // utilisation, so a 400% figure means four cores saturated.
            let fraction = Double(end - start) / 1_000_000_000.0 / elapsed * 100.0
            guard fraction > 0.5 else { continue }
            results.append((pid: pid, name: name, cpu: fraction))
        }
        return Array(results.sorted { $0.cpu > $1.cpu }.prefix(limit))
    }

    private static func sampleCPUTime() -> (times: [pid_t: UInt64],
                                           names: [pid_t: String],
                                           stamp: Date) {
        let stride = MemoryLayout<pid_t>.stride
        let byteCount = proc_listpids(UInt32(PROC_ALL_PIDS), 0, nil, 0)
        var pids = [pid_t](repeating: 0, count: Int(byteCount) / stride + 64)
        let filled = pids.withUnsafeMutableBufferPointer { buffer -> Int in
            Int(proc_listpids(UInt32(PROC_ALL_PIDS), 0, buffer.baseAddress,
                              Int32(buffer.count * stride))) / stride
        }
        let pidCount = min(max(filled, 0), pids.count)
        guard pidCount > 0 else { return ([:], [:], Date()) }

        var times: [pid_t: UInt64] = [:]
        var names: [pid_t: String] = [:]
        times.reserveCapacity(pidCount)
        names.reserveCapacity(pidCount)

        for index in 0..<pidCount {
            let pid = pids[index]
            guard pid > 0 else { continue }
            var info = proc_taskinfo()
            let strideInfo = Int32(MemoryLayout<proc_taskinfo>.stride)
            guard proc_pidinfo(pid, PROC_PIDTASKINFO, 0, &info, strideInfo) == strideInfo else {
                continue
            }
            times[pid] = info.pti_total_user &+ info.pti_total_system

            var nameBuffer = [CChar](repeating: 0, count: Int(MAXCOMLEN) + 1)
            guard proc_name(pid, &nameBuffer, UInt32(MAXCOMLEN)) == 0 else { continue }
            names[pid] = String(decoding: nameBuffer.prefix { $0 != 0 }.map { UInt8(bitPattern: $0) },
                                as: UTF8.self)
        }
        return (times, names, Date())
    }

    public static func snapshot() -> Snapshot {
        Snapshot(
            disk: disk(),
            memory: memory(),
            battery: battery(),
            uptimeSeconds: uptime(),
            loadAverage: loadAverage(),
            topCPU: topProcesses(),
            timestamp: Date())
    }
}

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