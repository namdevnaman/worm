import Foundation

/// The single authority on whether a path may be deleted.
///
/// Ported from Mole's `_mole_is_celetion_critical_path` / `should_protect_path`,
/// then strengthened in three places where the CLI is only incidentally safe:
///
/// 1. **User data roots are hard-blocked.** Mole does not block `~/Documents`,
///    `~/Desktop`, `~/Downloads`, `~/Pictures`, `~/Movies`, or `~/Music`. Its only
///    protection there is incidental — it relies on discovery never producing
///    such a path. This engine makes the deny first-class.
/// 2. **Risk is enforcement-grade.** Mole's `classify_cleanup_risk` is advisory:
///    it is called only under `MO_DEBUG=1` and gates nothing, so HIGH and LOW
///    delete identically. Here `Risk.hardBlocked` is computed first and a hard
///    block cannot be overridden by the user.
/// 3. **A denied resolved path never grants permission.** A cache sweep whose
///    base is an ancestor symlink must not escape into user data.
public enum SafetyPolicy {

    // MARK: - Verdict

    public enum Verdict: Equatable, Sendable {
        case allow
        case blocked(Reason)
        /// Allowed, but something about the current machine makes it less
        /// effective than the byte count suggests. A running app's cache is the
        /// canonical case: it can be cleared, but the app will keep writing to it
        /// and some of it will be recreated immediately.
        case allowWithWarning(Reason)

        public var isAllowed: Bool {
            switch self {
            case .allow, .allowWithWarning: return true
            case .blocked: return false
            }
        }

        public var reason: Reason? {
            switch self {
            case .allow: return nil
            case .allowWithWarning(let r), .blocked(let r): return r
            }
        }

        /// True when the item can be cleaned but will be partly wasted.
        public var hasWarning: Bool {
            if case .allowWithWarning = self { return true }
            return false
        }
    }

    /// Every reason a path can be refused. `HARD` reasons can never be
    /// overridden by a whitelist, a force toggle, or a UI checkbox.
    public enum Reason: String, Sendable, CaseIterable {
        case userDataRoot
        case systemCritical
        case criticalDeletionPath
        case ancestorSymlink
        case compiledModelCache
        case endpointSecurityCache
        case smallSystemUIState
        case toolchainState
        case credentialStore
        case activePowerLog
        case softwareUpdateStaging
        case sharedHomeStateRoot
        case independentCLITool
        case liveApplicationCache
        case openFileHandle
        case sqliteLiveDatabase
        case whitelisted
        case riskTooHigh
        case protectedBundleData
        case notInsideAllowedRoot
        case pathInvalid
        case identityChanged
        case privilegedMutableAncestor

        /// Hard blocks are structural. They are not user-overridable and are
        /// never cleared by the whitelist.
        public var isHard: Bool {
            switch self {
            case .userDataRoot, .systemCritical, .criticalDeletionPath, .ancestorSymlink,
                 .compiledModelCache, .endpointSecurityCache, .smallSystemUIState,
                 .toolchainState, .credentialStore, .activePowerLog,
                 .softwareUpdateStaging, .sharedHomeStateRoot, .independentCLITool,
                 .riskTooHigh, .protectedBundleData, .notInsideAllowedRoot,
                 .pathInvalid, .identityChanged, .privilegedMutableAncestor:
                return true
            case .liveApplicationCache, .openFileHandle, .sqliteLiveDatabase, .whitelisted:
                // These are evidence-based and time-sensitive: the app may be
                // closed later, so the UI re-probes rather than hard-blocking
                // forever. They still never delete while true.
                return false
            }
        }

        public var title: String {
            switch self {
            case .userDataRoot: return "Personal folder"
            case .systemCritical: return "System component"
            case .criticalDeletionPath: return "Protected system path"
            case .ancestorSymlink: return "Symlinked parent folder"
            case .compiledModelCache: return "Compiled model cache"
            case .endpointSecurityCache: return "Endpoint security cache"
            case .smallSystemUIState: return "Small macOS UI state"
            case .toolchainState: return "Developer toolchain state"
            case .credentialStore: return "Credential store"
            case .activePowerLog: return "Active PowerLog database"
            case .softwareUpdateStaging: return "Software Update staging"
            case .sharedHomeStateRoot: return "Shared CLI state folder"
            case .independentCLITool: return "Independent CLI tool state"
            case .liveApplicationCache: return "App is running"
            case .openFileHandle: return "File is open"
            case .sqliteLiveDatabase: return "Live database"
            case .whitelisted: return "On your protect list"
            case .riskTooHigh: return "Too risky to clean"
            case .protectedBundleData: return "Protected app data"
            case .notInsideAllowedRoot: return "Outside a cleanable folder"
            case .pathInvalid: return "Invalid path"
            case .identityChanged: return "Changed during review"
            case .privilegedMutableAncestor: return "Writable parent folder"
            }
        }

