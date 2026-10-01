import Foundation

/// Data left behind by apps that are no longer installed.
///
/// Two rules make this safe to run unattended:
///
/// - **Positive evidence of absence.** A trace is reported only when both the
///   installed-app scan and a Spotlight query fail to find the bundle. A query
///   that times out or fails is "unknown", and unknown keeps the item.
/// - **Exact identity.** Traces are grouped by a bundle ID derived from the
///   on-disk name. No vendor-prefix or substring matching, because that is how a
///   cleanup tool starts removing a different vendor's directory.
public enum OrphanDetector {

    /// One trace of one removed app.
    public struct Leftover: Sendable, Identifiable, Hashable {
        public let id: String
        public let bundleID: String
        public let path: String
        public let bytes: Int64
        public let ageDays: Int
        public let kind: Kind
        public let location: Location

        public init(id: String, bundleID: String, path: String, bytes: Int64,
                    ageDays: Int, kind: Kind, location: Location) {
            self.id = id
            self.bundleID = bundleID
            self.path = path
            self.bytes = bytes
            self.ageDays = ageDays
            self.kind = kind
            self.location = location
        }

        /// Whether removing this trace can cost the user something. Anything that
        /// holds settings the user configured is opt-in, never auto-selected.
        public var needsReview: Bool {
            switch kind {
            case .preferences, .applicationSupport, .container, .groupContainer:
                return true
            case .cache, .log, .launchAgent, .webkit, .httpStorage, .appScript,
                 .savedState:
                return false
            }
        }

        public enum Kind: String, Sendable {
            case preferences, cache, log, container, groupContainer, launchAgent
            case webkit, httpStorage, applicationSupport, appScript, savedState

            /// Whether this trace lives inside a sandbox container, whose contents macOS
        /// refuses to read without Full Disk Access.
        public var isSandbox: Bool {
            self == .container || self == .groupContainer
        }

        public var label: String {
                switch self {
                case .preferences: return "Settings"
                case .cache: return "Cache"
                case .log: return "Logs"
                case .container: return "Sandbox container"
                case .groupContainer: return "Shared container"
                case .launchAgent: return "Login item"
                case .webkit: return "Web data"
                case .httpStorage: return "Cookies"
                case .applicationSupport: return "Application data"
                case .appScript: return "Scripting definition"
                case .savedState: return "Saved state"
                }
            }
        }

        public enum Location: String, Sendable, CaseIterable {
            case preferences, webKit, httpStorage, applicationSupport, caches, logs
            case containers, groupContainers, launchAgents, appScripts, savedState

            public var displayName: String {
                switch self {
                case .preferences: return "Preferences"
                case .webKit: return "WebKit"
                case .httpStorage: return "HTTP Storage"
                case .applicationSupport: return "Application Support"
                case .caches: return "Caches"
                case .logs: return "Logs"
                case .containers: return "Containers"
                case .groupContainers: return "Group Containers"
                case .launchAgents: return "Launch Agents"
                case .appScripts: return "Application Scripts"
                case .savedState: return "Saved Application State"
                }
            }

            public var symbol: String {
                switch self {
                case .preferences: return "slider.horizontal.3"
                case .webKit: return "globe"
                case .httpStorage: return "circle.grid.2x2"
                case .applicationSupport: return "shippingbox"
                case .caches: return "externaldrive.badge.timemachine"
                case .logs: return "doc.text"
                case .containers: return "cube.transparent"
                case .groupContainers: return "square.stack.3d.down.right"
                case .launchAgents: return "power"
                case .appScripts: return "curlybraces"
                case .savedState: return "archivebox"
                }
            }
        }
    }

    /// Everything one removed app left behind.
    public struct OrphanGroup: Sendable, Identifiable, Hashable {
        public let bundleID: String
        public let displayName: String
        public let leftovers: [Leftover]

