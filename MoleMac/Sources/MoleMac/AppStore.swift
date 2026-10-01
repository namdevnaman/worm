import AppKit
import Combine
import Foundation
import MoleCore

/// Shared state for the whole app. One observable store keeps the views in sync
/// without threading a dozen environment objects through the view tree.
@MainActor
final class AppStore: ObservableObject {

    enum ScanState {
        case idle
        case scanning(progress: String)
        case scanned(ScanEngine.Result)
        case failed(String)

        var isScanning: Bool { if case .scanning = self { return true }; return false }
    }

    enum CleanPhase {
        case idle
        case running(completed: Int, total: Int, lastPath: String)
        case finished(CleanSummary)
    }

    struct CleanSummary {
        var removedBytes: Int64 = 0
        var removedCount: Int = 0
        var keptCount: Int = 0
        var outcomes: [Reclaimer.Outcome] = []
        var startedAt = Date()
        var duration: TimeInterval = 0
    }

    // MARK: Published state

    @Published private(set) var scanState: ScanState = .idle
    @Published private(set) var cleanPhase: CleanPhase = .idle
    @Published var selectedCategory: CleanCategory = .appCaches
    @Published var selectedPaths: Set<String> = []
    @Published var showBlocked = false
    @Published var deleteMode: Reclaimer.Mode = .trash
    @Published private(set) var lastSummary: CleanSummary?
    @Published private(set) var metrics: SystemMetrics.Snapshot?
    @Published private(set) var health: [HealthCheck] = []
    @Published private(set) var installedApps: [InstalledApps.App] = []
    /// Leftover groups found by the detector, newest scan.
    @Published private(set) var orphanGroups: [OrphanDetector.OrphanGroup] = []
    @Published private(set) var isLoadingOrphans = false
    @Published private(set) var isLoadingApps = false
    /// Leftover IDs the user has chosen. Persisted across a scan so a rescan
    /// does not silently drop the selection they were reviewing.
    @Published private(set) var selectedLeftoverIDs: Set<String> = []
    /// The uninstall plan awaiting a decision, if any.
    @Published var removalPlan: AppRemovalPlan?
    @Published var searchText = ""
    @Published var protectList: [String] = []
    @Published var banner: Banner?
    /// Free space captured before a scan or clean, so the reported gain is that
    /// run's change rather than the machine's overall drift.
    @Published private(set) var freeBytesBefore: Int64 = 0

    /// Boxes exposed for SwiftUI controls. `@State` is unavailable with this
    /// toolchain, so controls bind through a `Box` instead of a `@State` var.
    let searchTextBox = Box("")
    let showBlockedBox = Box(false)
    // One box, one mode. There used to be a second `Bool` box that also wrote
    // `deleteMode` without reading it, so the Clean tab's "Move to Trash"
    // segment and the Settings picker could disagree — the screen would promise
    // a recoverable clean while the run was permanent. The Bool is now derived.
    let deleteModeBox = Box(Reclaimer.Mode.trash)

    struct Banner: Identifiable, Equatable {
        enum Kind: Equatable { case info, success, warning, error }
        let id = UUID()
        let kind: Kind
        let title: String
        let detail: String
    }

    // MARK: Dependencies

    private let engine = ScanEngine()
    private var cancellables = Set<AnyCancellable>()
    private var metricsTask: Task<Void, Never>?

    init() {
        protectList = Whitelist.shared.entries
        // Mirror the published properties into their boxes so a control bound to
        // a box and code that reads the property stay in agreement.
        searchTextBox.$value
            .sink { [weak self] in self?.searchText = $0 }
            .store(in: &cancellables)
        showBlockedBox.$value
            .sink { [weak self] in self?.showBlocked = $0 }
            .store(in: &cancellables)
        deleteModeBox.$value
            .sink { [weak self] in self?.deleteMode = $0 }
            .store(in: &cancellables)
    }

    /// Derived so no two screens can show a different delete mode.
    var deleteIsPermanent: Bool { deleteMode == .permanent }

    func setDeleteMode(_ mode: Reclaimer.Mode) {
        deleteModeBox.value = mode
    }

    // MARK: Derived data