        public var detail: String {
            switch self {
            case .userDataRoot:
                return "Documents, Desktop, Downloads, Pictures, Movies and Music are never cleaned. Caches inside them are left alone."
            case .systemCritical:
                return "This is part of macOS itself and cannot be removed."
            case .criticalDeletionPath:
                return "This path is on the system deny list. Mole never deletes it."
            case .ancestorSymlink:
                return "A parent folder is a symbolic link, so the real target cannot be proven safe."
            case .compiledModelCache:
                return "Deleting this makes on-device Vision and text recognition fail with E5RT Code 13 until you restart."
            case .endpointSecurityCache:
                return "Endpoint security agents treat deleting this as tampering (MacFalconSensorTamper)."
            case .smallSystemUIState:
                return "Wallpaper and UI preview caches reclaim almost nothing but can leave blank or re-downloading UI."
            case .toolchainState:
                return "This holds toolchains, archives, device records or signing keys, not rebuildable cache."
            case .credentialStore:
                return "Password managers and keychains hold your credentials, not cache."
            case .activePowerLog:
                return "The active PowerLog database cannot be proven closed. Only report it."
            case .softwareUpdateStaging:
                return "macOS owns this tree. Directory age cannot prove it stays inactive, so it stays read-only."
            case .sharedHomeStateRoot:
                return "The app name only looks like a match. This is a shared CLI config folder, not app cache."
            case .independentCLITool:
                return "This belongs to a command line tool that runs independently of the app."
            case .liveApplicationCache:
                return "The owning app is running or its state could not be determined. Close it and scan again."
            case .openFileHandle:
                return "A process holds a file open here."
            case .sqliteLiveDatabase:
                return "This is an open SQLite database. Unlinking it can send the owner into an unbounded write loop."
            case .whitelisted:
                return "You chose to protect this path."
            case .riskTooHigh:
                return "This is user or system data rather than rebuildable cache."
            case .protectedBundleData:
                return "This app's data is protected from cleanup."
            case .notInsideAllowedRoot:
                return "Cleanup only ever touches well-known cache and log folders."
            case .pathInvalid:
                return "The path is not absolute, contains traversal, or has control characters."
            case .identityChanged:
                return "The item was replaced while you were reviewing it. Scan again."
            case .privilegedMutableAncestor:
                return "A writable parent folder makes a privileged delete unsafe. Skipped."
            }
        }
    }

    // MARK: - Evaluation

    /// Roots that a cleanup target must live under. A target outside these is
    /// refused outright, which bounds the blast radius of any rule bug.
    /// Roots a cleanup target may live under.
    ///
    /// Derived from the rule catalog rather than written by hand. A separate
    /// hand-kept list silently drifted from the rules — `.gradle/daemon` had a
    /// rule but no allowed root, so 228 MB of its own cache was refused as
    /// "outside a cleanable folder". One source of truth removes the whole class
    /// of bug: a rule's targets are always inside a cleanable root, and nothing
    /// else is.
    public static let allowedRoots: [URL] = allAllowedRoots

