import SwiftUI
import MoleCore

@main
struct WormApp: App {
    @StateObject private var store = AppStore()

    var body: some Scene {
        WindowGroup(id: WindowID.main) {
            RootView()
                .environmentObject(store)
                .tint(Theme.accent)
                .onAppear {
                    store.mainWindowOpener = {
                        NSApp.setActivationPolicy(.regular)
                        NSApp.activate(ignoringOtherApps: true)
                    }
                }
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentMinSize)
        .defaultSize(width: 1080, height: 720)

        // The menu bar item is the app's persistent surface:
        // Normal click opens the rich Status & Telemetry panel.
        // Right-click (or secondary tap) opens the quick native Actions Menu.
        MenuBarExtra {
            MenuBarPanel()
                .environmentObject(store)
        } label: {
            MenuBarLabel(store: store)
        }
        .menuBarExtraStyle(.window)
        .commands {
            CommandGroup(replacing: .newItem) {}
            CommandMenu("Clean") {
                Button("Scan") { store.scan() }
                    .keyboardShortcut("r", modifiers: .command)
                Button("Clean Selected…") { store.requestClean() }
                    .keyboardShortcut(.return, modifiers: [.command])
                    .disabled(store.selectedPaths.isEmpty)
                Divider()
                Button("Empty Trash") { store.emptyTrash() }
                Button("Reveal Log Folder") {
                    NSWorkspace.shared.activateFileViewerSelecting([Paths.logDir])
                }
            }
            CommandGroup(replacing: .help) {
                Button("macOS Privacy & Permissions Guide…") {
                    store.showPrivacyGuide = true
                }
                Button("Reveal Worm in Finder") {
                    NSWorkspaceBridge.revealSelfInFinder()
                }
                Button("Open Privacy & Security Settings") {
                    NSWorkspaceBridge.openFullDiskAccessSettings()
                }
            }
        }
    }
}

enum WindowID {
    static let main = "main"
}

/// The menu bar glyph.
///
/// Deliberately always the icon. `MenuBarExtra` does not re-render its label when
/// the store publishes in this SwiftUI version: the accessibility label tracked
/// the live value ("1.76 GB") while the drawn glyph stayed the icon from first
/// layout. A label that shows a number some of the time and an icon the rest of
/// the time would be a lie, so the bar says only "something is here" and the
/// panel carries the numbers.
struct MenuBarLabel: View {
    @ObservedObject var store: AppStore

    private var iconImage: NSImage {
        if let url = Bundle.main.url(forResource: "MenuBarIcon", withExtension: "png"),
           let img = NSImage(contentsOf: url) {
            img.isTemplate = true
            return img
        }
        let fallback = NSImage(systemSymbolName: "sparkles", accessibilityDescription: "Worm") ?? NSImage()
        fallback.isTemplate = true
        return fallback
    }

    var body: some View {
        Image(nsImage: iconImage)
            .help(store.selectedBytes > 0
                  ? "Worm — \(ByteFormat.compact(store.selectedBytes)) selected to clean"
                  : "Worm — nothing selected")
    }
}

struct RootView: View {
    @EnvironmentObject var store: AppStore
    @StateObject private var selection = Box(RootView.Tab.clean)
    /// Dismissible, and re-shown only after a rescan so it does not nag.
    @StateObject private var showAccessNotice = Box(true)

    enum Tab: Hashable {
        case clean, leftovers, apps, disk, status, settings
    }

    private var currentTabColor: Color {
        Theme.tabAccent(for: title(selection.value))
    }

