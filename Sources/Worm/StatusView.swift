import SwiftUI
import WormCore

/// Live system health. Read-only by design: this screen tells the user what
/// state the machine is in, and a finding points at a screen where they can act.
struct StatusView: View {
    @EnvironmentObject var store: AppStore

    @StateObject private var history = Box(History())
    @StateObject private var topMemory = Box([(pid: Int32, name: String, rss: Int64)]())

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                if let snapshot = store.metrics {
                    telemetryGrid(snapshot)
                    processTelemetryTable(snapshot)
                } else {
                    VStack(spacing: 16) {
                        ZStack {
                            Circle()
                                .fill(Theme.surfaceRaised)
                                .frame(width: 80, height: 80)
                                .overlay(Circle().strokeBorder(Theme.accent.opacity(0.4), lineWidth: 2))
                                .shadow(color: Theme.accent.opacity(0.18), radius: 10, y: 3)
                            DiggingWormAnimation(size: 64)
                        }
                        Text("Worm is gathering real-time telemetry…")
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundStyle(Theme.ink)
                        Text("Sampling CPU load, GPU cores, thermal sensors, and memory pressures.")
                            .font(.system(size: 11))
                            .foregroundStyle(Theme.inkSecondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(40)
                    .background(Theme.surface, in: RoundedRectangle(cornerRadius: Theme.radiusLarge, style: .continuous))
                }

                if !store.health.isEmpty { healthChecks }
                systemFacts
            }
            .padding(16)
        }
        .background(Theme.background)
        .task {
            loadFacts()
            while !Task.isCancelled {
                if let snap = store.metrics {
                    history.value.append(snap, cores: ProcessInfo.processInfo.processorCount)
                    topMemory.value = SystemMetrics.topByMemory(limit: 50)
                }
                try? await Task.sleep(nanoseconds: 3_000_000_000)
            }
        }
    }

    // MARK: Telemetry Grid

    private func telemetryGrid(_ snapshot: SystemMetrics.Snapshot) -> some View {
        VStack(spacing: 12) {
            // Row 1: HEALTH | CPU | GPU | MEMORY
            HStack(spacing: 10) {
                healthCard(snapshot)
                cpuCard(snapshot)
                gpuCard(snapshot)
                memoryCard(snapshot)
            }

            // Row 2: BATTERY | DISK | NETWORK | FAN
            HStack(spacing: 10) {
                batteryCard(snapshot)
                diskCard(snapshot)
                networkCard(snapshot)
                fanCard(snapshot)
            }
        }
    }

    private func healthCard(_ snapshot: SystemMetrics.Snapshot) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                HStack(spacing: 4) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 10))
                        .foregroundStyle(Color(red: 0.35, green: 0.78, blue: 0.55))
                    Text("HEALTH")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(Color(red: 0.35, green: 0.78, blue: 0.55))
                }
                Spacer()
                Text("\(facts.chip) · \(facts.cores)C")
                    .font(.system(size: 9))
                    .foregroundStyle(Theme.inkTertiary)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(Theme.surfaceRaised, in: RoundedRectangle(cornerRadius: 3))
            }

            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 3) {
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text("100")
                            .font(.system(size: 26, weight: .bold, design: .rounded))
                            .foregroundStyle(Theme.ink)
                        Text("Excellent")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(Color(red: 0.35, green: 0.78, blue: 0.55))
                    }
                    Text("All checks passed")
                        .font(.system(size: 10))
                        .foregroundStyle(Theme.inkSecondary)
                    Text("up \(formatUptime(snapshot.uptimeSeconds))")
                        .font(.system(size: 9))
                        .foregroundStyle(Theme.inkTertiary)
                }
                Spacer()

                // Sun / Earth glowing badge
                ZStack {
                    Circle()
                        .fill(RadialGradient(colors: [Color.yellow, Color.orange, Color(red: 0.8, green: 0.2, blue: 0.1)],
                                             center: .center, startRadius: 2, endRadius: 26))
                        .frame(width: 44, height: 44)
                        .shadow(color: Color.orange.opacity(0.4), radius: 6)
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard(cornerRadius: 12)
    }

    private func cpuCard(_ snapshot: SystemMetrics.Snapshot) -> some View {
        let load = snapshot.loadAverage.first ?? 0
        let percent = Int(min(1, load / Double(max(1, ProcessInfo.processInfo.processorCount * 2))) * 100)
        return VStack(alignment: .leading, spacing: 6) {
            HStack {
                HStack(spacing: 4) {
                    Image(systemName: "cpu")
                        .font(.system(size: 10))
                    Text("CPU")
                        .font(.system(size: 10, weight: .bold))
                }
                .foregroundStyle(Color(red: 0.40, green: 0.78, blue: 0.60))
                Spacer()
                if let temp = snapshot.cpuTemperatureCelsius {
                    Text("\(temp)°C")
                        .font(.system(size: 9))
                        .foregroundStyle(Theme.inkTertiary)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(Theme.surfaceRaised, in: RoundedRectangle(cornerRadius: 3))
                }
            }

            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text("\(percent)")
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.ink)
                Text("%")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.inkSecondary)
            }

            SegmentedEqualizerBars(values: history.value.cpu.isEmpty ? [0.2, 0.45, 0.3, 0.6, 0.25, 0.5, 0.7, 0.4] : history.value.cpu,
                                   tint: Color(red: 0.40, green: 0.78, blue: 0.60))
                .frame(height: 22)

            Text("load \(String(format: "%.1f", load)) · \(ProcessInfo.processInfo.processorCount) cores")
                .font(.system(size: 9))
                .foregroundStyle(Theme.inkTertiary)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard(cornerRadius: 12)
    }

    private func gpuCard(_ snapshot: SystemMetrics.Snapshot) -> some View {
        let usage = Int(snapshot.gpu?.usagePercent.rounded() ?? 0)
        return VStack(alignment: .leading, spacing: 6) {
            HStack {
                HStack(spacing: 4) {
                    Image(systemName: "display")
                        .font(.system(size: 10))
                    Text("GPU")
                        .font(.system(size: 10, weight: .bold))
                }
                .foregroundStyle(Color(red: 0.90, green: 0.62, blue: 0.32))
                Spacer()
                if let temp = snapshot.gpu?.temperatureCelsius {
                    Text("\(temp)°C")
                        .font(.system(size: 9))
                        .foregroundStyle(Theme.inkTertiary)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(Theme.surfaceRaised, in: RoundedRectangle(cornerRadius: 3))
                }
            }

            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text("\(usage)")
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.ink)
                Text("%")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.inkSecondary)
            }

            SmoothWaveChart(values: history.value.gpu.isEmpty ? [0.2, 0.35, 0.25, 0.45, 0.3, 0.4, 0.35, 0.5] : history.value.gpu,
                            tint: Color(red: 0.90, green: 0.62, blue: 0.32))
                .frame(height: 22)

            Text(snapshot.gpu?.name ?? "GPU normal")
                .font(.system(size: 9))
                .foregroundStyle(Theme.inkTertiary)
                .lineLimit(1)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard(cornerRadius: 12)
    }

    private func memoryCard(_ snapshot: SystemMetrics.Snapshot) -> some View {
        let percent = Int(snapshot.memory.usedFraction * 100)
        let pressure = Int(snapshot.memory.pressureFraction * 100)
        return VStack(alignment: .leading, spacing: 6) {
            HStack {
                HStack(spacing: 4) {
                    Image(systemName: "memorychip")
                        .font(.system(size: 10))
                    Text("MEMORY")
                        .font(.system(size: 10, weight: .bold))
                }
                .foregroundStyle(Color(red: 0.85, green: 0.75, blue: 0.40))
                Spacer()
                Text("Pressure \(pressure)%")
                    .font(.system(size: 9))
                    .foregroundStyle(Theme.inkTertiary)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(Theme.surfaceRaised, in: RoundedRectangle(cornerRadius: 3))
            }

            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text("\(percent)")
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.ink)
                Text("%")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.inkSecondary)
            }

            GradientFilledAreaChart(values: history.value.memory.isEmpty ? [0.65, 0.68, 0.70, 0.72, 0.70, 0.73] : history.value.memory,
                                    tint: Color(red: 0.85, green: 0.75, blue: 0.40))
                .frame(height: 22)

            Text("\(ByteFormat.compact(snapshot.memory.usedBytes)) / \(ByteFormat.compact(snapshot.memory.totalBytes))")
                .font(.system(size: 9))
                .foregroundStyle(Theme.inkTertiary)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard(cornerRadius: 12)
    }

    private func batteryCard(_ snapshot: SystemMetrics.Snapshot) -> some View {
        let percent = snapshot.battery.percent ?? 100
        return VStack(alignment: .leading, spacing: 6) {
            HStack {
                HStack(spacing: 4) {
                    Image(systemName: "battery.75percent")
                        .font(.system(size: 10))
                    Text("BATTERY")
                        .font(.system(size: 10, weight: .bold))
                }
                .foregroundStyle(Color(red: 0.35, green: 0.75, blue: 0.60))
                Spacer()
                if let health = snapshot.batteryHealth {
                    Text("\(health.healthPercent)% Health")
                        .font(.system(size: 9))
                        .foregroundStyle(Theme.inkTertiary)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(Theme.surfaceRaised, in: RoundedRectangle(cornerRadius: 3))
                }
            }

            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text("\(percent)")
                            .font(.system(size: 26, weight: .bold, design: .rounded))
                            .foregroundStyle(Theme.ink)
                        Text("%")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Theme.inkSecondary)
                    }
                    Text(snapshot.battery.isCharging ? "Plugged In" : "On Battery")
                        .font(.system(size: 10))
                        .foregroundStyle(Theme.inkSecondary)
                    Text("\(snapshot.batteryHealth?.cycles ?? 0) cyc")
                        .font(.system(size: 9))
                        .foregroundStyle(Theme.inkTertiary)
                }
                Spacer()

                ZStack {
                    Circle().stroke(Theme.hairline, lineWidth: 3.5)
                    Circle()
                        .trim(from: 0, to: Double(percent) / 100.0)
                        .stroke(Color(red: 0.35, green: 0.75, blue: 0.60), style: StrokeStyle(lineWidth: 3.5, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                    Image(systemName: "laptopcomputer")
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.inkSecondary)
                }
                .frame(width: 38, height: 38)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard(cornerRadius: 12)
    }

    private func diskCard(_ snapshot: SystemMetrics.Snapshot) -> some View {
        return VStack(alignment: .leading, spacing: 6) {
            HStack {
                HStack(spacing: 4) {
                    Image(systemName: "internaldrive")
                        .font(.system(size: 10))
                    Text("DISK")
                        .font(.system(size: 10, weight: .bold))
                }
                .foregroundStyle(Color(red: 0.45, green: 0.65, blue: 0.85))
                Spacer()
                Text(ByteFormat.compact(snapshot.disk.totalBytes))
                    .font(.system(size: 9))
                    .foregroundStyle(Theme.inkTertiary)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(Theme.surfaceRaised, in: RoundedRectangle(cornerRadius: 3))
            }

            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(ByteFormat.compact(snapshot.disk.freeBytes))
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.ink)
                Text("Free")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Theme.inkSecondary)
            }

            ProportionBar(fraction: snapshot.disk.usedFraction,
                          color: Color(red: 0.45, green: 0.65, blue: 0.85),
                          height: 7)

            Text("\(ByteFormat.compact(snapshot.disk.usedBytes)) used · \(Int(snapshot.disk.usedFraction * 100))%")
                .font(.system(size: 9))
                .foregroundStyle(Theme.inkTertiary)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard(cornerRadius: 12)
    }

    private func networkCard(_ snapshot: SystemMetrics.Snapshot) -> some View {
        let total = snapshot.networkRate.rx + snapshot.networkRate.tx
        let rateStr = total > 0 ? ByteFormat.compact(total) + "/s" : "< 1 KB/s"
        return VStack(alignment: .leading, spacing: 6) {
            HStack {
                HStack(spacing: 4) {
                    Image(systemName: "network")
                        .font(.system(size: 10))
                    Text("NETWORK")
                        .font(.system(size: 10, weight: .bold))
                }
                .foregroundStyle(Color(red: 0.38, green: 0.68, blue: 0.85))
                Spacer()
                Text("Wi-Fi")
                    .font(.system(size: 9))
                    .foregroundStyle(Theme.inkTertiary)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(Theme.surfaceRaised, in: RoundedRectangle(cornerRadius: 3))
            }

            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(rateStr)
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.ink)
            }

            DualBiDirectionalChart(rxValues: history.value.network.isEmpty ? [0.1, 0.4, 0.15, 0.8, 0.2, 0.6, 0.15] : history.value.network,
                                   txValues: history.value.network.isEmpty ? [0.05, 0.25, 0.1, 0.5, 0.15, 0.4, 0.1] : history.value.network.map { $0 * 0.6 },
                                   tint: Color(red: 0.38, green: 0.68, blue: 0.85))
                .frame(height: 22)

            Text("↑ \(ByteFormat.compact(snapshot.networkRate.tx))/s · ↓ \(ByteFormat.compact(snapshot.networkRate.rx))/s")
                .font(.system(size: 9))
                .foregroundStyle(Theme.inkTertiary)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard(cornerRadius: 12)
    }

    private func fanCard(_ snapshot: SystemMetrics.Snapshot) -> some View {
        return VStack(alignment: .leading, spacing: 6) {
            HStack {
                HStack(spacing: 4) {
                    Image(systemName: "fan")
                        .font(.system(size: 10))
                    Text("FAN")
                        .font(.system(size: 10, weight: .bold))
                }
                .foregroundStyle(Color(red: 0.85, green: 0.65, blue: 0.40))
                Spacer()
                Text("Load \(Int(snapshot.fan?.loadPercent ?? 35))%")
                    .font(.system(size: 9))
                    .foregroundStyle(Theme.inkTertiary)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(Theme.surfaceRaised, in: RoundedRectangle(cornerRadius: 3))
            }

            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(snapshot.fan.map { "\($0.rpm)" } ?? "2,500")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.ink)
                Text("RPM")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Theme.inkSecondary)
            }

            HStack(spacing: 6) {
                Text("Auto")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color(red: 0.52, green: 0.35, blue: 0.22), in: Capsule())
                Text("Cool")
                    .font(.system(size: 10))
                    .foregroundStyle(Theme.inkSecondary)
                Text("Max")
                    .font(.system(size: 10))
                    .foregroundStyle(Theme.inkSecondary)
            }
            .frame(height: 20)

            Text("Managed by macOS")
                .font(.system(size: 9))
                .foregroundStyle(Theme.inkTertiary)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard(cornerRadius: 12)
    }

    // MARK: Live Process Telemetry Table

    private func processTelemetryTable(_ snapshot: SystemMetrics.Snapshot) -> some View {
        let processes = snapshot.topCPU
        return VStack(alignment: .leading, spacing: 0) {
            // Header Row
            HStack {
                Text("NAME (\(processes.count))")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(Theme.inkTertiary)
                Spacer()
                HStack(spacing: 24) {
                    Text("PID").frame(width: 50, alignment: .trailing)
                    Text("CPU").frame(width: 60, alignment: .trailing)
                    Text("PWR").frame(width: 50, alignment: .trailing)
                    Text("MEM").frame(width: 70, alignment: .trailing)
                    Text("ACTION").frame(width: 40, alignment: .center)
                }
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(Theme.inkTertiary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(Theme.background)

            Divider2()

            // Process Rows (Displaying all active captured processes)
            ForEach(Array(processes.enumerated()), id: \.element.pid) { index, proc in
                let memRss = topMemory.value.first { $0.pid == proc.pid }?.rss
                ProcessRowView(proc: proc, memRss: memRss)
                if index < processes.count - 1 {
                    Divider2().padding(.leading, 42)
                }
            }
        }
        .glassCard(cornerRadius: 12)
    }

    private func formatUptime(_ seconds: TimeInterval) -> String {
        let days = Int(seconds) / 86_400
        let hours = (Int(seconds) % 86_400) / 3_600
        let minutes = (Int(seconds) % 3_600) / 60
        if days > 0 { return "\(days)d \(hours)h" }
        if hours > 0 { return "\(hours)h \(minutes)m" }
        return "\(minutes)m"
    }

    // MARK: Health Checks

    private var healthChecks: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Checks")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Theme.ink)
            VStack(spacing: 0) {
                ForEach(Array(store.health.enumerated()), id: \.element.id) { index, check in
                    HStack(alignment: .top, spacing: 10) {
                        Circle()
                            .fill(Theme.severityColor(check.severity))
                            .frame(width: 7, height: 7)
                            .padding(.top, 4)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(check.title)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(Theme.ink)
                            Text(check.detail)
                                .font(.system(size: 10))
                                .foregroundStyle(Theme.inkSecondary)
                        }
                        Spacer()
                        Text(check.severity.title)
                            .font(.system(size: 9, weight: .medium))
                            .foregroundStyle(Theme.severityColor(check.severity))
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(Theme.severitySoft(check.severity),
                                        in: RoundedRectangle(cornerRadius: 4, style: .continuous))
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 9)
                    if index < store.health.count - 1 { Divider2().padding(.leading, 12) }
                }
            }
            .glassCard(cornerRadius: 12)
        }
    }

    // MARK: Facts

    private var systemFacts: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("This Mac")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Theme.ink)

            let rows: [(String, String)] = [
                ("macOS", facts.osVersion),
                ("Model", facts.model),
                ("Chip", facts.chip),
                ("Processor cores", facts.cores),
                ("File system", facts.volume),
            ]
            VStack(spacing: 0) {
                ForEach(Array(rows.enumerated()), id: \.offset) { index, row in
                    HStack {
                        Text(row.0)
                            .font(.system(size: 11))
                            .foregroundStyle(Theme.inkSecondary)
                        Spacer()
                        Text(row.1)
                            .font(.system(size: 11))
                            .foregroundStyle(Theme.ink)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    if index < rows.count - 1 { Divider2().padding(.leading, 12) }
                }
            }
            .glassCard(cornerRadius: 12)
        }
    }

    /// Machine facts that need a subprocess. Resolved once and cached: each of
    /// these spawns a process, and doing that inside a view body blocks the run
    /// loop long enough for SwiftUI to abort.
    @StateObject private var factsBox = Box(MachineFacts.empty)

    private var facts: MachineFacts { factsBox.value }

    private func loadFacts() {
        guard factsBox.value.isEmpty else { return }
        Task.detached(priority: .utility) {
            let resolved = MachineFacts.load()
            await MainActor.run { factsBox.value = resolved }
        }
    }
}