    /// Roots the older hand-maintained list covered, kept so paths referenced by
    /// the uninstall and leftover flows stay inside a cleanable root.
    static let legacyRoots: [URL] = [
        Paths.home.appendingPathComponent("Library/Caches", isDirectory: true),
        Paths.home.appendingPathComponent("Library/Logs", isDirectory: true),
        Paths.home.appendingPathComponent("Library/Containers", isDirectory: true),
        Paths.home.appendingPathComponent("Library/Group Containers", isDirectory: true),
        Paths.home.appendingPathComponent("Library/Application Support", isDirectory: true),
        Paths.home.appendingPathComponent("Library/Saved Application State", isDirectory: true),
        Paths.home.appendingPathComponent("Library/Suggestions", isDirectory: true),
        Paths.home.appendingPathComponent("Library/IdentityCaches", isDirectory: true),
        Paths.home.appendingPathComponent("Library/DiagnosticReports", isDirectory: true),
        Paths.home.appendingPathComponent("Library/Messages/StickerCache", isDirectory: true),
        Paths.home.appendingPathComponent("Library/Messages/Caches", isDirectory: true),
        Paths.home.appendingPathComponent("Library/Developer/Xcode/DerivedData", isDirectory: true),
        Paths.home.appendingPathComponent("Library/Developer/Xcode/iOS DeviceSupport", isDirectory: true),
        Paths.home.appendingPathComponent("Library/Developer/CoreSimulator/Caches", isDirectory: true),
        Paths.home.appendingPathComponent("Library/Developer/XCTestDevices", isDirectory: true),
        Paths.home.appendingPathComponent(".cache", isDirectory: true),
        Paths.home.appendingPathComponent(".Trash", isDirectory: true),
        Paths.home.appendingPathComponent(".npm/_cacache", isDirectory: true),
        Paths.home.appendingPathComponent(".npm/_logs", isDirectory: true),
        Paths.home.appendingPathComponent(".tnpm/_cacache", isDirectory: true),
        Paths.home.appendingPathComponent(".tnpm/_logs", isDirectory: true),
        Paths.home.appendingPathComponent(".local/share/pnpm/store", isDirectory: true),
        Paths.home.appendingPathComponent(".gradle/caches/build-cache-1", isDirectory: true),
        Paths.home.appendingPathComponent(".cargo/registry/cache", isDirectory: true),
        Paths.home.appendingPathComponent(".rustup/downloads", isDirectory: true),
        Paths.home.appendingPathComponent(".pyenv/cache", isDirectory: true),
        Paths.home.appendingPathComponent(".bun/install/cache", isDirectory: true),
        Paths.home.appendingPathComponent(".yarn/cache", isDirectory: true),
        Paths.home.appendingPathComponent(".expo", isDirectory: true),
        Paths.home.appendingPathComponent(".pnpm-store", isDirectory: true),
        Paths.darwinUserCacheDir,
        Paths.darwinUserTempDir,
        URL(fileURLWithPath: "/Library/Caches", isDirectory: true),
        URL(fileURLWithPath: "/Library/Logs/DiagnosticReports", isDirectory: true),
        URL(fileURLWithPath: "/private/var/log", isDirectory: true),
    ]

    public static let allAllowedRoots: [URL] = legacyRoots + ScanCatalog.cleanableRoots

    /// User content roots. Never a cleanup source and never a cleanup target.
    public static let userDataRoots: [String] = [
        "Documents", "Desktop", "Downloads", "Pictures", "Movies", "Music",
        "Public", "Applications", "Library/Mobile Documents", "Library/CloudStorage",
    ]

    /// Paths Mole refuses for structural reasons, expressed as prefix patterns.
    static let criticalPrefixes: [String] = [
        "/", "/bin", "/dev", "/sbin", "/usr", "/System",
        "/Library/Apple", "/Library/Extensions", "/Library/Keychains",
        "/Applications/Finder.app", "/Applications/Safari.app",
        "/Volumes", "/Network", "/cores", "/etc", "/home", "/net",
        "/opt/homebrew", "/opt/homebrew/", "/usr/local", "/usr/local/",
        "/private/tmp", "/private/etc",
        "/private/var/audit", "/private/var/db", "/private/var/folders",
        "/private/var/root", "/private/var/tmp",
        "/Users/Shared", "/Users/Guest",
        // macOS-managed caches Mole will reach but never delete wholesale.
        "/System/Library/Caches", "/System/Library/Logs",
    ]

    /// Small macOS UI state: reclaimable but produces visible blank or
    /// re-downloading UI. R5 in Mole's own audit, kept out of the delete path.
    static let smallUIStatePrefixes: [String] = [
        "Library/Application Support/com.apple.wallpaper",
        "Library/Caches/com.apple.wallpaper",
        "Library/Caches/com.apple.idleassetsd",
        "Library/Application Support/com.apple.idleassetsd",
        "Library/Caches/com.apple.iconservices",
        "Library/Caches/pscache",
    ]

    /// Developer toolchain state that is *not* rebuildable: archives, device
    /// records, signing material, dependency stores with mixed state.
    ///
    /// Deliberately excludes downloaded model and package stores such as
    /// `~/.cache/huggingface` and `~/.cache/torch`. Those are large, they are
    /// re-fetchable by their owning tool, and Mole's own audit class treats them
    /// as review-only rather than off-limits. Refusing them hid 4.8 GB of
    /// genuinely reclaimable space and made the app look broken next to the CLI.
    /// They are surfaced with a "re-download" risk badge instead.
    static let toolchainPrefixes: [String] = [
        "Library/Developer/Xcode/Archives",
        "Library/Developer/Xcode/UserData/IB Support",
        "Library/Developer/Xcode/iOS DeviceSupport/Symbols",
        "Library/Developer/Xcode/DocumentationCache",
        "Library/Developer/CoreSimulator/Devices",
        "Library/Developer/CoreSimulator/Profiles/Runtimes",
        "Library/Developer/Xcode/DerivedData/ModuleCache.noindex",
        "Library/Android", ".android/avd", ".android/adbkey", ".android/debug.keystore",
        ".android/build-cache", "AndroidStudioProjects",
        "DevEcoStudioProjects", "HarmonyOS", "Huawei", ".huawei", ".ohos",
        ".m2/repository", ".ivy2/cache", ".nuget/packages", ".pub-cache",
        ".gradle/caches/modules-2", ".sbt/boot", ".sbt/launchers",
        ".stack/programs", ".cabal/packages",
        "Library/Anki2", "Library/Mail", "Library/Messages",
        "Library/Application Support/MobileSync",
    ]

