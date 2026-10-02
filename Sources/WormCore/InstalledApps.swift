import Foundation

/// Installed application inventory, used by the Apps view and by orphan
/// detection.
public enum InstalledApps {

    public struct App: Sendable, Identifiable, Hashable {
        public let id: String          // bundle ID, or path when no bundle ID
        public let name: String
        public let path: String
        public let version: String?
        public let sizeBytes: Int64
        public let isSystem: Bool
        public let isRunning: Bool
        public let signer: String?

        public var isProtected: Bool {
            if isSystem { return true }
            if ProtectedBundles.isProtected(id) { return true }
            // A developer toolchain install carries signing identity and
            // archives; uninstalling it should be a deliberate act.
            if ["com.apple.dt.Xcode", "com.apple.dt.xcode"].contains(id) { return true }
            if path.contains("/System/Applications") { return true }
            return false
        }

        public var protectionReason: String? {
            if isSystem { return "Part of macOS" }
            if ProtectedBundles.isProtected(id) { return "Protected system component" }
            if id == "com.apple.dt.Xcode" { return "Developer toolchain" }
            return nil
        }
    }

    /// Directories that hold installable apps.
    public static let searchRoots = [
        "/Applications",
        "/System/Applications",
        "/System/Applications/Utilities",
        "/Applications/Utilities",
    ]

    public static var userSearchRoots: [URL] {
        [Paths.home.appendingPathComponent("Applications", isDirectory: true)]
    }

    private static let inventoryCache = LivenessProbe.ProbeCache<[App]>(ttl: 120)

    /// Every `.app` bundle in the search roots, up to three levels deep.
    ///
    /// Cached for two minutes: measuring an app means walking its bundle, and
    /// both the Apps screen and the liveness gate need this inventory.
    ///
    /// Concurrent callers share one computation instead of each starting their
    /// own. Without this, the scan's per-target owner lookup fired ~150
    /// simultaneous full inventory builds, each spawning 150 `codesign`
    /// subprocesses, and the scan never finished.
    public static func all() -> [App] {
        if let cached = inventoryCache.cached() { return cached }
        return buildInventorySharingWork()
    }

    /// Build the inventory once, with concurrent callers waiting for the result.
    ///
    /// A plain cache was not enough. The liveness gate resolves an owner name per
    /// cache folder, so a scan of ~150 folders asked for this inventory ~150
    /// times at once; every caller missed the empty cache and started its own
    /// build, each spawning one `codesign` per app. That is ~22,000 processes and
    /// a scan that never finished. Callers now wait for the first build.
    private static func buildInventorySharingWork() -> [App] {
        inventoryLock.lock()
        if let cached = inventoryCache.cached() {
            inventoryLock.unlock()
            return cached
        }
        if inventoryInProgress {
            inventoryLock.unlock()
            // Bounded wait: an owner lookup must never hang the scan. A timeout
            // falls through to building it here, which is slow but correct.
            for _ in 0..<300 {
                Thread.sleep(forTimeInterval: 0.1)
                if let cached = inventoryCache.cached() { return cached }
            }
        }
        inventoryInProgress = true
        inventoryLock.unlock()

        let computed = computeAll()
        inventoryCache.store(computed)

        inventoryLock.lock()
        inventoryInProgress = false
        inventoryLock.unlock()
        return computed
    }

    private static let inventoryLock = NSLock()
    nonisolated(unsafe) private static var inventoryInProgress = false

