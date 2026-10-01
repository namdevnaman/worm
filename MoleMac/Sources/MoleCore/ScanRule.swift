import Foundation

/// Why a target is safe (or not) to clean. Unlike Mole's advisory
/// `classify_cleanup_risk`, this is attached to every target and consulted by
/// the reclaimer.
public enum Risk: Int, Sendable, Comparable, CaseIterable {
    /// Regenerated automatically; deleting costs only time.
    case regenerable = 0
    /// Re-download or rebuild, but not free. Chat images, large model caches.
    case reDownload = 1
    /// Not rebuildable from the machine. Backups, archives, project output.
    case userData = 2
    /// System-owned. Refused.
    case unsafe = 3

    public static func < (lhs: Risk, rhs: Risk) -> Bool { lhs.rawValue < rhs.rawValue }

    public var title: String {
        switch self {
        case .regenerable: return "Safe"
        case .reDownload: return "Re-download"
        case .userData: return "Keep"
        case .unsafe: return "Blocked"
        }
    }

    public var detail: String {
        switch self {
        case .regenerable:
            return "Rebuilt automatically by the app. Cleaning may make the next launch slower."
        case .reDownload:
            return "Content is fetched again from the network. Anything expired can no longer be recovered."
        case .userData:
            return "This is your content, not a cache. Off by default."
        case .unsafe:
            return "Not a cleanup target."
        }
    }
}

public enum CleanCategory: String, Sendable, CaseIterable, Identifiable {
    // Match the CLI's section order so the two surfaces stay comparable.
    case userEssentials
    case appCaches
    case browsers
    case cloudOffice
    case developerTools
    case aiTools
    case appsUtilities
    case virtualization
    case applicationSupport
    case appLeftovers
    case deviceFirmware
    case logs
    case systemCaches
    case misc
    case trash
    case largeFiles

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .userEssentials: return "User Essentials"
        case .appCaches: return "App Caches"
        case .browsers: return "Browsers"
        case .cloudOffice: return "Cloud & Office"
        case .developerTools: return "Developer Tools"
        case .aiTools: return "AI Tools"
        case .appsUtilities: return "Apps & Utilities"
        case .virtualization: return "Virtualization"
        case .applicationSupport: return "Application Support"
        case .appLeftovers: return "Uninstalled App Leftovers"
        case .deviceFirmware: return "Device Backups & Firmware"
        case .logs: return "Logs"
        case .systemCaches: return "System Caches"
        case .misc: return "Misc"
        case .trash: return "Trash"
        case .largeFiles: return "Large Files"
        }
    }

    /// The CLI's own wording, so a user comparing surfaces sees one description.
    public var summary: String {
        switch self {
        case .userEssentials:
            return "Per-user caches, logs, Trash and recent-item lists. Rebuilt automatically."
        case .appCaches:
            return "App temporary files. Regenerated next launch."
        case .browsers:
            return "Browser caches. Cookies and sessions stay."
        case .cloudOffice:
            return "Cloud drive and Office caches. Sign-in state is kept."
        case .developerTools:
            return "Xcode, SwiftPM, package manager and node caches. First build will be slower."
        case .aiTools:
            return "Temporary AI app caches. Conversations, projects, and local models are kept."
        case .appsUtilities:
            return "Caches for creative, media and utility apps."
        case .virtualization:
            return "VM image and download caches. Your virtual machines are kept."
        case .applicationSupport:
            return "Code, shader and thumbnail caches inside Application Support."
        case .appLeftovers:
            return "Data left behind by apps that are no longer on this Mac."
        case .deviceFirmware:
            return "Cached iOS, iPadOS and watchOS firmware images."
        case .logs:
            return "Diagnostic logs. Stale files go to Trash. Active large logs are emptied in place."
        case .systemCaches:
            return "macOS-managed caches. Rebuilt automatically."
        case .misc: return "Miscellaneous one-off caches."
        case .trash: return "Empties your Trash permanently."
        case .largeFiles: return "Review large files on this Mac. Nothing is deleted from here."
        }
    }

    public var symbol: String {
        switch self {
        case .userEssentials: return "house"
        case .appCaches: return "square.stack.3d.up"
        case .browsers: return "safari"
        case .cloudOffice: return "cloud"
        case .developerTools: return "hammer"
        case .aiTools: return "sparkles"
        case .appsUtilities: return "app.badge"
        case .virtualization: return "cpu"
        case .applicationSupport: return "shippingbox"
        case .appLeftovers: return "trash.slash"
        case .deviceFirmware: return "iphone.gen3"
        case .logs: return "doc.text.magnifyingglass"
        case .systemCaches: return "gearshape.2"
        case .misc: return "ellipsis.circle"
        case .trash: return "trash"
        case .largeFiles: return "magnifyingglass"
        }
    }

    /// Categories the app never offers for cleaning. Large Files is a review
    /// surface; the user opens or removes files themselves.
    public var isReviewOnly: Bool { self == .largeFiles }
}

