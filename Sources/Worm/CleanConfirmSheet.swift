import WormCore
import SwiftUI

/// Confirmation shown before a clean runs.
///
/// This sheet exists because a single click on the Clean button used to move
/// gigabytes with no second step. It states exactly what will happen, in the
/// user's own terms: how many items, how much space, which categories, and
/// whether the result is recoverable.
struct CleanConfirmSheet: View {
    @EnvironmentObject var store: AppStore

    private var confirmation: AppStore.CleanConfirmation? {
        store.pendingCleanConfirmation
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider2()

            if let confirmation {
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        headline(confirmation)
                        breakdown(confirmation)
                        modeNote(confirmation)
                    }
                    .padding(16)
                }
                .frame(maxHeight: 340)
            }

            Divider2()
            actions
        }
        .frame(width: 480)
        .background(Theme.surface)
    }

    private var header: some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 15))
                .foregroundStyle(Theme.warn)
            VStack(alignment: .leading, spacing: 1) {
                Text("Review before cleaning")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Theme.ink)
                Text("Nothing has been removed yet.")
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.inkTertiary)
            }
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
    }

    private func headline(_ confirmation: AppStore.CleanConfirmation) -> some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 1) {
                Text(ByteFormat.compact(confirmation.bytes))
                    .font(.system(size: 26, weight: .semibold, design: .rounded))
                    .foregroundStyle(Theme.ink)
                    .monospacedDigit()
                Text("selected")
                    .font(.system(size: 10))
                    .foregroundStyle(Theme.inkTertiary)
            }
            VStack(alignment: .leading, spacing: 1) {
                Text("\(confirmation.itemCount)")
                    .font(.system(size: 26, weight: .semibold, design: .rounded))
                    .foregroundStyle(Theme.ink)
                    .monospacedDigit()
                Text(confirmation.itemCount == 1 ? "item" : "items")
                    .font(.system(size: 10))
                    .foregroundStyle(Theme.inkTertiary)
            }
            Spacer()
        }
    }

    /// Where the selected bytes are, by category. A user deciding to proceed
    /// wants to see which part of the disk this actually touches.
    private func breakdown(_ confirmation: AppStore.CleanConfirmation) -> some View {
        let byCategory = Dictionary(grouping: store.selectedTargets, by: \.categoryID)
            .mapValues { $0.reduce(0) { $0 + $1.bytes } }
            .sorted { $0.value > $1.value }

        return VStack(alignment: .leading, spacing: 6) {
            Text("BY CATEGORY")
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(Theme.inkTertiary)

            ForEach(byCategory, id: \.key) { category, bytes in
                HStack(spacing: 8) {
                    Image(systemName: category.symbol)
                        .font(.system(size: 10))
                        .foregroundStyle(Theme.inkTertiary)
                        .frame(width: 14)
                    Text(category.title)
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.ink)
                    Spacer()
                    ProportionBar(fraction: Double(bytes) / Double(max(confirmation.bytes, 1)),
                                  height: 4)
                        .frame(width: 90)
                    Text(ByteFormat.compact(bytes))
                        .font(.system(size: 10, design: .rounded))
                        .foregroundStyle(Theme.inkSecondary)
                        .monospacedDigit()
                        .frame(width: 62, alignment: .trailing)
                }
            }
        }
    }

    private func modeNote(_ confirmation: AppStore.CleanConfirmation) -> some View {
        HStack(alignment: .top, spacing: 7) {
            Image(systemName: confirmation.mode == .trash
                  ? "trash" : "exclamationmark.triangle")
                .font(.system(size: 11))
                .foregroundStyle(confirmation.mode == .trash ? Theme.accent : Theme.danger)
            Text(confirmation.mode == .trash
                 ? "Items move to the Trash. You can put them back until you empty it."
                 : "Items are deleted immediately. There is no way to undo this.")
                .font(.system(size: 11))
                .foregroundStyle(confirmation.mode == .trash ? Theme.inkSecondary : Theme.danger)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(confirmation.mode == .trash ? Theme.accentSoft : Theme.dangerSoft,
                    in: RoundedRectangle(cornerRadius: Theme.radius, style: .continuous))
    }

    private var actions: some View {
        HStack(spacing: 8) {
            Button("Cancel") { store.pendingCleanConfirmation = nil }
                .buttonStyle(.plain)
                .font(.system(size: 11))
                .foregroundStyle(Theme.ink)
                .padding(.horizontal, 15)
                .padding(.vertical, 6)
                .background(Theme.background,
                            in: RoundedRectangle(cornerRadius: Theme.radius, style: .continuous))

            Spacer()

            Button {
                store.confirmClean()
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: "trash.slash")
                        .font(.system(size: 11, weight: .semibold))
                    Text(store.deleteMode == .trash ? "Move to Trash" : "Delete Permanently")
                        .font(.system(size: 11, weight: .semibold))
                }
                .padding(.horizontal, 15)
                .padding(.vertical, 6)
                .background(store.deleteMode == .trash ? Theme.accent : Theme.danger,
                            in: RoundedRectangle(cornerRadius: Theme.radius, style: .continuous))
                .foregroundStyle(.white)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}