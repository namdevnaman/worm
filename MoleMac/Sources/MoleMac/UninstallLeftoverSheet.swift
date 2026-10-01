import MoleCore
import SwiftUI

/// Selection state for the uninstall sheet.
///
/// Held in an observable model rather than two separate `@StateObject`s, because
/// `@StateObject` cannot be initialised from `init` with a computed value in a
/// way that survives the first render reliably.
final class UninstallModel: ObservableObject {
    let selected: Box<Set<String>>
    let isWorking = Box(false)

    init(plan: AppRemovalPlan) {
        selected = Box(Set(plan.autoSelected.map(\.id)))
    }
}

/// Shown after the user asks to uninstall an app.
///
/// Shows what the app left behind *before* anything is removed, with rebuildable
/// items pre-selected and anything holding settings held back for a decision.
/// This is the step the CLI has no equivalent for: `mo uninstall` removes traces
/// wholesale, so a user cannot see what went.
struct UninstallLeftoverSheet: View {
    @EnvironmentObject var store: AppStore
    /// Trace IDs the user has chosen. Rebuildable traces start selected;
    /// settings and app data do not, because removing those costs the user
    /// something they may not have noticed.
    private let plan: AppRemovalPlan
    @StateObject private var model: UninstallModel

    init(plan: AppRemovalPlan) {
        self.plan = plan
        _model = StateObject(wrappedValue: UninstallModel(plan: plan))
    }

    private var removable: [OrphanDetector.Leftover] {
        plan.traces.filter {
            SafetyPolicy.verdict(for: $0.path, bundleID: $0.bundleID,
                                 whitelist: .empty, probeLiveness: false).isAllowed
        }
    }

    private var autoSelected: [OrphanDetector.Leftover] {
        removable.filter { model.selected.value.contains($0.id) }
    }

    private var needsReview: [OrphanDetector.Leftover] {
        removable.filter { !autoSelected.contains($0) }
    }

