import SwiftUI
import MoleCore

/// Settings: the protect list, the delete mode default, and the audit log.
struct SettingsView: View {
    @EnvironmentObject var store: AppStore
    @StateObject private var newPath = Box("")
    @StateObject private var entries = Box(AuditLog.recentEntries())
    /// Mirrors `store.showBlocked`, which is what the Clean screen reads.
    @StateObject private var showKeptItems = Box(true)

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                protectList
                defaults
                auditLog
                about
            }
            .padding(18)
        }
        .background(Theme.background)
        .onAppear { entries.value = AuditLog.recentEntries() }
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
        store.addToProtectList(entry)
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
                    Picker("", selection: store.deleteModeBox.binding) {
                        Text("Trash").tag(Reclaimer.Mode.trash)
                        Text("Permanent").tag(Reclaimer.Mode.permanent)
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .frame(width: 170)
                    .help("Trash keeps items recoverable")
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
                VStack(spacing: 0) {
                    ForEach(Array(entries.value.prefix(80).enumerated()), id: \.element.id) { index, entry in
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
                        .padding(.vertical, 6)
                        if index < min(entries.value.count, 80) - 1 { Divider2().padding(.leading, 12) }
                    }
                }
                .background(Theme.surface, in: RoundedRectangle(cornerRadius: Theme.radiusLarge,
                                                                style: .continuous))
            }
        }
    }

    // MARK: About

    private var about: some View {
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

            VStack(alignment: .leading, spacing: 3) {
                Text("MoleMac is an independent GUI built on the cleaning logic of the open-source Mole CLI. It is free and not affiliated with Mole for Mac.")
                    .font(.system(size: 10))
                    .foregroundStyle(Theme.inkTertiary)
                    .fixedSize(horizontal: false, vertical: true)
                Text("Log folder: \(Paths.logDir.path)")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(Theme.inkTertiary)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: Theme.radiusLarge,
                                                            style: .continuous))
        }
    }
}