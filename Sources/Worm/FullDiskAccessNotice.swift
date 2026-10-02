import WormCore
import SwiftUI

/// Shown when the app can list a protected folder but not read its contents.
///
/// TCC lets an unprivileged app enumerate `~/Library/Containers` yet refuse to
/// descend into it, so every container measures 0 bytes. Without this prompt the
/// app looks broken rather than un-permissioned, and the user has no way to tell
/// the difference between "nothing there" and "we cannot see it".
struct FullDiskAccessNotice: View {
    let onDismiss: () -> Void
    @StateObject private var showGuide = Box(false)

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "lock.shield")
                .font(.system(size: 15))
                .foregroundStyle(Theme.warn)

            VStack(alignment: .leading, spacing: 3) {
                HStack {
                    Text("Grant Full Disk Access to see real sizes")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Theme.ink)
                    Spacer()
                    Button(action: onDismiss) {
                        Image(systemName: "xmark")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(Theme.inkTertiary)
                    }
                    .buttonStyle(.plain)
                    .help("Dismiss notice")
                }

                Text("""
                macOS lets Worm list app containers but not read them, so mail, \
                messages and some app data report 0 bytes, and app leftovers \
                cannot be verified. Nothing is cleaned beyond your home folder \
                either way.
                """)
                .font(.system(size: 11))
                .foregroundStyle(Theme.inkSecondary)
                .fixedSize(horizontal: false, vertical: true)

                Text("""
                System Settings → Privacy & Security → Full Disk Access. If \
                Worm is already listed, select it and press − first, then press \
                + and choose it again, then quit and reopen Worm.
                """)
                .font(.system(size: 11))
                .foregroundStyle(Theme.ink)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 1)

                HStack(spacing: 10) {
                    Button("Open Settings") {
                        NSWorkspaceBridge.openFullDiskAccessSettings()
                    }
                    .buttonStyle(.plain)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Theme.accent)

                    Button("Show App in Finder") {
                        NSWorkspaceBridge.revealSelfInFinder()
                    }
                    .buttonStyle(.plain)
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.inkSecondary)

                    Button("Help & Guide…") {
                        showGuide.value = true
                    }
                    .buttonStyle(.plain)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Theme.ink)

                    Spacer(minLength: 0)

                    Button("Not now") { onDismiss() }
                        .buttonStyle(.plain)
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.inkSecondary)
                }
                .padding(.top, 2)
            }

            Spacer(minLength: 0)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: Theme.radius, style: .continuous)
                .fill(Theme.warnSoft))
        .sheet(isPresented: showGuide.binding) {
            PrivacyGuideSheet()
        }
    }
}