import SwiftUI
import MoleCore

@main
struct MoleMacApp: App {
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

        // The menu bar item is the app's persistent surface: it keeps the scan
        // result one click away without the window, which is the whole point of a
        // cleanup tool you trust to run in the background.
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
        }
    }
}

enum WindowID {
    static let main = "main"
}

/// The menu bar glyph: the icon normally, the recoverable size when there is one,
/// so the bar itself answers "is it worth opening?".
///
/// `store` is observed here rather than injected as an environment object: the
/// `App` body does not depend on `store`, so a label reading it that way was
/// never invalidated when a scan finished and sat on the icon indefinitely.
struct MenuBarLabel: View {
    @ObservedObject var store: AppStore

    var body: some View {
        if store.selectedBytes > 0 {
            Text(ByteFormat.compact(store.selectedBytes))
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .help("\(ByteFormat.compact(store.selectedBytes)) selected to clean")
        } else {
            Image(systemName: "sparkles")
                .help("MoleMac — nothing selected")
        }
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

    var body: some View {
        VStack(spacing: 0) {
            tabBar
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
        .frame(minWidth: 1000, minHeight: 640)
        .sheet(isPresented: Binding(
            get: { store.cleanIsRunning },
            set: { if !$0 { store.dismissCleanSummary() } })) {
            CleanProgressSheet().environmentObject(store)
        }
        .overlay(alignment: .top) {
            if let banner = store.banner { BannerView(banner: banner) }
        }
        .task {
            store.scan()
            store.loadOrphans()
            store.loadMetrics()
        }
        .sheet(item: $store.removalPlan) { plan in
            UninstallLeftoverSheet(plan: plan).environmentObject(store)
        }
        .sheet(item: Binding(
            get: { store.pendingCleanConfirmation },
            set: { if $0 == nil { store.pendingCleanConfirmation = nil } })) { _ in
            CleanConfirmSheet().environmentObject(store)
        }
    }

    private var tabBar: some View {
        HStack(spacing: 0) {
            ForEach([Tab.clean, .leftovers, .apps, .disk, .status, .settings], id: \.self) { tab in
                tabButton(tab)
            }
            Spacer()
            if store.banner != nil {
                Button { store.banner = nil } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 9))
                        .foregroundStyle(Theme.inkTertiary)
                }
                .buttonStyle(.plain)
                .padding(.trailing, 14)
            }
        }
        .padding(.top, 8)
        .padding(.bottom, 8)
        .background(Theme.background)
    }

    private func tabButton(_ tab: Tab) -> some View {
        let isActive = selection.value == tab
        return Button {
            selection.value = tab
        } label: {
            HStack(spacing: 5) {
                Image(systemName: symbol(tab))
                    .font(.system(size: 11, weight: .medium))
                Text(title(tab))
                    .font(.system(size: 12, weight: isActive ? .semibold : .regular))
            }
            .foregroundStyle(isActive ? Theme.ink : Theme.inkSecondary)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: Theme.radius, style: .continuous)
                    .fill(isActive ? Theme.surface : .clear))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.radius, style: .continuous)
                    .strokeBorder(isActive ? Theme.hairline : .clear, lineWidth: 1))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
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