    /// Credential and secret stores.
    static let credentialPrefixes: [String] = [
        ".ssh", ".gnupg", ".gpg", ".aws/credentials", ".kube/config",
        "Library/Keychains", "Library/Mail Downloads",
        "1Password", "2FAS", "Bitwarden", "LastPass", "KeePass", "Dashlane",
        "Enpass", "Passwords", "Wallet",
    ]

    /// Independent command line tools whose home state an app uninstall must
    /// never sweep. R18: case-insensitive APFS makes `.claude` and `.cache`
    /// collide with app display names like "Local", "Config", "Cache".
    /// Durable state inside `~/.codex` that must survive any cleanup.
    static let codexDurableState = [
        "config.toml", "auth.json", "credentials.json", "history.jsonl",
        "sessions", "shell_snapshots", "skills", "prompts", "rules",
        "mcp.json", "version.json", "log",
    ]

    static let independentCLIFolders: [String] = [
        // `~/.codex` is absent from this list, and that is deliberate.
        //
        // The CLI-root collision this guards against is real: uninstalling
        // Codex.app must not delete the CLI's config, credentials or sessions.
        // But a blanket block on `~/.codex` also made the app's own age-gated
        // staging rules unreachable, which is why 67 MB of `~/.codex/.tmp`
        // marketplace staging stayed behind. So the durable state is protected
        // by name below while the staging area stays cleanable.
        ".claude", ".config/claude", ".gemini", ".opencode",
        ".cursor", ".copilot", ".config/opencode", ".local/share/opencode",
        ".local/share/claude", ".local/share/cursor-agent", ".copilot/pkg",
        ".codeium", ".aider", ".continue",
    ]

    /// Compiled on-device model caches. R11.
    static let compiledModelMarkers = ["e5bundlecache", "e5rt", "coreml", ".mlmodelc"]

    /// Endpoint security agent cache prefixes. R7.
    static let endpointSecurityPrefixes = [
        "crowdstrike", "falcon", "sentinelone", "com.sentinelone", "eset", "jamf",
        "carbonblack", "cylance", "symantec", "mcafee", "sophos", "bitdefender",
        "trendmicro", "paloalto", "cortex", "panw", "tanium", "kaseya",
    ]