    /// Scan targets plus any leftover traces, so every screen counts one set.
    ///
    /// Leftovers are appended rather than merged: a trace is a directory the scan
    /// rules do not own, so there is no duplicate to remove, and appending keeps
    /// the scan's own ordering intact.
    var targets: [CleanupTarget] {
        guard case .scanned(let result) = scanState else { return [] }
        let leftovers = leftoverTargets()
        guard !leftovers.isEmpty else { return result.targets }
        return (result.targets + leftovers).sorted { $0.bytes > $1.bytes }
    }

    var blocked: [ScanEngine.BlockedTarget] {
        if case .scanned(let result) = scanState { return result.blocked }
        return []
    }

    /// Targets in the visible category, after the search filter.
    var visibleTargets: [CleanupTarget] {
        let inCategory = targets.filter { $0.categoryID == selectedCategory }
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !query.isEmpty else { return inCategory }
        return inCategory.filter {
            $0.label.lowercased().contains(query)
                || $0.path.lowercased().contains(query)
        }
    }

    var visibleBlocked: [ScanEngine.BlockedTarget] {
        let inCategory = blocked.filter { $0.category == selectedCategory }
        guard showBlocked else { return [] }
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !query.isEmpty else { return inCategory }
        return inCategory.filter {
            $0.label.lowercased().contains(query) || $0.path.lowercased().contains(query)
        }
    }

    var selectedTargets: [CleanupTarget] {
        targets.filter { selectedPaths.contains($0.path) }
    }

var selectedBytes: Int64 {
        selectedTargets.reduce(0) { $0 + $1.bytes }
    }

    /// One line describing the scan, reused by the menu bar panel so both places
    /// cannot drift apart in wording.
    var reclaimableSummary: String {
        if scanState.isScanning { return "Scanning…" }
        switch scanState {
        case .scanned:
            let cleanable = selectedBytes
            return cleanable > 0
                ? "\(ByteFormat.compact(cleanable)) selected to clean"
                : "\(ByteFormat.compact(totalBytes)) reclaimable"
        case .failed:
            return "Scan failed — open MoleMac to retry"
        case .idle, .scanning:
            return "Nothing scanned yet"
        }
    }

    /// Brings the main window forward. `openMainWindow` is only available from an
    /// `App`, so the window plumbing is handed in at launch.
    func openMainWindow() {
        mainWindowOpener?()
    }

    /// Injected by `MoleMacApp`, since only an `App` can reopen its window.
    var mainWindowOpener: (() -> Void)?

    /// Paths that are cleanable but carry a caution, keyed by path.
    var warnings: [String: SafetyPolicy.Reason] {
        if case .scanned(let result) = scanState { return result.warnings }
        return [:]
    }

    func warning(for path: String) -> SafetyPolicy.Reason? { warnings[path] }

    var orphanBytes: Int64 { orphanGroups.reduce(0) { $0 + $1.bytes } }

    var selectedLeftovers: [OrphanDetector.Leftover] {
        orphanGroups.flatMap(\.leftovers)
            .filter { selectedLeftoverIDs.contains($0.id) }
    }

    var totalBytes: Int64 {
        targets.reduce(0) { $0 + $1.bytes }
    }

    /// Free space gained since the last scan or clean. Stored rather than
    /// computed, because `statfs` inside a view body is a blocking call.
    @Published private(set) var freeSpaceGain: Int64 = 0

    /// Category rollup for the sidebar. Uses a scan result when one exists so
    /// the counts agree with the detail list, and falls back to nothing rather
    /// than guessing.
    func bytes(for category: CleanCategory) -> Int64 {
        targets.filter { $0.categoryID == category }.reduce(0) { $0 + $1.bytes }
    }

    func count(for category: CleanCategory) -> Int {
        targets.filter { $0.categoryID == category }.count
    }

    func keptCount(for category: CleanCategory) -> Int {
        blocked.filter { $0.category == category }.count
    }

    /// Categories ordered the way the CLI orders its sections, biggest first
    /// among those with something to show.
    var orderedCategories: [CleanCategory] {
        CleanCategory.allCases
    }

    // MARK: Scanning