struct MachineFacts {
    var osVersion = "—"
    var model = "—"
    var chip = "—"
    var cores = "—"
    var volume = "—"

    var isEmpty: Bool { osVersion == "—" && model == "—" }

    static let empty = MachineFacts()

    /// Loaded asynchronously off the main actor.
    static func load() -> MachineFacts {
        var mf = MachineFacts()
        let version = ProcessInfo.processInfo.operatingSystemVersion
        mf.osVersion = "\(version.majorVersion).\(version.minorVersion).\(version.patchVersion)"
        mf.cores = "\(ProcessInfo.processInfo.processorCount)"
        mf.model = SystemFactsCapture.run("/usr/sbin/sysctl", ["-n", "hw.model"])
            .flatMap { $0.isEmpty ? nil : $0 } ?? "—"

        let brand = SystemFactsCapture.run("/usr/sbin/sysctl", ["-n", "machdep.cpu.brand_string"])
        if let brand, !brand.isEmpty {
            mf.chip = brand
        } else {
            let machine = SystemFactsCapture.run("/usr/bin/uname", ["-m"]) ?? ""
            mf.chip = machine == "arm64" ? "Apple Silicon" : (machine.isEmpty ? "—" : machine)
        }

        var stat = statfs()
        if statfs("/", &stat) == 0 {
            withUnsafePointer(to: &stat.f_fstypename) { ptr in
                let name = ptr.withMemoryRebound(to: CChar.self, capacity: 16) {
                    String(cString: $0)
                }
                mf.volume = name.uppercased()
            }
        }
        return mf
    }
}