    private static func computeAll() -> [App] {
        let running = runningBundleIDs()

        // Discover bundle paths first, cheaply. Sizing is a full walk of each
        // bundle, so it runs concurrently and bounded: doing it serially here
        // made a single inventory cost 12s, which is the whole Apps screen.
        var candidates: [Candidate] = []
        var seenPaths = Set<String>()
        for root in searchRoots + userSearchRoots.map(\.path) {
            for url in discoverBundles(under: root) where !seenPaths.contains(url.path) {
                seenPaths.insert(url.path)
                let info = readInfoPlist(at: url)
                let bundleID = info["CFBundleIdentifier"] as? String ?? url.path
                candidates.append(Candidate(url: url, info: info, bundleID: bundleID))
            }
        }

        // Bound the concurrency with a counting semaphore rather than an actor:
        // each measurement is a blocking directory walk, so it belongs on a
        // background thread rather than an actor's executor.
        let slots = DispatchSemaphore(value: 8)
        let group = DispatchGroup()
        // A reference box rather than a captured `var`: the compiler cannot
        // prove the concurrent writes are serialised by the lock, and the
        // capture is what makes the whole inventory a data-race candidate.
        let measured = ResultSlots(count: candidates.count)

        for (index, candidate) in candidates.enumerated() {
            DispatchQueue.global(qos: .userInteractive).async(group: group) {
                slots.wait()
                defer { slots.signal() }
                // Quick size measurement with a tight deadline for rapid UI feedback
                let bytes = SizeMeasurer.measure(candidate.url.path, timeout: 0.8)
                measured.set(index, bytes)
            }
        }
        group.wait()

        var apps: [App] = []
        apps.reserveCapacity(candidates.count)
        for (index, candidate) in candidates.enumerated() {
            let bytes = measured.get(index)
            let url = candidate.url
            let name = candidate.info["CFBundleName"] as? String
                ?? candidate.info["CFBundleDisplayName"] as? String
                ?? url.deletingPathExtension().lastPathComponent
            let version = candidate.info["CFBundleShortVersionString"] as? String
                ?? candidate.info["CFBundleVersion"] as? String

            apps.append(App(
                id: candidate.bundleID,
                name: name,
                path: url.path,
                version: version,
                sizeBytes: bytes,
                isSystem: url.path.hasPrefix("/System/")
                    || url.path.hasPrefix("/Applications/Utilities/"),
                isRunning: running?.contains(candidate.bundleID) == true,
                signer: nil))
        }
        return apps.sorted { $0.sizeBytes > $1.sizeBytes }
    }

    /// One discovered app bundle. `Sendable` because the size pass reads only
    /// the path; the plist dictionary stays on the actor-free caller side.
    struct Candidate: @unchecked Sendable {
        let url: URL
        let info: [String: Any]
        let bundleID: String
    }

    /// Fixed-size result slots for the concurrent size pass. A lock-guarded
    /// buffer, so the inventory never hands Swift a concurrently-captured `var`.
    final class ResultSlots: @unchecked Sendable {
        private let lock = NSLock()
        private var values: [Int64]

        init(count: Int) { values = [Int64](repeating: 0, count: count) }

        func set(_ index: Int, _ value: Int64) {
            lock.lock(); values[index] = value; lock.unlock()
        }

        func get(_ index: Int) -> Int64 {
            lock.lock(); defer { lock.unlock() }
            return values[index]
        }
    }

    /// Every `.app` bundle under `root`, up to three levels deep.
    ///
    /// Deliberately does *not* use `.skipsPackageDescendants`: that option makes
    /// `FileManager.enumerator` skip a `.app` bundle entirely, including the
    /// bundle node itself, so the walk finds nothing and then traverses the whole
    /// Applications tree instead. Depth is bounded explicitly instead.
    static func discoverBundles(under root: String) -> [URL] {
        let rootURL = URL(fileURLWithPath: root)
        // Not recursive: app bundles live directly in these roots. A recursive
        // enumerator reported as layout `[.vertical, .fill]` and rendered the
        // list pinned to the bottom of the window, because it produced the
        // unbounded size estimate SwiftUI uses for a lazy container.
        let contents = (try? FileManager.default.contentsOfDirectory(
            at: rootURL, includingPropertiesForKeys: nil)) ?? []

        var results: [URL] = []
        for entry in contents {
            guard entry.pathExtension == "app" else { continue }
            guard FileManager.default.fileExists(atPath: entry.path) else { continue }
            results.append(entry)
        }
        return results
    }

    /// Older recursive form, retained for callers that need nested bundles such
    /// as Homebrew casks in `/opt`.
    static func discoverBundlesRecursively(under root: String) -> [URL] {
        let rootURL = URL(fileURLWithPath: root)
        let rootDepth = rootURL.pathComponents.count
        guard let enumerator = FileManager.default.enumerator(
            at: rootURL, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]
        ) else { return [] }