    public static func verdict(
        for path: String,
        bundleID: String? = nil,
        whitelist: Whitelist = .shared,
        probeLiveness: Bool = true
    ) -> Verdict {
        // 1. Structural validity first. A malformed path can never be safe.
        guard path.hasPrefix("/") else { return .blocked(.pathInvalid) }
        // `..` as a complete path component only. A directory legitimately named
        // `name..files` is not traversal and must stay usable.
        if path.split(separator: "/", omittingEmptySubsequences: false).contains("..") {
            return .blocked(.pathInvalid)
        }
        if path.unicodeScalars.contains(where: { $0.value < 0x20 || $0.value == 0x7F }) {
            return .blocked(.pathInvalid)
        }

        // 2. Hard user-data roots. Checked before everything because a symlink
        //    or a weird rule must never reach personal content.
        if userDataRootContaining(path) != nil {
            return .blocked(.userDataRoot)
        }

        // 3. Named protections that live inside generically-denied trees. Checked
        //    before the symlink guard so the user sees the real cause: every
        //    one of these sits under `/private/var/db` or `/private/var/folders`,
        //    which are hard-blocked roots, and `/var` is itself a symlink to
        //    `/private/var`, so the symlink guard would otherwise claim the
        //    PowerLog database and EDR caches are "symlinked parents".
        //
        //    Ordering them first cannot weaken anything: each is a deny rule on
        //    an absolute system path that step 4 would refuse anyway.
        let resolved = resolvePhysical(path)
        if softwareUpdateStaging(path) || softwareUpdateStaging(resolved) {
            return .blocked(.softwareUpdateStaging)
        }
        if path.contains("/private/var/db/powerlog/")
            || resolved.contains("/private/var/db/powerlog/") {
            return .blocked(.activePowerLog)
        }
        if endpointSecurityMatch(resolved) == true || endpointSecurityMatch(path) == true {
            return .blocked(.endpointSecurityCache)
        }

        // 4. Ancestor symlink guard (R6). A cache sweep whose base is a
        //    symlink must not walk into somewhere else. The resolved leaf is
        //    re-checked against the user-data roots, because a resolved path may
        //    only narrow permission, never grant it.
        if resolved != path {
            if isSymlinked(path: path, upTo: allowedRoots) {
                return .blocked(.ancestorSymlink)
            }
            if userDataRootContaining(resolved) != nil {
                return .blocked(.userDataRoot)
            }
        }

        // 5. Critical deletion paths, string and inode identity.
        if let hit = criticalDeletionPath(path) ?? criticalDeletionPath(resolved) {
            _ = hit
            return .blocked(.criticalDeletionPath)
        }

        // 6. Specific structural protections.
        if let reason = structuralProtection(for: path, resolved: resolved) {
            return .blocked(reason)
        }

        // 7. Containment: must live under a known cleanable root.
        if !isInsideAllowedRoot(resolved), !isInsideAllowedRoot(path) {
            return .blocked(.notInsideAllowedRoot)
        }

        // 8. Bundle ID protection for app data.
        if let bundleID, ProtectedBundles.isProtected(bundleID) {
            return .blocked(.protectedBundleData)
        }

        // 9. User whitelist. Never clears a hard block.
        if whitelist.contains(path) {
            return .blocked(.whitelisted)
        }

        // 10. Liveness probes. Only for user-level cache paths.
        //
        // A running app is a warning, not a refusal. The reference CLI offers
        // these and notes "close Edge to clean another 1.44 GB"; blocking them
        // outright withheld 1.77 GB from the total and made the app look broken
        // next to the CLI. What still *is* refused is anything where the bytes
        // are the user's data rather than the app's cache, and any live SQLite
        // database, which is the one case where deletion corrupts state.
        if probeLiveness, let liveReason = livenessBlock(for: path) {
            if liveReason == .openFileHandle || liveReason == .sqliteLiveDatabase {
                return .blocked(liveReason)
            }
            return .allowWithWarning(liveReason)
        }

        return .allow
    }

    // MARK: - Individual checks

    static func userDataRootContaining(_ path: String) -> String? {
        for root in userDataRoots {
            let full = Paths.home.appendingPathComponent(root).standardizedFileURL.path
            if path == full || path.hasPrefix(full + "/") { return root }
        }
        // macOS also exposes synced iCloud folders through Library/Mobile Documents
        // and Library/CloudStorage, and those can point anywhere.
        for root in ["Library/Mobile Documents", "Library/CloudStorage"] {
            let full = Paths.home.appendingPathComponent(root).standardizedFileURL.path
            if path == full || path.hasPrefix(full + "/") { return root }
        }
        return nil
    }

    static func criticalDeletionPath(_ path: String) -> String? {
        let p = path.hasSuffix("/") && path != "/" ? String(path.dropLast()) : path
        if p == "/" { return p }
        for prefix in criticalPrefixes where prefix != "/" {
            if p == prefix { return prefix }
            if prefix.hasSuffix("/") {
                if p.hasPrefix(prefix) { return prefix }
            } else if p.hasPrefix(prefix + "/") {
                return prefix
            }
        }
        // A bare /Users/<name> is a home directory, not a leaf.
        if p.hasPrefix("/Users/") && !p.contains("/Users/".dropLast(1)) {
            let afterUsers = String(p.dropFirst("/Users/".count))
            if !afterUsers.isEmpty && !afterUsers.contains("/") { return p }
        }
        // APFS is case-insensitive but case-preserving: /SYSTEM and
        // /OPT/HOMEBREW are the same inode as protected roots.
        let lowered = p.lowercased()
        for prefix in criticalPrefixes.map({ $0.lowercased() }) where prefix != "/" {
            if lowered == prefix || lowered.hasPrefix(prefix.hasSuffix("/") ? prefix : prefix + "/") {
                return prefix
            }
        }
        return nil
    }