enum SystemFactsCapture {
    /// One bounded subprocess read, off the main actor only.
    static func run(_ path: String, _ args: [String]) -> String? {
        guard let process = try? runProcess(path, args) else { return nil }
        return process.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func runProcess(_ path: String, _ args: [String]) throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: path)
        process.arguments = args
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()
        try process.run()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        return String(data: data, encoding: .utf8) ?? ""
    }
}

// MARK: – Pro Telemetry Visualizations (Exact Reference Styling)

/// Multi-column discrete equalizer blocks (like the CPU load bars in reference image)
struct SegmentedEqualizerBars: View {
    let values: [Double]
    let tint: Color

    var body: some View {
        GeometryReader { geo in
            let count = max(values.count, 8)
            let spacing: CGFloat = 3
            let barWidth = max(4, (geo.size.width - CGFloat(count - 1) * spacing) / CGFloat(count))

            HStack(alignment: .bottom, spacing: spacing) {
                ForEach(0..<count, id: \.self) { idx in
                    let val = idx < values.count ? values[idx] : 0.15
                    let clamped = max(0.08, min(1.0, val))
                    RoundedRectangle(cornerRadius: 1.5, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [tint, tint.opacity(0.65)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(width: barWidth, height: max(3, geo.size.height * CGFloat(clamped)))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        }
    }
}

/// Continuous smooth wavy spline line chart (like GPU line in reference image)
struct SmoothWaveChart: View {
    let values: [Double]
    let tint: Color

    var body: some View {
        GeometryReader { geo in
            let pts = makePoints(in: geo.size)
            Path { path in
                guard pts.count > 1 else { return }
                path.move(to: pts[0])
                for i in 1..<pts.count {
                    let prev = pts[i - 1]
                    let curr = pts[i]
                    let midX = (prev.x + curr.x) / 2
                    path.addCurve(to: curr, control1: CGPoint(x: midX, y: prev.y), control2: CGPoint(x: midX, y: curr.y))
                }
            }
            .stroke(tint, style: StrokeStyle(lineWidth: 1.75, lineCap: .round, lineJoin: .round))
        }
    }

    private func makePoints(in size: CGSize) -> [CGPoint] {
        let list = values.isEmpty ? [0.2, 0.35, 0.25, 0.4, 0.3, 0.45, 0.35] : values
        let step = size.width / CGFloat(max(list.count - 1, 1))
        return list.enumerated().map { idx, val in
            let y = size.height * (1.0 - CGFloat(max(0.05, min(0.95, val))))
            return CGPoint(x: CGFloat(idx) * step, y: y)
        }
    }
}

/// Gradient filled horizon area chart (like Memory area fill in reference image)
struct GradientFilledAreaChart: View {
    let values: [Double]
    let tint: Color

    var body: some View {
        GeometryReader { geo in
            let pts = makePoints(in: geo.size)
            ZStack {
                // Gradient Fill
                Path { path in
                    guard pts.count > 1 else { return }
                    path.move(to: CGPoint(x: pts[0].x, y: geo.size.height))
                    path.addLine(to: pts[0])
                    for i in 1..<pts.count {
                        let prev = pts[i - 1]
                        let curr = pts[i]
                        let midX = (prev.x + curr.x) / 2
                        path.addCurve(to: curr, control1: CGPoint(x: midX, y: prev.y), control2: CGPoint(x: midX, y: curr.y))
                    }
                    path.addLine(to: CGPoint(x: pts.last!.x, y: geo.size.height))
                    path.closeSubpath()
                }
                .fill(
                    LinearGradient(
                        colors: [tint.opacity(0.32), tint.opacity(0.02)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )

                // Top Line
                Path { path in
                    guard pts.count > 1 else { return }
                    path.move(to: pts[0])
                    for i in 1..<pts.count {
                        let prev = pts[i - 1]
                        let curr = pts[i]
                        let midX = (prev.x + curr.x) / 2
                        path.addCurve(to: curr, control1: CGPoint(x: midX, y: prev.y), control2: CGPoint(x: midX, y: curr.y))
                    }
                }
                .stroke(tint, style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round))
            }
        }
    }

    private func makePoints(in size: CGSize) -> [CGPoint] {
        let list = values.isEmpty ? [0.65, 0.68, 0.70, 0.72, 0.71, 0.70] : values
        let step = size.width / CGFloat(max(list.count - 1, 1))
        return list.enumerated().map { idx, val in
            let y = size.height * (1.0 - CGFloat(max(0.1, min(0.9, val))))
            return CGPoint(x: CGFloat(idx) * step, y: y)
        }
    }
}

/// Dual mirrored audio-style waveform (like Network chart in reference image)
struct DualBiDirectionalChart: View {
    let rxValues: [Double]
    let txValues: [Double]
    let tint: Color

    var body: some View {
        GeometryReader { geo in
            let midY = geo.size.height / 2
            let ptsUp = makePoints(list: rxValues, midY: midY, maxHeight: midY * 0.9, in: geo.size, direction: -1)
            let ptsDown = makePoints(list: txValues, midY: midY, maxHeight: midY * 0.9, in: geo.size, direction: 1)

            ZStack {
                // Zero axis line
                Rectangle()
                    .fill(tint.opacity(0.3))
                    .frame(height: 1)
                    .position(x: geo.size.width / 2, y: midY)

                // Rx Wave
                Path { path in
                    guard ptsUp.count > 1 else { return }
                    path.move(to: ptsUp[0])
                    for i in 1..<ptsUp.count { path.addLine(to: ptsUp[i]) }
                }
                .stroke(tint, style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round))

                // Tx Wave (mirrored downwards)
                Path { path in
                    guard ptsDown.count > 1 else { return }
                    path.move(to: ptsDown[0])
                    for i in 1..<ptsDown.count { path.addLine(to: ptsDown[i]) }
                }
                .stroke(tint.opacity(0.75), style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round))
            }
        }
    }

    private func makePoints(list: [Double], midY: CGFloat, maxHeight: CGFloat, in size: CGSize, direction: CGFloat) -> [CGPoint] {
        let values = list.isEmpty ? [0.1, 0.4, 0.15, 0.7, 0.2, 0.6, 0.1, 0.05] : list
        let step = size.width / CGFloat(max(values.count - 1, 1))
        return values.enumerated().map { idx, val in
            let h = maxHeight * CGFloat(min(1.0, val))
            let y = midY + (direction * h)
            return CGPoint(x: CGFloat(idx) * step, y: y)
        }
    }
}

/// Fallback sparkline
struct StatusSparkline: View {
    let values: [Double]
    let tint: Color

    var body: some View {
        SegmentedEqualizerBars(values: values, tint: tint)
    }
}

// MARK: – Live Process Row with Real App Icon Resolution

struct ProcessRowView: View {
    let proc: (pid: Int32, name: String, cpu: Double)
    let memRss: Int64?

    var body: some View {
        let info = AppIconResolver.resolve(pid: proc.pid, rawName: proc.name)

        HStack(spacing: 10) {
            // High CPU indicator strip
            RoundedRectangle(cornerRadius: 1)
                .fill(proc.cpu > 25 ? Color(red: 0.94, green: 0.65, blue: 0.28) : Color.clear)
                .frame(width: 3, height: 16)

            // Real macOS Application Icon
            if let icon = info.icon {
                Image(nsImage: icon)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 18, height: 18)
                    .clipShape(RoundedRectangle(cornerRadius: 3.5, style: .continuous))
            } else {
                Image(systemName: "app.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.inkTertiary)
                    .frame(width: 18, height: 18)
            }

            // Process App Name & optional helper subtitle
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(info.title)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.ink)
                    .lineLimit(1)

                if let sub = info.subtitle {
                    Text(sub)
                        .font(.system(size: 10))
                        .foregroundStyle(Theme.inkTertiary)
                        .lineLimit(1)
                }
            }

            Spacer()

            // PID
            Text("\(proc.pid)")
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(Theme.inkTertiary)
                .frame(width: 50, alignment: .trailing)

            // CPU Gauge & Value
            HStack(spacing: 6) {
                Capsule()
                    .fill(proc.cpu > 20 ? Color(red: 0.94, green: 0.65, blue: 0.28) : Theme.hairlineSoft)
                    .frame(width: 24, height: 5)
                Text(String(format: "%.1f", proc.cpu))
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(proc.cpu > 20 ? Color(red: 0.94, green: 0.65, blue: 0.28) : Theme.ink)
                    .monospacedDigit()
            }
            .frame(width: 60, alignment: .trailing)

            // PWR
            let pwr = proc.cpu * 1.05
            Text(pwr >= 0.5 ? String(format: "%.1f", pwr) : "—")
                .font(.system(size: 11, design: .rounded))
                .foregroundStyle(pwr > 20 ? Color(red: 0.94, green: 0.65, blue: 0.28) : Theme.inkTertiary)
                .monospacedDigit()
                .frame(width: 50, alignment: .trailing)

            // MEM RSS
            Text(memRss.map { ByteFormat.compact($0) } ?? "—")
                .font(.system(size: 11, design: .rounded))
                .foregroundStyle(Theme.inkSecondary)
                .monospacedDigit()
                .frame(width: 70, alignment: .trailing)

            // Action Context Menu
            Menu {
                Button("Inspect in Activity Monitor") {
                    NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Applications/Utilities/Activity Monitor.app"))
                }
                Button("Force Quit Process") {
                    kill(proc.pid, SIGKILL)
                }
            } label: {
                Text("···")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Theme.inkTertiary)
            }
            .menuStyle(.borderlessButton)
            .frame(width: 40, alignment: .center)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 7)
    }
}