    var body: some View {
        VStack(spacing: 0) {
            topNavigationBar
            Divider2()

            VStack(spacing: 0) {
                if SizeMeasurer.Access.lacksFullDiskAccess, showAccessNotice.value {
                    FullDiskAccessNotice {
                        showAccessNotice.value = false
                    }
                    .padding(.horizontal, 18)
                    .padding(.top, 10)
                    .padding(.bottom, 2)
                }

                Group {
                    switch selection.value {
                    case .clean: CleanView()
                    case .leftovers: LeftoversView()
                    case .apps: AppsView()
                    case .disk: DiskView()
                    case .status: StatusView()
                    case .settings: SettingsView()
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(Theme.background)
        .onReceive(store.$activeTab) { tab in
            switch tab.lowercased() {
            case "clean": selection.value = .clean
            case "leftovers", "optimize": selection.value = .leftovers
            case "apps", "software": selection.value = .apps
            case "disk", "analyze": selection.value = .disk
            case "status": selection.value = .status
            case "settings": selection.value = .settings
            default: break
            }
        }
        .frame(minWidth: 1000, minHeight: 640)
        .preferredColorScheme(store.themeMode == .dark ? .dark : (store.themeMode == .light ? .light : nil))
        .sheet(isPresented: Binding(
            get: { store.cleanIsRunning },
            set: { if !$0 { store.dismissCleanSummary() } })) {
            CleanProgressSheet().environmentObject(store)
        }
        .overlay(alignment: .top) {
            if let banner = store.banner { BannerView(banner: banner) }
        }
        .task {
            if !store.hasScannedOnce && !store.scanState.isScanning {
                store.scan()
            }
            if store.orphanGroups.isEmpty {
                store.loadOrphans()
            }
            if store.installedApps.isEmpty {
                store.loadApps()
            }
            if store.metrics == nil {
                store.loadMetrics()
            }
            UpdateChecker.shared.checkForUpdates()
        }
        .sheet(item: $store.removalPlan) { plan in
            UninstallLeftoverSheet(plan: plan).environmentObject(store)
        }
        .sheet(item: Binding(
            get: { store.pendingCleanConfirmation },
            set: { if $0 == nil { store.pendingCleanConfirmation = nil } })) { _ in
            CleanConfirmSheet().environmentObject(store)
        }
        .sheet(isPresented: $store.showPrivacyGuide) {
            PrivacyGuideSheet()
        }
    }

    private var topNavigationBar: some View {
        HStack(spacing: 12) {
            // Worm Brandmark Button: Normal click opens Status tab, Right-click (two fingers) shows native actions menu
            Button {
                selection.value = .status
                store.activeTab = "status"
            } label: {
                HStack(spacing: 7) {
                    WormBrandmarkIcon(tintColor: currentTabColor)

                    Text("Worm")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(Theme.ink)
                }
                .padding(.leading, 4)
                .padding(.trailing, 9)
                .padding(.vertical, 3)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Theme.surface)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .strokeBorder(Theme.hairline, lineWidth: 1)
                )
            }
            .buttonStyle(FluidButtonStyle(scale: 0.96))
            .focusable(false)
            .background(WithoutFocusRing())
            .fixedSize()
            .help("Click to view Status · Right-click (or two-finger click) for Actions Menu")
            .contextMenu {
                NativeMenuBarMenu(store: store)
            }
            .padding(.leading, 12)

            // Integrated segmented navigation pill tabs
            HStack(spacing: 2) {
                ForEach([Tab.clean, .leftovers, .apps, .disk, .status, .settings], id: \.self) { tab in
                    tabButton(tab)
                }
            }
            .padding(3)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Theme.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(Theme.hairline, lineWidth: 1)
            )

            Spacer()

            // Useful Quick Toolbar: Screen Clean, Keep Screen On, and Doctor
            HStack(spacing: 8) {
                // Quick Screen Clean button
                Button {
                    CleanScreenController.show()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "sparkle.magnifyingglass")
                            .font(.system(size: 10))
                        Text("Clean Screen")
                            .font(.system(size: 11, weight: .medium))
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Theme.surface, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 6, style: .continuous).strokeBorder(Theme.hairline, lineWidth: 1))
                    .foregroundStyle(Theme.inkSecondary)
                }
                .buttonStyle(FluidButtonStyle(scale: 0.95))
                .help("Blackout screen for physical cleaning")

                // Keep Screen On Quick Menu
                Menu {
                    Button("Off") { KeepScreenOnManager.shared.deactivate() }
                    Button("For 15 Minutes") { KeepScreenOnManager.shared.activate(minutes: 15) }
                    Button("For 30 Minutes") { KeepScreenOnManager.shared.activate(minutes: 30) }
                    Button("For 1 Hour") { KeepScreenOnManager.shared.activate(minutes: 60) }
                    Button("Indefinitely") { KeepScreenOnManager.shared.activate(minutes: 0) }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "display")
                            .font(.system(size: 10))
                        Text(KeepScreenOnManager.shared.activeMinutes.map { $0 == 0 ? "Awake: On" : "Awake: \($0)m" } ?? "Awake")
                            .font(.system(size: 11, weight: .medium))
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(KeepScreenOnManager.shared.activeMinutes != nil ? Theme.accent.opacity(0.18) : Theme.surface)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .strokeBorder(KeepScreenOnManager.shared.activeMinutes != nil ? Theme.accent : Theme.hairline, lineWidth: 1)
                    )
                    .foregroundStyle(KeepScreenOnManager.shared.activeMinutes != nil ? Theme.accent : Theme.inkSecondary)
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
                .help("Prevent Mac from sleeping")

