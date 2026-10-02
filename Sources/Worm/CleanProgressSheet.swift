import SwiftUI
import WormCore

/// Modal shown while a clean runs and after it finishes. It reports exactly
/// what happened, including what was kept and why — the part a CLI summary
/// hides.
struct CleanProgressSheet: View {
    @EnvironmentObject var store: AppStore
    @StateObject private var revealKept = Box(true)

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider2()

            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    if case .running(let completed, let total, let lastPath) = store.cleanPhase {
                        runningBody(completed: completed, total: total, lastPath: lastPath)
                    } else if case .finished(let summary) = store.cleanPhase {
                        finishedBody(summary)
                    }
                }
                .padding(16)
            }
            .frame(maxHeight: 380)

            Divider2()
            footer
        }
        .frame(width: 560)
        .background(Theme.surface)
    }

    private var header: some View {
        HStack(spacing: 10) {
            if case .running = store.cleanPhase {
                ProgressView().controlSize(.small).scaleEffect(0.7).frame(width: 16)
                VStack(alignment: .leading, spacing: 1) {
                    Text("Cleaning")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Theme.ink)
                    Text(store.deleteMode == .trash
                         ? "Moving items to the Trash"
                         : "Deleting permanently")
                        .font(.system(size: 10))
                        .foregroundStyle(Theme.inkTertiary)
                }
            } else {
                let kept = (store.lastSummary?.keptCount ?? 0) > 0
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(Theme.accent)
                VStack(alignment: .leading, spacing: 1) {
                    Text("Clean finished")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Theme.ink)
                    Text(kept
                         ? "Some items were kept for safety (close open apps to reclaim more)"
                         : "All selected items cleaned successfully")
                        .font(.system(size: 10))
                        .foregroundStyle(Theme.inkTertiary)
                }
            }
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private func runningBody(completed: Int, total: Int, lastPath: String) -> some View {
        VStack(spacing: 14) {
            HStack(spacing: 16) {
                EatingWormAnimation(size: 96)
                VStack(alignment: .leading, spacing: 3) {
                    Text("Worm is munching through junk files…")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Theme.ink)
                    Text("Chewing unneeded caches, old logs, and residual traces.")
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.inkTertiary)
                }
                Spacer()
            }
            .padding(.vertical, 6)
            .padding(.horizontal, 8)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Theme.background)
            )

            ProportionBar(fraction: total > 0 ? Double(completed) / Double(total) : 0,
                          height: 7)
            HStack {
                Text("\(completed) of \(total)")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .monospacedDigit()
                Spacer()
                Text(lastPath)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            .font(.system(size: 10))
            .foregroundStyle(Theme.inkTertiary)

            Text("Nothing is deleted until each item is re-checked. If an item changed while you were reviewing it, it is kept.")
                .font(.system(size: 10))
                .foregroundStyle(Theme.inkTertiary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func finishedBody(_ summary: AppStore.CleanSummary) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 14) {
                stat("Freed", ByteFormat.compact(summary.removedBytes), Theme.accent)
                stat("Cleaned", "\(summary.removedCount) items", Theme.ink)
                if summary.keptCount > 0 {
                    stat("Kept", "\(summary.keptCount) items", Theme.inkSecondary)
                }
                stat("Took", String(format: "%.1fs", summary.duration), Theme.inkSecondary)
            }

            if summary.removedBytes > 0 {
                VStack(alignment: .leading, spacing: 4) {
                    ProportionBar(
                        fraction: min(Double(summary.removedBytes) / Double(20 * 1024 * 1024 * 1024), 1),
                        height: 6)
                    Text("20 GB reference")
                        .font(.system(size: 9))
                        .foregroundStyle(Theme.inkTertiary)
                }
            }

            let kept = summary.outcomes.filter { $0.status != .removed }
            if !kept.isEmpty {
                Toggle(isOn: revealKept.binding) {
                    Text("\(kept.count) item\(kept.count == 1 ? "" : "s") kept")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Theme.ink)
                }
                .toggleStyle(.checkbox)

                if revealKept.value {
                    VStack(spacing: 0) {
                        ForEach(Array(kept.enumerated()), id: \.element.id) { index, outcome in
                            VStack(alignment: .leading, spacing: 1) {
                                HStack {
                                    Text((outcome.path as NSString).lastPathComponent)
                                        .font(.system(size: 11))
                                        .foregroundStyle(Theme.ink)
                                        .lineLimit(1)
                                    Spacer()
                                    Text(ByteFormat.compact(outcome.bytesReclaimed))
                                        .font(.system(size: 10, design: .rounded))
                                        .foregroundStyle(Theme.inkTertiary)
                                }
                                Text(outcome.note)
                                    .font(.system(size: 10))
                                    .foregroundStyle(Theme.inkTertiary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Theme.background)
                            if index < kept.count - 1 { Divider2().padding(.leading, 10) }
                        }
                    }
                    .background(Theme.surface, in: RoundedRectangle(cornerRadius: Theme.radius,
                                                                     style: .continuous))
                }
            }
        }
    }

    private func stat(_ title: String, _ value: String, _ color: Color) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(title)
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(Theme.inkTertiary)
                .textCase(.uppercase)
            Text(value)
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .foregroundStyle(color)
                .monospacedDigit()
        }
    }

    private var footer: some View {
        HStack {
            if case .finished = store.cleanPhase {
                Button("Empty Trash") { store.emptyTrash() }
                    .buttonStyle(.plain)
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.inkSecondary)
            }
            Spacer()
            let isRunning: Bool = {
                if case .running = store.cleanPhase { return true }
                return false
            }()
            Button("Done") { store.dismissCleanSummary() }
                .buttonStyle(.plain)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(isRunning ? Theme.inkTertiary : .white)
                .padding(.horizontal, 16)
                .padding(.vertical, 6)
                .background(isRunning ? Theme.hairline : Theme.accent,
                            in: RoundedRectangle(cornerRadius: Theme.radius, style: .continuous))
                .disabled(isRunning)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 11)
    }
}