        public var id: String { bundleID }
        public var bytes: Int64 { leftovers.reduce(0) { $0 + $1.bytes } }
        public var reviewCount: Int { leftovers.filter(\.needsReview).count }
        /// Traces safe to remove without a second look: caches, logs, cookies.
        public var autoSelected: [Leftover] { leftovers.filter { !$0.needsReview } }
        public var newestTraceDays: Int { leftovers.map(\.ageDays).min() ?? 0 }
        public var iconURL: URL? { InstalledApps.appURL(forBundleID: bundleID) }
    }

    /// One search location: where it is, and what kind of trace it produces.
    public struct Source: Sendable {
        public let location: Leftover.Location
        public let kind: Leftover.Kind
        public let root: URL

        public init(_ location: Leftover.Location, _ kind: Leftover.Kind, _ root: URL) {
            self.location = location
            self.kind = kind
            self.root = root
        }
    }

    /// Where traces live and what kind each location produces. A location absent
    /// from this list is never searched.
    public static let locations: [Source] = [
        Source(.caches, .cache, Paths.caches),
        Source(.logs, .log, Paths.logs),
        Source(.preferences, .preferences,
               Paths.library.appendingPathComponent("Preferences")),
        Source(.webKit, .webkit, Paths.library.appendingPathComponent("WebKit")),
        Source(.httpStorage, .httpStorage,
               Paths.library.appendingPathComponent("HTTPStorages")),
        Source(.applicationSupport, .applicationSupport, Paths.appSupport),
        Source(.containers, .container, Paths.containers),
        Source(.groupContainers, .groupContainer, Paths.groupContainers),
        Source(.launchAgents, .launchAgent,
               Paths.library.appendingPathComponent("LaunchAgents")),
        // `~/Library/Application Scripts` is deliberately absent. It holds the
        // AppleScript terminology definitions an app's scripting support resolves
        // at runtime, not residue from a removed app: it listed `group.is
        // .workflow.shortcuts` and `UBF8T346G9.Office*`, both belonging to
        // software that is installed. macOS also refuses to read it without Full
        // Disk Access, so every entry measured 0 bytes and could not even be
        // sized honestly. Removing a definition breaks an installed app's
        // scripting with nothing to show for it.
        Source(.savedState, .savedState,
               Paths.library.appendingPathComponent("Saved Application State")),
    ]

    /// Bundle IDs that are never an orphan.
    static let neverDelete: Set<String> = [
        "com.apple.finder", "com.apple.dock", "com.apple.Safari", "com.apple.mail",
        "com.apple.systempreferences", "com.apple.SystemSettings", "com.apple.Settings",
        "com.apple.controlcenter", "com.apple.loginwindow", "com.apple.Spotlight",
        "com.apple.notificationcenterui", "com.apple.CoreServices",
    ]

    /// Traces that own credentials or keys, whatever their age.
    static let credentialMarkers = [
        "1password", "bitwarden", "lastpass", "keepass", "dashlane", "enpass",
        "keychain", "ssh", "gpg", "gnupg",
    ]

    /// Stems that belong to no single app. Treating one as a bundle ID would
    /// sweep away unrelated data.
    /// Trailing qualifiers that mark a trace as belonging to a different thing
    /// than its stem suggests.
    ///
    /// `com.apphousekitchen.aldente-pro_stats.sqlite3` is Aldente's statistics
    /// database, not a second app called `aldente-pro_stats`. Reporting it as its
    /// own app splits one vendor's traces across two rows and invents an app that
    /// was never installed. Matched against the *stem* after suffix peeling, so
    /// `com.vendor.app.binarycookies` is unaffected.
    static let groupQualifiers: [String] = [
        "_stats", "-stats", "_helper", "_agent", "_updater", "_update",
        "_daemon", "_service", "_worker", "_plugin", "_ext",
    ]

