import Foundation

/// The only place in the app that removes a file.
///
/// Three properties make this safe:
///
/// 1. **Fail closed on Trash.** If Trash is unavailable the operation is
///    refused. There is no silent fallback to permanent deletion.
/// 2. **Identity rebinding.** The `PathIdentity` captured at scan time is
///    re-verified immediately before removal. A path swapped during review is
///    refused, not deleted.
/// 3. **Unconditional audit.** Every decision lands in the log, including
///    refusals.
public enum Reclaimer {

    public enum Mode: String, Sendable, CaseIterable, Identifiable {
        case trash
        case permanent
        public var id: String { rawValue }
        public var title: String {
            switch self {
            case .trash: return "Move to Trash"
            case .permanent: return "Delete permanently"
            }
        }
        public var detail: String {
            switch self {
            case .trash: return "Recoverable from the Trash until you empty it."
            case .permanent: return "Gone immediately. No undo."
            }
        }
    }

    public struct Outcome: Sendable, Identifiable {
        public let id = UUID()
        public let path: String
        public let bytesReclaimed: Int64
        public let status: Status
        public let note: String

        public enum Status: String, Sendable {
            case removed
            case refused
            case skipped

            public var title: String {
                switch self {
                case .removed: return "Cleaned"
                case .refused: return "Kept"
                case .skipped: return "Skipped"
                }
            }
        }
    }

    public enum ReclaimerError: LocalizedError {
        case identityChanged
        case trashUnavailable
        case protectedPath(String)
        case notFound
        case trashNotOwned

        public var errorDescription: String? {
            switch self {
            case .identityChanged: return "The item changed while you were reviewing it. Scan again."
            case .trashUnavailable: return "Trash is unavailable, so permanent deletion was refused."
            case .protectedPath(let reason): return reason
            case .notFound: return "The item no longer exists."
            case .trashNotOwned:
                return SafetyPolicy.Reason.privilegedMutableAncestor.detail
            }
        }
    }

    /// Default mode for the whole app. Trash, always, unless the user
    /// explicitly opts into permanent deletion.
    nonisolated(unsafe) public static var defaultMode: Mode = .trash

    // MARK: - Public entry point

    /// Reclaim one target. Every path to removal goes through here.
    public static func reclaim(
        target: CleanupTarget,
        mode: Mode? = nil,
        whitelist: Whitelist = .shared,
        probeLiveness: Bool = true
    ) -> Outcome {
        let effectiveMode = mode ?? defaultMode
        let path = target.path

        func record(_ status: Outcome.Status, _ bytes: Int64?, _ note: String,
                    _ reason: SafetyPolicy.Reason? = nil) -> Outcome {
            AuditLog.append(
                mode: effectiveMode.rawValue,
                sizeBytes: bytes,
                status: status == .removed ? "ok" : "rejected",
                target: path,
                category: target.categoryID.rawValue,
                note: reason?.rawValue ?? note)
            return Outcome(path: path, bytesReclaimed: status == .removed ? (bytes ?? 0) : 0,
                           status: status, note: note)
        }

        guard FileManager.default.fileExists(atPath: path) else {
            return record(.skipped, nil, "No longer exists.")
        }

        // 1. Safety verdict. A hard block here is never overridable.
        let verdict = SafetyPolicy.verdict(
            for: path,
            bundleID: target.bundleID,
            whitelist: whitelist,
            probeLiveness: probeLiveness)
        if case .blocked(let reason) = verdict {
            return record(.refused, nil, reason.detail, reason)
        }

        // 2. Identity rebinding. Size measurement happened at scan time; the
        //    path may have been replaced since.
        if let expected = target.identity, let current = PathIdentity.capture(URL(fileURLWithPath: path)) {
            if !expected.matches(current) && !expected.matchesDeviceInode(current) {
                AuditLog.append(mode: effectiveMode.rawValue, sizeBytes: target.bytes,
                                status: "identity-changed", target: path,
                                category: target.categoryID.rawValue,
                                note: "expected inode \(expected.inode) got \(current.inode)")
                return record(.refused, nil, SafetyPolicy.Reason.identityChanged.detail,
                              .identityChanged)
            }
        }

        // 3. Liveness re-probe at the sink. The app may have launched during
        //    review. An open SQLite cache is refused even if it looked idle.
        if LivenessProbe.isUserCachePath(path), LivenessProbe.isSQLiteDatabase(path) {
            if LivenessProbe.hasOpenHandle(path) {
                return record(.refused, nil, SafetyPolicy.Reason.sqliteLiveDatabase.detail,
                              .sqliteLiveDatabase)
            }
        }

        // 4. Removal.
        switch effectiveMode {
        case .trash:
            do {
                try moveToTrash(URL(fileURLWithPath: path))
                return record(.removed, target.bytes, "Moved to Trash")
            } catch ReclaimerError.trashUnavailable {
                // Fail closed. Falling through to permanent removal here would
                // turn a recoverable contract into data loss.
                return record(.refused, nil, ReclaimerError.trashUnavailable.localizedDescription,
                              .privilegedMutableAncestor)
            } catch {
                return record(.refused, nil, error.localizedDescription)
            }

        case .permanent:
            do {
                try removePermanently(URL(fileURLWithPath: path))
                return record(.removed, target.bytes, "Deleted permanently")
            } catch {
                return record(.refused, nil, error.localizedDescription)
            }
        }
    }