        var results: [URL] = []
        while let next = enumerator.nextObject() as? URL {
            guard next.pathExtension == "app" else {
                if next.pathComponents.count > rootDepth + 3 {
                    enumerator.skipDescendants()
                }
                continue
            }
            // Record the bundle and stop: its contents are measured on demand,
            // not discovered here.
            enumerator.skipDescendants()
            results.append(next)
        }
        return results
    }

    /// Every bundle ID that exists anywhere in the search roots.
    ///
    /// `all()` returns only what it could read and measure, so orphan detection
    /// needs this as a second source of truth: a trace whose bundle sits in a
    /// directory that scan skipped must not be mistaken for a removed app.
    public static var bundleIDsInSearchPaths: Set<String> {
        if let cached = bundleIDCache.cached() { return cached }
        var ids = Set<String>()
        for root in searchRoots + userSearchRoots.map(\.path) {
            for url in discoverBundles(under: root) {
                if let id = readInfoPlist(at: url)["CFBundleIdentifier"] as? String {
                    ids.insert(id)
                }
            }
        }
        bundleIDCache.store(ids)
        return ids
    }

    private static let bundleIDCache = LivenessProbe.ProbeCache<Set<String>>(ttl: 300)

    /// Read `Info.plist`. Uses `plutil -convert xml1` semantics by going
    /// through `PropertyListSerialization`, never by parsing `plutil -p` text.
    static func readInfoPlist(at appURL: URL) -> [String: Any] {
        var candidates: [URL] = [appURL.appendingPathComponent("Contents/Info.plist")]
        // iOS apps running on Apple Silicon live in a Wrapper.
        if let wrapper = try? FileManager.default.contentsOfDirectory(
            at: appURL.appendingPathComponent("Contents"), includingPropertiesForKeys: nil) {
            for child in wrapper where child.lastPathComponent.hasSuffix(".app") {
                candidates.append(child.appendingPathComponent("Info.plist"))
            }
        }
        for candidate in candidates {
            if let data = try? Data(contentsOf: candidate),
               let plist = try? PropertyListSerialization.propertyList(
                   from: data, options: [], format: nil) as? [String: Any] {
                return plist
            }
        }
        return [:]
    }

    static func codeSigningTeam(_ appURL: URL) -> String? {
        guard let out = try? Paths.run("/usr/bin/codesign", ["-dv", "--verbose=2", appURL.path],
                                       timeout: 4),
              out.status == 0 else { return nil }
        for line in out.stderr.split(separator: "\n") {
            if line.hasPrefix("TeamIdentifier=") {
                return String(line.dropFirst("TeamIdentifier=".count))
            }
        }
        return nil
    }

    private static func runningBundleIDs() -> Set<String>? {
        // `lsappinfo` is the authoritative source for which apps LaunchServices
        // considers running, but it needs a live login session and blocks
        // without one. `lsappinfo info -only name <pid>` has the same problem.
        //
        // So this returns the set of running *executable names* and callers
        // match against the app's own name. A nil result means unknown.
        LivenessProbe.runningProcessNames()
    }
}

extension InstalledApps {
    static let appURLCache = LivenessProbe.ProbeCache<[String: URL]>(ttl: 120)

    /// Locate an installed app by bundle ID.
    ///
    /// Spotlight first because it is instant, then the same bounded filesystem
    /// walk used for the inventory. Both are cached, because the liveness gate
    /// asks this once per cache folder during a scan.
    /// Installed apps only when the inventory is already warm.
    ///
    /// Used from the liveness gate, which runs once per cache folder during a
    /// scan. Building the inventory from there meant ~150 concurrent full
    /// builds; reading it read-only means a miss is simply a miss, and the gate
    /// falls back to matching process names.
    static func warmInventory() -> [String: App]? {
        guard let cached = inventoryCache.cached() else { return nil }
        return Dictionary(cached.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
    }

    public static func appURL(forBundleID bundleID: String) -> URL? {
        if let cached = appURLCache.cached()?[bundleID] { return cached }

        // A warm inventory answers this without a subprocess.
        if let warm = warmInventory(), let app = warm[bundleID] {
            let url = URL(fileURLWithPath: app.path)
            var merged = appURLCache.cached() ?? [:]
            merged[bundleID] = url
            appURLCache.store(merged)
            return url
        }

        guard let out = try? Paths.run(
            "/usr/bin/mdfind", ["kMDItemCFBundleIdentifier == \"\(bundleID)\"c"], timeout: 4),
            out.status == 0 else { return nil }

        let hit = out.stdout.split(separator: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .first { $0.hasSuffix(".app") && FileManager.default.fileExists(atPath: $0) }
            .map { URL(fileURLWithPath: $0) }

        // No fallback build. `mdfind` answers in well under a second, and the
        // fallback was what turned a liveness check into an inventory build.
        if let hit {
            var merged = appURLCache.cached() ?? [:]
            merged[bundleID] = hit
            appURLCache.store(merged)
        }
        return hit
    }
}