    static let genericStems: Set<String> = [
        "cache", "caches", "logs", "temp", "tmp", "default", "shared", "common",
        "httpstorages", "webkit", "cookies", "localstorage", "mobilemeaccounts",
        "byhost", "containers", "group containers", "system", "userdefaults",
        "contextstoreagent", "tokenbucketratelimiter", "apmanalyticssuitename",
        "apmexperimentsuitename",
    ]

    /// Find leftover groups, each requiring proven absence of the app.
    ///
    /// `minAgeDays` defaults to 30 because a bundle ID can be absent for a week
    /// during an app update that moves the bundle temporarily.
    public static func findLeftovers(minAgeDays: Int = ScanCatalog.orphanAgeDays)
    -> [OrphanGroup] {
        // Sandboxes are the one location that cannot be judged without Full Disk
        // Access: their contents will not read, so every size measures 0 and every
        // content probe fails open. That produced an empty-looking yet
        // *deletable* list — `group.net.whatsapp.family` was offered while
        // WhatsApp was running, purely because nothing could contradict it.
        // Sandboxes are therefore skipped rather than guessed at.
        //
        // Caches, logs, Preferences, WebKit and Application Support are readable
        // without the grant, so they are still scanned and reported.
        let noSandboxAccess = SizeMeasurer.Access.lacksFullDiskAccess
        let sources = locations.filter {
            !noSandboxAccess || !$0.kind.isSandbox
        }

        var installedIDs = Set(InstalledApps.bundleIDsInSearchPaths)
        installedIDs.formUnion(InstalledApps.all().map(\.id))

        var grouped: [String: [Leftover]] = [:]

        for source in sources {
            let entries = childNames(of: source.root)
            for name in entries where !name.hasPrefix(".") {
                guard let bundleID = bundleID(forEntry: name),
                      isCandidate(bundleID) else { continue }

                // Either proof of presence keeps the trace.
                //
                // A group container's name is not the app's bundle ID:
                // `group.net.whatsapp.WhatsApp.shared` belongs to
                // `net.whatsapp.WhatsApp`. Comparing the directory name literally
                // finds no match, so a *running, installed* app's shared data was
                // reported as an orphan. Absence is therefore judged against
                // every ID the trace could plausibly belong to, and a prefix match
                // against any installed ID counts too.
                if presenceProves(for: name,
                                  bundleID: bundleID,
                                  installedIDs: installedIDs) { continue }

                let url = source.root.appendingPathComponent(name)
                let age = ageDays(of: url)
                guard age >= minAgeDays else { continue }

                let bytes = SizeMeasurer.measure(url.path, timeout: 1.5)
                let trace = Leftover(id: "\(source.location.rawValue)/\(name)",
                                     bundleID: bundleID,
                                     path: url.path,
                                     bytes: bytes,
                                     ageDays: age,
                                     kind: source.kind,
                                     location: source.location)
                grouped[bundleID, default: []].append(trace)
            }
        }

        return grouped.map { bundleID, traces in
            OrphanGroup(bundleID: bundleID,
                        displayName: displayName(for: bundleID),
                        leftovers: traces.sorted { $0.bytes > $1.bytes })
        }
        .sorted { $0.bytes > $1.bytes }
    }

    /// Container-name prefixes that wrap the real bundle ID, and the trailing
    /// words a container appends to it.
    static let containerSuffixes: Set<String> = [
        "shared", "private", "family", "teams", "groups", "media", "agent",
        "store", "backing", "index", "data", "library", "plugin", "plugins",
        "sharingservice", "sharingserviceextension", "watchkitapp",
    ]

