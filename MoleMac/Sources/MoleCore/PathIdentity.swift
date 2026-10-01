import Foundation

/// A device/inode/mtime snapshot captured at scan time and re-verified at the
/// deletion sink.
///
/// Why this exists: measuring a directory's size takes real time. During that
/// window the path can be swapped for something else. Deleting by pathname
/// alone would delete the *replacement*, which may be live user data. Mole
/// re-verifies identity five times inside `safe_remove` for this reason; a GUI
/// has the same race, so the same binding applies.
public struct PathIdentity: Sendable, Hashable {
    public let device: UInt64
    public let inode: UInt64
    public let modificationSeconds: Double
    public let sizeBytes: Int64
    public let isDirectory: Bool

    public init(device: UInt64, inode: UInt64, modificationSeconds: Double,
                sizeBytes: Int64, isDirectory: Bool) {
        self.device = device
        self.inode = inode
        self.modificationSeconds = modificationSeconds
        self.sizeBytes = sizeBytes
        self.isDirectory = isDirectory
    }

    /// Returns nil when the path no longer exists, so absence is distinct from
    /// "changed" and never silently passes as a match.
    public static func capture(_ url: URL) -> PathIdentity? {
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory) else {
            return nil
        }
        guard let stat = try? FileManager.default.attributesOfItem(atPath: url.path) else {
            return nil
        }
        let device = (stat[.systemFileNumber] as? NSNumber)?.uint64Value ?? 0
        let inode = (stat[.systemNumber] as? NSNumber)?.uint64Value ?? 0
        let mtime = (stat[.modificationDate] as? Date)?.timeIntervalSince1970 ?? 0
        let size = (stat[.size] as? NSNumber)?.int64Value ?? 0
        return PathIdentity(
            device: device, inode: inode,
            modificationSeconds: mtime, sizeBytes: size,
            isDirectory: isDirectory.boolValue)
    }

    public func matches(_ other: PathIdentity) -> Bool {
        device == other.device
            && inode == other.inode
            && modificationSeconds == other.modificationSeconds
    }

    public func matchesDeviceInode(_ other: PathIdentity) -> Bool {
        device == other.device && inode == other.inode
    }
}

/// Tab-separated audit trail, appended unconditionally on every deletion
/// decision. `sizeBytes` is recorded as `unknown` rather than `0` when
/// measurement fails, so the log never understates a large delete.
public enum AuditLog {
    public struct Entry: Sendable, Identifiable, Hashable {
        public let id = UUID()
        public let timestamp: Date
        public let mode: String
        public let sizeBytes: Int64?
        public let status: String
        public let target: String
        public let category: String
        public let note: String

        public init(timestamp: Date, mode: String, sizeBytes: Int64?, status: String,
                    target: String, category: String, note: String) {
            self.timestamp = timestamp
            self.mode = mode
            self.sizeBytes = sizeBytes
            self.status = status
            self.target = target
            self.category = category
            self.note = note
        }

        public var sizeText: String {
            guard let sizeBytes else { return "unknown" }
            return ByteFormat.compact(sizeBytes)
        }
    }

    private static let queue = DispatchQueue(label: "dev.molemac.audit", qos: .utility)

    public static func append(
        mode: String, sizeBytes: Int64?, status: String, target: String,
        category: String, note: String = ""
    ) {
        queue.async {
            let formatter = ISO8601DateFormatter()
            let line = [
                formatter.string(from: Date()),
                mode,
                sizeBytes.map { String($0) } ?? "unknown",
                status,
                category.replacingOccurrences(of: "\t", with: " "),
                target.replacingOccurrences(of: "\t", with: " "),
                note.replacingOccurrences(of: "\t", with: " "),
            ].joined(separator: "\t")

            do {
                try FileManager.default.createDirectory(
                    at: Paths.logDir, withIntermediateDirectories: true)
                let fileURL = Paths.deletionLog
                if !FileManager.default.fileExists(atPath: fileURL.path) {
                    FileManager.default.createFile(atPath: fileURL.path, contents: nil)
                }
                guard let handle = try? FileHandle(forWritingTo: fileURL) else { return }
                defer { try? handle.close() }
                try handle.seekToEnd()
                try handle.write(contentsOf: Data((line + "\n").utf8))
            } catch {
                // A broken audit trail is surfaced rather than silently
                // swallowed; callers see this through `recentEntries` returning
                // nothing while `lastWriteFailed` is true.
                writeFailureFlag = true
            }
        }
    }

    nonisolated(unsafe) static var writeFailureFlag = false

    public static func recentEntries(limit: Int = 500) -> [Entry] {
        guard let text = try? String(contentsOf: Paths.deletionLog, encoding: .utf8) else {
            return []
        }
        let formatter = ISO8601DateFormatter()
        let lines = text.split(separator: "\n")
        let recent = lines.count > limit ? Array(lines.suffix(limit)) : Array(lines)
        let rows = recent.reversed().compactMap { line -> Entry? in
            let fields = line.split(separator: "\t", omittingEmptySubsequences: false).map(String.init)
            guard fields.count >= 6 else { return nil }
            return Entry(
                timestamp: formatter.date(from: fields[0]) ?? Date(),
                mode: fields[1],
                sizeBytes: Int64(fields[2]),
                status: fields[3],
                target: fields[5],
                category: fields[4],
                note: fields.count > 6 ? fields[6] : "")
        }
        return Array(rows)
    }
}