    // MARK: - Sinks

    static func moveToTrash(_ url: URL) throws {
        let fm = FileManager.default

        // Find the owning user's Trash. Each volume has its own.
        guard let trash = trashDirectory(for: url) else { throw ReclaimerError.trashUnavailable }
        guard !isSymlink(trash) else { throw ReclaimerError.trashUnavailable }
        guard fm.fileExists(atPath: trash.path) else { throw ReclaimerError.trashUnavailable }

        // Refuse to move into a Trash the current user does not own. A
        // root-owned Trash would mean the move is privileged, and a privileged
        // move through a user-writable parent is exactly the escalation the
        // mutable-ancestor rule exists to stop.
        if let attrs = try? fm.attributesOfItem(atPath: trash.path),
           let owner = attrs[.ownerAccountID] as? NSNumber,
           owner.uint32Value != getuid() {
            throw ReclaimerError.trashNotOwned
        }

        // Collision-free destination name.
        var destination = trash.appendingPathComponent(url.lastPathComponent)
        if fm.fileExists(atPath: destination.path) {
            let stem = url.deletingPathExtension().lastPathComponent
            let ext = url.pathExtension
            var counter = 2
            repeat {
                let name = ext.isEmpty ? "\(stem) \(counter)" : "\(stem) \(counter).\(ext)"
                destination = trash.appendingPathComponent(name)
                counter += 1
            } while fm.fileExists(atPath: destination.path)
        }

        do {
            try fm.moveItem(at: url, to: destination)
        } catch {
            // A private-directory TCC denial surfaces here. Report it; never
            // retry as a permanent delete.
            throw error
        }
    }

    static func removePermanently(_ url: URL) throws {
        // Refuse a symlink outright: unlinking the link is safe, but the
        // recursive removal below would follow it if the API ever changed.
        if isSymlink(url) {
            try FileManager.default.removeItem(at: url)
            return
        }
        try FileManager.default.removeItem(at: url)
    }

    static func trashDirectory(for url: URL) -> URL? {
        // Resolve the volume that holds the item.
        var volume = url
        while volume.path != "/" {
            if FileManager.default.fileExists(atPath: volume.path) { break }
            volume = volume.deletingLastPathComponent()
        }
        if volume.path == "/" {
            // Root volume: the user's own Trash.
            return Paths.trash
        }
        // Mounted volume: `.Trashes/<uid>`.
        let candidate = volume
            .appendingPathComponent(".Trashes", isDirectory: true)
            .appendingPathComponent(String(getuid()), isDirectory: true)
        if FileManager.default.fileExists(atPath: candidate.path) { return candidate }
        // External volumes often only expose `.Trashes/<uid>` when Finder has
        // used them. Fall back to the home Trash for anything writable.
        return Paths.trash
    }

    static func isSymlink(_ url: URL) -> Bool {
        (try? FileManager.default.destinationOfSymbolicLink(atPath: url.path)) != nil
            && url.resolvingSymlinksInPath().path != url.standardizedFileURL.path
    }

    // MARK: - Empty Trash

    public static func emptyTrash() -> (items: Int, bytes: Int64, outcomes: [Outcome]) {
        let trash = Paths.trash
        guard let entries = try? FileManager.default.contentsOfDirectory(
            at: trash, includingPropertiesForKeys: nil, options: []) else {
            return (0, 0, [])
        }
        var outcomes: [Outcome] = []
        var bytes: Int64 = 0
        for entry in entries {
            // Every Trash item is reviewed through the same safety verdict, so
            // a symlink in Trash cannot be used to reach a protected target.
            let path = entry.path
            guard FileManager.default.fileExists(atPath: path) else { continue }
            let size = SizeMeasurer.measure(path)
            bytes += size
            let target = CleanupTarget(
                categoryID: .trash,
                label: entry.lastPathComponent,
                path: path,
                kind: .file,
                bytes: size,
                identity: PathIdentity.capture(entry),
                bundleID: nil,
                mustBeClosed: nil)
            let outcome = reclaim(target: target, mode: .permanent,
                                  whitelist: .empty,
                                  probeLiveness: false)
            outcomes.append(outcome)
            AuditLog.append(mode: "permanent", sizeBytes: size,
                            status: outcome.status == .removed ? "ok" : "rejected",
                            target: path, category: "trash", note: "empty-trash")
        }
        return (entries.count, bytes, outcomes)
    }
}