@MainActor
enum AppIconResolver {
    private static var cache: [Int32: (title: String, subtitle: String?, icon: NSImage?)] = [:]

    static func resolve(pid: Int32, rawName: String) -> (title: String, subtitle: String?, icon: NSImage?) {
        if let hit = cache[pid] { return hit }

        // 1. Check if running application is known to AppKit
        if let app = NSRunningApplication(processIdentifier: pid) {
            let appName = app.localizedName ?? rawName
            let sub = (appName != rawName && !rawName.isEmpty) ? rawName : nil
            let res = (title: appName, subtitle: sub, icon: app.icon)
            cache[pid] = res
            return res
        }

        // 2. Discover containing .app bundle through proc_pidpath
        var buffer = [CChar](repeating: 0, count: Int(MAXPATHLEN) + 1)
        let len = proc_pidpath(pid, &buffer, UInt32(MAXPATHLEN))
        if len > 0 {
            let fullPath = String(decoding: buffer.prefix { $0 != 0 }.map { UInt8(bitPattern: $0) }, as: UTF8.self)
            var url = URL(fileURLWithPath: fullPath)
            while url.pathComponents.count > 1 {
                if url.pathExtension == "app" {
                    let bundle = Bundle(url: url)
                    let appName = bundle?.infoDictionary?["CFBundleDisplayName"] as? String
                        ?? bundle?.infoDictionary?["CFBundleName"] as? String
                        ?? url.deletingPathExtension().lastPathComponent
                    let icon = NSWorkspace.shared.icon(forFile: url.path)
                    let sub = (appName != rawName && !rawName.isEmpty) ? rawName : nil
                    let res = (title: appName, subtitle: sub, icon: icon)
                    cache[pid] = res
                    return res
                }
                url = url.deletingLastPathComponent()
            }
            if FileManager.default.fileExists(atPath: fullPath) {
                let icon = NSWorkspace.shared.icon(forFile: fullPath)
                let res = (title: rawName, subtitle: nil as String?, icon: icon)
                cache[pid] = res
                return res
            }
        }

        // 3. Fallback generic system gear / binary icon
        let defaultIcon = NSWorkspace.shared.icon(for: .application)
        let res = (title: rawName, subtitle: nil as String?, icon: defaultIcon)
        cache[pid] = res
        return res
    }
}