public struct CleanupTarget: Sendable, Identifiable, Hashable {
    public let id = UUID()
    public let categoryID: CleanCategory
    public let label: String
    public let path: String
    public let kind: Kind
    public let bytes: Int64
    public let identity: PathIdentity?
    public let bundleID: String?
    public let mustBeClosed: String?
    /// False when the size could not be measured, e.g. a TCC-protected container
    /// read without Full Disk Access. The UI must say "needs access" rather than
    /// report 0 bytes, which is indistinguishable from an empty folder.
    public let isMeasurable: Bool

    public enum Kind: Sendable, Hashable {
        case file
        case directory
    }

    public init(categoryID: CleanCategory, label: String, path: String, kind: Kind,
                bytes: Int64, identity: PathIdentity?, bundleID: String?,
                mustBeClosed: String?, isMeasurable: Bool = true) {
        self.categoryID = categoryID
        self.label = label
        self.path = path
        self.kind = kind
        self.bytes = bytes
        self.identity = identity
        self.bundleID = bundleID
        self.mustBeClosed = mustBeClosed
        self.isMeasurable = isMeasurable
    }

    public var homeRelativePath: String {
        let home = Paths.home.standardizedFileURL.path
        if path.hasPrefix(home + "/") { return "~" + path.dropFirst(home.count) }
        return path
    }
}

/// How a rule expands into concrete targets.
public enum ScanRule: @unchecked Sendable {
    /// The literal directory itself is the target.
    case directory(path: String, label: String, category: CleanCategory,
                   minAgeDays: Int?, risk: Risk, mustBeClosed: String?)

    /// Every direct child of a directory.
    case children(of: String, label: String, category: CleanCategory,
                  minAgeDays: Int?, risk: Risk, mustBeClosed: String?,
                  keepNames: Set<String>)

    /// Files inside a directory matching a predicate on the file extension and age.
    case files(in: String, extensions: [String], label: String,
               category: CleanCategory, minAgeDays: Int, risk: Risk,
               mustBeClosed: String?)

    /// Every direct child of every directory matching a glob, one level deep.
    /// e.g. `~/Library/Containers/*/Data/Library/Caches/*`
    case glob(depth: Int, pattern: String, label: String,
              category: CleanCategory, minAgeDays: Int?, risk: Risk,
              mustBeClosed: String?)

    var category: CleanCategory {
        switch self {
        case .directory(_, _, let c, _, _, _): return c
        case .children(_, _, let c, _, _, _, _): return c
        case .files(_, _, _, let c, _, _, _): return c
        case .glob(_, _, _, let c, _, _, _): return c
        }
    }

    public var ruleLabel: String {
        switch self {
        case .directory(_, let l, _, _, _, _): return l
        case .children(_, let l, _, _, _, _, _): return l
        case .files(_, _, let l, _, _, _, _): return l
        case .glob(_, _, let l, _, _, _, _): return l
        }
    }

    public var risk: Risk {
        switch self {
        case .directory(_, _, _, _, let r, _): return r
        case .children(_, _, _, _, let r, _, _): return r
        case .files(_, _, _, _, _, let r, _): return r
        case .glob(_, _, _, _, _, let r, _): return r
        }
    }
}

/// Expand `*` and `?` against a directory without shelling out.
enum Glob {
    /// Immediate children of `base` whose names match `pattern`.
    static func children(of base: URL, pattern: String) -> [URL] {
        guard let names = try? FileManager.default.contentsOfDirectory(
            atPath: base.path) else { return [] }
        return names.compactMap { name -> URL? in
            guard matches(name: name, pattern: pattern) else { return nil }
            return base.appendingPathComponent(name)
        }
    }

    /// `**` walks up to `maxDepth` extra levels below the matched directory.
    static func descendants(of base: URL, maxExtraDepth: Int) -> [URL] {
        guard let enumerator = FileManager.default.enumerator(
            at: base,
            includingPropertiesForKeys: [.isRegularFileKey, .isDirectoryKey],
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else { return [] }

        var results: [URL] = [base]
        let baseDepth = base.pathComponents.count
        while let next = enumerator.nextObject() as? URL {
            guard next.pathComponents.count - baseDepth <= maxExtraDepth else {
                enumerator.skipDescendants()
                continue
            }
            results.append(next)
        }
        return results
    }

    static func matches(name: String, pattern: String) -> Bool {
        let nameChars = Array(name)
        let patternChars = Array(pattern)
        return match(nameChars, 0, patternChars, 0)
    }

    private static func match(_ s: [Character], _ i: Int, _ p: [Character], _ j: Int) -> Bool {
        var i = i, j = j
        while j < p.count {
            if p[j] == "*" {
                // Collapse consecutive stars, then try every split point.
                while j < p.count && p[j] == "*" { j += 1 }
                if j == p.count { return true }
                var k = i
                while k <= s.count {
                    if match(s, k, p, j) { return true }
                    k += 1
                }
                return false
            }
            if i >= s.count { return false }
            if p[j] == "?" || Character(p[j].lowercased()) == Character(s[i].lowercased()) {
                i += 1; j += 1
                continue
            }
            return false
        }
        return i == s.count
    }
}