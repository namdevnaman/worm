import SwiftUI
import MoleCore

/// Sidebar row for one clean category. Shows selected/total and reclaimable
/// bytes, which is the pair a user actually decides on.
struct CategoryRow: View {
    let category: CleanCategory
    let totalBytes: Int64
    let selectedCount: Int
    let totalCount: Int
    let keptCount: Int
    let isActive: Bool

    var body: some View {
        HStack(spacing: 9) {
            Image(systemName: category.symbol)
                .font(.system(size: 12, weight: .medium))
                .frame(width: 16)
                .foregroundStyle(isActive ? Theme.accent : Theme.inkTertiary)

            VStack(alignment: .leading, spacing: 1) {
                Text(category.title)
                    .font(.system(size: 12, weight: isActive ? .semibold : .regular))
                    .foregroundStyle(isActive ? Theme.ink : Theme.inkSecondary)
                    .lineLimit(1)

                if totalCount > 0 {
                    Text("\(selectedCount)/\(totalCount) selected")
                        .font(.system(size: 10))
                        .foregroundStyle(Theme.inkTertiary)
                        .lineLimit(1)
                } else if totalBytes == 0 && keptCount == 0 {
                    Text("Nothing found")
                        .font(.system(size: 10))
                        .foregroundStyle(Theme.inkTertiary)
                }
            }

            Spacer(minLength: 4)

            if totalBytes > 0 {
                Text(ByteFormat.compact(totalBytes))
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(isActive ? Theme.accent : Theme.inkSecondary)
                    .monospacedDigit()
            }
        }
        .padding(.vertical, 5)
        .padding(.horizontal, 8)
        .background(
            RoundedRectangle(cornerRadius: Theme.radius, style: .continuous)
                .fill(isActive ? Theme.accentSoft : .clear)
        )
        .contentShape(Rectangle())
    }
}

/// One cleanable item, with a checkbox the user controls.
struct TargetRow: View {
    let target: CleanupTarget
    let isSelected: Bool
    let risk: Risk
    /// A caution that does not prevent cleaning, such as the app being open.
    var warning: SafetyPolicy.Reason?
    let onToggle: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            // A checkbox drawn here rather than a `Toggle`: `Toggle` keeps its
            // own internal state keyed by view identity, so when the row is
            // rebuilt with a fresh binding the box keeps showing its initial
            // value and disagrees with the store.
            Checkbox(isOn: isSelected, label: "Select \(target.label)", action: onToggle)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(target.label)
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.ink)
                        .lineLimit(1)
                        .truncationMode(.middle)

                    if risk != .regenerable {
                        Badge(text: risk.title,
                              color: Theme.riskColor(risk),
                              background: Theme.riskSoft(risk))
                    }
                    if let warning {
                        Badge(text: shortWarning(warning),
                              color: Theme.warn,
                              background: Theme.warnSoft,
                              symbol: "exclamationmark.triangle.fill")
                    }
                }

                Text(target.homeRelativePath)
                    .font(.system(size: 10))
                    .foregroundStyle(Theme.inkTertiary)
                    .lineLimit(1)
                    .truncationMode(.head)
            }

            Spacer(minLength: 6)

            if let closed = target.mustBeClosed {
                Image(systemName: "app.badge.checkmark")
                    .font(.system(size: 10))
                    .foregroundStyle(Theme.inkTertiary)
                    .help("Close \(closed) first for a complete clean")
            }

            if target.isMeasurable {
                Text(ByteFormat.compact(target.bytes))
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(Theme.ink)
                    .monospacedDigit()
            } else {
                // "0 bytes" would read as an empty folder. Say the real reason.
                Text("needs access")
                    .font(.system(size: 10))
                    .foregroundStyle(Theme.warn)
            }
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 10)
        .background(isSelected ? Theme.surfaceRaised : Theme.surface)
        .contentShape(Rectangle())
        .onTapGesture(perform: onToggle)
    }
}

/// One-line form of a warning, for a row that has no room for the full reason.
func shortWarning(_ reason: SafetyPolicy.Reason) -> String {
    switch reason {
    case .liveApplicationCache: return "App is open"
    case .openFileHandle: return "File in use"
    case .sqliteLiveDatabase: return "Database in use"
    case .whitelisted: return "Protected"
    default: return reason.title
    }
}

/// Checkbox the app draws itself.
///
/// SwiftUI's own `Toggle` is unsuitable for the item list: it holds internal
/// state that survives a binding change, so rows rebuilt after a rescan show a
/// stale tick. This reads purely from `isOn`, so the picture can never disagree
/// with the model.
struct Checkbox: View {
    let isOn: Bool
    var label: String = ""
    var action: () -> Void = {}

    var body: some View {
        Button(action: action) {
            ZStack {
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .fill(isOn ? Theme.accent : Color.white)
                    .frame(width: 13, height: 13)
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .strokeBorder(isOn ? Theme.accent : Theme.hairline, lineWidth: 1)
                    .frame(width: 13, height: 13)
                if isOn {
                    Image(systemName: "checkmark")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(.white)
                }
            }
            .frame(width: 20, height: 20)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .accessibilityAddTraits(isOn ? [.isSelected, .isButton] : .isButton)
    }
}

/// An item the policy refused. Shown with the reason, never silently dropped:
/// a user who sees 4 GB missing from the total deserves to know it was kept.
struct BlockedRow: View {
    let blocked: ScanEngine.BlockedTarget

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "lock.fill")
                .font(.system(size: 10))
                .foregroundStyle(Theme.inkTertiary)
                .frame(width: 16)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(blocked.label)
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.inkSecondary)
                        .lineLimit(1)
                    Badge(text: blocked.reason.title,
                          color: Theme.inkSecondary,
                          background: Theme.background)
                }
                Text(blocked.reason.detail)
                    .font(.system(size: 10))
                    .foregroundStyle(Theme.inkTertiary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 6)

            Text(ByteFormat.compact(blocked.bytes))
                .font(.system(size: 11, design: .rounded))
                .foregroundStyle(Theme.inkTertiary)
                .monospacedDigit()
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 10)
        .background(Theme.background.opacity(0.6))
        .help(blocked.path)
    }
}