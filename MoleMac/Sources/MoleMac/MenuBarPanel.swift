import MoleCore
import SwiftUI

/// The panel behind the menu bar icon.
///
/// It answers the question the window answers, at a glance and without stealing
/// focus: how much is recoverable right now, what is using the machine, and what
/// happens if I press Clean. It reads the same `AppStore` as the window, so a
/// scan started in either place shows up in both.
struct MenuBarPanel: View {
    @EnvironmentObject var store: AppStore
    /// Used instead of `NSApp.activate` so the *window* comes forward, not just
    /// the process: activating a running app whose window is closed does nothing.
    @Environment(\.openWindow) private var openWindow
    @StateObject private var metrics = Box(SystemMetrics.snapshot())

    /// Recomputed rather than sampled once: the panel is usually on screen for a
    /// few seconds, and stale CPU numbers are worse than none.
    private var snapshot: SystemMetrics.Snapshot { metrics.value }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header

            Divider2()

            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    grid
                    topProcesses
                    cleanBlock
                }
                .padding(12)
            }
        }
        .frame(width: 340)
        .background(MenuPalette.panel)
        .task {
            // Cheap enough to poll while visible, but not while it is not.
            while !Task.isCancelled {
                metrics.value = SystemMetrics.snapshot()
                try? await Task.sleep(nanoseconds: 2_000_000_000)
            }
        }
    }

    // MARK: Header

    private var header: some View {
        HStack(alignment: .center, spacing: 9) {
            ZStack {
                Circle()
                    .fill(MenuPalette.accent.opacity(0.16))
                    .frame(width: 30, height: 30)
                Image(systemName: "sparkles")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(MenuPalette.accent)
            }

            VStack(alignment: .leading, spacing: 1) {
                Text("MoleMac")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(MenuPalette.ink)
                Text(store.reclaimableSummary)
                    .font(.system(size: 11))
                    .foregroundStyle(MenuPalette.inkSecondary)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    // MARK: Metrics

    private var grid: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                MetricCard(title: "Disk",
                           value: "\(Int((snapshot.disk.usedFraction * 100).rounded()))%",
                           detail: "\(ByteFormat.compact(snapshot.disk.freeBytes)) free",
                           fraction: snapshot.disk.usedFraction,
                           tint: diskTint,
                           symbol: "internaldrive")

                MetricCard(title: "Memory",
                           value: "\(Int((snapshot.memory.usedFraction * 100).rounded()))%",
                           detail: "\(ByteFormat.compact(snapshot.memory.usedBytes)) / \(ByteFormat.compact(snapshot.memory.totalBytes))",
                           fraction: snapshot.memory.usedFraction,
                           tint: MenuPalette.warn,
                           symbol: "memorychip")
            }

            HStack(spacing: 8) {
                MetricCard(title: "Load",
                           value: loadText,
                           detail: "up \(uptimeText)",
                           fraction: nil,
                           tint: MenuPalette.accent,
                           symbol: "gauge.with.dots.needle.bottom.50percent")

                MetricCard(title: "Battery",
                           value: snapshot.battery.percent.map { "\($0)%" } ?? "—",
                           detail: snapshot.battery.isCharging ? "Charging" : batteryDetail,
                           fraction: snapshot.battery.percent.map { Double($0) / 100 },
                           tint: MenuPalette.good,
                           symbol: snapshot.battery.isCharging
                               ? "bolt.fill" : "battery.75percent")
            }
        }
    }

    private var diskTint: Color {
        snapshot.disk.usedFraction > 0.9 ? MenuPalette.danger
            : (snapshot.disk.usedFraction > 0.75 ? MenuPalette.warn : MenuPalette.info)
    }

    private var loadText: String {
        let avg = snapshot.loadAverage.first ?? 0
        return String(format: "%.1f", avg)
    }

    private var uptimeText: String {
        let minutes = Int(snapshot.uptimeSeconds) / 60
        if minutes < 60 { return "\(minutes)m" }
        let hours = minutes / 60
        if hours < 24 { return "\(hours)h \(minutes % 60)m" }
        return "\(hours / 24)d \(hours % 24)h"
    }

    private var batteryDetail: String {
        guard let minutes = snapshot.battery.timeToEmptyMinutes, minutes > 0 else {
            return "On battery"
        }
        return minutes > 90 ? "On battery" : "\(minutes) min left"
    }

    private var topProcesses: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("Top processes")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(MenuPalette.inkSecondary)
                .textCase(.uppercase)

            if snapshot.topCPU.isEmpty {
                Text("No activity to report.")
                    .font(.system(size: 11))
                    .foregroundStyle(MenuPalette.inkTertiary)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(snapshot.topCPU.prefix(4).enumerated()), id: \.offset) { index, proc in
                        HStack(spacing: 6) {
                            Text(proc.name)
                                .font(.system(size: 11))
                                .foregroundStyle(MenuPalette.ink)
                                .lineLimit(1)
                                .truncationMode(.tail)
                            Spacer(minLength: 6)
                            Text(String(format: "%.0f%%", proc.cpu))
                                .font(.system(size: 11, weight: .medium, design: .rounded))
                                .foregroundStyle(proc.cpu > 50 ? MenuPalette.danger
                                                             : MenuPalette.inkSecondary)
                                .monospacedDigit()
                                .fixedSize()
                        }
                        .padding(.vertical, 3)

                        if index < min(4, snapshot.topCPU.count) - 1 { Divider2() }
                    }
                }
            }
        }
    }

    // MARK: Cleaning

    private var cleanBlock: some View {
        VStack(alignment: .leading, spacing: 7) {
            Divider2()

            HStack(alignment: .firstTextBaseline) {
                Text(store.reclaimableSummary)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(MenuPalette.ink)
                Spacer(minLength: 6)
                if store.scanState.isScanning {
                    ProgressView().controlSize(.small).scaleEffect(0.6).frame(width: 14)
                } else {
                    Button {
                        store.scan()
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 11, weight: .medium))
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(MenuPalette.inkSecondary)
                    .help("Scan again")
                }
            }

            if let banner = store.banner {
                HStack(spacing: 5) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 9))
                    Text(banner.title)
                        .font(.system(size: 10))
                        .lineLimit(2)
                }
                .foregroundStyle(MenuPalette.warn)
            }

            HStack(spacing: 7) {
                Button {
                    openWindow(id: WindowID.main)
                    NSApp.activate(ignoringOtherApps: true)
                } label: {
                    Text("Open MoleMac")
                        .font(.system(size: 11, weight: .medium))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                        .background(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(MenuPalette.surface))
                        .foregroundStyle(MenuPalette.ink)
                }
                .buttonStyle(.plain)

                Button {
                    store.requestClean()
                } label: {
                    Text(store.selectedPaths.isEmpty
                         ? "Nothing selected"
                         : "Clean \(ByteFormat.compact(store.selectedBytes))")
                        .font(.system(size: 11, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                        .background(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(store.selectedPaths.isEmpty
                                      ? MenuPalette.surface : MenuPalette.accent))
                        .foregroundStyle(store.selectedPaths.isEmpty
                                         ? MenuPalette.inkTertiary : .white)
                }
                .buttonStyle(.plain)
                .disabled(store.selectedPaths.isEmpty || store.cleanIsRunning)
            }

            Text("Cleaning always asks first, and goes to the Trash unless you switch modes.")
                .font(.system(size: 9))
                .foregroundStyle(MenuPalette.inkTertiary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

/// One metric tile.
private struct MetricCard: View {
    let title: String
    let value: String
    let detail: String
    let fraction: Double?
    let tint: Color
    let symbol: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: symbol).font(.system(size: 9))
                Text(title).font(.system(size: 10, weight: .semibold))
                Spacer(minLength: 0)
            }
            .foregroundStyle(MenuPalette.inkSecondary)

            Text(value)
                .font(.system(size: 19, weight: .semibold, design: .rounded))
                .foregroundStyle(MenuPalette.ink)
                .monospacedDigit()
                .fixedSize(horizontal: true, vertical: false)

            if let fraction {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(MenuPalette.track)
                        Capsule().fill(tint)
                            .frame(width: max(2, geo.size.width * min(1, max(0, fraction))))
                    }
                }
                .frame(height: 4)
            }

            Text(detail)
                .font(.system(size: 9))
                .foregroundStyle(MenuPalette.inkTertiary)
                .lineLimit(1)
        }
        .padding(9)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(MenuPalette.card))
    }
}

/// Semantic colours for the menu bar panel.
///
/// A menu bar panel follows the system appearance, so hardcoding the app's light
/// palette would leave a white card floating on a dark menu bar.
enum MenuPalette {
    static let panel = Color(nsColor: .windowBackgroundColor)
    static let card = Color(nsColor: .controlBackgroundColor)
    static let surface = Color(nsColor: .controlAccentColor).opacity(0.14)
    static let track = Color(nsColor: .quaternaryLabelColor).opacity(0.35)
    static let ink = Color(nsColor: .labelColor)
    static let inkSecondary = Color(nsColor: .secondaryLabelColor)
    static let inkTertiary = Color(nsColor: .tertiaryLabelColor)
    static let accent = Color(red: 0.176, green: 0.353, blue: 0.255)
    static let warn = Color(red: 0.706, green: 0.451, blue: 0.094)
    static let danger = Color(red: 0.702, green: 0.173, blue: 0.145)
    static let good = Color(red: 0.114, green: 0.541, blue: 0.353)
    static let info = Color(red: 0.157, green: 0.404, blue: 0.702)
}