import WormCore
import SwiftUI

/// Leftovers screen: every trace left by apps that are no longer installed.
///
/// Each app is one row with its traces nested beneath, so a user reads it as
/// "this app left these things behind" rather than as a flat list of folders.
/// Nothing here is pre-selected at the app level; selection is per trace, so
/// the reversible items can go while settings stay until confirmed.
struct LeftoversView: View {
    @EnvironmentObject var store: AppStore
    @StateObject private var expanded = Box<Set<String>>([])
    @StateObject private var search = Box("")
    @StateObject private var showOnlyReview = Box(false)

    var body: some View {
        // Fixed column layout rather than `HSplitView`: the list pane is pushed
        // to the bottom of the window by the split view's own sizing, and the
        // user has to drag it back every time the tab is opened.
        HStack(spacing: 0) {
            list
                .frame(width: 420)
                .frame(maxHeight: .infinity)

            Rectangle()
                .fill(Theme.hairline)
                .frame(width: 1)

            detail
                .frame(maxWidth: .infinity)
        }
        .task {
            if store.orphanGroups.isEmpty { store.loadOrphans() }
        }
    }

    // MARK: List

    private var list: some View {
        VStack(spacing: 0) {
            header

            if store.isLoadingOrphans {
                loading
            } else if store.orphanGroups.isEmpty {
                empty
            } else {
                ScrollView {
                    // A plain VStack, not a LazyVStack: the lazy variant does not
                    // report a bounded content height, which lets the enclosing
                    // stack push it toward the bottom of the window.
                    VStack(spacing: 0) {
                        ForEach(visibleGroups) { group in
                            groupRow(group)
                            if expanded.value.contains(group.bundleID) {
                                ForEach(group.leftovers) { trace in
                                    traceRow(group: group, trace: trace)
                                }
                            }
                            Divider2().padding(.leading, 12)
                        }
                    }
                    .padding(.bottom, 12)
                }
            }
        }
        .background(Theme.surface)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Image(systemName: "trash.slash")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.inkTertiary)
                Text("Leftovers")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Theme.ink)

                Spacer()

                if store.isLoadingOrphans {
                    ProgressView().controlSize(.small).scaleEffect(0.6).frame(width: 16)
                } else {
                    Button { store.loadOrphans() } label: {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 11, weight: .medium))
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(Theme.inkSecondary)
                    .help("Scan again")
                }
            }

            Text("Data left behind by apps you removed. Nothing here is deleted until you choose it.")
                .font(.system(size: 10))
                .foregroundStyle(Theme.inkTertiary)
                .fixedSize(horizontal: false, vertical: true)

            if !store.orphanGroups.isEmpty {
                HStack(spacing: 12) {
                    Text("\(store.orphanGroups.count) apps")
                    Text(ByteFormat.compact(store.orphanBytes))
                    Spacer()

                    Button("Select All") {
                        store.selectAllLeftovers()
                    }
                    .buttonStyle(.plain)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Theme.accent)

                    Text("·")
                        .foregroundStyle(Theme.inkTertiary)

                    Button("Clear") {
                        store.deselectAllLeftovers()
                    }
                    .buttonStyle(.plain)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Theme.inkTertiary)
                }
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Theme.ink)
                .monospacedDigit()
            }

            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 10))
                    .foregroundStyle(Theme.inkTertiary)
                TextField("Filter apps", text: search.binding)
                    .textFieldStyle(.plain)
                    .font(.system(size: 11))
                if !search.value.isEmpty {
                    Button { search.value = "" } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(Theme.inkTertiary)
                    }
                    .buttonStyle(.plain)
                }
                Spacer()
                HStack(spacing: 4) {
                    Checkbox(isOn: showOnlyReview.value,
                             label: "Only items needing review") {
                        showOnlyReview.toggle()
                    }
                    Text("Needs review")
                        .font(.system(size: 10))
                        .foregroundStyle(Theme.inkSecondary)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(Theme.background,
                        in: RoundedRectangle(cornerRadius: Theme.radius, style: .continuous))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    private var loading: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(Theme.surfaceRaised)
                    .frame(width: 80, height: 80)
                    .overlay(Circle().strokeBorder(Theme.accent.opacity(0.4), lineWidth: 2))
                    .shadow(color: Theme.accent.opacity(0.18), radius: 10, y: 3)
                DiggingWormAnimation(size: 64)
            }
            Text("Worm is digging into leftover folders…")
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundStyle(Theme.ink)
            Text("Finding leftovers from uninstalled apps.")
                .font(.system(size: 11))
                .foregroundStyle(Theme.inkTertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var empty: some View {
        VStack(spacing: 10) {
            Image(systemName: "checkmark.seal")
                .font(.system(size: 28, weight: .light))
                .foregroundStyle(Theme.accent)
            Text("No leftovers found")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Theme.ink)
            Text("Every app that has data on this Mac still has its app installed.")
                .font(.system(size: 11))
                .foregroundStyle(Theme.inkTertiary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 280)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(30)
    }

    private var visibleGroups: [OrphanDetector.OrphanGroup] {
        let query = search.value.lowercased().trimmingCharacters(in: .whitespaces)
        var result = store.orphanGroups
        if showOnlyReview.value {
            result = result.filter { !$0.leftovers.filter(\.needsReview).isEmpty }
        }
        guard !query.isEmpty else { return result }
        return result.filter {
            $0.bundleID.lowercased().contains(query)
                || $0.displayName.lowercased().contains(query)
                || $0.leftovers.contains { $0.path.lowercased().contains(query) }
        }
    }

    // MARK: Rows

    private func groupRow(_ group: OrphanDetector.OrphanGroup) -> some View {
        let isExpanded = expanded.value.contains(group.bundleID)
        let removable = group.leftovers.filter {
            SafetyPolicy.verdict(for: $0.path, bundleID: $0.bundleID,
                                 whitelist: .empty, probeLiveness: false).isAllowed
        }
        let selectedCount = group.leftovers.filter { store.isSelected(leftover: $0) }.count
        let allSelected = !removable.isEmpty && removable.allSatisfy { store.isSelected(leftover: $0) }

        return HStack(spacing: 8) {
            // App-level Checkbox: one click selects all traces in this app
            Checkbox(isOn: allSelected, label: "Select all items in \(group.displayName)") {
                store.toggleGroup(group)
            }

            Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(Theme.inkTertiary)
                .frame(width: 10)

            VStack(alignment: .leading, spacing: 1) {
                Text(group.displayName)
                    .font(.system(size: 12, weight: isExpanded ? .semibold : .regular))
                    .foregroundStyle(Theme.ink)
                    .lineLimit(1)
                HStack(spacing: 5) {
                    Text(group.bundleID)
                        .font(.system(size: 9))
                        .foregroundStyle(Theme.inkTertiary)
                        .lineLimit(1)
                    if group.reviewCount > 0 {
                        Badge(text: "\(group.reviewCount) need review",
                              color: Theme.warn, background: Theme.warnSoft)
                    }
                }
            }

            Spacer(minLength: 4)

            if selectedCount > 0 {
                Badge(text: "\(selectedCount) selected",
                      color: Theme.accent, background: Theme.accentSoft)
            }
            Text(ByteFormat.compact(group.bytes))
                .font(.system(size: 11, design: .rounded))
                .foregroundStyle(Theme.inkSecondary)
                .monospacedDigit()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .contentShape(Rectangle())
        .onTapGesture {
            var next = expanded.value
            if next.contains(group.bundleID) { next.remove(group.bundleID) } else {
                next.insert(group.bundleID)
            }
            expanded.value = next
        }
        .contextMenu {
            Button("Select All in App") { store.toggleGroup(group) }
            Button("Select Rebuildable Items") { store.selectRebuildable(in: group) }
            Button("Clear Selection") { store.clearSelection(in: group) }
        }
    }

    private func traceRow(group: OrphanDetector.OrphanGroup,
                          trace: OrphanDetector.Leftover) -> some View {
        HStack(spacing: 9) {
            Checkbox(isOn: store.isSelected(leftover: trace),
                     label: "Select \(trace.path)") {
                store.toggle(leftover: trace)
            }
            .disabled(!canRemove(trace))
            .opacity(canRemove(trace) ? 1 : 0.4)

            Image(systemName: trace.location.symbol)
                .font(.system(size: 10))
                .foregroundStyle(Theme.inkTertiary)
                .frame(width: 14)

            VStack(alignment: .leading, spacing: 1) {
                Text(trace.path.components(separatedBy: "/Library/").last
                    ?? (trace.path as NSString).lastPathComponent)
                    .font(.system(size: 11))
                    .foregroundStyle(canRemove(trace) ? Theme.ink : Theme.inkTertiary)
                    .lineLimit(1)
                    .truncationMode(.head)
                HStack(spacing: 5) {
                    Text(trace.location.displayName)
                    Text("·")
                    Text("\(trace.ageDays)d old")
                    if trace.needsReview {
                        Text("· needs review")
                            .foregroundStyle(Theme.warn)
                    }
                }
                .font(.system(size: 9))
                .foregroundStyle(Theme.inkTertiary)
            }

            Spacer(minLength: 4)

            Text(SizeMeasurer.isMeasurementValid(trace.path)
                 ? ByteFormat.compact(trace.bytes) : "needs access")
                .font(.system(size: 10, design: .rounded))
                .foregroundStyle(SizeMeasurer.isMeasurementValid(trace.path)
                                 ? Theme.inkTertiary : Theme.warn)
                .monospacedDigit()
        }
        .padding(.leading, 31)
        .padding(.trailing, 12)
        .padding(.vertical, 5)
        .background(Theme.surfaceRaised.opacity(isSelected(trace) ? 1 : 0))
    }

    private func isSelected(_ trace: OrphanDetector.Leftover) -> Bool {
        store.isSelected(leftover: trace)
    }

    private func canRemove(_ trace: OrphanDetector.Leftover) -> Bool {
        SafetyPolicy.verdict(for: trace.path, bundleID: trace.bundleID,
                             whitelist: .empty, probeLiveness: false).isAllowed
    }

    // MARK: Detail

    private var detail: some View {
        VStack(spacing: 0) {
            if store.isLoadingOrphans {
                Spacer()
            } else {
                summary
                Divider2()
                actions
            }
        }
        .background(Theme.background)
    }

    private var summary: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Selection")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Theme.ink)

            let selected = store.selectedLeftovers
            VStack(spacing: 6) {
                statRow("Items", "\(selected.count)")
                statRow("Size", ByteFormat.compact(selected.reduce(0) { $0 + $1.bytes }))
                statRow("Need review",
                        "\(selected.filter(\.needsReview).count)",
                        tint: selected.contains(where: \.needsReview) ? Theme.warn : nil)
            }

            if selected.isEmpty {
                Text("Nothing selected. Open an app to choose which traces to remove.")
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.inkTertiary)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                VStack(alignment: .leading, spacing: 5) {
                    Text("By location")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(Theme.inkTertiary)
                    ForEach(byLocation(selected), id: \.0) { location, count, bytes in
                        HStack {
                            Image(systemName: location.symbol)
                                .font(.system(size: 10))
                                .foregroundStyle(Theme.inkTertiary)
                                .frame(width: 14)
                            Text(location.displayName)
                                .font(.system(size: 11))
                                .foregroundStyle(Theme.ink)
                            Spacer()
                            Text("\(count)")
                                .font(.system(size: 10))
                                .foregroundStyle(Theme.inkTertiary)
                            Text(ByteFormat.compact(bytes))
                                .font(.system(size: 10, design: .rounded))
                                .foregroundStyle(Theme.inkSecondary)
                                .monospacedDigit()
                                .frame(width: 60, alignment: .trailing)
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
    }

    private func byLocation(_ traces: [OrphanDetector.Leftover])
    -> [(OrphanDetector.Leftover.Location, Int, Int64)] {
        var totals: [OrphanDetector.Leftover.Location: (Int, Int64)] = [:]
        for trace in traces {
            let existing = totals[trace.location] ?? (0, 0)
            totals[trace.location] = (existing.0 + 1, existing.1 + trace.bytes)
        }
        return totals.map { ($0.key, $0.value.0, $0.value.1) }
            .sorted { $0.2 > $1.2 }
    }

    private func statRow(_ title: String, _ value: String, tint: Color? = nil) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 11))
                .foregroundStyle(Theme.inkSecondary)
            Spacer()
            Text(value)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(tint ?? Theme.ink)
                .monospacedDigit()
        }
    }

    private var actions: some View {
        VStack(alignment: .leading, spacing: 10) {
            let selected = store.selectedLeftovers
            let blocked = selected.filter {
                !SafetyPolicy.verdict(for: $0.path, bundleID: $0.bundleID,
                                      whitelist: .empty, probeLiveness: false).isAllowed
            }

            if !blocked.isEmpty {
                HStack(alignment: .top, spacing: 6) {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(Theme.danger)
                    Text("\(blocked.count) selected item\(blocked.count == 1 ? "" : "s") cannot be removed by this app and will be skipped.")
                        .font(.system(size: 10))
                        .foregroundStyle(Theme.danger)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(9)
                .background(Theme.dangerSoft,
                            in: RoundedRectangle(cornerRadius: Theme.radius, style: .continuous))
            }

            Button {
                store.removeSelectedLeftovers()
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: "trash")
                        .font(.system(size: 11, weight: .semibold))
                    Text(selected.isEmpty
                         ? "Remove Selected"
                         : "Remove \(selected.count) Item\(selected.count == 1 ? "" : "s")")
                        .font(.system(size: 12, weight: .semibold))
                        .contentTransition(.numericText())
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 7)
                .background(
                    RoundedRectangle(cornerRadius: Theme.radius, style: .continuous)
                        .fill(selected.isEmpty ? Theme.hairline : Theme.accent))
                .foregroundStyle(selected.isEmpty ? Theme.inkTertiary : .white)
            }
            .buttonStyle(FluidButtonStyle(scale: 0.97))
            .animation(Theme.springSmooth, value: selected.count)
            .disabled(selected.isEmpty || store.cleanIsRunning)

            Text("Removed items go to the Trash, so you can put them back if an app turns out to want them.")
                .font(.system(size: 10))
                .foregroundStyle(Theme.inkTertiary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}