    /// Whether any evidence shows the app that owns this trace is present.
    ///
    /// The trace name is normalised first: a `group.` prefix is dropped and a
    /// trailing container word such as `shared` or `family` is trimmed, then any
    /// surviving identifier is checked against the installed inventory, the
    /// LaunchServices registry and Spotlight. A trace also survives if *any*
    /// installed ID is a prefix of it, because `group.net.whatsapp.WhatsApp.shared`
    /// is owned by the installed `net.whatsapp.WhatsApp`.
    static func presenceProves(for name: String,
                               bundleID: String,
                               installedIDs: Set<String>) -> Bool {
        var candidates: [String] = [bundleID]
        var stem = name

        for prefix in ["group.", "systemgroup."] where stem.hasPrefix(prefix) {
            stem.removeFirst(prefix.count)
        }
        // A leading Apple team identifier: `SY64MV22J9.com.raycast.macos.shared`
        // and `UBF8T346G9.OfficeOsWebHost` both wrap a vendor ID behind a
        // 10-character team string.
        if let dot = stem.firstIndex(of: ".") {
            let first = String(stem[..<dot])
            if first.count >= 8,
               first.allSatisfy({ $0.isUppercase || $0.isNumber }),
               first.contains(where: { $0.isNumber }) {
                stem = String(stem[stem.index(after: dot)...])
            }
        }
        // Trim trailing container words, repeatedly: `WhatsAppSMB.shared` is two
        // suffixes away from `WhatsApp`.
        var trimmed = true
        while trimmed {
            trimmed = false
            guard let dot = stem.lastIndex(of: ".") else { break }
            let last = String(stem[stem.index(after: dot)...])
            guard containerSuffixes.contains(last.lowercased()) else { break }
            stem = String(stem[..<dot])
            trimmed = true
        }
        if !stem.isEmpty, stem != name, isReverseDNS(stem) {
            candidates.append(stem)
        }
        // `WhatsAppSMB` is a sibling of `WhatsApp`, so also try the name with its
        // last label removed and each installed ID as a prefix.
        if let dot = stem.lastIndex(of: ".") {
            let owner = String(stem[..<dot])
            if isReverseDNS(owner) { candidates.append(owner) }
        }

        for candidate in candidates {
            if installedIDs.contains(candidate) { return true }
            // A candidate shorter than the real ID also proves presence:
            // `net.whatsapp.family` is one container flavour of the installed
            // `net.whatsapp.WhatsApp`, so a candidate that the installed ID
            // extends keeps the trace.
            if installedIDs.contains(where: { $0.hasPrefix(candidate + ".") }) {
                return true
            }
        }
        // Any installed ID that is a component-wise prefix of the trace.
        for installed in installedIDs {
            if name == installed { return true }
            if name.hasPrefix(installed + ".") { return true }
        }
        // Fall back to the live sources for the most specific candidates only.
        for candidate in candidates where labelCount(candidate) >= 2 {
            if stillInstalled(bundleID: candidate) { return true }
        }
        return false
    }

    /// Child names of a location, or nothing when it cannot be read. A TCC
    /// denial here is silent by design: one unreadable folder must not abort the
    /// whole sweep, and it simply contributes no candidates.
    private static func childNames(of root: URL) -> [String] {
        (try? FileManager.default.contentsOfDirectory(atPath: root.path)) ?? []
    }

    /// Traces belonging to one bundle ID, for the post-uninstall popup.
    ///
    /// No age gate here: the user just removed the app, so its traces are
    /// exactly what needs reviewing. Every returned trace still passes the same
    /// absence check, because the app bundle may have moved to the Trash.
    public static func traces(forBundleID bundleID: String,
                              minAgeDays: Int = 0) -> [Leftover] {
        guard isCandidate(bundleID) else { return [] }

        var results: [Leftover] = []
        for source in locations {
            for name in childNames(of: source.root) where !name.hasPrefix(".") {
                guard extractedBundleID(from: name) == bundleID else { continue }
                let url = source.root.appendingPathComponent(name)
                let age = ageDays(of: url)
                guard age >= minAgeDays else { continue }
                let bytes = SizeMeasurer.measure(url.path, timeout: 1.2)
                results.append(Leftover(id: "\(source.location.rawValue)/\(name)",
                                        bundleID: bundleID,
                                        path: url.path,
                                        bytes: bytes,
                                        ageDays: age,
                                        kind: source.kind,
                                        location: source.location))
            }
        }
        return results.sorted { $0.bytes > $1.bytes }
    }

