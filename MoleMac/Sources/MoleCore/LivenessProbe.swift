import Foundation

/// Owner-process and open-handle probes for user cache paths.
///
/// The contract that matters: **unknown refuses**. A probe that fails, times
/// out, or cannot parse must never be read as "the app is closed". Mole calls
/// this the tri-state guard and treats state 2 (unknown) as a denial for
/// exactly this reason.
public enum LivenessProbe {

    /// 0 = not running, 1 = running, 2 = could not tell.
    public enum ProcessState: Int, Sendable {
        case notRunning = 0
        case running = 1
        case unknown = 2
    }

    /// Cache paths whose owning process still matters. Mirrors Mole's
    /// `_mole_user_cache_scope`.
    public static func isUserCachePath(_ path: String) -> Bool {
        let p = path
        let caches = Paths.caches.path
        let containers = Paths.containers.path
        let groups = Paths.groupContainers.path

        // Any directory inside ~/Library/Caches qualifies, not only reverse-DNS
        // ones. Display-named folders such as `Microsoft Edge` are exactly the
        // case that must be gated: they hold no bundle ID, so the owner check
        // falls back to matching the folder name against running processes.
        if p.hasPrefix(caches + "/") {
            let rest = String(p.dropFirst(caches.count + 1))
            let leaf = rest.split(separator: "/", omittingEmptySubsequences: false)
                .first.map(String.init) ?? rest
            return !leaf.isEmpty
        }
        if p.hasPrefix(containers + "/") && p.contains("/Data/Library/Caches") {
            return true
        }
        if p.hasPrefix(groups + "/") {
            for suffix in ["/Caches", "/Library/Caches", "/Library/Logs"] {
                if p.hasSuffix(suffix) { return true }
            }
        }
        return false
    }

    /// `~/Library/Caches/com.vendor.app` → `com.vendor.app`. Only a
    /// reverse-DNS leaf is treated as an owning bundle.
    static func isReverseDNSDir(_ leaf: String) -> Bool {
        let first = leaf.split(separator: "/", omittingEmptySubsequences: false).first.map(String.init) ?? leaf
        guard first.contains(".") else { return false }
        let parts = first.split(separator: ".")
        guard parts.count >= 2, parts[0].count >= 3 else { return false }
        let allowed = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-_")
        return parts.allSatisfy { !$0.isEmpty && $0.unicodeScalars.allSatisfy(allowed.contains) }
    }

    /// Reverse-DNS owner bundle for a cache path, if one can be proven.
    public static func ownerBundleID(for path: String) -> String? {
        let caches = Paths.caches.path
        let containers = Paths.containers.path

        if path.hasPrefix(caches + "/") {
            let rest = String(path.dropFirst(caches.count + 1))
            let leaf = rest.split(separator: "/", omittingEmptySubsequences: false)
                .first.map(String.init) ?? rest
            if isReverseDNSDir(leaf) { return leaf }
        }
        if path.hasPrefix(containers + "/") {
            let rest = String(path.dropFirst(containers.count + 1))
            if let id = rest.split(separator: "/", omittingEmptySubsequences: false).first.map(String.init),
               isReverseDNSDir(id) {
                return id
            }
        }
        return nil
    }

    /// The app name implied by a cache directory, for folders whose leaf is not
    /// a provable bundle ID.
    ///
    /// Needed because a blanket `~/Library/Caches/*` sweep must still refuse the
    /// cache of an app the user has open. Covers two shapes:
    ///
    /// - Display-named folders such as `Microsoft Edge`.
    /// - Bundle-shaped folders that fail the reverse-DNS test because the first
    ///   label is short, such as `ai.opencode.desktop`. These are the common case
    ///   for modern Electron apps, so treating them as "no owner" would leave
    ///   every one of them ungated.
    public static func ownerDisplayName(for path: String) -> String? {
        let caches = Paths.caches.path
        guard path.hasPrefix(caches + "/") else { return nil }
        let rest = String(path.dropFirst(caches.count + 1))
        guard let leaf = rest.split(separator: "/", omittingEmptySubsequences: false)
            .first.map(String.init), !leaf.isEmpty else { return nil }

        // A provable reverse-DNS leaf is handled by the bundle-ID path.
        if isReverseDNSDir(leaf) { return nil }
        if toolCacheLeaves.contains(leaf) { return nil }
        return leaf
    }