    static func structuralProtection(for path: String, resolved: String) -> Reason? {
        let relative = relativeToHome(path) ?? relativeToHome(resolved) ?? ""
        let lowerRelative = relative.lowercased()
        let lastComponent = (resolved as NSString).lastPathComponent.lowercased()

        // Active PowerLog database: never deleted, never truncated, never
        // vacuumed. Size and mtime cannot prove Apple closed every connection.
        if resolved.contains("/private/var/db/powerlog/") {
            return .activePowerLog
        }
        if softwareUpdateStaging(resolved) { return .softwareUpdateStaging }

        // Compiled model cache, checked on the directory and its parent.
        if compiledModelMarkers.contains(where: { lastComponent.contains($0) }) {
            return .compiledModelCache
        }
        if lastComponent.contains("crashpad") == false,
           compiledModelMarkers.contains(where: { (resolved as NSString).lastPathComponent.lowercased().contains($0) }) {
            return .compiledModelCache
        }

        for prefix in credentialPrefixes {
            let full = Paths.home.appendingPathComponent(prefix).standardizedFileURL.path.lowercased()
            if lowerRelative == prefix.lowercased() || lowerRelative.hasPrefix(prefix.lowercased() + "/") {
                return .credentialStore
            }
            if lowerRelative.hasPrefix(full) { return .credentialStore }
        }
        if relative.hasPrefix("Library/Keychains") { return .credentialStore }

        for prefix in independentCLIFolders {
            if lowerRelative == prefix.lowercased() || lowerRelative.hasPrefix(prefix.lowercased() + "/") {
                return .independentCLITool
            }
        }

        // Durable Codex CLI state, protected by name.
        //
        // `~/.codex` is absent from `independentCLIFolders` on purpose: a blanket
        // block there also made the app's own age-gated staging rules
        // unreachable, leaving 67 MB of `~/.codex/.tmp` stranded. These entries
        // cover what the block was actually protecting — config, credentials,
        // sessions and history — while leaving `.codex/.tmp` cleanable.
        for name in codexDurableState {
            if lowerRelative == ".codex/\(name)"
                || lowerRelative.hasPrefix(".codex/\(name)/") {
                return .independentCLITool
            }
        }

        for prefix in toolchainPrefixes {
            if lowerRelative.hasPrefix(prefix.lowercased()) { return .toolchainState }
        }

        for prefix in smallUIStatePrefixes {
            if lowerRelative.hasPrefix(prefix.lowercased()) { return .smallSystemUIState }
        }

        return nil
    }

    /// Software Update staging. Checked separately from `criticalPrefixes` so the
    /// user gets the reason that explains it ("macOS owns this") rather than a
    /// generic "protected system path". The outcome is identical: refused.
    /// True when the path belongs to an endpoint security agent's cache.
    /// Anchored under `/private/var/folders`, because those vendor names are
    /// too generic to refuse anywhere else.
    static func endpointSecurityMatch(_ path: String) -> Bool? {
        let lowered = path.lowercased()
        guard lowered.contains("/private/var/folders/") else { return nil }
        return endpointSecurityPrefixes.contains { lowered.contains($0) } ? true : nil
    }

    static func softwareUpdateStaging(_ path: String) -> Bool {
        for prefix in ["/Library/Updates", "/macOS Install Data"] {
            if path == prefix || path.hasPrefix(prefix + "/") { return true }
        }
        return false
    }

    static func isInsideAllowedRoot(_ path: String) -> Bool {
        let p = path.hasSuffix("/") ? String(path.dropLast()) : path
        for root in allowedRoots {
            let r = root.standardizedFileURL.path
            if p == r || p.hasPrefix(r + "/") { return true }
        }
        return false
    }

    /// Canonicalize symlinks in every component, the way `cd -P` does.
    static func resolvePhysical(_ path: String) -> String {
        URL(fileURLWithPath: path)
            .resolvingSymlinksInPath()
            .standardizedFileURL
            .path
    }

    /// True when any component between `path` and the filesystem root is a
    /// symbolic link. Used to refuse a cache sweep whose base is redirected.
    static func isSymlinked(path: String, upTo roots: [URL] = allowedRoots) -> Bool {
        var current = URL(fileURLWithPath: path).standardizedFileURL
        var hops = 0
        while hops < 64 {
            hops += 1
            if let attrs = try? FileManager.default.attributesOfItem(atPath: current.path),
               attrs[.type] as? FileAttributeType == .typeSymbolicLink {
                return true
            }
            if roots.contains(where: { sameFile($0.standardizedFileURL, current) }) {
                return false
            }
            let parent = current.deletingLastPathComponent().standardizedFileURL
            if parent.path == current.path || parent.path == "/" { return false }
            current = parent
        }
        return true
    }

    static func sameFile(_ a: URL, _ b: URL) -> Bool {
        let am = try? FileManager.default.attributesOfItem(atPath: a.path)
        let bm = try? FileManager.default.attributesOfItem(atPath: b.path)
        guard let am, let bm else { return a.standardizedFileURL == b.standardizedFileURL }
        let ai = (am[.systemFileNumber] as? NSNumber)?.uint64Value
        let bi = (bm[.systemFileNumber] as? NSNumber)?.uint64Value
        guard let ai, let bi else { return false }
        return ai == bi
    }

