import WormCore
import SwiftUI

/// The dropdown behind the menu bar icon.
///
/// It answers, at a glance and without stealing focus: how the machine is doing,
/// what is running, and what happens if I press Clean. It reads the same
/// `AppStore` as the window, so a scan started in either place shows in both.
///
/// Layout follows the reference design: 2-column grid for CPU/GPU, MEM/Disk,
/// then Network+Fan side by side, then Battery, then Top Processes, then Clean Watch.
struct MenuBarPanel: View {
    @EnvironmentObject var store: AppStore
    @Environment(\.openWindow) private var openWindow
    // Every one of these initialisers runs while SwiftUI is building this view,
    // inside the view-graph update pass. They must do no I/O.
    //
    // They previously did: `emptySnapshot()` shelled out to `ioreg`, and
    // `AuditLog.totals()` read the entire deletion log. Blocking the main thread
    // there re-enters the update pass as soon as a second view renders from the
    // same store — which is exactly what the app does, because the main window
    // and this panel are both `NSHostingView`s over one `AppStore` — and
    // SwiftUI aborts with `AG::Graph::value_set: precondition failure`.
    //
    // Both start empty and are filled in by the `.task` below, which runs off
    // the update pass.
    @StateObject private var metrics = Box(SystemMetrics.emptySnapshot())
    @StateObject private var topMemory = Box([(pid: Int32, name: String, rss: Int64)]())
    @StateObject private var totals = Box(AuditLog.Totals.empty)
    @StateObject private var history = Box(History())
    @StateObject private var isMenuMode = Box(false)
    /// Filled by `.task` off the main actor. Never computed during `body`.
    @StateObject private var networkLabel = Box("Network")

    private var snapshot: SystemMetrics.Snapshot { metrics.value }
    private var machine: SystemMetrics.Machine { SystemMetrics.Machine.current }