    /// Process-name candidates for a cache folder leaf.
    ///
    /// A dotted leaf yields each label, because `ai.opencode.desktop` is owned by
    /// a process called `OpenCode` and no other spelling recovers that.
    public static func candidateProcessNames(for leaf: String) -> [String] {
        var names = processNameVariants(of: leaf)
        // Sparkle-style updaters are cached as `@vendor-updater` but run as
        // `vendor-updater`, so the leading `@` has to go.
        if leaf.hasPrefix("@") {
            names.append(contentsOf: processNameVariants(of: String(leaf.dropFirst())))
        }
        if leaf.contains(".") {
            for component in leaf.split(separator: ".") where component.count >= 3 {
                names.append(contentsOf: processNameVariants(of: String(component)))
            }
        }
        return names
    }

    /// Case-insensitive membership test. Folder names and process names
    /// routinely differ only in case, and a false "running" keeps an item while
    /// a false "not running" would clean a live app's cache.
    public static func matchesProcess(_ names: Set<String>, candidates: [String]) -> Bool {
        if candidates.contains(where: { names.contains($0) }) { return true }
        let lowered = Set(names.map { $0.lowercased() })
        return candidates.contains { lowered.contains($0.lowercased()) }
    }

    /// Cache folders whose name is a build tool rather than a running app.
    ///
    /// A match here suppresses *process-name* gating: a `pip` or `node-gyp`
    /// folder is written by a tool invocation, not by a long-lived process, so
    /// gating on a same-named process would keep the cache forever for nothing.
    ///
    /// Only names that are unambiguously tools belong here. An editor or a media
    /// app is not a tool cache: excluding `Sublime Text` would leave that app's
    /// cache with no owner at all, and therefore no gate.
    static let toolCacheLeaves: Set<String> = [
        "pip", "node-gyp", "electron", "Homebrew", "ms-playwright", "deno",
        "typescript", "go-build", "com.apple.python", "go", "yarn", "pnpm",
    ]

    /// Ask LaunchServices whether a bundle ID has a live on-disk app and, more
    /// importantly, whether that app is currently running.
    public static func ownerProcessState(for path: String) -> ProcessState {
        if let bundleID = ownerBundleID(for: path) {
            return runningAppState(bundleID: bundleID)
        }
        // A display-named cache folder has no provable bundle ID, so match the folder
        // name against the running process list. Over-approximating keeps an
        // item; under-approximating would clean a live app's cache.
        if let leaf = ownerDisplayName(for: path) {
            guard let names = runningProcessNames() else { return .unknown }
            return matchesProcess(names, candidates: candidateProcessNames(for: leaf))
                ? .running : .notRunning
        }
        return .notRunning
    }

    /// A TTL-guarded cache for probe results. Probes cost a process launch, and
    /// the scan calls them once per target, so the same bundle is asked about
    /// dozens of times in a row.
    public final class ProbeCache<Value>: @unchecked Sendable {
        private let lock = NSLock()
        private var value: Value?
        private var stamp = Date.distantPast
        private let ttl: TimeInterval

        init(ttl: TimeInterval) { self.ttl = ttl }

        func cached() -> Value? {
            lock.lock(); defer { lock.unlock() }
            guard let value, Date().timeIntervalSince(stamp) < ttl else { return nil }
            return value
        }

        func store(_ new: Value) {
            lock.lock(); value = new; stamp = Date(); lock.unlock()
        }

        func invalidate() {
            lock.lock(); value = nil; stamp = .distantPast; lock.unlock()
        }
    }

    private static let processNameCache = ProbeCache<Set<String>>(ttl: 2.0)
    private static let displayNameCache = ProbeCache<[String: String]>(ttl: 300.0)

    /// Discard cached probe state. Called when the user forces a rescan, so a
    /// newly closed app does not leave a stale "running" verdict behind.
    public static func invalidateCaches() {
        processNameCache.invalidate()
    }

    /// Whether the app owning `bundleID` is currently running.
    ///
    /// Built from `ps`, not `lsappinfo`. `lsappinfo` blocks without a live
    /// login session, so a helper process invoking it can hang indefinitely;
    /// `ps` always answers. The trade-off is that matching is by executable
    /// name, so this over-approximates: a system agent that happens to share an
    /// app's short name counts as running, which keeps the target rather than
    /// risking a live app's cache.
    public static func runningAppState(bundleID: String) -> ProcessState {
        guard let names = runningProcessNames() else { return .unknown }

        // The app's own executable name, read from its bundle.
        var candidates: [String] = []
        if let appURL = InstalledApps.appURL(forBundleID: bundleID) {
            candidates.append(contentsOf: processNameVariants(
                of: appURL.deletingPathExtension().lastPathComponent))
        }
        // The bundle ID's last component, which helpers and renamed processes
        // often keep.
        if let leaf = bundleID.split(separator: ".").last {
            candidates.append(contentsOf: processNameVariants(of: String(leaf)))
        }

        return matchesProcess(names, candidates: candidates) ? .running : .notRunning
    }