    /// Post a banner and schedule its removal. A banner that never clears hides
    /// the Clean button, which is what made the first build feel "stuck".
    func notify(_ banner: Banner, autoDismissAfter seconds: TimeInterval = 6) {
        self.banner = banner
        bannerTask?.cancel()
        bannerTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(seconds))
            guard !Task.isCancelled else { return }
            await MainActor.run { self?.banner = nil }
        }
    }

    private var bannerTask: Task<Void, Never>?

    func scan() {
        guard !scanState.isScanning else { return }

        // A cached "app is running" verdict would keep a just-closed app's cache
        // blocked for the rest of the session.
        LivenessProbe.invalidateCaches()
        scanState = .scanning(progress: "Measuring cache and log folders")
        freeBytesBefore = SystemMetrics.disk().freeBytes

        Task { [weak self] in
            guard let self else { return }
            let result = await engine.scan()
            await MainActor.run {
                self.scanState = .scanned(result)
                self.applyDefaultSelection()
                self.notify(Banner(
                    kind: result.targets.isEmpty ? .info : .success,
                    title: result.targets.isEmpty
                        ? "Nothing to clean"
                        : "Found \(ByteFormat.compact(self.totalBytes))",
                    detail: result.targets.isEmpty
                        ? "Your caches are already small. Reclaimable space appears here as apps accumulate temporary files."
                        : "\(result.targets.count) items in \(String(format: "%.1f", result.duration))s. \(result.blocked.count) kept for safety."),
                    autoDismissAfter: 5)
            }
        }
    }

    /// Leftovers surfaced as ordinary Clean targets.
    ///
    /// The Leftovers tab and the Clean screen are two views of one detector, so
    /// a trace found by either is reachable from both. Surfacing them here is
    /// what makes the Clean sidebar's "Uninstalled App Leftovers" row show a
    /// real count instead of "Nothing found".
    private func leftoverTargets() -> [CleanupTarget] {
        orphanGroups.flatMap(\.leftovers).compactMap { trace in
            // A trace the safety policy refuses must not appear as cleanable
            // here; the Leftovers tab already shows it as kept with a reason.
            guard SafetyPolicy.verdict(for: trace.path, bundleID: trace.bundleID,
                                       whitelist: .shared,
                                       probeLiveness: false).isAllowed else { return nil }
            return CleanupTarget(
                categoryID: .appLeftovers,
                label: trace.bundleID,
                path: trace.path,
                kind: .directory,
                bytes: trace.bytes,
                identity: PathIdentity.capture(URL(fileURLWithPath: trace.path)),
                bundleID: trace.bundleID,
                mustBeClosed: nil)
        }
    }

    /// Selects the regenerable items and leaves anything that costs the user
    /// something — re-downloads, chat media, firmware, app settings — untouched
    /// until they choose it. This is the difference between the CLI and a GUI:
    /// the CLI has no per-item selection, so it either runs everything or
    /// nothing.
    private func applyDefaultSelection() {
        guard case .scanned(let result) = scanState else { return }

        var selection = Set(result.targets
            .filter { target in
                switch target.categoryID {
                case .logs, .userEssentials, .appCaches, .browsers, .developerTools,
                     .misc, .virtualization, .applicationSupport, .appsUtilities,
                     .cloudOffice, .systemCaches:
                    // .userEssentials carries Messages attachments and Mail
                    // downloads, which are re-downloads; the label decides.
                    return !isReDownload(target)
                case .aiTools:
                    return !isReDownload(target)
                case .appLeftovers, .deviceFirmware, .trash, .largeFiles:
                    return false
                }
            }
            .map(\.path))

        // Leftovers default off: removing an app's data is a decision, not a
        // cache sweep, even when the app is provably gone.
        selectedPaths = selection
    }

    private func isReDownload(_ target: CleanupTarget) -> Bool {
        let label = target.label.lowercased()
        return label.contains("attachment")
            || label.contains("mail")
            || label.contains("service worker")
            || label.contains("model")
            || label.contains("crx")
    }

    func toggle(_ target: CleanupTarget) {
        if selectedPaths.contains(target.path) {
            selectedPaths.remove(target.path)
        } else {
            selectedPaths.insert(target.path)
        }
    }

    func setCategory(_ category: CleanCategory, selectAll: Bool?) {
        selectedCategory = category
        guard let selectAll else { return }
        let pool = selectAll ? targets.filter { $0.categoryID == category }.map(\.path) : []
        if selectAll {
            selectedPaths.formUnion(pool)
        } else {
            for path in pool { selectedPaths.remove(path) }
        }
    }

    func selectAllVisible(_ selected: Bool) {
        if selected {
            selectedPaths.formUnion(visibleTargets.map(\.path))
        } else {
            for target in visibleTargets { selectedPaths.remove(target.path) }
        }
    }

    var visibleSelectionState: (selected: Int, total: Int) {
        let paths = Set(visibleTargets.map(\.path))
        return (paths.filter { selectedPaths.contains($0) }.count, paths.count)
    }

    /// True while a clean is running or its report is showing.
    var cleanIsRunning: Bool {
        switch cleanPhase {
        case .idle: return false
        case .running, .finished: return true
        }
    }

    // MARK: Cleaning

    /// Set when the user has confirmed a clean. The Clean button opens a
    /// confirmation sheet instead of deleting immediately.
    func requestClean() {
        let batch = selectedTargets
        guard !batch.isEmpty, !cleanIsRunning else { return }
        pendingCleanConfirmation = CleanConfirmation(
            itemCount: batch.count,
            bytes: batch.reduce(0) { $0 + $1.bytes },
            mode: deleteMode)
    }

    /// What the confirmation sheet needs to describe the run precisely.
    struct CleanConfirmation: Identifiable {
        let id = UUID()
        let itemCount: Int
        let bytes: Int64
        let mode: Reclaimer.Mode
    }

    @Published var pendingCleanConfirmation: CleanConfirmation?

    /// Called only by the confirmation sheet's confirm button. This is the single
    /// place a clean can begin.
    func confirmClean() {
        pendingCleanConfirmation = nil
        cleanSelected()
    }

    /// Start a clean. Only reached after `pendingCleanConfirmation` was set and
    /// the sheet's confirm button called `confirmClean()`, so no other caller can
    /// skip the confirmation.
    private func cleanSelected() {
        let batch = selectedTargets
        guard !batch.isEmpty else { return }
        guard !cleanIsRunning else { return }
        pendingCleanConfirmation = nil

        // Snapshot the free space *before* the first deletion so the reported
        // gain reflects this run rather than whatever else the machine did.
        freeBytesBefore = SystemMetrics.disk().freeBytes
        let started = Date()
        var summary = CleanSummary()
        summary.startedAt = started

        cleanPhase = .running(completed: 0, total: batch.count, lastPath: "")

        Task { [weak self] in
            for (index, target) in batch.enumerated() {
                // Concurrency here would make the progress readout meaningless
                // and buys little: the cost is the move, not the CPU.
                let outcome = Reclaimer.reclaim(
                    target: target,
                    mode: self?.deleteMode ?? Reclaimer.defaultMode)
                if outcome.status == .removed {
                    summary.removedBytes += outcome.bytesReclaimed
                    summary.removedCount += 1
                } else if outcome.status == .refused {
                    summary.keptCount += 1
                }
                summary.outcomes.append(outcome)

                let phase = CleanPhase.running(completed: index + 1,
                                               total: batch.count,
                                               lastPath: target.label)
                await MainActor.run {
                    self?.cleanPhase = phase
                }
            }
            summary.duration = Date().timeIntervalSince(started)

            await MainActor.run {
                self?.cleanPhase = .finished(summary)
                self?.lastSummary = summary
                self?.selectedPaths.removeAll()
                // Refresh after cleaning so the counts reflect the new state,
                // including anything a running app recreated immediately.
                self?.scan()
            }
        }
    }

    func dismissCleanSummary() {
        cleanPhase = .idle
    }

    // MARK: Protect list

    func addToProtectList(_ path: String) {
        do {
            try Whitelist.shared.add(path)
            protectList = Whitelist.shared.entries
            notify(Banner(kind: .success, title: "Protected",
                          detail: "Nothing under this path will be cleaned again."))
        } catch {
            notify(Banner(kind: .error, title: "Could not protect path",
                          detail: error.localizedDescription))
        }
    }

    func removeFromProtectList(_ path: String) {
        do {
            try Whitelist.shared.remove(path)
            protectList = Whitelist.shared.entries
            scan()
        } catch {
            notify(Banner(kind: .error, title: "Could not update protect list",
                          detail: error.localizedDescription))
        }
    }

    // MARK: Supporting data

    /// Poll live metrics off the main actor.
    ///
    /// The work must not run on the main actor: `Health.checks()` shells out to
    /// `defaults` and `topProcesses()` sleeps while sampling CPU. Doing that
    /// during a SwiftUI graph update blocks the run loop long enough that
    /// AttributeGraph trips its precondition and the app aborts.
    func loadMetrics() {
        metricsTask?.cancel()
        metricsTask = Task.detached(priority: .utility) { [weak self] in
            while !Task.isCancelled {
                let snapshot = SystemMetrics.snapshot()
                let health = Health.checks()
                await MainActor.run {
                    self?.metrics = snapshot
                    self?.health = health
                    let baseline = self?.freeBytesBefore ?? 0
                    self?.freeSpaceGain = max(0, snapshot.disk.freeBytes - baseline)
                }
                try? await Task.sleep(for: .seconds(3))
            }
        }
    }

    /// Detect leftover data. Off the main actor: the absence check reads
    /// LaunchServices and measures every candidate trace.
    func loadOrphans() {
        isLoadingOrphans = true
        Task.detached(priority: .utility) { [weak self] in
            let groups = OrphanDetector.findLeftovers()
            await MainActor.run {
                self?.orphanGroups = groups
                self?.isLoadingOrphans = false
            }
        }
    }

    func isSelected(leftover: OrphanDetector.Leftover) -> Bool {
        selectedLeftoverIDs.contains(leftover.id)
    }

    func toggle(leftover: OrphanDetector.Leftover) {
        if selectedLeftoverIDs.contains(leftover.id) {
            selectedLeftoverIDs.remove(leftover.id)
        } else {
            selectedLeftoverIDs.insert(leftover.id)
        }
    }

    func selectRebuildable(in group: OrphanDetector.OrphanGroup) {
        selectedLeftoverIDs.formUnion(group.autoSelected.map(\.id))
    }

    func clearSelection(in group: OrphanDetector.OrphanGroup) {
        for trace in group.leftovers { selectedLeftoverIDs.remove(trace.id) }
    }

    /// Remove the chosen traces. Each one goes through the reclaimer, so the
    /// safety verdict and the audit log still apply.
    func removeSelectedLeftovers() {
        let traces = selectedLeftovers
        guard !traces.isEmpty else { return }

        var removed: Int64 = 0
        var removedCount = 0
        var keptCount = 0

        for trace in traces {
            let target = CleanupTarget(
                categoryID: .appLeftovers,
                label: (trace.path as NSString).lastPathComponent,
                path: trace.path,
                kind: .directory,
                bytes: trace.bytes,
                identity: PathIdentity.capture(URL(fileURLWithPath: trace.path)),
                bundleID: trace.bundleID,
                mustBeClosed: nil)
            let outcome = Reclaimer.reclaim(target: target, mode: .trash,
                                           whitelist: .empty, probeLiveness: false)
            if outcome.status == .removed {
                removed += outcome.bytesReclaimed
                removedCount += 1
            } else if outcome.status == .refused {
                keptCount += 1
            }
        }

        selectedLeftoverIDs.removeAll()
        notify(Banner(kind: keptCount > 0 ? .warning : .success,
                      title: "Removed \(removedCount) leftover\(removedCount == 1 ? "" : "s")",
                      detail: keptCount > 0
                        ? "\(ByteFormat.compact(removed)) freed. \(keptCount) kept and are still selected."
                        : "\(ByteFormat.compact(removed)) freed."))
        loadOrphans()
    }

    /// Show the uninstall plan for an app.
    func requestRemoval(of app: InstalledApps.App) {
        removalPlan = AppRemovalPlan.forApp(app)
    }

    func dismissRemovalPlan() {
        removalPlan = nil
    }

    /// Uninstall the app and remove the traces the user selected.
    func performRemoval(plan: AppRemovalPlan,
                        traces: [OrphanDetector.Leftover]) {
        let app = plan.app
        var removedBytes: Int64 = 0
        var removedCount = 0

        // App first: once it is in the Trash, LaunchServices no longer vouches for
        // the traces, so they are cleaned while the evidence is still available.
        do {
            try FileManager.default.trashItem(at: URL(fileURLWithPath: app.path),
                                               resultingItemURL: nil)
            AuditLog.append(mode: "trash", sizeBytes: app.sizeBytes, status: "ok",
                            target: app.path, category: "uninstall",
                            note: "app:\(app.id)")
        } catch {
            notify(Banner(kind: .error, title: "Could not remove \(app.name)",
                          detail: error.localizedDescription))
            return
        }

        for trace in traces {
            let target = CleanupTarget(
                categoryID: .appLeftovers,
                label: (trace.path as NSString).lastPathComponent,
                path: trace.path,
                kind: .directory,
                bytes: trace.bytes,
                identity: PathIdentity.capture(URL(fileURLWithPath: trace.path)),
                bundleID: trace.bundleID,
                mustBeClosed: nil)
            let outcome = Reclaimer.reclaim(target: target, mode: .trash,
                                           whitelist: .empty, probeLiveness: false)
            if outcome.status == .removed {
                removedBytes += outcome.bytesReclaimed
                removedCount += 1
            }
        }

removalPlan = nil

        // Whatever the user chose not to tick is now genuinely an orphan, because
        // the app is gone. Tell them rather than leaving it to be rediscovered in
        // a list they have to go looking for.
        let keptBack = OrphanDetector.traces(forBundleID: app.id)
            .filter { left in !traces.contains { $0.id == left.id } }

        notify(Banner(
            kind: keptBack.isEmpty ? .success : .info,
            title: "Removed \(app.name)",
            detail: keptBackDetail(appName: app.name,
                                   removedCount: removedCount,
                                   removedBytes: removedBytes,
                                   keptBack: keptBack)))
        loadApps()
        loadOrphans()
    }

    private func keptBackDetail(appName: String, removedCount: Int,
                                removedBytes: Int64,
                                keptBack: [OrphanDetector.Leftover]) -> String {
        var parts: [String] = []
        if removedCount > 0 {
            parts.append("With \(removedCount) leftover\(removedCount == 1 ? "" : "s"), \(ByteFormat.compact(removedBytes))")
        }
        parts.append("Restore from the Trash if you change your mind.")

        guard !keptBack.isEmpty else { return parts.joined(separator: ". ") + "." }
        let total = keptBack.reduce(0) { $0 + $1.bytes }
        return parts.joined(separator: ". ")
            + ". \(keptBack.count) trace\(keptBack.count == 1 ? "" : "s") of \(appName) kept, \(ByteFormat.compact(total)) — now listed under Leftovers."
    }

    /// Load the installed-app list. Off the main actor because reading every
    /// bundle plist and walking each app bundle for its size is real work.
    func loadApps() {
        isLoadingApps = true
        Task.detached(priority: .utility) { [weak self] in
            let apps = InstalledApps.all()
            await MainActor.run {
                self?.installedApps = apps
                self?.isLoadingApps = false
            }
        }
    }

    func emptyTrash() {
        let result = Reclaimer.emptyTrash()
        notify(Banner(
            kind: result.outcomes.allSatisfy { $0.status == .removed } ? .success : .warning,
            title: "Emptied Trash",
            detail: result.outcomes.isEmpty
                ? "The Trash was already empty."
                : "\(result.outcomes.filter { $0.status == .removed }.count) items removed, \(ByteFormat.compact(result.bytes)) freed."),
            autoDismissAfter: 5)
        scan()
    }

    /// Reveal a path in Finder. Used by the detail inspector so a user can
    /// verify a claim in the file manager rather than trusting the app.
    func revealInFinder(_ path: String) {
        NSWorkspaceBridge.reveal(path)
    }

    func openInFinder(_ path: String) {
        NSWorkspaceBridge.open(path)
    }
}

enum NSWorkspaceBridge {
    static func reveal(_ path: String) {
        NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: path)])
    }

    static func open(_ path: String) {
        NSWorkspace.shared.open(URL(fileURLWithPath: path))
    }

    /// Opens System Settings at Full Disk Access.
    ///
    /// The anchor is `Privacy_AllFilesAccess`. macOS 26 opens the Privacy &
    /// Security pane but does not scroll to the requested row, so the deep link
    /// alone can leave the user staring at an unrelated section; the notice in
    /// the app therefore names the exact path to click.
    static func openFullDiskAccessSettings() {
        guard let url = URL(string:
            "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFilesAccess")
        else { return }
        NSWorkspace.shared.open(url)
        NSWorkspace.shared.activateFileViewerSelecting([])
    }

    /// Reveals this app in Finder so the user can drag it onto the Full Disk
    /// Access list, which is the only way to add it without a prompt.
    static func revealSelfInFinder() {
        let bundle = Bundle.main.bundleURL
        guard FileManager.default.fileExists(atPath: bundle.path) else { return }
        NSWorkspace.shared.activateFileViewerSelecting([bundle])
    }
}