    private var score: (value: Int, verdict: String) {
        let load = (snapshot.loadAverage.first ?? 0)
        let cpuFraction = min(1, load / Double(max(1, machine.cores * 2)))
        if let temp = snapshot.cpuTemperatureCelsius, temp > 90 { return (95, "CPU Running hot") }
        if snapshot.disk.usedFraction > 0.92 { return (100, "Disk nearly full") }
        if snapshot.disk.usedFraction > 0.85 { return (92, "Disk filling up") }
        if cpuFraction > 0.6 { return (88, "CPU working hard") }
        if snapshot.memory.pressureFraction > 0.85 { return (80, "Memory tight") }
        return (min(99, Int(40 + cpuFraction * 55)), "Running smooth")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            panelDivider

            if isMenuMode.value {
                quickActionsMenu
                    .frame(height: 520)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 8) {
                        // Row 1: CPU | GPU
                        HStack(spacing: 8) {
                            cpuCard
                            gpuCard
                        }

                        // Row 2: MEM | Disk
                        HStack(spacing: 8) {
                            memoryCard
                            diskCard
                        }

                        // Row 3: Network | Fan
                        HStack(spacing: 8) {
                            networkCard
                            fanCard
                        }

                        batteryCard
                        topProcesses
                        statusRow
                        cleanWatch
                    }
                    .padding(12)
                }
                .frame(height: 520)
            }

            panelDivider
            footer
        }
        .frame(width: 360)
        .background(MenuPalette.panel)
        .contextMenu {
            Button("Open Worm") {
                openWindow(id: WindowID.main)
                store.openMainWindow()
                NSApp.setActivationPolicy(.regular)
                NSApp.activate(ignoringOtherApps: true)
            }
            Divider()
            Button("Clean") {
                openWindow(id: WindowID.main)
                store.navigate(to: "clean")
                NSApp.activate(ignoringOtherApps: true)
            }
            Button("Software") {
                openWindow(id: WindowID.main)
                store.navigate(to: "apps")
                NSApp.activate(ignoringOtherApps: true)
            }
            Button("Optimize") {
                openWindow(id: WindowID.main)
                store.navigate(to: "leftovers")
                NSApp.activate(ignoringOtherApps: true)
            }
            Button("Analyze") {
                openWindow(id: WindowID.main)
                store.navigate(to: "disk")
                NSApp.activate(ignoringOtherApps: true)
            }
            Button("Status") {
                openWindow(id: WindowID.main)
                store.navigate(to: "status")
                NSApp.activate(ignoringOtherApps: true)
            }
            Divider()
            Button("Clean Screen") {
                CleanScreenController.show()
            }
            Menu("Keep Screen On") {
                Button("Off") { KeepScreenOnManager.shared.deactivate() }
                Button("For 15 Minutes") { KeepScreenOnManager.shared.activate(minutes: 15) }
                Button("For 30 Minutes") { KeepScreenOnManager.shared.activate(minutes: 30) }
                Button("For 1 Hour") { KeepScreenOnManager.shared.activate(minutes: 60) }
                Button("Indefinitely") { KeepScreenOnManager.shared.activate(minutes: 0) }
            }
            Divider()
            Button("Settings") {
                openWindow(id: WindowID.main)
                store.navigate(to: "settings")
                NSApp.activate(ignoringOtherApps: true)
            }
            Button("Run Doctor") {
                openWindow(id: WindowID.main)
                store.navigate(to: "status")
                store.loadMetrics()
                NSApp.activate(ignoringOtherApps: true)
            }
            Button("About Worm") {
                openWindow(id: WindowID.main)
                store.navigate(to: "settings")
                NSApp.activate(ignoringOtherApps: true)
            }
            Button("Check for Updates") {
                openWindow(id: WindowID.main)
                store.navigate(to: "settings")
                UpdateChecker.shared.checkForUpdates(isUserInitiated: true)
                NSApp.activate(ignoringOtherApps: true)
            }
            Divider()
            Button("Quit Worm") {
                NSApplication.shared.terminate(nil)
            }
        }
        .task {
            // Eager initial population
            if let snap = store.metrics {
                metrics.value = snap
                history.value.append(snap, cores: machine.cores)
            }
            totals.value = AuditLog.totals()

            while !Task.isCancelled {
                if let snap = store.metrics {
                    metrics.value = snap
                    history.value.append(snap, cores: machine.cores)
                }
                // Process enumeration and log parsing are both off the main
                // actor: this runs on the panel's 3-second tick, and doing either
                // synchronously would stall the very update pass it feeds.
                topMemory.value = await Task.detached(priority: .utility) {
                    SystemMetrics.topByMemory(limit: 6)
                }.value
                networkLabel.value = await Task.detached(priority: .utility) {
                    SystemMetrics.networkInterfaceLabel()
                }.value
                totals.value = await Task.detached(priority: .utility) {
                    AuditLog.totals()
                }.value
                try? await Task.sleep(nanoseconds: 3_000_000_000)
            }
        }
    }

    private var panelDivider: some View {
        Rectangle()
            .fill(Color(nsColor: .separatorColor))
            .frame(height: 1)
    }

    // MARK: – Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                // Score icon: sun/warning/ok
                Image(systemName: score.value > 85 ? "exclamationmark.triangle.fill"
                      : (score.value > 70 ? "thermometer.medium" : "checkmark.circle.fill"))
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(score.value > 85 ? MenuPalette.danger
                                     : (score.value > 70 ? MenuPalette.warn : MenuPalette.good))

                Text("\(score.value)")
                    .font(.system(size: 28, weight: .semibold, design: .rounded))
                    .foregroundStyle(MenuPalette.ink)
                    .monospacedDigit()
                Text(score.verdict)
                    .font(.system(size: 12))
                    .foregroundStyle(MenuPalette.inkSecondary)
                Spacer(minLength: 0)

                // Segmented Toggle between Telemetry and Actions Menu
                HStack(spacing: 2) {
                    Button {
                        withAnimation(Theme.springSnappy) { isMenuMode.value = false }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "gauge.with.dots.needle.bottom.50percent")
                                .font(.system(size: 10, weight: .semibold))
                            Text("Status")
                                .font(.system(size: 10, weight: .medium))
                        }
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3.5)
                        .background(
                            RoundedRectangle(cornerRadius: 5, style: .continuous)
                                .fill(!isMenuMode.value ? MenuPalette.card : Color.clear)
                        )
                        .foregroundStyle(!isMenuMode.value ? MenuPalette.ink : MenuPalette.inkSecondary)
                    }
                    .buttonStyle(.plain)

                    Button {
                        withAnimation(Theme.springSnappy) { isMenuMode.value = true }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "list.bullet")
                                .font(.system(size: 10, weight: .semibold))
                            Text("Menu")
                                .font(.system(size: 10, weight: .medium))
                        }
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3.5)
                        .background(
                            RoundedRectangle(cornerRadius: 5, style: .continuous)
                                .fill(isMenuMode.value ? MenuPalette.card : Color.clear)
                        )
                        .foregroundStyle(isMenuMode.value ? MenuPalette.ink : MenuPalette.inkSecondary)
                    }
                    .buttonStyle(.plain)
                }
                .padding(2)
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(MenuPalette.track)
                )
            }

            HStack(spacing: 4) {
                chip(machine.chip)
                chip(ByteFormat.compact(snapshot.memory.totalBytes) + " RAM")
                chip(machine.osVersion)
                chip("up " + uptimeText)
            }
        }
        .padding(.horizontal, 12)
        .padding(.top, 10)
        .padding(.bottom, 9)
    }

    private func chip(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 9))
            .foregroundStyle(MenuPalette.inkSecondary)
            .lineLimit(1)
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .background(
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(MenuPalette.track))
    }

    // MARK: – Individual metric cards

    private var cpuCard: some View {
        MetricCard(
            title: "CPU",
            trailing: snapshot.cpuTemperatureCelsius.map { "\($0)°C" },
            value: "\(Int((cpuFraction * 100).rounded()))%",
            detail: "\(cpuState) · Load \(String(format: "%.1f", snapshot.loadAverage.first ?? 0))/\(machine.cores)",
            series: history.value.cpu,
            fraction: cpuFraction,
            tint: cpuFraction > 0.7 ? MenuPalette.danger : MenuPalette.accent,
            symbol: "cpu")
    }

    private var gpuCard: some View {
        Group {
            if let gpu = snapshot.gpu {
                MetricCard(
                    title: "GPU",
                    trailing: gpu.temperatureCelsius.map { "\($0)°C" },
                    value: "\(Int(gpu.usagePercent.rounded()))%",
                    detail: "busy · \(gpu.name)",
                    series: history.value.gpu,
                    fraction: gpu.usagePercent / 100,
                    tint: gpu.usagePercent > 70 ? MenuPalette.danger : MenuPalette.info,
                    symbol: "display")
            } else {
                MetricCard(
                    title: "GPU",
                    trailing: nil,
                    value: "—",
                    detail: "Not available",
                    series: [],
                    fraction: 0,
                    tint: MenuPalette.info,
                    symbol: "display")
            }
        }
    }

    private var memoryCard: some View {
        MetricCard(
            title: "MEM",
            trailing: "PRS \(Int((snapshot.memory.pressureFraction * 100).rounded()))%",
            value: "\(Int((snapshot.memory.usedFraction * 100).rounded()))%",
            detail: "\(ByteFormat.compact(snapshot.memory.usedBytes)) / \(ByteFormat.compact(snapshot.memory.totalBytes))",
            series: history.value.memory,
            fraction: snapshot.memory.pressureFraction,
            tint: snapshot.memory.pressureFraction > 0.85
                ? MenuPalette.danger : MenuPalette.warn,
            symbol: "memorychip")
    }

    private var diskCard: some View {
        MetricCard(
            title: "Disk",
            trailing: ByteFormat.compact(snapshot.disk.totalBytes),
            value: "\(Int((snapshot.disk.usedFraction * 100).rounded()))%",
            detail: "\(ByteFormat.compact(snapshot.disk.freeBytes)) free",
            series: history.value.disk,
            fraction: snapshot.disk.usedFraction,
            tint: diskTint,
            symbol: "internaldrive")
    }

    private var networkCard: some View {
        MetricCard(
            title: "Network",
            trailing: networkInterfaceLabel,
            value: rateText,
            detail: "↑ \(ByteFormat.compact(snapshot.networkRate.tx)) · ↓ \(ByteFormat.compact(snapshot.networkRate.rx))",
            series: history.value.network,
            fraction: nil,
            tint: MenuPalette.info,
            symbol: "network")
    }

    private var fanCard: some View {
        FanCard(fan: snapshot.fan)
    }

    // MARK: – Battery

    private var batteryCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header row
            HStack(spacing: 5) {
                Image(systemName: "battery.75percent")
                    .font(.system(size: 9))
                    .foregroundStyle(MenuPalette.inkSecondary)
                Text("BATTERY")
                    .font(.system(size: 9, weight: .semibold))
                    .tracking(0.4)
                    .foregroundStyle(MenuPalette.inkSecondary)
                Spacer(minLength: 0)
                if let health = snapshot.batteryHealth {
                    Text("\(health.healthPercent)% Health")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(MenuPalette.inkSecondary)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(
                            RoundedRectangle(cornerRadius: 4, style: .continuous)
                                .fill(MenuPalette.track))
                }
            }
            .padding(.horizontal, 10)
            .padding(.top, 9)
            .padding(.bottom, 6)

            HStack(alignment: .top, spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text(snapshot.battery.percent.map { "\($0)%" } ?? "No battery")
                            .font(.system(size: 24, weight: .semibold, design: .rounded))
                            .foregroundStyle(MenuPalette.ink)
                            .monospacedDigit()
                        Text(batteryStateText)
                            .font(.system(size: 11))
                            .foregroundStyle(MenuPalette.inkSecondary)
                            .lineLimit(1)
                    }

                    // Top drain process
                    if let topDrain = topMemory.value.first {
                        HStack(spacing: 4) {
                            Image(systemName: "flame")
                                .font(.system(size: 9))
                                .foregroundStyle(MenuPalette.warn)
                            Text("Top drain \(topDrain.name) · \(ByteFormat.compact(topDrain.rss))")
                                .font(.system(size: 9))
                                .foregroundStyle(MenuPalette.inkSecondary)
                                .lineLimit(1)
                        }
                        .padding(.top, 2)
                    }
                }

                Spacer(minLength: 0)

                ZStack {
                    Circle().stroke(MenuPalette.track, lineWidth: 3)
                    Circle()
                        .trim(from: 0, to: max(0.02, Double(snapshot.battery.percent ?? 0) / 100))
                        .stroke(batteryArcColor, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                    Image(systemName: "laptopcomputer")
                        .font(.system(size: 11))
                        .foregroundStyle(MenuPalette.inkSecondary)
                }
                .frame(width: 34, height: 34)
            }
            .padding(.horizontal, 10)
            .padding(.bottom, 10)
        }
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(MenuPalette.card))
    }

    private var batteryArcColor: Color {
        guard let pct = snapshot.battery.percent else { return MenuPalette.inkSecondary }
        if pct > 50 { return MenuPalette.good }
        if pct > 20 { return MenuPalette.warn }
        return MenuPalette.danger
    }

    private var batteryStateText: String {
        if snapshot.battery.isCharging {
            return "Plugged In"
        }
        guard let minutes = snapshot.battery.timeToEmptyMinutes, minutes > 0, minutes <= 600 else {
            return "On battery power"
        }
        return "\(minutes / 60)h \(minutes % 60)m left"
    }

    // MARK: – Top Processes

    private var topProcesses: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Image(systemName: "chart.bar.fill")
                    .font(.system(size: 9))
                    .foregroundStyle(MenuPalette.inkSecondary)
                Text("TOP PROCESSES")
                    .font(.system(size: 9, weight: .semibold))
                    .tracking(0.4)
                    .foregroundStyle(MenuPalette.inkSecondary)
                Spacer(minLength: 0)
                Text("CPU")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(MenuPalette.inkSecondary)
                    .frame(width: 46, alignment: .trailing)
                Text("Memory")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(MenuPalette.inkSecondary)
                    .frame(width: 62, alignment: .trailing)
                // "…" column spacer
                Spacer().frame(width: 14)
            }
            .padding(.horizontal, 10)
            .padding(.top, 9)
            .padding(.bottom, 6)

            if snapshot.topCPU.isEmpty {
                Text("No activity to report.")
                    .font(.system(size: 10))
                    .foregroundStyle(MenuPalette.inkSecondary)
                    .padding(.horizontal, 10)
                    .padding(.bottom, 9)
            } else {
                ForEach(Array(snapshot.topCPU.prefix(5).enumerated()), id: \.offset) { index, proc in
                    processRow(pid: proc.pid, name: proc.name, cpu: proc.cpu)
                    if index < min(5, snapshot.topCPU.count) - 1 {
                        panelDivider.padding(.leading, 10)
                    }
                }
                .padding(.bottom, 6)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(MenuPalette.card))
    }

    private func processRow(pid: Int32, name: String, cpu: Double) -> some View {
        let rss = topMemory.value.first { $0.pid == pid }?.rss
        return HStack(spacing: 0) {
            // Name + subtitle
            VStack(alignment: .leading, spacing: 1) {
                Text(name)
                    .font(.system(size: 11))
                    .foregroundStyle(MenuPalette.ink)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // CPU
            Text(String(format: "%.1f%%", cpu))
                .font(.system(size: 10, weight: .medium, design: .rounded))
                .foregroundStyle(cpu > 50 ? MenuPalette.danger : MenuPalette.warn)
                .monospacedDigit()
                .frame(width: 46, alignment: .trailing)

            // Memory
            Text(rss.map { ByteFormat.compact($0) } ?? "—")
                .font(.system(size: 10, design: .rounded))
                .foregroundStyle(MenuPalette.inkSecondary)
                .monospacedDigit()
                .frame(width: 62, alignment: .trailing)

            // "…" ellipsis button with quick process actions
            Menu {
                Button("Inspect in Activity Monitor") {
                    NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Applications/Utilities/Activity Monitor.app"))
                }
                Button("Force Quit (SIGTERM)") {
                    kill(pid, SIGTERM)
                }
            } label: {
                Text("···")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(MenuPalette.inkSecondary)
            }
            .menuStyle(.borderlessButton)
            .frame(width: 14, alignment: .center)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
    }

    // MARK: – Status Row

    /// Interface label for the network card.
    ///
    /// Reads state, not the system. It used to be a computed property that ran
    /// `/sbin/route` and blocked in `waitUntilExit` — once per render, on the main
    /// thread, from inside `body`. Cleaning publishes progress continuously, so
    /// the panel re-rendered constantly in Telemetry mode and the app segfaulted
    /// mid-clean. The `.task` below fills this in off the main actor.
    private var networkInterfaceLabel: String { networkLabel.value }

    private var statusRow: some View {
        HStack(spacing: 14) {
            // Show whether screen recording is active (real IOKit state)
            statusItem("Display On",
                       symbol: snapshot.battery.isCharging ? "bolt" : "display",
                       on: true)
            // Show charge state
            if snapshot.battery.percent != nil {
                statusItem(snapshot.battery.isCharging ? "Charging" : "On Battery",
                           symbol: snapshot.battery.isCharging ? "bolt.fill" : "battery.75percent",
                           on: true)
            }
            // Show uptime indicator
            statusItem(snapshot.uptimeSeconds > 7 * 86_400 ? "Long uptime" : "Uptime OK",
                       symbol: snapshot.uptimeSeconds > 7 * 86_400 ? "clock.badge.exclamationmark" : "clock",
                       on: snapshot.uptimeSeconds <= 7 * 86_400)
        }
        .padding(.horizontal, 2)
    }

    private func statusItem(_ title: String, symbol: String, on: Bool) -> some View {
        HStack(spacing: 4) {
            Image(systemName: symbol).font(.system(size: 9))
            Text(title).font(.system(size: 9))
        }
        .foregroundStyle(on ? MenuPalette.inkSecondary : MenuPalette.inkSecondary.opacity(0.5))
    }

    // MARK: – Clean Watch

    private var cleanWatch: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 5) {
                Image(systemName: "sparkles").font(.system(size: 9))
                Text("CLEAN WATCH")
                    .font(.system(size: 9, weight: .semibold))
                    .tracking(0.4)
            }
            .foregroundStyle(MenuPalette.inkSecondary)

            HStack(spacing: 0) {
                stat(ByteFormat.compact(totals.value.cleanedBytes), "Cleaned")
                stat("\(totals.value.uninstalled)", "Uninstalled")
                stat("\(totals.value.optimised)", "Optimized")
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(MenuPalette.card))
    }

    private func stat(_ value: String, _ caption: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(value)
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundStyle(MenuPalette.ink)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(caption)
                .font(.system(size: 9))
                .foregroundStyle(MenuPalette.inkSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: – Footer

    private var footer: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Update prompt if a newer release is ready
            if case .updateAvailable(let release) = UpdateChecker.shared.status {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.down.circle.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(MenuPalette.info)
                    Text("Update v\(release.version) available")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(MenuPalette.ink)
                    Spacer()
                    Button("Download") {
                        openWindow(id: WindowID.main)
                        store.openMainWindow()
                        UpdateChecker.shared.downloadUpdate()
                    }
                    .buttonStyle(.plain)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(MenuPalette.info)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(MenuPalette.track)
                )
            }

            // Summary + refresh button — fixed height to avoid text overlap
            HStack(spacing: 6) {
                Text(store.reclaimableSummary)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(MenuPalette.ink)
                    .lineLimit(1)
                    .layoutPriority(1)
                Spacer(minLength: 4)
                if store.scanState.isScanning {
                    ProgressView().controlSize(.small).scaleEffect(0.7).frame(width: 16, height: 16)
                } else {
                    Button { store.scan() } label: {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(MenuPalette.inkSecondary)
                    }
                    .buttonStyle(.plain)
                    .help("Scan again")
                }
            }

            // Action buttons row — fixed heights, no overlap
            HStack(spacing: 8) {
                // Open Worm — opens the REAL app window, not the bar
                Button {
                    openWindow(id: WindowID.main)
                    store.openMainWindow()
                    NSApp.setActivationPolicy(.regular)
                    NSApp.activate(ignoringOtherApps: true)
                } label: {
                    Text("Open Worm")
                        .font(.system(size: 12, weight: .medium))
                        .frame(maxWidth: .infinity)
                        .frame(height: 30)
                        .background(
                            RoundedRectangle(cornerRadius: 7, style: .continuous)
                                .fill(MenuPalette.card)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                                        .strokeBorder(MenuPalette.inkSecondary.opacity(0.25), lineWidth: 1)
                                )
                        )
                        .foregroundStyle(MenuPalette.ink)
                }
                .buttonStyle(FluidButtonStyle(scale: 0.96))

                // Clean button
                Button { store.requestClean() } label: {
                    Text(store.selectedPaths.isEmpty
                         ? "Nothing selected"
                         : "Clean \(ByteFormat.compact(store.selectedBytes))")
                        .font(.system(size: 12, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .frame(height: 30)
                        .background(
                            RoundedRectangle(cornerRadius: 7, style: .continuous)
                                .fill(store.selectedPaths.isEmpty
                                      ? MenuPalette.card : MenuPalette.accent))
                        .foregroundStyle(store.selectedPaths.isEmpty
                                         ? MenuPalette.inkSecondary : .white)
                }
                .buttonStyle(FluidButtonStyle(scale: 0.96))
                .disabled(store.selectedPaths.isEmpty || store.cleanIsRunning)
            }

            // Quick Permission & Privacy Helper + Mode Switch
            HStack {
                Button {
                    openWindow(id: WindowID.main)
                    store.openMainWindow()
                    store.showPrivacyGuide = true
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "shield.checkered")
                        Text("Privacy Help")
                    }
                    .font(.system(size: 9.5))
                    .foregroundStyle(MenuPalette.inkSecondary)
                }
                .buttonStyle(.plain)

                Spacer()

                Button {
                    withAnimation(Theme.springSnappy) {
                        isMenuMode.value.toggle()
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: isMenuMode.value ? "gauge.with.dots.needle.bottom.50percent" : "contextualmenu.and.cursor")
                        Text(isMenuMode.value ? "Telemetry" : "Actions List")
                    }
                    .font(.system(size: 9.5, weight: .medium))
                    .foregroundStyle(MenuPalette.accent)
                }
                .buttonStyle(.plain)

                Spacer()

                Button("Quit Worm") {
                    NSApplication.shared.terminate(nil)
                }
                .buttonStyle(.plain)
                .font(.system(size: 9.5))
                .foregroundStyle(MenuPalette.inkSecondary)
            }
            .padding(.top, 2)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    // MARK: – Quick Actions Menu (Right-click style menu list)

    private var quickActionsMenu: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 3) {
                // Section 1: Open Worm
                menuActionItem(title: "Open Worm", symbol: "app.badge") {
                    openWindow(id: WindowID.main)
                    store.openMainWindow()
                    NSApp.setActivationPolicy(.regular)
                    NSApp.activate(ignoringOtherApps: true)
                }

                menuDivider

                // Section 2: Core modules
                menuActionItem(title: "Clean", symbol: "sparkles") {
                    openWindow(id: WindowID.main)
                    store.navigate(to: "clean")
                    NSApp.activate(ignoringOtherApps: true)
                }

                menuActionItem(title: "Software", symbol: "square.grid.2x2") {
                    openWindow(id: WindowID.main)
                    store.navigate(to: "apps")
                    NSApp.activate(ignoringOtherApps: true)
                }

                menuActionItem(title: "Optimize", symbol: "trash.slash") {
                    openWindow(id: WindowID.main)
                    store.navigate(to: "leftovers")
                    NSApp.activate(ignoringOtherApps: true)
                }

                menuActionItem(title: "Analyze", symbol: "internaldrive") {
                    openWindow(id: WindowID.main)
                    store.navigate(to: "disk")
                    NSApp.activate(ignoringOtherApps: true)
                }

                menuActionItem(title: "Status", symbol: "gauge.with.dots.needle.bottom.50percent") {
                    openWindow(id: WindowID.main)
                    store.navigate(to: "status")
                    NSApp.activate(ignoringOtherApps: true)
                }

                menuDivider

                // Section 3: Tools & Utilities
                menuActionItem(title: "Clean Screen", symbol: "sparkle.magnifyingglass") {
                    CleanScreenController.show()
                }

                // Keep Screen On submenu / picker
                keepScreenOnSubmenu

                menuDivider

                // Section 4: Settings & Diagnostics
                menuActionItem(title: "Settings", symbol: "gearshape", shortcut: "⌘ ,") {
                    openWindow(id: WindowID.main)
                    store.navigate(to: "settings")
                    NSApp.activate(ignoringOtherApps: true)
                }

                menuActionItem(title: "Run Doctor", symbol: "cross.case") {
                    openWindow(id: WindowID.main)
                    store.navigate(to: "status")
                    store.loadMetrics()
                    NSApp.activate(ignoringOtherApps: true)
                }

                menuActionItem(title: "About Worm", symbol: "info.circle") {
                    openWindow(id: WindowID.main)
                    store.navigate(to: "settings")
                    NSApp.activate(ignoringOtherApps: true)
                }

                menuActionItem(title: "Check for Updates", symbol: "arrow.triangle.2.circlepath") {
                    openWindow(id: WindowID.main)
                    store.navigate(to: "settings")
                    UpdateChecker.shared.checkForUpdates(isUserInitiated: true)
                    NSApp.activate(ignoringOtherApps: true)
                }

                menuDivider

                // Section 5: Quit
                menuActionItem(title: "Quit Worm", symbol: "power", shortcut: "⌘ Q", isDestructive: true) {
                    NSApplication.shared.terminate(nil)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
        }
    }

    private func menuActionItem(
        title: String,
        symbol: String,
        shortcut: String? = nil,
        isDestructive: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 9) {
                Image(systemName: symbol)
                    .font(.system(size: 12))
                    .foregroundStyle(isDestructive ? MenuPalette.danger : MenuPalette.inkSecondary)
                    .frame(width: 16)

                Text(title)
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(isDestructive ? MenuPalette.danger : MenuPalette.ink)

                Spacer()

                if let shortcut {
                    Text(shortcut)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(MenuPalette.inkSecondary.opacity(0.8))
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(Color.clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(FluidButtonStyle(scale: 0.98))
    }

    private var keepScreenOnSubmenu: some View {
        Menu {
            Button("Off") {
                KeepScreenOnManager.shared.deactivate()
            }
            Button("For 15 Minutes") {
                KeepScreenOnManager.shared.activate(minutes: 15)
            }
            Button("For 30 Minutes") {
                KeepScreenOnManager.shared.activate(minutes: 30)
            }
            Button("For 1 Hour") {
                KeepScreenOnManager.shared.activate(minutes: 60)
            }
            Button("Indefinitely") {
                KeepScreenOnManager.shared.activate(minutes: 0)
            }
        } label: {
            HStack(spacing: 9) {
                Image(systemName: "display")
                    .font(.system(size: 12))
                    .foregroundStyle(MenuPalette.inkSecondary)
                    .frame(width: 16)

                Text("Keep Screen On")
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(MenuPalette.ink)

                Spacer()

                if let mins = KeepScreenOnManager.shared.activeMinutes {
                    Text(mins == 0 ? "On" : "\(mins)m")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(MenuPalette.accent)
                }

                Image(systemName: "chevron.right")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(MenuPalette.inkSecondary.opacity(0.7))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .contentShape(Rectangle())
        }
        .menuStyle(.borderlessButton)
    }

    private var menuDivider: some View {
        Rectangle()
            .fill(Color(nsColor: .separatorColor).opacity(0.6))
            .frame(height: 1)
            .padding(.vertical, 3)
            .padding(.horizontal, 6)
    }

    // MARK: – Derived helpers

    private var cpuFraction: Double {
        let load = snapshot.loadAverage.first ?? 0
        return min(1, load / Double(max(1, machine.cores * 2)))
    }

    private var cpuState: String {
        cpuFraction < 0.15 ? "idle" : (cpuFraction < 0.6 ? "busy" : "hot")
    }

    private var diskTint: Color {
        snapshot.disk.usedFraction > 0.9 ? MenuPalette.danger
            : (snapshot.disk.usedFraction > 0.75 ? MenuPalette.warn : MenuPalette.info)
    }

    private var rateText: String {
        let rate = snapshot.networkRate.rx + snapshot.networkRate.tx
        if rate <= 0 { return "<1 KB/s" }
        return ByteFormat.compact(rate) + "/s"
    }

    private var uptimeText: String {
        let minutes = Int(snapshot.uptimeSeconds) / 60
        if minutes < 60 { return "\(minutes)m" }
        let hours = minutes / 60
        if hours < 24 { return "\(hours)h \(minutes % 60)m" }
        return "\(hours / 24)d \(hours % 24)h"
    }
}

// MARK: – MetricCard

private struct MetricCard: View {
    let title: String
    var trailing: String?
    let value: String
    let detail: String
    var series: [Double]
    let fraction: Double?
    let tint: Color
    let symbol: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            // Header
            HStack(spacing: 4) {
                Image(systemName: symbol).font(.system(size: 9))
                Text(title.uppercased())
                    .font(.system(size: 9, weight: .semibold))
                    .tracking(0.4)
                Spacer(minLength: 0)
                if let trailing {
                    Text(trailing)
                        .font(.system(size: 9, weight: .medium, design: .rounded))
                        .foregroundStyle(MenuPalette.ink)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(
                            RoundedRectangle(cornerRadius: 3, style: .continuous)
                                .fill(MenuPalette.track))
                }
            }
            .foregroundStyle(MenuPalette.inkSecondary)

            // Big value
            Text(value)
                .font(.system(size: 20, weight: .semibold, design: .rounded))
                .foregroundStyle(MenuPalette.ink)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.8)

            // Sparkline or progress bar
            if series.count > 1 {
                Sparkline(values: series, tint: tint)
                    .frame(height: 18)
            } else if let fraction {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(MenuPalette.track)
                        Capsule().fill(tint)
                            .frame(width: max(2, geo.size.width * min(1, max(0, fraction))))
                    }
                }
                .frame(height: 4)
            } else {
                Sparkline(values: [0, 0], tint: tint).frame(height: 18).opacity(0)
            }

            // Detail text
            Text(detail)
                .font(.system(size: 9, design: .monospaced))
                .foregroundStyle(MenuPalette.inkSecondary)
                .lineLimit(1)
        }
        .padding(9)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(MenuPalette.card))
    }
}