    static func relativeToHome(_ path: String) -> String? {
        let home = Paths.home.standardizedFileURL.path
        guard path == home || path.hasPrefix(home + "/") else { return nil }
        return String(path.dropFirst(home.count)).trimmingCharacters(in: CharacterSet(charactersIn: "/"))
    }

    /// Liveness gate for user cache paths.
///
/// Two layers, because neither alone is sufficient:
///
/// - **Owner process.** For a reverse-DNS cache directory (`com.vendor.app`)
///   the owning bundle ID is provable. For a display-named directory
///   (`Microsoft Edge`) it is not, so the directory name is matched against the
///   running process list. Without this, a blanket `~/Library/Caches/*` sweep
///   would happily offer the cache of a browser the user has open.
/// - **Open descriptor**, for files only. A directory is covered by its owner
///   check; a file with a live descriptor is the case that actually corrupts
///   state, because unlinking an open SQLite database sends its owner into an
///   unbounded write loop.
    static func livenessBlock(for path: String) -> Reason? {
        guard LivenessProbe.isUserCachePath(path) else { return nil }

        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory) else {
            return nil
        }

        // 1. Owner process. This is the cheap check that catches a live app, and
        //    it must run before the descriptor probe so a running app is named
        //    as such rather than as "a file is open".
        switch LivenessProbe.ownerProcessState(for: path) {
        case .running, .unknown:
            return .liveApplicationCache
        case .notRunning:
            break
        }

        // 2. Live descriptor. Files only, so a directory sweep does not pay for
        //    an lsof call per cache folder.
        guard !isDirectory.boolValue else { return nil }
        if LivenessProbe.isSQLiteDatabase(path) || LivenessProbe.hasOpenHandle(path) {
            return .openFileHandle
        }
        return nil
    }
}

/// Bundle IDs that own real user data and are never cache-cleaned.
public enum ProtectedBundles {
    static let critical: Set<String> = [
        "com.apple.finder", "com.apple.dock", "com.apple.Safari", "com.apple.mail",
        "com.apple.systempreferences", "com.apple.SystemSettings", "com.apple.controlcenter",
        "com.apple.Spotlight", "com.apple.notificationcenterui", "com.apple.loginwindow",
        "com.apple.Preview", "com.apple.TextEdit", "com.apple.Notes", "com.apple.reminders",
        "com.apple.iCal", "com.apple.AddressBook", "com.apple.Photos", "com.apple.AppStore",
        "com.apple.calculator", "com.apple.ScreenSharing", "com.apple.ActivityMonitor",
        "com.apple.Console", "com.apple.DiskUtility", "com.apple.KeychainAccess",
        "com.apple.Terminal", "com.apple.ScriptEditor2", "com.apple.FontBook",
        "com.apple.CoreServices", "com.apple.coreservices", "com.apple.SystemUIServer",
        "com.apple.securityd", "com.apple.trustd", "com.apple.security",
        "com.apple.sharedfilelist", "com.apple.backgroundtaskmanagement",
        "com.apple.loginitems", "com.apple.MobileSoftwareUpdate", "com.apple.SoftwareUpdate",
        "com.apple.installer", "com.apple.frameworks",
        "com.apple.CalendarAgent", "com.apple.e5rt.e5bundlecache",
        "com.apple.PhotosAnalysis", "com.apple.photoanalysisd",
        "com.apple.wallpaper", "com.apple.idleassetsd", "com.apple.mediaanalysisd",
    ]

    /// Prefix match, mirroring Mole's runtime blanket `com.apple.*` guard but
    /// kept explicit so a user-installed Apple app stays uninstallable.
    static let applePrefixes = ["com.apple."]

    static let userDataPrefixes: [String] = [
        "com.apple.Passwords", "com.apple.AddressBook", "com.apple.reminders",
        "com.apple.notes", "com.apple.MobileSMS", "com.apple.mobilephone",
    ]

    static func isProtected(_ bundleID: String) -> Bool {
        if critical.contains(bundleID) { return true }
        if userDataPrefixes.contains(bundleID) { return true }
        // System frameworks, daemons and agents.
        if bundleID.hasPrefix("com.apple.CoreServices")
            || bundleID.hasPrefix("com.apple.backgroundtaskmanagement")
            || bundleID.hasPrefix("com.apple.loginitems")
            || bundleID.hasPrefix("com.apple.security")
            || bundleID.hasPrefix("com.apple.keychain")
            || bundleID.hasPrefix("com.apple.print")
            || bundleID.hasPrefix("com.apple.background")
            || bundleID.hasPrefix("com.apple.system") { return true }
        return false
    }

