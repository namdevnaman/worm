import SwiftUI
import MoleCore

/// Settings: the protect list, the delete mode default, and the audit log.
struct SettingsView: View {
    @EnvironmentObject var store: AppStore
    @StateObject private var newPath = Box("")
    @StateObject private var entries = Box(AuditLog.recentEntries())
    /// Mirrors `store.showBlocked`, which is what the Clean screen reads.
    @StateObject private var showKeptItems = Box(true)
    @StateObject private var showPrivacyGuide = Box(false)

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                protectList
                defaults
                privacyCard
                auditLog
                about
            }
            .padding(18)
        }
        .sheet(isPresented: showPrivacyGuide.binding) {
            PrivacyGuideSheet()
        }
        .background(Theme.background)
        .onAppear {
            entries.value = AuditLog.recentEntries()
            showKeptItems.value = store.showBlocked
        }
    }

    // MARK: Protect list

    private var protectList: some View {
        VStack(alignment: .leading, spacing: 6) {
            VStack(alignment: .leading, spacing: 1) {
                Text("Protect List")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.ink)
                Text("Nothing under these paths is ever cleaned. A path protects itself and everything inside it.")
                    .font(.system(size: 10))
                    .foregroundStyle(Theme.inkTertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(spacing: 8) {
                HStack(spacing: 8) {
                    TextField("Add a path, e.g. ~/Library/Caches/com.vendor.app",
                              text: newPath.binding)
                        .textFieldStyle(.plain)
                        .font(.system(size: 11))
                        .onSubmit(commit)
                    Button("Add", action: commit)
                        .buttonStyle(.plain)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(newPath.value.isEmpty ? Theme.inkTertiary : Theme.accent)
                        .disabled(newPath.value.isEmpty)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(Theme.background, in: RoundedRectangle(cornerRadius: Theme.radius,
                                                                     style: .continuous))

                if store.protectList.isEmpty {
                    Text("No paths protected. Add one for anything you never want cleaned.")
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.inkTertiary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 6)
                } else {
                    VStack(spacing: 0) {
                        ForEach(Array(store.protectList.enumerated()), id: \.element) { index, entry in
                            HStack(spacing: 10) {
                                Image(systemName: "lock.fill")
                                    .font(.system(size: 10))
                                    .foregroundStyle(Theme.inkTertiary)
                                    .frame(width: 14)
                                Text(Paths.expand(entry).path)
                                    .font(.system(size: 11))
                                    .foregroundStyle(Theme.ink)
                                    .lineLimit(1)
                                    .truncationMode(.head)
                                Spacer()
                                Button {
                                    store.removeFromProtectList(entry)
                                } label: {
                                    Image(systemName: "minus.circle")
                                        .font(.system(size: 11))
                                }
                                .buttonStyle(.plain)
                                .foregroundStyle(Theme.inkTertiary)
                                .help("Stop protecting this path")
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 7)
                            if index < store.protectList.count - 1 {
                                Divider2().padding(.leading, 36)
                            }
                        }
                    }
                    .background(Theme.surface, in: RoundedRectangle(cornerRadius: Theme.radiusLarge,
                                                                    style: .continuous))
                }
            }
            .padding(12)
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: Theme.radiusLarge,
                                                            style: .continuous))
        }
    }

    private func commit() {
        let entry = newPath.value.trimmingCharacters(in: .whitespaces)
        guard !entry.isEmpty else { return }
        let expanded = Paths.expand(entry).path
        store.addToProtectList(expanded)
        newPath.value = ""
    }

    // MARK: Defaults

    private var defaults: some View {
        VStack(alignment: .leading, spacing: 6) {
            VStack(alignment: .leading, spacing: 1) {
                Text("Cleanup Defaults")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.ink)
                Text("Applies to every new clean. You can still change it per run.")
                    .font(.system(size: 10))
                    .foregroundStyle(Theme.inkTertiary)
            }

            VStack(spacing: 0) {
                HStack {
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Move to Trash")
                            .font(.system(size: 11))
                            .foregroundStyle(Theme.ink)
                        Text("Recoverable. Recommended unless you need the space back immediately.")
                            .font(.system(size: 10))
                            .foregroundStyle(Theme.inkTertiary)
                    }
                    Spacer()
                    DeleteModeSegments(mode: store.deleteModeBox.binding,
                                   trashTitle: "Trash",
                                   permanentTitle: "Permanent")
                    .frame(width: 190)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 9)

                Divider2().padding(.leading, 12)

                HStack {
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Show items kept for safety")
                            .font(.system(size: 11))
                            .foregroundStyle(Theme.ink)
                        Text("Lists what was not cleaned, and why.")
                            .font(.system(size: 10))
                            .foregroundStyle(Theme.inkTertiary)
                    }
                    Spacer()
                    Toggle("", isOn: showKeptItems.binding)
                        .labelsHidden()
                        .toggleStyle(.switch)
                        .onChange(of: showKeptItems.value) { _, new in
                            store.showBlocked = new
                        }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 9)

                Divider2().padding(.leading, 12)

                HStack {
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Appearance")
                            .font(.system(size: 11))
                            .foregroundStyle(Theme.ink)
                        Text("Choose between System, Dark (deep loam soil), or Light.")
                            .font(.system(size: 10))
                            .foregroundStyle(Theme.inkTertiary)
                    }
                    Spacer()
                    HStack(spacing: 4) {
                        ForEach(Theme.Mode.allCases) { mode in
                            let active = store.themeMode == mode
                            Button {
                                withAnimation(Theme.springSnappy) {
                                    store.themeMode = mode
                                }
                            } label: {
                                Text(mode.rawValue)
                                    .font(.system(size: 11, weight: active ? .semibold : .regular))
                                    .foregroundStyle(active ? .white : Theme.inkSecondary)
                                    .padding(.horizontal, 9)
                                    .padding(.vertical, 4)
                                    .background(
                                        RoundedRectangle(cornerRadius: 5, style: .continuous)
                                            .fill(active ? Theme.accent : .clear)
                                    )
                            }
                            .buttonStyle(FluidButtonStyle(scale: 0.96))
                        }
                    }
                    .padding(2)
                    .background(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(Theme.background)
                    )
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 9)
            }
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: Theme.radiusLarge,
                                                            style: .continuous))
        }
    }

    // MARK: Privacy & Permissions

    private var privacyCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            VStack(alignment: .leading, spacing: 1) {
                Text("macOS Privacy & Permissions")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.ink)
                Text("Fix Gatekeeper warnings, quarantine blocks, and Full Disk Access permissions.")
                    .font(.system(size: 10))
                    .foregroundStyle(Theme.inkTertiary)
            }

            VStack(spacing: 0) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 6) {
                            Image(systemName: "shield.checkered")
                                .font(.system(size: 12))
                                .foregroundStyle(Theme.accent)
                            Text("Installation & Unblocking Guide")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(Theme.ink)
                        }
                        Text("Step-by-step instructions for 'Open Anyway', terminal quarantine removal, and disk access.")
                            .font(.system(size: 10))
                            .foregroundStyle(Theme.inkSecondary)
                    }

                    Spacer()

                    Button {
                        showPrivacyGuide.value = true
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: "questionmark.circle")
                            Text("Open Guide")
                        }
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Theme.accent)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(Theme.accentSoft)
                        )
                    }
                    .buttonStyle(FluidButtonStyle(scale: 0.96))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
            }
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: Theme.radiusLarge,
                                                            style: .continuous))
        }
    }

    // MARK: Audit log

    private var auditLog: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 1) {
                    Text("Activity Log")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Theme.ink)
                    Text("Every clean and refusal is recorded here.")
                        .font(.system(size: 10))
                        .foregroundStyle(Theme.inkTertiary)
                }
                Spacer()
                Button("Reveal in Finder") {
                    NSWorkspace.shared.activateFileViewerSelecting([Paths.deletionLog])
                }
                .buttonStyle(.plain)
                .font(.system(size: 10))
                .foregroundStyle(Theme.accent)
                .disabled(entries.value.isEmpty)
            }

            if entries.value.isEmpty {
                Text("Nothing recorded yet.")
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.inkTertiary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(14)
                    .background(Theme.surface, in: RoundedRectangle(cornerRadius: Theme.radiusLarge,
                                                                    style: .continuous))
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(Array(entries.value.prefix(150).enumerated()), id: \.element.id) { index, entry in
                            HStack(spacing: 10) {
                                Text(entry.status == "ok" ? "Cleaned" : "Kept")
                                    .font(.system(size: 9, weight: .medium))
                                    .foregroundStyle(entry.status == "ok" ? Theme.accent : Theme.inkSecondary)
                                    .frame(width: 46, alignment: .leading)
                                Text(entry.target)
                                    .font(.system(size: 10))
                                    .foregroundStyle(Theme.ink)
                                    .lineLimit(1)
                                    .truncationMode(.head)
                                Spacer(minLength: 6)
                                Text(entry.sizeText)
                                    .font(.system(size: 10, design: .rounded))
                                    .foregroundStyle(Theme.inkSecondary)
                                    .monospacedDigit()
                                Text(entry.timestamp, format: .dateTime.month().day().hour().minute())
                                    .font(.system(size: 9))
                                    .foregroundStyle(Theme.inkTertiary)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 7)
                            if index < min(entries.value.count, 150) - 1 {
                                Divider2().padding(.leading, 12)
                            }
                        }
                    }
                }
                .frame(height: 180)
                .background(Theme.surface, in: RoundedRectangle(cornerRadius: Theme.radiusLarge,
                                                                style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.radiusLarge, style: .continuous)
                        .strokeBorder(Theme.hairline, lineWidth: 1)
                )
            }
        }
    }

    // MARK: About & Updates

    private var about: some View {
        VStack(alignment: .leading, spacing: 14) {
            updatesCard

            VStack(alignment: .leading, spacing: 6) {
                Text("About")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.ink)

                VStack(alignment: .leading, spacing: 7) {
                    Label("Your personal folders are never cleaned",
                          systemImage: "folder.badge.person.crop")
                    Label("Unknown state is treated as unsafe, never as safe",
                          systemImage: "questionmark.shield")
                    Label("Items are moved to Trash by default",
                          systemImage: "trash")
                    Label("System caches need an admin password and are offered separately",
                          systemImage: "lock.shield")
                }
                .font(.system(size: 11))
                .foregroundStyle(Theme.inkSecondary)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Worm v\(UpdateChecker.currentVersion) — Ultra-fast, transparent system cleaner & monitor for macOS.")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Theme.inkSecondary)
                    
                    Text("Open source under the MIT License • Clean, safe, zero-telemetry.")
                        .font(.system(size: 10))
                        .foregroundStyle(Theme.inkTertiary)

                    HStack(spacing: 12) {
                        Link(destination: URL(string: "https://github.com/namdevnaman/worm")!) {
                            HStack(spacing: 4) {
                                Image(systemName: "link")
                                Text("GitHub Repository")
                            }
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(Theme.accent)
                        }

                        Link(destination: URL(string: "https://github.com/namdevnaman/worm/releases")!) {
                            HStack(spacing: 4) {
                                Image(systemName: "tag")
                                Text("Releases")
                            }
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(Theme.accent)
                        }

                        Link(destination: URL(string: "https://github.com/namdevnaman/worm/blob/main/LICENSE")!) {
                            HStack(spacing: 4) {
                                Image(systemName: "doc.text")
                                Text("MIT License")
                            }
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(Theme.accent)
                        }
                    }
                    .padding(.top, 2)

                    Text("Log folder: \(Paths.logDir.path)")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(Theme.inkTertiary)
                        .padding(.top, 2)
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Theme.surface, in: RoundedRectangle(cornerRadius: Theme.radiusLarge,
                                                                style: .continuous))
            }
        }
    }

    private var updatesCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 1) {
                    Text("Software Updates")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Theme.ink)
                    Text("Current version: v\(UpdateChecker.currentVersion)")
                        .font(.system(size: 10))
                        .foregroundStyle(Theme.inkTertiary)
                }
                Spacer()

                Button {
                    UpdateChecker.shared.checkForUpdates(isUserInitiated: true)
                } label: {
                    HStack(spacing: 5) {
                        if UpdateChecker.shared.status.isChecking {
                            ProgressView().controlSize(.small).scaleEffect(0.7)
                        } else {
                            Image(systemName: "arrow.triangle.2.circlepath")
                        }
                        Text(UpdateChecker.shared.status.isChecking ? "Checking…" : "Check for Updates")
                    }
                    .font(.system(size: 11, weight: .medium))
                }
                .buttonStyle(.plain)
                .foregroundStyle(Theme.accent)
                .disabled(UpdateChecker.shared.status.isChecking)
            }

            // Update status / action banner
            updateStatusContent
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Theme.surface, in: RoundedRectangle(cornerRadius: Theme.radiusLarge,
                                                                style: .continuous))
        }
    }

    @ViewBuilder
    private var updateStatusContent: some View {
        switch UpdateChecker.shared.status {
        case .idle:
            HStack(spacing: 8) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(Theme.accent)
                    .font(.system(size: 12))
                Text("Automatic updates enabled. Worm stays up to date with the latest clean definitions.")
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.inkSecondary)
            }
        case .checking:
            HStack(spacing: 8) {
                ProgressView().controlSize(.small).scaleEffect(0.8)
                Text("Checking for latest release…")
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.inkSecondary)
            }
        case .upToDate:
            HStack(spacing: 8) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(Theme.accent)
                    .font(.system(size: 14))
                VStack(alignment: .leading, spacing: 2) {
                    Text("Worm is up to date!")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Theme.ink)
                    Text("You have the latest version (v\(UpdateChecker.currentVersion)).")
                        .font(.system(size: 10))
                        .foregroundStyle(Theme.inkTertiary)
                }
            }
        case .updateAvailable(let release):
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.down.circle.fill")
                        .foregroundStyle(Theme.info)
                        .font(.system(size: 18))
                    VStack(alignment: .leading, spacing: 2) {
                        Text("New Version Available: v\(release.version)")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Theme.ink)
                        Text(release.name.isEmpty ? "A newer release of Worm is ready for download." : release.name)
                            .font(.system(size: 10))
                            .foregroundStyle(Theme.inkSecondary)
                            .lineLimit(2)
                    }
                    Spacer()
                }

                if !release.body.isEmpty {
                    Text(release.body.prefix(180) + (release.body.count > 180 ? "…" : ""))
                        .font(.system(size: 10))
                        .foregroundStyle(Theme.inkTertiary)
                        .lineLimit(3)
                        .padding(6)
                        .background(Theme.background, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                }

                // Download instructions
                VStack(alignment: .leading, spacing: 4) {
                    Text("How to update:")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(Theme.ink)
                    ForEach(release.instructions, id: \.self) { step in
                        Text(step)
                            .font(.system(size: 9.5))
                            .foregroundStyle(Theme.inkSecondary)
                    }
                }
                .padding(8)
                .background(Theme.background, in: RoundedRectangle(cornerRadius: 6, style: .continuous))

                HStack(spacing: 8) {
                    Button {
                        UpdateChecker.shared.downloadUpdate()
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: "arrow.down.to.line")
                            Text("Download Update")
                        }
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Theme.accent, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                    }
                    .buttonStyle(.plain)

                    Button {
                        UpdateChecker.shared.openReleasePage()
                    } label: {
                        Text("View Release Notes")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(Theme.ink)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Theme.background, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }
        case .downloading(let progress):
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Downloading update…")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Theme.ink)
                    Spacer()
                    Text("\(Int(progress * 100))%")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(Theme.inkSecondary)
                }
                ProgressView(value: progress)
            }
        case .downloaded(let url):
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundStyle(Theme.accent)
                        .font(.system(size: 16))
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Update downloaded successfully!")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(Theme.ink)
                        Text("Saved to Downloads: \(url.lastPathComponent)")
                            .font(.system(size: 10))
                            .foregroundStyle(Theme.inkTertiary)
                    }
                    Spacer()
                    Button("Show in Finder") {
                        NSWorkspace.shared.activateFileViewerSelecting([url])
                    }
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(Theme.accent)
                }

                // Installation Instructions
                VStack(alignment: .leading, spacing: 3) {
                    Text("Installation Instructions:")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(Theme.ink)
                    Text("1. Open Finder to the downloaded archive or DMG.")
                        .font(.system(size: 9.5))
                        .foregroundStyle(Theme.inkSecondary)
                    Text("2. Replace Worm in /Applications.")
                        .font(.system(size: 9.5))
                        .foregroundStyle(Theme.inkSecondary)
                    Text("3. Relaunch Worm.")
                        .font(.system(size: 9.5))
                        .foregroundStyle(Theme.inkSecondary)
                }
                .padding(8)
                .background(Theme.background, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
            }
        case .failed(let msg):
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(Theme.warn)
                    .font(.system(size: 14))
                VStack(alignment: .leading, spacing: 2) {
                    Text("Update Check")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Theme.ink)
                    Text(msg)
                        .font(.system(size: 10))
                        .foregroundStyle(Theme.inkTertiary)
                }
                Spacer()
                Button("Check GitHub") {
                    UpdateChecker.shared.openReleasePage()
                }
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(Theme.info)
            }
        }
    }
}