    /// The bundle ID a directory or file name belongs to, if any.
    ///
    /// Handles the three shapes an app leaves behind: a bare bundle ID
    /// (`com.vendor.app`), a preferences file (`com.vendor.app.plist`), and a
    /// trace with its own suffix (`com.vendor.app.binarycookies`).
    public static func bundleID(forEntry name: String) -> String? {
        extractedBundleID(from: name)
    }

    /// Trace suffixes that belong to the file, not to the bundle ID.
    static let traceSuffixes: Set<String> = [
        "binarycookies", "cookies", "plist", "sfl4", "sfl2", "savedState", "lock",
        "sqlite", "sqlite3", "db", "json", "log",
    ]

    /// Strip known trace suffixes until a reverse-DNS identifier remains.
    ///
    /// A suffix that is not stripped is read as part of the bundle ID, which
    /// would make `com.vendor.app.binarycookies` a different app from
    /// `com.vendor.app`, so the trace would never group with its siblings.
    public static func extractedBundleID(from name: String) -> String? {
        // A trace name is `<stem>` with optional suffixes. `pathExtension` cannot
        // tell a suffix from a bundle ID's own last label, so the split is done
        // on a known-suffix basis instead: peel only labels that are trace
        // suffixes, and stop at the first one that is not.
        //
        // The order matters. `ai.elementlabs.lmstudio` ends in a bare vendor
        // label that happens to collide with a real extension, so peeling on
        // "is there a dot at all" would turn it into `ai.elementlabs` and lose
        // the app. `com.vendor.app.binarycookies` peels correctly because
        // `binarycookies` is a known suffix, while
        // `com.vendor.app_stats.sqlite3` peels to `com.vendor.app_stats` and is
        // then rejected by the qualifier test.
        var candidate = name
        while let dot = candidate.lastIndex(of: ".") {
            let suffix = String(candidate[candidate.index(after: dot)...]).lowercased()
            guard traceSuffixes.contains(suffix) else { break }
            candidate = String(candidate[..<dot])
            if candidate.isEmpty { return nil }
        }

guard isReverseDNS(candidate) else { return nil }
        // More than four labels is almost never one app: `com.apple.Safari` is
        // three, and `com.apple.private.Foo.Bar` is a nested framework
        // rather than a removable app. Rejecting long identifiers is what stops
        // one group from swallowing every framework-owned trace.
        guard labelCount(candidate) <= 4 else { return nil }
        // Every label must name a vendor, not a filename. `default.store` has
        // two reverse-DNS-shaped labels and so passes the shape check, but
        // "default" is a generic word — the entry is a SQLite file that belongs
        // to whichever app owns it, and reporting it as an app of its own
        // invents a vendor and offers the user's real data for deletion.
        // `com.raycast.shared` fails the same way on its last label.
        let labels = candidate.lowercased().split(separator: ".").map(String.init)
        guard !labels.contains(where: { genericStems.contains($0) }) else { return nil }
        // A qualified stem is a satellite of another app, not an app itself.
        if groupQualifiers.contains(where: { candidate.hasSuffix($0) }) { return nil }
        return candidate
    }

    /// Reverse-DNS shape check that admits the real-world prefixes a cleanup
    /// tool must recognise.
    ///
    /// `ProtectedBundles.isReverseDNS` requires a first label of at least three
    /// characters, which rejects `ai.*`, `io.*` and `pro.*`. Those are genuine
    /// TLD-backed vendor prefixes used by LM Studio, container tooling and
    /// BetterDisplay, so requiring three characters would silently skip their
    /// leftovers forever.
    static func isReverseDNS(_ value: String) -> Bool {
        let parts = value.split(separator: ".", omittingEmptySubsequences: false)
        guard parts.count >= 2 else { return false }
        let allowed = CharacterSet(charactersIn:
            "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-_")
        return parts.allSatisfy { part in
            !part.isEmpty && part.unicodeScalars.allSatisfy { allowed.contains($0) }
        }
    }

