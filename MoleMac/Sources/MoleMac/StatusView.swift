import SwiftUI
import MoleCore

/// Live system health. Read-only by design: this screen tells the user what
/// state the machine is in, and a finding points at a screen where they can act.
struct StatusView: View {
    @EnvironmentObject var store: AppStore

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if let snapshot = store.metrics {
                    meters(snapshot)
                } else {
                    ProgressView("Reading system state…")
                        .controlSize(.small)
                        .frame(maxWidth: .infinity).padding(40)
                }

                if !store.health.isEmpty { healthChecks }
                if let snapshot = store.metrics, !snapshot.topCPU.isEmpty { topProcesses(snapshot) }
                systemFacts
            }
            .padding(18)
        }
        .background(Theme.background)
        .task {
            store.loadMetrics()
            loadFacts()
        }
    }

    // MARK: Meters

    private func meters(_ snapshot: SystemMetrics.Snapshot) -> some View {
        HStack(spacing: 12) {
            meter(title: "Disk",
                  used: ByteFormat.compact(snapshot.disk.usedBytes),
                  detail: "\(ByteFormat.compact(snapshot.disk.freeBytes)) free",
                  fraction: snapshot.disk.usedFraction,
                  note: snapshot.disk.usedFraction > 0.9 ? "low" : nil)

            meter(title: "Memory",
                  used: ByteFormat.compact(snapshot.memory.usedBytes),
                  detail: "of \(ByteFormat.compact(snapshot.memory.totalBytes))",
                  fraction: snapshot.memory.usedFraction,
                  note: nil)

            meter(title: "Uptime",
                  used: formatUptime(snapshot.uptimeSeconds),
                  detail: loadAverageText(snapshot.loadAverage),
                  fraction: min(snapshot.uptimeSeconds / (14 * 86_400), 1),
                  note: snapshot.uptimeSeconds > 14 * 86_400 ? "long" : nil)
        }
    }

    private func meter(title: String, used: String, detail: String,
                       fraction: Double, note: String?) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(title)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(Theme.inkTertiary)
                .textCase(.uppercase)
            Text(used)
                .font(.system(size: 18, weight: .semibold, design: .rounded))
                .foregroundStyle(Theme.ink)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            ProportionBar(fraction: fraction,
                          color: fraction > 0.9 ? Theme.warn : Theme.accent)
            HStack(spacing: 4) {
                Text(detail)
                if let note {
                    Text("·").foregroundStyle(Theme.inkTertiary)
                    Text(note).foregroundStyle(Theme.warn)
                }
            }
            .font(.system(size: 10))
            .foregroundStyle(Theme.inkTertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: Theme.radiusLarge,
                                                        style: .continuous))
    }

    private func formatUptime(_ seconds: TimeInterval) -> String {
        let days = Int(seconds) / 86_400
        let hours = (Int(seconds) % 86_400) / 3_600
        return days > 0 ? "\(days)d \(hours)h" : "\(hours)h"
    }

    private func loadAverageText(_ load: [Double]) -> String {
        load.first.map { String(format: "load %.2f", $0) } ?? "load —"
    }

    // MARK: Health

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
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        Spacer(minLength: 6)

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
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: Theme.radiusLarge,
                                                            style: .continuous))
        }
    }

    // MARK: Processes

    private func topProcesses(_ snapshot: SystemMetrics.Snapshot) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            VStack(alignment: .leading, spacing: 1) {
                Text("Top Processes")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.ink)
                Text("Share of one CPU core each process is using.")
                    .font(.system(size: 10))
                    .foregroundStyle(Theme.inkTertiary)
            }

            VStack(spacing: 0) {
                let peak = max(snapshot.topCPU.map(\.cpu).max() ?? 1, 1)
                ForEach(Array(snapshot.topCPU.enumerated()), id: \.element.pid) { index, process in
                    HStack(spacing: 10) {
                        Text(process.name)
                            .font(.system(size: 11))
                            .foregroundStyle(Theme.ink)
                            .lineLimit(1)
                            .frame(width: 150, alignment: .leading)
                        ProportionBar(fraction: process.cpu / peak, height: 5)
                        Text(String(format: "%.0f%%", process.cpu))
                            .font(.system(size: 10, design: .rounded))
                            .foregroundStyle(Theme.inkSecondary)
                            .monospacedDigit()
                            .frame(width: 38, alignment: .trailing)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    if index < snapshot.topCPU.count - 1 { Divider2().padding(.leading, 12) }
                }
            }
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: Theme.radiusLarge,
                                                            style: .continuous))
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
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: Theme.radiusLarge,
                                                            style: .continuous))
        }
    }

    /// Machine facts that need a subprocess. Resolved once and cached: each of
    /// these spawns a process, and doing that inside a view body blocks the run
    /// loop long enough for SwiftUI to abort.
    @StateObject private var factsBox = Box(MachineFacts())

    private var facts: MachineFacts { factsBox.value }

    private func loadFacts() {
        guard factsBox.value.isEmpty else { return }
        Task.detached(priority: .utility) {
            let resolved = MachineFacts()
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

    /// Every field here is a fixed property of the machine, so one read at
    /// launch is enough.
    init() {
        let version = ProcessInfo.processInfo.operatingSystemVersion
        osVersion = "\(version.majorVersion).\(version.minorVersion).\(version.patchVersion)"
        cores = "\(ProcessInfo.processInfo.processorCount)"
        model = SystemFactsCapture.run("/usr/sbin/sysctl", ["-n", "hw.model"])
            .flatMap { $0.isEmpty ? nil : $0 } ?? "—"

        let brand = SystemFactsCapture.run("/usr/sbin/sysctl", ["-n", "machdep.cpu.brand_string"])
        if let brand, !brand.isEmpty {
            chip = brand
        } else {
            let machine = SystemFactsCapture.run("/usr/bin/uname", ["-m"]) ?? ""
            chip = machine == "arm64" ? "Apple Silicon" : (machine.isEmpty ? "—" : machine)
        }

        if let df = SystemFactsCapture.run("/bin/df", ["-H", "/"]),
           let last = df.split(separator: "\n").last {
            volume = String(last.split(separator: " ").last ?? "")
        }
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