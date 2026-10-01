import Foundation

/// Size measurement that never follows symlinks and never wedges on a hostile
/// tree. Every directory walk is budgeted; a slow subtree is reported as
/// unknown rather than blocking the scan.
public enum SizeMeasurer {

    /// Bytes a subtree occupies, following no symlinks and skipping packages.
    /// Returns 0 for an unreadable path rather than guessing upward.
    public static func measure(_ path: String, timeout: TimeInterval = 2.0) -> Int64 {
        let url = URL(fileURLWithPath: path)
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory) else {
            return 0
        }
        if !isDirectory.boolValue {
            let attrs = try? FileManager.default.attributesOfItem(atPath: path)
            return (attrs?[.size] as? NSNumber)?.int64Value ?? 0
        }

        let deadline = Date().addingTimeInterval(timeout)
        var total: Int64 = 0
        let keys: [URLResourceKey] = [.isRegularFileKey, .fileAllocatedSizeKey,
                                      .totalFileAllocatedSizeKey, .fileSizeKey]

        guard let enumerator = FileManager.default.enumerator(
            at: url, includingPropertiesForKeys: keys,
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else { return 0 }

        while let next = enumerator.nextObject() as? URL {
            if Date() > deadline { break }
            guard let values = try? next.resourceValues(forKeys: Set(keys)) else { continue }
            guard values.isRegularFile == true else { continue }

            // Allocated size reflects what is actually freed. St_blocks is what
            // `du` reports, so prefer it when available.
            if let allocated = values.totalFileAllocatedSize {
                total += Int64(allocated)
            } else if let size = values.fileSize {
                total += Int64(size)
            }
        }
        return total
    }

    /// Apparent size, which is what a user sees in Finder. Used for the
    /// "sparse file" case where allocated blocks are misleadingly small.
    public static func apparentSize(_ path: String, timeout: TimeInterval = 2.0) -> Int64 {
        let url = URL(fileURLWithPath: path)
        let deadline = Date().addingTimeInterval(timeout)
        var total: Int64 = 0
        guard let enumerator = FileManager.default.enumerator(
            at: url, includingPropertiesForKeys: [.isRegularFileKey, .fileSizeKey],
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else { return 0 }
        while let next = enumerator.nextObject() as? URL {
            if Date() > deadline { break }
            guard let values = try? next.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey]),
                  values.isRegularFile == true else { continue }
            total += Int64(values.fileSize ?? 0)
        }
        return total
    }

    /// Whether the app can read the contents of `path`.
    ///
    /// TCC lets a process *list* a protected directory such as
    /// `~/Library/Containers` but refuses to descend into it. A measurement in
    /// that state returns 0 bytes, which is indistinguishable from an empty
    /// folder — so a scan reported 27 leftover containers at "0 bytes" and the
    /// real figure was never shown. This probe separates the two cases so the UI
    /// can say "needs Full Disk Access" instead of lying with a zero.
    public static func canRead(_ path: String) -> Bool {
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory) else {
            return true // absent is not unreadable
        }
        if !isDirectory.boolValue {
            return FileManager.default.isReadableFile(atPath: path)
        }
        guard let entries = try? FileManager.default.contentsOfDirectory(
            atPath: path) else { return false }
        // An empty listing is inconclusive, so probe one child.
        guard let first = entries.first else {
            return FileManager.default.isReadableFile(atPath: path)
        }
        return FileManager.default.isReadableFile(
            atPath: (path as NSString).appendingPathComponent(first))
    }

    /// True when a measurement of `path` is trustworthy.
    ///
    /// A 0-byte result on a directory that is actually readable means the folder
    /// really is empty; a 0-byte result on an unreadable one is a measurement
    /// failure and must not be presented as "nothing here".
    public static func isMeasurementValid(_ path: String) -> Bool {
        canRead(path)
    }

    /// Directories whose contents macOS refuses to read without Full Disk
    /// Access. Detected once, since the answer does not change mid-session.
    public enum Access {
        private static let flag = LivenessProbe.ProbeCache<Bool>(ttl: 30)

        public static var lacksFullDiskAccess: Bool {
            if let cached = flag.cached() { return cached }
            let result = probe()
            flag.store(result)
            return result
        }

        private static func probe() -> Bool {
            // A container we cannot descend into is the signal. "Is this folder
            // empty" is not a usable probe: an empty container and a protected one
            // look the same from the outside.
            //
            // The signal is a *majority*, not "any". Without Full Disk Access
            // essentially no container contents can be read, so the fraction sits
            // near zero. With it, nearly all can — but a handful can still be
            // unreadable for unrelated reasons (root-owned, SIP-protected,
            // belonging to a removed app with odd ownership). Testing "any
            // unreadable" therefore reported missing access even when the grant
            // was live, and the app kept asking for a permission it already had.
            let sample = Paths.containers.path
            let names = (try? FileManager.default.contentsOfDirectory(atPath: sample)) ?? []
            guard !names.isEmpty else { return true }
            // Cap the work: a Mac can hold hundreds of containers and one stat per
            // entry is not free.
            let probed = names.prefix(40)
            let readable = probed.filter { canRead("\(sample)/\($0)") }.count
            return readable * 2 < probed.count
        }
    }

    /// File count, used by the detail inspector so a user can judge a cache by
    /// its shape ("40,000 tiny files") not just its byte total.
    public static func fileCount(_ path: String, timeout: TimeInterval = 1.5) -> Int {
        let url = URL(fileURLWithPath: path)
        let deadline = Date().addingTimeInterval(timeout)
        var count = 0
        guard let enumerator = FileManager.default.enumerator(
            at: url, includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else { return 0 }
        while enumerator.nextObject() != nil {
            if Date() > deadline { break }
            count += 1
        }
        return count
    }
}

