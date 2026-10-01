import SwiftUI
import MoleCore

/// The main Clean screen: category list on the left, item list in the middle,
/// and a detail inspector for the highlighted item.
struct CleanView: View {
    @EnvironmentObject var store: AppStore
        var body: some View {
        HSplitView {
            sidebar
                .frame(minWidth: 210, idealWidth: 230, maxWidth: 300)

            detail
                .frame(minWidth: 340)
        }
    }

    // MARK: Sidebar

    private var sidebar: some View {
        VStack(spacing: 0) {
            header

            ScrollView {
                VStack(spacing: 2) {
                    ForEach(store.orderedCategories) { category in
                        CategoryRow(
                            category: category,
                            totalBytes: store.bytes(for: category),
                            selectedCount: store.selectedTargets
                                .filter { $0.categoryID == category }.count,
                            totalCount: store.count(for: category),
                            keptCount: store.keptCount(for: category),
                            isActive: store.selectedCategory == category,
                            onToggleCategory: {
                                // One click means "clean exactly this". A category
                                // that is partly selected becomes fully selected,
                                // and a fully selected one clears — so the same
                                // control both narrows a clean to one category and
                                // undoes it.
                                let pool = store.targets.filter { $0.categoryID == category }
                                let selected = pool.filter { store.selectedPaths.contains($0.path) }
                                store.setCategory(category, selectAll: selected.count < pool.count)
                            })
                            .onTapGesture { store.setCategory(category, selectAll: nil) }
                            .contextMenu {
                                Button("Clean only this category") {
                                    store.setCategory(category, selectAll: true)
                                }
                                Button("Clear this category") {
                                    store.setCategory(category, selectAll: false)
                                }
                            }
                    }
                }
                .padding(.horizontal, 8)
                .padding(.bottom, 12)
            }

            Divider2()

            selectionFooter
                .padding(10)
        }
        .background(Theme.background)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Clean")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Theme.ink)
                Spacer()
                if store.scanState.isScanning {
                    ProgressView().controlSize(.small).scaleEffect(0.6).frame(width: 16)
                } else {
                    Button {
                        store.scan()
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 11, weight: .medium))
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(Theme.inkSecondary)
                    .help("Scan again")
                }
            }

            if store.scanState.isScanning {
                if case .scanning(let progress) = store.scanState {
                    Text(progress)
                        .font(.system(size: 10))
                        .foregroundStyle(Theme.inkTertiary)
                }
            } else if store.totalBytes > 0 {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text(ByteFormat.compact(store.totalBytes))
                            .font(.system(size: 20, weight: .semibold, design: .rounded))
                            .foregroundStyle(Theme.ink)
                            .monospacedDigit()
                        Text("reclaimable")
                            .font(.system(size: 11))
                            .foregroundStyle(Theme.inkTertiary)
                    }
                    if !store.blocked.isEmpty {
                        Text("\(ByteFormat.compact(store.blocked.reduce(0) { $0 + $1.bytes })) kept for safety")
                            .font(.system(size: 10))
                            .foregroundStyle(Theme.inkTertiary)
                    }
                }
            } else if case .scanned = store.scanState {
                Text("Nothing to clean. Your caches are already small.")
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.inkTertiary)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                Text("Scan to find reclaimable space.")
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.inkTertiary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.top, 12)
        .padding(.bottom, 10)
    }

    private var selectionFooter: some View {
        VStack(spacing: 8) {
            Divider2()

            Button {
                // Opens the confirmation sheet. Cleaning on a single click is
                // what let an accidental click move gigabytes.
                store.requestClean()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "trash.slash")
                        .font(.system(size: 11, weight: .semibold))
                    Text(store.selectedPaths.isEmpty
                         ? "Clean"
                         : "Clean \(ByteFormat.compact(store.selectedBytes))")
                        .font(.system(size: 12, weight: .semibold))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 7)
                .background(
                    RoundedRectangle(cornerRadius: Theme.radius, style: .continuous)
                        .fill(store.selectedPaths.isEmpty ? Theme.hairline : Theme.accent)
                )
                .foregroundStyle(store.selectedPaths.isEmpty ? Theme.inkTertiary : .white)
            }
            .buttonStyle(.plain)
            .disabled(store.selectedPaths.isEmpty || store.cleanIsRunning)

            // Shared with Settings, so the two screens cannot drift apart visually.
            DeleteModeSegments(mode: store.deleteModeBox.binding)
        }
    }

    // MARK: Detail

    private var detail: some View {
        VStack(spacing: 0) {
            listHeader
            Divider2()

            if case .failed(let message) = store.scanState {
                emptyState(symbol: "exclamationmark.triangle",
                           title: "Scan failed",
                           detail: message)
            } else if store.scanState.isScanning {
                emptyState(symbol: "hourglass",
                           title: "Scanning",
                           detail: "Measuring cache and log folders. Large folders take a moment.")
            } else if store.visibleTargets.isEmpty && store.visibleBlocked.isEmpty {
                emptyState(symbol: store.selectedCategory.symbol,
                           title: "Nothing in \(store.selectedCategory.title)",
                           detail: store.selectedCategory.summary)
            } else {
                itemList
            }
        }
        .background(Theme.surface)
    }

    private var listHeader: some View {
        VStack(spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(store.selectedCategory.title)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Theme.ink)
                    Text(store.selectedCategory.summary)
                        .font(.system(size: 10))
                        .foregroundStyle(Theme.inkTertiary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 8)

                let selection = store.visibleSelectionState
                Button(selection.selected == selection.total && selection.total > 0
                       ? "Deselect All" : "Select All") {
                    store.selectAllVisible(!(selection.selected == selection.total
                                             && selection.total > 0))
                }
                .buttonStyle(.plain)
                .font(.system(size: 11))
                .foregroundStyle(Theme.accent)
                .disabled(store.visibleTargets.isEmpty)
            }

            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 10))
                    .foregroundStyle(Theme.inkTertiary)
                TextField("Filter by name or path", text: store.searchTextBox.binding)
                    .textFieldStyle(.plain)
                    .font(.system(size: 11))
                if !store.searchTextBox.value.isEmpty {
                    Button {
                        store.searchTextBox.value = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(Theme.inkTertiary)
                    }
                    .buttonStyle(.plain)
                }
                Spacer()
                HStack(spacing: 5) {
                    Checkbox(isOn: store.showBlocked, label: "Show kept") {
                        store.showBlocked.toggle()
                    }
                    Text("Show kept")
                        .font(.system(size: 10))
                        .foregroundStyle(Theme.inkSecondary)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(
                RoundedRectangle(cornerRadius: Theme.radius, style: .continuous)
                    .fill(Theme.background)
            )
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    private var itemList: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(store.visibleTargets) { target in
                    TargetRow(
                        target: target,
                        isSelected: store.selectedPaths.contains(target.path),
                        risk: risk(for: target),
                        warning: store.warning(for: target.path),
                        onToggle: { store.toggle(target) })
                    .contextMenu {
                        Button("Reveal in Finder") { store.revealInFinder(target.path) }
                        Button("Protect This Path") { store.addToProtectList(target.path) }
                    }
                    Divider2().padding(.leading, 36)
                }

                if store.showBlocked {
                    ForEach(store.visibleBlocked) { blocked in
                        BlockedRow(blocked: blocked)
                        Divider2().padding(.leading, 36)
                    }
                }
            }
        }
    }

    private func risk(for target: CleanupTarget) -> Risk {
        // Derive risk from the rule that produced the target so a re-download
        // target cannot be silently promoted to "safe" by a label change.
        for rule in ScanCatalog.rules(for: target.categoryID) {
            if target.label.hasPrefix(rule.ruleLabel) { return rule.risk }
        }
        switch target.categoryID {
        case .trash, .deviceFirmware: return .userData
        default: return .regenerable
        }
    }

    private func emptyState(symbol: String, title: String, detail: String) -> some View {
        VStack(spacing: 10) {
            Image(systemName: symbol)
                .font(.system(size: 28, weight: .light))
                .foregroundStyle(Theme.hairline)
            Text(title)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Theme.inkSecondary)
            Text(detail)
                .font(.system(size: 11))
                .foregroundStyle(Theme.inkTertiary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 320)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(30)
    }
}

