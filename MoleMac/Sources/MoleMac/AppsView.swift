import SwiftUI
import MoleCore

/// Apps view: installed apps with sizes, plus leftover data from apps that are
/// already gone. Removal always goes through the Trash.
struct AppsView: View {
    @EnvironmentObject var store: AppStore
    @StateObject private var search = Box("")

    private var visibleApps: [InstalledApps.App] {
        let query = search.value.lowercased().trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else { return store.installedApps }
        return store.installedApps.filter {
            $0.name.lowercased().contains(query) || $0.id.lowercased().contains(query)
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                if store.isLoadingApps && store.installedApps.isEmpty {
                    ProgressView("Reading installed apps…")
                        .controlSize(.small)
                        .frame(maxWidth: .infinity).padding(40)
                }

                installedSection
            }
            .padding(18)
        }
        .background(Theme.background)
        .task { if store.installedApps.isEmpty { load() } }

    }

    private func load() {
        store.loadApps()
    }

    // MARK: Installed

    private var installedSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 1) {
                    Text("Installed Apps")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Theme.ink)
                    Text("\(store.installedApps.count) apps · removal moves to the Trash")
                        .font(.system(size: 10))
                        .foregroundStyle(Theme.inkTertiary)
                }
                Spacer()
                HStack(spacing: 6) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 10))
                        .foregroundStyle(Theme.inkTertiary)
                    TextField("Filter apps", text: search.binding)
                        .textFieldStyle(.plain)
                        .font(.system(size: 11))
                        .frame(width: 150)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(Theme.background,
                            in: RoundedRectangle(cornerRadius: Theme.radius, style: .continuous))
            }

            VStack(spacing: 0) {
                ForEach(Array(visibleApps.enumerated()), id: \.element.id) { index, app in
                    appRow(app)
                    if index < visibleApps.count - 1 { Divider2().padding(.leading, 34) }
                }
            }
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: Theme.radiusLarge,
                                                            style: .continuous))
        }
    }

    private func appRow(_ app: InstalledApps.App) -> some View {
        HStack(spacing: 10) {
            AppIcon(app: app, size: 22)

            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 5) {
                    Text(app.name)
                        .font(.system(size: 12))
                        .foregroundStyle(app.isProtected ? Theme.inkSecondary : Theme.ink)
                    if app.isRunning {
                        Badge(text: "Running", color: Theme.accent, background: Theme.accentSoft)
                    }
                    if app.isProtected, let reason = app.protectionReason {
                        Badge(text: reason, color: Theme.inkSecondary, background: Theme.background)
                    }
                }
                Text(app.id)
                    .font(.system(size: 10))
                    .foregroundStyle(Theme.inkTertiary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            Spacer(minLength: 6)

            Text(ByteFormat.compact(app.sizeBytes))
                .font(.system(size: 11, design: .rounded))
                .foregroundStyle(Theme.inkSecondary)
                .monospacedDigit()

            Button {
                // The uninstall sheet lists this app's leftover files first.
                store.requestRemoval(of: app)
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: 11))
                    .frame(width: 22, height: 20)
            }
            .buttonStyle(.plain)
            .foregroundStyle(Theme.inkTertiary)
            .disabled(app.isProtected)
            .help(app.isProtected
                  ? "\(app.protectionReason ?? "Protected") — cannot be removed here"
                  : "Move \(app.name) to the Trash")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .contentShape(Rectangle())
        .contextMenu {
            Button("Reveal in Finder") { store.revealInFinder(app.path) }
            Button("Protect This App's Cache") { store.addToProtectList(app.path) }
        }
    }

}

/// Reads the app's icon. Missing icons fall back to the first letter rather than
/// a generic placeholder, so the list stays scannable.
struct AppIcon: View {
    let app: InstalledApps.App
    var size: CGFloat

    var body: some View {
        Group {
            if let icon = NSWorkspace.shared.icon(forFile: app.path).isTemplate
                ? nil : NSWorkspace.shared.icon(forFile: app.path), icon.size.width > 1 {
                Image(nsImage: icon)
                    .resizable()
                    .frame(width: size, height: size)
            } else {
                RoundedRectangle(cornerRadius: size * 0.22, style: .continuous)
                    .fill(Theme.hairline)
                    .overlay(
                        Text(String(app.name.prefix(1)).uppercased())
                            .font(.system(size: size * 0.45, weight: .medium))
                            .foregroundStyle(Theme.inkSecondary))
            }
        }
        .frame(width: size, height: size)
    }
}