    /// Executable-name spellings an app's binary might use. macOS process names
    /// drop spaces and sometimes drop a suffix, so all three forms are tried.
    public static func processNameVariants(of raw: String) -> [String] {
        var variants = [raw, raw.replacingOccurrences(of: " ", with: ""),
                        raw.replacingOccurrences(of: " ", with: "-")]
        // "Google Chrome Helper (GPU)" should also match "Google Chrome".
        if let parenthesis = raw.firstIndex(of: "(") {
            let prefix = String(raw[raw.startIndex..<parenthesis])
                .trimmingCharacters(in: .whitespaces)
            if !prefix.isEmpty { variants.append(contentsOf: processNameVariants(of: prefix)) }
        }
        return variants.filter { !$0.isEmpty }
    }

    /// Executable names currently running. `nil` means unknown.
    public static func runningProcessNames() -> Set<String>? {
        if let cached = processNameCache.cached() { return cached }

        guard let out = try? Paths.run("/bin/ps", ["-Ao", "comm="], timeout: 5), out.status == 0 else {
            return nil
        }
        let names = Set(out.stdout.split(separator: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .map { ($0 as NSString).lastPathComponent })
        processNameCache.store(names)
        return names
    }

    /// Display name for an installed bundle ID, read from the app's own
    /// Info.plist. Never from `mdls`, which returns the on-disk file name.
    public static func installedDisplayName(bundleID: String) -> String? {
        if let cached = displayNameCache.cached(), let name = cached[bundleID] { return name }
        guard let appURL = InstalledApps.appURL(forBundleID: bundleID) else { return nil }
        let name = appURL.deletingPathExtension().lastPathComponent

        var merged = displayNameCache.cached() ?? [:]
        merged[bundleID] = name
        displayNameCache.store(merged)
        return name
    }

    /// Whether a process holds an open handle on `path`.
    ///
    /// Both a record on stdout and a clean exit status count as in-use: `lsof`
    /// exits 1 when it finds nothing, so status alone is not evidence of safety.
    /// A failed or timed-out probe returns `true`, which callers treat as a
    /// refusal.
    ///
    /// Directories use `lsof +d`, which probes only the directory's own
    /// immediate entries. `lsof +D` walks the entire subtree, which on a large
    /// browser cache takes tens of seconds and would make the scan unusable;
    /// the owner-process probe above already covers a directory's owner.
    public static func hasOpenHandle(_ path: String) -> Bool {
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory) else {
            return false
        }

        let arguments: [String]
        let timeout: TimeInterval
        if isDirectory.boolValue {
            arguments = ["+d", path, "-F", "p", "--", path]
            timeout = 2.5
        } else {
            arguments = ["-F", "p", "--", path]
            timeout = 2.5
        }

        guard let out = try? Paths.run("/usr/sbin/lsof", arguments, timeout: timeout) else {
            return true // unknown probe: refuse
        }
        if out.status == 0 { return true }
        if out.status == 1 {
            // Exit 1 means no matches. But confirm stdout is genuinely empty,
            // because a truncated read on a timeout looks the same.
            return out.stdout.contains { !$0.isWhitespace && !$0.isNewline }
        }
        return true // status > 1: unreadable or timed out
    }
    /// SQLite databases, including the `-wal` / `-shm` / `-journal` companions.
    public static func isSQLiteDatabase(_ path: String) -> Bool {
        let ext = (path as NSString).pathExtension.lowercased()
        let name = ((path as NSString).lastPathComponent as NSString).deletingPathExtension.lowercased()
        if ["sqlite", "sqlite3", "db-wal", "db-shm", "db-journal"].contains(ext) { return true }
        if ["-wal", "-shm", "-journal"].contains(where: { name.hasSuffix($0) }) { return true }
        // Apple's own cache databases.
        let leaf = (path as NSString).lastPathComponent.lowercased()
        if leaf == "cache.db" || leaf == "photolibrary.db" || leaf == "library.db" { return true }
        return false
    }
}