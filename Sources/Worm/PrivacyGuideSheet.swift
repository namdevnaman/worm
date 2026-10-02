import SwiftUI
import WormCore

/// Complete visual guide for macOS permissions, Gatekeeper, and Privacy blocking.
///
/// Designed to help any user on macOS 14 / 15 / Sequoia unblock Worm if blocked by:
/// 1. Gatekeeper ("Worm cannot be opened because Apple cannot check it for malicious software")
/// 2. Quarantine flag (`com.apple.quarantine`)
/// 3. Full Disk Access (TCC permission)
struct PrivacyGuideSheet: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var copiedCommand = Box(false)
    @StateObject private var selectedTopic = Box(Topic.gatekeeper)

    enum Topic: String, CaseIterable, Identifiable {
        case gatekeeper = "Gatekeeper & 'Open Anyway'"
        case quarantine = "Terminal Fix (xattr)"
        case fda = "Full Disk Access"

        var id: String { rawValue }
        var icon: String {
            switch self {
            case .gatekeeper: return "lock.open.shield"
            case .quarantine: return "terminal"
            case .fda: return "internaldrive"
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Theme.accent.opacity(0.18))
                        .frame(width: 36, height: 36)
                    Image(systemName: "shield.lefthalf.filled.badge.checkmark")
                        .font(.system(size: 18))
                        .foregroundStyle(Theme.accent)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("macOS Privacy & Gatekeeper Guide")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(Theme.ink)
                    Text("How to run Worm smoothly on any Mac without warnings or blocks.")
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.inkSecondary)
                }

                Spacer()

                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(Theme.inkTertiary)
                }
                .buttonStyle(.plain)
                .keyboardShortcut(.cancelAction)
            }
            .padding(.horizontal, 20)
            .padding(.top, 18)
            .padding(.bottom, 14)

            Divider2()

            // Topic Switcher
            HStack(spacing: 8) {
                ForEach(Topic.allCases) { topic in
                    let isSelected = selectedTopic.value == topic
                    Button {
                        withAnimation(Theme.springSnappy) {
                            selectedTopic.value = topic
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: topic.icon)
                                .font(.system(size: 11))
                            Text(topic.rawValue)
                                .font(.system(size: 11, weight: isSelected ? .semibold : .medium))
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(isSelected ? Theme.accent : Theme.surface)
                        )
                        .foregroundStyle(isSelected ? .white : Theme.inkSecondary)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .strokeBorder(isSelected ? Color.clear : Theme.hairline, lineWidth: 1)
                        )
                    }
                    .buttonStyle(FluidButtonStyle(scale: 0.97))
                }
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .background(Theme.surface.opacity(0.4))

            Divider2()

            // Content Area
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    switch selectedTopic.value {
                    case .gatekeeper:
                        gatekeeperGuide
                    case .quarantine:
                        quarantineGuide
                    case .fda:
                        fdaGuide
                    }
                }
                .padding(20)
            }

            Divider2()

            // Footer
            HStack {
                Button("Open Privacy & Security Settings") {
                    NSWorkspaceBridge.openFullDiskAccessSettings()
                }
                .buttonStyle(.plain)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Theme.accent)

                Spacer()

                Button("Got it") {
                    dismiss()
                }
                .buttonStyle(.plain)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 7)
                .background(Theme.accent, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .background(Theme.surface)
        }
        .frame(width: 580, height: 490)
        .background(Theme.background)
    }

    // MARK: - Topic 1: Gatekeeper
    private var gatekeeperGuide: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(Theme.warn)
                    .font(.system(size: 15))
                Text("If macOS says \"Worm cannot be opened\"")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Theme.ink)
            }

            Text("Because Worm is an open-source tool compiled with an ad-hoc signature, macOS Gatekeeper blocks it on first download until you explicitly allow it.")
                .font(.system(size: 11.5))
                .foregroundStyle(Theme.inkSecondary)
                .fixedSize(horizontal: false, vertical: true)

            VStack(alignment: .leading, spacing: 10) {
                stepCard(
                    stepNumber: "1",
                    title: "Open System Settings",
                    detail: "Click Apple () menu at top left → System Settings → Privacy & Security."
                )

                stepCard(
                    stepNumber: "2",
                    title: "Scroll down to 'Security'",
                    detail: "Near the bottom, you will see a message: 'Worm was blocked from use because it is not from an identified developer'."
                )

                stepCard(
                    stepNumber: "3",
                    title: "Click 'Open Anyway'",
                    detail: "Click Open Anyway and enter your Mac password / Touch ID. You only have to do this once!"
                )
            }

            HStack(spacing: 8) {
                Image(systemName: "lightbulb.fill")
                    .foregroundStyle(Theme.accent)
                    .font(.system(size: 12))
                Text("Alternative shortcut: Right-click (or Control-click) Worm in Finder, choose Open, then click Open in the confirmation dialog.")
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.inkSecondary)
            }
            .padding(10)
            .background(Theme.accentSoft, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
    }

    // MARK: - Topic 2: Quarantine
    private var quarantineGuide: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "terminal.fill")
                    .foregroundStyle(Theme.info)
                    .font(.system(size: 15))
                Text("One-Line Terminal Fix (Instant Unblock)")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Theme.ink)
            }

            Text("macOS flags downloaded apps with a quarantine attribute. If Gatekeeper refuses to launch the app, removing this attribute unlocks Worm permanently.")
                .font(.system(size: 11.5))
                .foregroundStyle(Theme.inkSecondary)

            VStack(alignment: .leading, spacing: 6) {
                Text("Copy & paste this command into Terminal:")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Theme.ink)

                HStack {
                    Text("xattr -cr /Applications/Worm.app")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(Theme.ink)
                        .padding(8)

                    Spacer()

                    Button {
                        let pasteboard = NSPasteboard.general
                        pasteboard.clearContents()
                        pasteboard.setString("xattr -cr /Applications/Worm.app", forType: .string)
                        copiedCommand.value = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                            copiedCommand.value = false
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: copiedCommand.value ? "checkmark" : "doc.on.doc")
                            Text(copiedCommand.value ? "Copied!" : "Copy")
                        }
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(copiedCommand.value ? Theme.accent : Theme.ink)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 5, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .padding(.trailing, 6)
                }
                .background(Theme.darkSurface.opacity(0.8), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).strokeBorder(Theme.hairline, lineWidth: 1))
            }

            Text("Press Return in Terminal, then launch Worm. It will open without any popups!")
                .font(.system(size: 10.5))
                .foregroundStyle(Theme.inkTertiary)
        }
    }

    // MARK: - Topic 3: Full Disk Access
    private var fdaGuide: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "lock.shield.fill")
                    .foregroundStyle(Theme.accent)
                    .font(.system(size: 15))
                Text("Why Full Disk Access is Needed")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Theme.ink)
            }

            Text("Apple's privacy framework (TCC) prevents apps from inspecting cache folders in ~/Library/Containers unless Full Disk Access is granted.")
                .font(.system(size: 11.5))
                .foregroundStyle(Theme.inkSecondary)

            VStack(alignment: .leading, spacing: 10) {
                stepCard(
                    stepNumber: "1",
                    title: "Open Full Disk Access",
                    detail: "Go to System Settings → Privacy & Security → Full Disk Access."
                )

                stepCard(
                    stepNumber: "2",
                    title: "Enable Worm",
                    detail: "Find Worm in the list and toggle the switch to ON. If not listed, click the (+) button and select Worm from /Applications."
                )

                stepCard(
                    stepNumber: "3",
                    title: "Relaunch Worm",
                    detail: "macOS will ask to quit & reopen Worm so the permissions take effect immediately."
                )
            }

            HStack(spacing: 12) {
                Button("Open Full Disk Access Settings") {
                    NSWorkspaceBridge.openFullDiskAccessSettings()
                }
                .buttonStyle(.plain)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Theme.accent)

                Button("Reveal Worm in Finder") {
                    NSWorkspaceBridge.revealSelfInFinder()
                }
                .buttonStyle(.plain)
                .font(.system(size: 11))
                .foregroundStyle(Theme.inkSecondary)
            }
            .padding(.top, 4)
        }
    }

    private func stepCard(stepNumber: String, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                Circle()
                    .fill(Theme.accent.opacity(0.15))
                    .frame(width: 22, height: 22)
                Text(stepNumber)
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.accent)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 11.5, weight: .semibold))
                    .foregroundStyle(Theme.ink)
                Text(detail)
                    .font(.system(size: 10.5))
                    .foregroundStyle(Theme.inkSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
        }
        .padding(10)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).strokeBorder(Theme.hairline, lineWidth: 1))
    }
}