                // Active section indicator pill
                HStack(spacing: 6) {
                    Circle()
                        .fill(currentTabColor)
                        .frame(width: 6, height: 6)
                    Text(title(selection.value))
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Theme.ink)
                }
                .padding(.horizontal, 9)
                .padding(.vertical, 4)
                .background(Theme.surface, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 6, style: .continuous).strokeBorder(Theme.hairline, lineWidth: 1))
            }
            .padding(.trailing, 12)
        }
        .padding(.vertical, 6)
        .background(
            ZStack {
                VisualEffectBlur(material: .headerView, blendingMode: .withinWindow)
                Theme.surface.opacity(0.7)
            }
        )
    }

    private func tabButton(_ tab: Tab) -> some View {
        let isActive = selection.value == tab
        let tabColor = Theme.tabAccent(for: title(tab))

        return Button {
            withAnimation(Theme.springBouncy) {
                selection.value = tab
            }
        } label: {
            HStack(spacing: 5) {
                Image(systemName: symbol(tab))
                    .font(.system(size: 11, weight: isActive ? .semibold : .medium))
                Text(title(tab))
                    .font(.system(size: 12, weight: isActive ? .semibold : .medium))
            }
            .foregroundStyle(isActive ? .white : Theme.inkSecondary)
            .padding(.horizontal, 11)
            .padding(.vertical, 5)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(isActive ? tabColor : Color.clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(FluidButtonStyle(scale: 0.96))
    }

    private func title(_ tab: Tab) -> String {
        switch tab {
        case .clean: return "Clean"
        case .leftovers: return "Leftovers"
        case .apps: return "Apps"
        case .disk: return "Disk"
        case .status: return "Status"
        case .settings: return "Settings"
        }
    }

    private func symbol(_ tab: Tab) -> String {
        switch tab {
        case .clean: return "sparkles"
        case .leftovers: return "trash.slash"
        case .apps: return "square.grid.2x2"
        case .disk: return "internaldrive"
        case .status: return "gauge.with.dots.needle.bottom.50percent"
        case .settings: return "gearshape"
        }
    }
}

struct BannerView: View {
    let banner: AppStore.Banner

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: symbol)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(color)

            VStack(alignment: .leading, spacing: 1) {
                Text(banner.title)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Theme.ink)
                Text(banner.detail)
                    .font(.system(size: 10))
                    .foregroundStyle(Theme.inkSecondary)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: Theme.radius, style: .continuous)
                .fill(Theme.surface))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.radius, style: .continuous)
                .strokeBorder(Theme.hairline, lineWidth: 1))
        .shadow(color: .black.opacity(0.10), radius: 8, y: 3)
        .padding(.top, 8)
        .padding(.horizontal, 16)
        .frame(maxWidth: 520)
    }

    private var color: Color {
        switch banner.kind {
        case .info: return Theme.info
        case .success: return Theme.accent
        case .warning: return Theme.warn
        case .error: return Theme.danger
        }
    }

    private var symbol: String {
        switch banner.kind {
        case .info: return "info.circle.fill"
        case .success: return "checkmark.circle.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .error: return "xmark.octagon.fill"
        }
    }
}

/// The clean, native menu list matching the reference design.
/// Contains no telemetry cards or bulky details by default — exactly:
/// Open Worm, Clean, Software, Optimize, Analyze, Status, Clean Screen, Keep Screen On,
/// Settings, Run Doctor, About Worm, Check for Updates, Quit Worm.
struct NativeMenuBarMenu: View {
    @ObservedObject var store: AppStore
    @Environment(\.openWindow) private var openWindow

    var body: some View {
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
        }

        Divider()

        Button("Settings") {
            openWindow(id: WindowID.main)
            store.navigate(to: "settings")
            NSApp.activate(ignoringOtherApps: true)
        }
        .keyboardShortcut(",", modifiers: .command)

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
        .keyboardShortcut("q", modifiers: .command)
    }
}