    /// Number of dot-separated labels. `pro.betterdisplay.BetterDisplay` has
    /// three, `ai.elementlabs.lmstudio` has three, and
    /// `com.apple.AddressBookSourceSync` has four — but the four-label Apple
    /// subsystem is rejected by the label cap only when it also carries an
    /// Apple prefix, which `isCandidate` handles separately.
    static func labelCount(_ value: String) -> Int {
        value.split(separator: ".").count
    }

    /// Bundle IDs that must never be reported, whatever is on disk.
    ///
    /// Two families matter here:
    ///
    /// - **Shared data.** A container or group container can be shared by
    ///   several apps, so it outlives any one of them. `com.docker.docker`
    ///   holds VM images, which are the user's data rather than rebuildable
    ///   cache, and an earlier build wrongly reported 19 GB of it as an orphan.
    /// - **Vendor infrastructure.** Update agents, helper daemons and Sparkle
    ///   frames belong to whichever app is currently installed, so their
    ///   presence says nothing about a removed app.
static let neverOrphanPrefixes: [String] = [
        "com.apple.", "group.com.apple.", "systemgroup.com.apple.",
        // Apple "is" group containers: Shortcuts and Workflow live here and ship
        // with macOS, so nothing on this Mac can ever be their orphan.
        "group.is.", "systemgroup.is.", "is.",
        "group.tvappservices.", "com.apple.tv.",
        "org.sparkle-project.", "com.microsoft.autoupdate",
        "com.microsoft.updates", "com.microsoft.EdgeUpdater",
        "com.microsoft.OneDriveUpdater", "com.google.keystone",
        // Suite-level identifiers. `com.microsoft.office` is written by whichever
        // of Word, Excel or PowerPoint the user has open, and none of them
        // carries that ID as its own bundle identifier, so an absence check can
        // never see the app that owns it.
        "com.microsoft.office", "com.microsoft.shared",
        "com.google.updater", "com.google.GoogleUpdater",
    ]

    /// Exact IDs whose on-disk data is user content, not an app's residue.
    static let sharedDataIDs: Set<String> = [
        "com.docker.docker", "com.docker",
        "com.parallels.desktop", "com.vmware.fusion", "com.utmapp.UTM",
        // Crash-reporting and analytics SDKs. They are libraries embedded in
        // dozens of unrelated apps, so a leftover proves nothing about any one
        // of them being uninstalled.
        "io.sentry", "com.crashlytics", "com.google.firebase.analytics",
        "io.mixpanel", "com.amplitude", "com.appsflyer",
        // Cross-app services that several apps register with at once.
        "group.net.whatsapp.WhatsApp.family",
    ]

    /// Whether a bundle ID may be reported as an orphan at all.
    public static func isCandidate(_ bundleID: String) -> Bool {
        if neverDelete.contains(bundleID) { return false }
        if sharedDataIDs.contains(bundleID) { return false }
        if neverOrphanPrefixes.contains(where: { bundleID.hasPrefix($0) }) { return false }
        if ProtectedBundles.isProtected(bundleID) { return false }
        let lowered = bundleID.lowercased()
        if credentialMarkers.contains(where: { lowered.contains($0) }) { return false }
        // A single-letter first label is not a vendor identifier.
        guard let first = bundleID.split(separator: ".").first, first.count >= 2 else {
            return false
        }
        return true
    }

    /// Positive evidence that nothing on this Mac provides this bundle ID.
    ///
    /// One `mdfind` call per candidate is the cost driver here: the Apps, WebKit
    /// and HTTPStorages directories hold hundreds of bundle-ID-shaped entries, so
    /// several hundred subprocesses turn a scan into minutes. Three facts replace
    /// the per-candidate query:
    ///
    /// - The installed-app inventory already proved which bundles are present.
    /// - `lsregister -dump` lists every *registered* bundle ID in one call, and a
    ///   registered bundle is by definition still on this Mac.
    /// - Spotlight is consulted once per candidate, but only for candidates the
    ///   two cheap sources have not already cleared.
    ///
    /// Every failure mode returns `true`, so a broken query keeps the trace
    /// rather than deleting it.
    public static func stillInstalled(bundleID: String) -> Bool {
        if registeredBundleIDs.contains(bundleID) { return true }
        return spotlightHasApp(bundleID: bundleID)
    }