    /// True for any bundle ID shaped like `com.vendor.product`.
    static func isReverseDNS(_ value: String) -> Bool {
        let parts = value.split(separator: ".", omittingEmptySubsequences: false)
        guard parts.count >= 2, parts[0].count >= 3 else { return false }
        let allowed = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-_")
        return parts.allSatisfy { part in
            !part.isEmpty && part.unicodeScalars.allSatisfy { allowed.contains($0) }
        }
    }

    static let applePrefix = "com.apple."
}

/// User-controlled protect list. Persisted in `~/.config/mole/protect.txt`.
public final class Whitelist: @unchecked Sendable {
    public static let shared = Whitelist()

    /// A whitelist that protects nothing. Reserved for operations the user has
    /// explicitly scoped to a known set of paths, such as emptying the Trash,
    /// which is a discard contract rather than a discovery-driven sweep.
    public static let empty = Whitelist()

    private let lock = NSLock()
    private var patterns: [String] = []
    private var expandedPatterns: [String] = []
    private let loadsFromDisk: Bool

    public init() {
        loadsFromDisk = true
        reload()
    }

    private init(patterns: [String]) {
        loadsFromDisk = false
        self.patterns = patterns
        self.expandedPatterns = patterns.map { Paths.expand($0).standardizedFileURL.path }
    }

    /// Fixed contents with no disk access. Tests use this so they never read
    /// or overwrite the real protect list.
    convenience init(testPatterns: [String]) {
        self.init(patterns: testPatterns)
    }

    public func reload() {
        guard loadsFromDisk else { return }
        let url = Paths.configDir.appendingPathComponent("protect.txt")
        guard let text = try? String(contentsOf: url, encoding: .utf8) else {
            lock.lock(); patterns = []; expandedPatterns = []; lock.unlock()
            return
        }
        let loaded = text
            .split(separator: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty && !$0.hasPrefix("#") }
        lock.lock()
        patterns = loaded
        expandedPatterns = loaded.map { Paths.expand($0).standardizedFileURL.path }
        lock.unlock()
    }

    public var entries: [String] {
        lock.lock(); defer { lock.unlock() }
        return patterns
    }

    /// Prefix match on the literal expanded string. No globbing: a pattern is
    /// never expanded into a wildcard set, which is what keeps a hostile entry
    /// from widening the delete path.
    public func contains(_ path: String) -> Bool {
        let p = URL(fileURLWithPath: path).standardizedFileURL.path
        lock.lock(); defer { lock.unlock() }
        for pattern in expandedPatterns {
            if p == pattern || p.hasPrefix(pattern.hasSuffix("/") ? pattern : pattern + "/") {
                return true
            }
        }
        return false
    }

    public func add(_ pattern: String) throws {
        let trimmed = pattern.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        let existing = entries
        guard !existing.contains(where: { $0 == trimmed }) else { return }
        try store(existing + [trimmed])
    }

    public func remove(_ pattern: String) throws {
        try store(entries.filter { $0 != pattern })
    }

    public func move(fromOffsets source: IndexSet, toOffset destination: Int) throws {
        var current = entries
        // Hand-rolled so MoleCore stays free of a SwiftUI dependency; the UI
        // layer only needs the resulting order, not the gesture itself.
        let moving = source.sorted().compactMap { index in
            current.indices.contains(index) ? current[index] : nil
        }
        let remaining = current.enumerated()
            .filter { !source.contains($0.offset) }
            .map(\.element)
        let clamped = min(max(destination, 0), remaining.count)
        let head = Array(remaining.prefix(clamped))
        let tail = Array(remaining.suffix(remaining.count - clamped))
        current = head + moving + tail
        try store(current)
    }

    public func toggle(_ pattern: String) throws {
        if entries.contains(pattern) {
            try remove(pattern)
        } else {
            try add(pattern)
        }
    }

    private func store(_ next: [String]) throws {
        try FileManager.default.createDirectory(
            at: Paths.configDir, withIntermediateDirectories: true)
        let header = """
        # MoleMac protect list
        # One path per line. Nothing listed here is ever cleaned.
        # A path protects itself and everything below it.

        """
        let body = next.map { "  " + Paths.expand($0).path }.joined(separator: "\n")
        try (header + body + (next.isEmpty ? "" : "\n")).write(
            to: Paths.configDir.appendingPathComponent("protect.txt"),
            atomically: true, encoding: .utf8)
        lock.lock()
        patterns = next
        expandedPatterns = next.map { Paths.expand($0).standardizedFileURL.path }
        lock.unlock()
    }
}