/// Runs scan rules and produces cleanable targets. Named `ScanEngine` rather
/// than `Scanner` because `Foundation.Scanner` already occupies that name and
/// unqualified references silently resolve to the wrong type.
public actor ScanEngine {

    public struct Result: Sendable {
        public var targets: [CleanupTarget]
        public var blocked: [BlockedTarget]
        /// Targets that are cleanable but carry a warning, keyed by path.
        public var warnings: [String: SafetyPolicy.Reason]
        public var duration: TimeInterval
    }

    /// A target the user asked about but policy refused.
    public struct BlockedTarget: Sendable, Identifiable, Hashable {
        public let id = UUID()
        public let path: String
        public let label: String
        public let bytes: Int64
        public let reason: SafetyPolicy.Reason
        public let category: CleanCategory
    }

    private let whitelist: Whitelist
    /// Bounded concurrency. Independent semaphores so a single huge category
    /// cannot starve the others.
    private let gate = ConcurrencyLimiter(limit: 12)

    public init(whitelist: Whitelist = .shared) {
        self.whitelist = whitelist
    }

    public func scan(categories: [CleanCategory] = CleanCategory.allCases.filter { !$0.isReviewOnly },
                     includeBlocked: Bool = true) async -> Result {
        let start = Date()

        // Expand rules into candidate paths only. Sizing walks whole directory
        // trees, so it has to happen inside the concurrent group: doing it
        // serially here made a full scan take minutes.
        let candidates = categories.flatMap { ScanCatalog.rules(for: $0) }
            .flatMap(expandRule)

        let gate = self.gate
        let whitelist = self.whitelist

        var allowed: [CleanupTarget] = []
        var blocked: [BlockedTarget] = []
        var warnings: [String: SafetyPolicy.Reason] = [:]

        await withTaskGroup(of: ScannedCandidate?.self) { group in
            for candidate in candidates {
                group.addTask {
                    await gate.withPermit {
                        guard FileManager.default.fileExists(atPath: candidate.path) else {
                            return nil
                        }
                        // Size inside the permit: it is the expensive step and
                        // the permit is what bounds it.
                        let target = ScanEngine.materialize(candidate)
                        let verdict = SafetyPolicy.verdict(
                            for: target.path,
                            bundleID: target.bundleID,
                            whitelist: whitelist,
                            probeLiveness: target.mustBeClosed == nil)
                        return ScannedCandidate(target: target, verdict: verdict)
                    }
                }
            }

            for await scanned in group {
                guard let scanned else { continue }
                switch scanned.verdict {
                case .blocked(let reason):
                    if includeBlocked {
                        blocked.append(BlockedTarget(
                            path: scanned.target.path,
                            label: scanned.target.label,
                            bytes: scanned.target.bytes,
                            reason: reason,
                            category: scanned.target.categoryID))
                    }
                case .allowWithWarning(let reason):
                    warnings[scanned.target.path] = reason
                    allowed.append(scanned.target)
                case .allow:
                    allowed.append(scanned.target)
                }
            }
        }

        return Result(
            targets: allowed.sorted { $0.bytes > $1.bytes },
            blocked: blocked.sorted { $0.bytes > $1.bytes },
            warnings: warnings,
            duration: Date().timeIntervalSince(start))
    }

    private struct ScannedCandidate: Sendable {
        let target: CleanupTarget
        let verdict: SafetyPolicy.Verdict
    }

    // MARK: - Rule expansion

    /// A path a rule produced, before it has been sized or vetted. Carrying
    /// only the path lets sizing happen concurrently.
    struct Candidate: Sendable {
        var path: String
        var label: String
        var category: CleanCategory
        var mustBeClosed: String?
    }

    /// Turn a candidate into a full target: measure it, bind its identity, and
    /// resolve the owning bundle ID. Nonisolated because the concurrent group
    /// that sizes candidates runs off the actor.
    nonisolated static func materialize(_ candidate: Candidate) -> CleanupTarget {
        let url = URL(fileURLWithPath: candidate.path)
        var isDir: ObjCBool = false
        _ = FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir)
        let bundleID = isDir.boolValue ? LivenessProbe.ownerBundleID(for: url.path) : nil
        // A protected container reports 0 bytes, which reads as "empty". Record
        // that the measurement is untrustworthy so the UI can say why.
        let measurable = SizeMeasurer.isMeasurementValid(url.path)
        return CleanupTarget(
            categoryID: candidate.category,
            label: candidate.label,
            path: url.path,
            kind: isDir.boolValue ? .directory : .file,
            bytes: SizeMeasurer.measure(url.path),
            identity: PathIdentity.capture(url),
            bundleID: bundleID,
            mustBeClosed: candidate.mustBeClosed,
            isMeasurable: measurable)
    }

    func expandRule(_ rule: ScanRule) -> [Candidate] {
        switch rule {
        case .directory(let path, let label, let category, let minAge, _, let closed):
            let url = Paths.expand(path)
            guard passesAge(url, minAge) else { return [] }
            return [make(url: url, label: label, category: category, closed: closed)]

        case .children(let base, let label, let category, let minAge, _, let closed, let keep):
            let baseURL = Paths.expand(base)
            guard let names = try? FileManager.default.contentsOfDirectory(
                atPath: baseURL.path) else { return [] }
            return names
                .filter { !keep.contains($0) && !$0.hasPrefix(".") }
                .compactMap { name -> Candidate? in
                    let child = baseURL.appendingPathComponent(name)
                    var isDir: ObjCBool = false
                    guard FileManager.default.fileExists(
                        atPath: child.path, isDirectory: &isDir) else { return nil }
                    guard passesAge(child, minAge) else { return nil }
                    return make(url: child, label: "\(label): \(name)",
                                category: category, closed: closed)
                }

        case .files(let dir, let extensions, let label, let category, let minAge, _, let closed):
            let dirURL = Paths.expand(dir)
            guard let names = try? FileManager.default.contentsOfDirectory(
                atPath: dirURL.path) else { return [] }
            let extSet = Set(extensions)
            return names.compactMap { name -> Candidate? in
                let ext = (name as NSString).pathExtension.lowercased()
                guard extSet.contains(ext) || extSet.contains("") else { return nil }
                let url = dirURL.appendingPathComponent(name)
                var isDir: ObjCBool = false
                guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir),
                      !isDir.boolValue else { return nil }
                guard passesAge(url, minAge) else { return nil }
                return make(url: url, label: label, category: category, closed: closed)
            }

        case .glob(let depth, let pattern, let label, let category, let minAge, _, let closed):
            let (base, leafPattern) = splitGlob(pattern)
            let baseURL = Paths.expand(base)
            let matches = Glob.children(of: baseURL, pattern: leafPattern)
            return matches.flatMap { matched -> [Candidate] in
                // depth 0: the matched dir is the target.
                if depth == 0 {
                    guard passesAge(matched, minAge) else { return [] }
                    return [make(url: matched, label: "\(label): \(matched.lastPathComponent)",
                                 category: category, closed: closed)]
                }
                // depth >= 1: target the children of the matched dir.
                guard let children = try? FileManager.default.contentsOfDirectory(
                    atPath: matched.path) else { return [] }
                return children.compactMap { name -> Candidate? in
                    let child = matched.appendingPathComponent(name)
                    var isDir: ObjCBool = false
                    guard FileManager.default.fileExists(
                        atPath: child.path, isDirectory: &isDir), isDir.boolValue else { return nil }
                    guard passesAge(child, minAge) else { return nil }
                    return make(url: child,
                                label: "\(label): \(name)",
                                category: category, closed: closed)
                }
            }
        }
    }

    func make(url: URL, label: String, category: CleanCategory, closed: String?) -> Candidate {
        Candidate(path: url.path, label: label, category: category, mustBeClosed: closed)
    }

    /// Split a rule pattern into its literal parent and its final wildcard
    /// component. Rules are authored one wildcard level deep on purpose: a
    /// recursive pattern would make a discovery bug able to reach anywhere.
    func splitGlob(_ pattern: String) -> (String, String) {
        let expanded = Paths.expand(pattern).path
        let components = expanded.split(separator: "/", omittingEmptySubsequences: false).map(String.init)
        guard let last = components.last else { return (pattern, "*") }
        if last.contains("*") || last.contains("?") {
            let parent = "/" + components.dropLast().joined(separator: "/")
            return (parent, last)
        }
        return (expanded, "*")
    }

    func passesAge(_ url: URL, _ minAgeDays: Int?) -> Bool {
        guard let minAgeDays, minAgeDays > 0 else { return true }
        guard let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
              let modified = attrs[.modificationDate] as? Date else { return true }
        let age = Date().timeIntervalSince(modified)
        return age > Double(minAgeDays) * 86_400
    }
}

/// Fixed-size concurrency gate.
///
/// A released permit is handed **directly** to the first waiter rather than
/// incrementing a free count. Incrementing the count and leaving waiters parked
/// deadlocks: a newly arriving task then steals the free slot, so the parked
/// waiter is never resumed and the group never finishes.
actor ConcurrencyLimiter {
    private var available: Int
    private var waiters: [CheckedContinuation<Void, Never>] = []
    private let limit: Int

    init(limit: Int) {
        self.limit = limit
        self.available = limit
    }

    func withPermit<T>(_ body: @Sendable () async -> T) async -> T {
        await acquire()
        // A throwing or cancelled body must still return its permit, otherwise
        // one cancellation leaks a slot and eventually wedges every waiter.
        let result = await body()
        release()
        return result
    }

    private func acquire() async {
        if available > 0 {
            available -= 1
            return
        }
        await withCheckedContinuation { continuation in
            waiters.append(continuation)
        }
        // The permit was transferred by `release`, so `available` is unchanged.
    }

    private func release() {
        if waiters.isEmpty {
            available = min(limit, available + 1)
        } else {
            waiters.removeFirst().resume()
        }
    }
}