    private var selectedBytes: Int64 {
        autoSelected.reduce(0) { $0 + $1.bytes }
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider2()

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    if plan.traces.isEmpty {
                        noTraces
                    } else {
                        autoSection
                        if !needsReview.isEmpty { reviewSection }
                        footerNote
                    }
                }
                .padding(16)
            }
            .frame(maxHeight: 420)

            Divider2()
            actions
        }
        .frame(width: 560)
        .background(Theme.surface)
    }

    // MARK: Header

    private var header: some View {
        HStack(alignment: .top, spacing: 11) {
            AppIcon(app: plan.app, size: 40)

            VStack(alignment: .leading, spacing: 2) {
                Text(plan.app.name)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Theme.ink)

                if plan.traces.isEmpty {
                    Text("No leftover files found for this app.")
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.inkTertiary)
                } else {
                    Text("\(plan.traces.count) leftover item\(plan.traces.count == 1 ? "" : "s") · \(ByteFormat.compact(plan.bytes))")
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.inkTertiary)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
    }

    private var noTraces: some View {
        Text("""
        Nothing outside the app bundle references this app, so removing it leaves \
        no files behind. Its settings and documents live in your home folder and \
        are never touched.
        """)
        .font(.system(size: 11))
        .foregroundStyle(Theme.inkSecondary)
        .fixedSize(horizontal: false, vertical: true)
        .padding(.vertical, 10)
    }

    // MARK: Sections

    private var autoSection: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack {
                Text("\(autoSelected.count) selected · \(ByteFormat.compact(selectedBytes))")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Theme.ink)
                Spacer()
                Button(autoSelected.count == removable.filter({ !$0.needsReview }).count
                       ? "Select all" : "Deselect all") {
                    let ids = Set(removable.filter { !$0.needsReview }.map(\.id))
                    model.selected.value = autoSelected.count == ids.count ? [] : ids
                }
                .buttonStyle(.plain)
                .font(.system(size: 11))
                .foregroundStyle(Theme.accent)
            }

            Text("SAFE TO REMOVE · rebuilt automatically")
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(Theme.inkTertiary)

            traceList(autoSelected)
        }
    }

    private var reviewSection: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text("NEEDS REVIEW · \(needsReview.count)")
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(Theme.warn)

            Text("These hold settings or the app's own data. Remove them only if you do not expect to reinstall.")
                .font(.system(size: 10))
                .foregroundStyle(Theme.inkTertiary)
                .fixedSize(horizontal: false, vertical: true)

            traceList(needsReview)
        }
    }

    private func traceList(_ traces: [OrphanDetector.Leftover]) -> some View {
        VStack(spacing: 0) {
            ForEach(Array(traces.enumerated()), id: \.element.id) { index, trace in
                HStack(spacing: 9) {
                    Checkbox(isOn: model.selected.value.contains(trace.id),
                             label: "Select \(trace.path)") {
                        if model.selected.value.contains(trace.id) {
                            model.selected.value.remove(trace.id)
                        } else {
                            model.selected.value.insert(trace.id)
                        }
                    }
                    VStack(alignment: .leading, spacing: 1) {
                        Text((trace.path as NSString).lastPathComponent)
                            .font(.system(size: 11))
                            .foregroundStyle(Theme.ink)
                            .lineLimit(1)
                            .truncationMode(.middle)
                        Text(shortPath(trace.path))
                            .font(.system(size: 9))
                            .foregroundStyle(Theme.inkTertiary)
                            .lineLimit(1)
                            .truncationMode(.head)
                    }
                    Spacer(minLength: 4)
                    Text(ByteFormat.compact(trace.bytes))
                        .font(.system(size: 10, design: .rounded))
                        .foregroundStyle(Theme.inkSecondary)
                        .monospacedDigit()
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                if index < traces.count - 1 { Divider2().padding(.leading, 38) }
            }
        }
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: Theme.radius,
                                                        style: .continuous))
    }

    /// `~/Library/Preferences/com.vendor.app.plist` reads better than the
    /// absolute path when the folder is long.
    private func shortPath(_ path: String) -> String {
        let home = Paths.home.path
        guard path.hasPrefix(home + "/") else { return path }
        return String(path.dropFirst(home.count))
    }

    private var footerNote: some View {
        HStack(alignment: .top, spacing: 6) {
            Image(systemName: "trash")
                .font(.system(size: 10))
                .foregroundStyle(Theme.inkTertiary)
            Text("The app itself stays in the Trash, and removed files go there too, so this can be undone.")
                .font(.system(size: 10))
                .foregroundStyle(Theme.inkTertiary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: Actions

    private var actions: some View {
        HStack(spacing: 8) {
            Button("Keep Everything") { store.dismissRemovalPlan() }
                .buttonStyle(.plain)
                .font(.system(size: 11))
                .foregroundStyle(Theme.inkSecondary)

            Spacer()

            Button("Skip") { store.dismissRemovalPlan() }
                .buttonStyle(.plain)
                .font(.system(size: 11))
                .foregroundStyle(Theme.ink)
                .padding(.horizontal, 15)
                .padding(.vertical, 6)
                .background(Theme.background,
                            in: RoundedRectangle(cornerRadius: Theme.radius, style: .continuous))

            Button {
                model.isWorking.value = true
                store.performRemoval(plan: plan, traces: autoSelected)
                model.isWorking.value = false
            } label: {
                HStack(spacing: 5) {
                    if model.isWorking.value {
                        ProgressView().controlSize(.small).scaleEffect(0.6).frame(width: 12)
                    } else {
                        Image(systemName: "trash")
                            .font(.system(size: 11, weight: .semibold))
                    }
                    Text(autoSelected.isEmpty
                         ? "Remove App Only"
                         : "Remove App + \(autoSelected.count) Item\(autoSelected.count == 1 ? "" : "s")")
                        .font(.system(size: 11, weight: .semibold))
                }
                .padding(.horizontal, 15)
                .padding(.vertical, 6)
                .background(Theme.accent,
                            in: RoundedRectangle(cornerRadius: Theme.radius, style: .continuous))
                .foregroundStyle(.white)
            }
            .buttonStyle(.plain)
            .disabled(model.isWorking.value)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}