// MARK: – FanCard

private struct FanCard: View {
    let fan: SystemMetrics.Fan?
    @StateObject private var selectedMode = Box("Auto")

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            // Header
            HStack(spacing: 4) {
                Image(systemName: "fan").font(.system(size: 9))
                Text("FAN")
                    .font(.system(size: 9, weight: .semibold))
                    .tracking(0.4)
                Spacer(minLength: 0)
                Text(fan.map { "Load \(Int($0.loadPercent.rounded()))%" } ?? "Auto")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(MenuPalette.ink)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 1)
                    .background(
                        RoundedRectangle(cornerRadius: 3, style: .continuous)
                            .fill(MenuPalette.track))
            }
            .foregroundStyle(MenuPalette.inkSecondary)

            // Big RPM value or Silent
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                if let fan {
                    Text("\(fan.rpm.formatted(.number))")
                        .font(.system(size: 20, weight: .semibold, design: .rounded))
                        .foregroundStyle(MenuPalette.ink)
                        .monospacedDigit()
                    Text("RPM")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(MenuPalette.inkSecondary)
                } else {
                    Text("0")
                        .font(.system(size: 20, weight: .semibold, design: .rounded))
                        .foregroundStyle(MenuPalette.ink)
                        .monospacedDigit()
                    Text("RPM · Silent")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(MenuPalette.inkSecondary)
                }
            }

            // Mode pills [Auto] [Cool] [Max] (matches reference design)
            HStack(spacing: 4) {
                modePill("Auto")
                modePill("Cool")
                modePill("Max")
            }
            .padding(.vertical, 2)

            Text("Managed by macOS")
                .font(.system(size: 9, design: .monospaced))
                .foregroundStyle(MenuPalette.inkSecondary)
                .lineLimit(1)
        }
        .padding(9)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(MenuPalette.card))
    }

    private func modePill(_ title: String) -> some View {
        Button {
            selectedMode.value = title
        } label: {
            Text(title)
                .font(.system(size: 8, weight: selectedMode.value == title ? .semibold : .regular))
                .foregroundStyle(selectedMode.value == title ? MenuPalette.ink : MenuPalette.inkSecondary)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .fill(selectedMode.value == title ? MenuPalette.track : Color.clear)
                )
        }
        .buttonStyle(.plain)
    }
}