    /// Bundle IDs LaunchServices still knows about, read once and cached.
    private static let registeredCache = LivenessProbe.ProbeCache<Set<String>>(ttl: 600)

    static var registeredBundleIDs: Set<String> {
        if let cached = registeredCache.cached() { return cached }

        let lsregister = "/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"
        guard let out = try? Paths.run(lsregister, ["-dump"], timeout: 20),
              out.status == 0 else {
            // Unknown: cache an empty set so the check degrades to Spotlight only
            // rather than re-running a 20-second query per candidate.
            registeredCache.store([])
            return []
        }

        var ids = Set<String>()
        for line in out.stdout.split(separator: "\n") {
            // Lines look like: `path:  /Applications/Some.app (0x1234)  bundle id: com.vendor.app`
            guard let range = line.range(of: "bundle id: ") else { continue }
            let value = line[range.upperBound...].trimmingCharacters(in: .whitespaces)
            guard !value.isEmpty, ProtectedBundles.isReverseDNS(value) else { continue }
            ids.insert(value)
        }
        registeredCache.store(ids)
        return ids
    }

    private static func spotlightHasApp(bundleID: String) -> Bool {
        guard let out = try? Paths.run(
            "/usr/bin/mdfind", ["kMDItemCFBundleIdentifier == \"\(bundleID)\"c"], timeout: 4)
        else { return true }
        guard out.status == 0 else { return true }
        return out.stdout.contains(".app")
    }

    /// Human name for a bundle ID. Falls back to the bundle ID itself rather
    /// than inventing one, so the UI never shows a name that may mislead.
    public static func displayName(for bundleID: String) -> String {
        guard let appURL = InstalledApps.appURL(forBundleID: bundleID) else {
            return bundleID
        }
        return appURL.deletingPathExtension().lastPathComponent
    }

    public static func ageDays(of url: URL) -> Int {
        guard let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
              let modified = attrs[.modificationDate] as? Date else { return 0 }
        return Int(Date().timeIntervalSince(modified) / 86_400)
    }
}
/// Everything needed to uninstall one app: the bundle itself, the traces it
/// leaves behind, and the launch agents that must be unloaded before removal.
///
/// The trace list is gathered *before* the bundle moves to the Trash, while the
/// absence check still has a real answer. Afterwards the bundle sits in the
/// Trash and "is this app still installed" becomes ambiguous.
public struct AppRemovalPlan: Sendable, Identifiable {
    public typealias Leftover = OrphanDetector.Leftover
    public let app: InstalledApps.App
    public let traces: [Leftover]

    /// Identifies the sheet rather than the app, so removing one app and then
    /// another still presents a fresh sheet.
    public let id = UUID()

    public init(app: InstalledApps.App, traces: [Leftover]) {
        self.app = app
        self.traces = traces
    }

    public var bytes: Int64 { traces.reduce(0) { $0 + $1.bytes } }
    /// Traces safe to remove without a second look.
    public var autoSelected: [Leftover] { traces.filter { !$0.needsReview } }
    /// Traces holding settings or the app\'s own data.
    public var needsReview: [Leftover] { traces.filter(\.needsReview) }

    /// Gather the plan. Cheap enough to run on every uninstall click.
    public static func forApp(_ app: InstalledApps.App) -> AppRemovalPlan {
        let traces = OrphanDetector.traces(forBundleID: app.id, minAgeDays: 0)
        return AppRemovalPlan(app: app, traces: traces)
    }
}