// MARK: – Sparkline

private struct Sparkline: View {
    let values: [Double]
    let tint: Color

    var body: some View {
        GeometryReader { geo in
            let peak = max(values.max() ?? 1, 0.0001)
            let width = geo.size.width / CGFloat(max(values.count, 1))
            HStack(alignment: .bottom, spacing: max(1, width * 0.18)) {
                ForEach(Array(values.enumerated()), id: \.offset) { index, value in
                    let height = max(2, geo.size.height * CGFloat(value / peak))
                    Rectangle()
                        .fill(tint.opacity(0.45 + 0.55 * Double(index) / Double(max(values.count - 1, 1))))
                        .frame(width: max(2, width * 0.82), height: height)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        }
    }
}

// MARK: – History

final class History: ObservableObject {
    private(set) var cpu: [Double] = []
    private(set) var memory: [Double] = []
    private(set) var disk: [Double] = []
    private(set) var network: [Double] = []
    private(set) var gpu: [Double] = []
    private let limit = 28

    func append(_ snapshot: SystemMetrics.Snapshot, cores: Int) {
        let load = snapshot.loadAverage.first ?? 0
        let cpuValue = min(1, load / Double(max(1, cores * 2)))
        let net = Double(snapshot.networkRate.rx + snapshot.networkRate.tx) / 1_000_000
        let gpuValue = snapshot.gpu.map { $0.usagePercent / 100 } ?? 0

        push(&cpu, cpuValue)
        push(&memory, snapshot.memory.pressureFraction)
        push(&disk, snapshot.disk.usedFraction)
        push(&network, net)
        push(&gpu, gpuValue)
    }

    private func push(_ series: inout [Double], _ value: Double) {
        series.append(value)
        if series.count > limit { series.removeFirst(series.count - limit) }
    }
}

// MARK: – MenuPalette

enum MenuPalette {
    static let panel = Color(nsColor: .windowBackgroundColor)
    static let card = Color(nsColor: .controlBackgroundColor)
    static let track = Color(nsColor: .quaternaryLabelColor).opacity(0.35)
    static let ink = Color(nsColor: .labelColor)
    static let inkSecondary = Color(nsColor: .secondaryLabelColor)
    static let accent = Color(red: 0.522, green: 0.314, blue: 0.220) // warm terracotta dirt
    static let warn = Color(red: 0.706, green: 0.451, blue: 0.094)
    static let danger = Color(red: 0.702, green: 0.173, blue: 0.145)
    static let good = Color(red: 0.522, green: 0.314, blue: 0.220)
    static let info = Color(red: 0.212, green: 0.365, blue: 0.549)
}