import Foundation
import AppKit

/// Software update checker and installer for Worm.
///
/// Checks GitHub Releases or custom update feed API, reports when a newer
/// version is available, provides release notes, download instructions, and
/// offers one-click download or browser opening.
@MainActor
public final class UpdateChecker: ObservableObject {
    public static let shared = UpdateChecker()

    // Configurable repo coordinates
    public static let currentVersion = "1.0.1"
    public static let repoOwner = "namdevnaman"
    public static let repoName = "worm"
    // Release API endpoint
    public static let releasesAPI = URL(string: "https://api.github.com/repos/\(repoOwner)/\(repoName)/releases/latest")!
    public static let releasesWebURL = URL(string: "https://github.com/\(repoOwner)/\(repoName)/releases")!

    public struct ReleaseInfo: Equatable, Sendable {
        public let tagName: String
        public let version: String
        public let name: String
        public let body: String
        public let publishedAt: String
        public let htmlURL: URL
        public let downloadURL: URL?
        public let assetName: String?
        public let assetSize: Int64
        public let instructions: [String]
    }

    public enum Status: Equatable {
        case idle
        case checking
        case upToDate
        case updateAvailable(ReleaseInfo)
        case downloading(progress: Double)
        case downloaded(URL)
        case failed(String)

        public var isChecking: Bool {
            if case .checking = self { return true }
            return false
        }
    }

    @Published public private(set) var status: Status = .idle
    @Published public private(set) var lastChecked: Date?

    private var checkTask: Task<Void, Never>?
    private var downloadTask: Task<Void, Never>?

    public init() {}

    /// Check for updates asynchronously.
    public func checkForUpdates(isUserInitiated: Bool = false) {
        guard !status.isChecking else { return }
        status = .checking

        checkTask?.cancel()
        checkTask = Task { [weak self] in
            do {
                var request = URLRequest(url: Self.releasesAPI)
                request.timeoutInterval = 8
                request.setValue("application/vnd.github.v3+json", forHTTPHeaderField: "Accept")
                request.setValue("Worm/\(Self.currentVersion)", forHTTPHeaderField: "User-Agent")

                let (data, response) = try await URLSession.shared.data(for: request)
                guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                    let code = (response as? HTTPURLResponse)?.statusCode ?? -1
                    await self?.setStatus(.failed("Update server returned status \(code)"))
                    return
                }

                guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let tagName = json["tag_name"] as? String else {
                    await self?.setStatus(.failed("Invalid release response"))
                    return
                }

                let cleanVersion = tagName.trimmingCharacters(in: CharacterSet(charactersIn: "vV "))
                let name = json["name"] as? String ?? "Worm \(tagName)"
                let body = json["body"] as? String ?? ""
                let pub = json["published_at"] as? String ?? ""
                let htmlStr = json["html_url"] as? String ?? ""
                let htmlURL = URL(string: htmlStr) ?? Self.releasesWebURL

                var downloadURL: URL?
                var assetName: String?
                var assetSize: Int64 = 0

                if let assets = json["assets"] as? [[String: Any]] {
                    for asset in assets {
                        if let aName = asset["name"] as? String,
                           aName.hasSuffix(".zip") || aName.hasSuffix(".dmg") || aName.localizedCaseInsensitiveContains("worm") {
                            if let dl = asset["browser_download_url"] as? String, let u = URL(string: dl) {
                                downloadURL = u
                                assetName = aName
                                assetSize = (asset["size"] as? Int64) ?? 0
                                break
                            }
                        }
                    }
                }

                let instructions = [
                    "1. Click 'Download Update' to download the latest archive to your Downloads folder.",
                    "2. Once downloaded, click 'Show in Finder' to locate the file.",
                    "3. Drag 'Worm.app' into your /Applications directory to replace the older version.",
                    "4. Launch Worm from Applications or your Menu Bar."
                ]

                let release = ReleaseInfo(
                    tagName: tagName,
                    version: cleanVersion,
                    name: name,
                    body: body,
                    publishedAt: pub,
                    htmlURL: htmlURL,
                    downloadURL: downloadURL,
                    assetName: assetName,
                    assetSize: assetSize,
                    instructions: instructions
                )

                let hasUpdate = Self.compareVersions(newer: cleanVersion, older: Self.currentVersion)
                if hasUpdate {
                    await self?.setStatus(.updateAvailable(release))
                } else {
                    await self?.setStatus(.upToDate)
                }
                await MainActor.run { self?.lastChecked = Date() }
            } catch {
                if isUserInitiated {
                    await self?.setStatus(.failed("Could not connect to update server."))
                } else {
                    await self?.setStatus(.idle)
                }
            }
        }
    }

    /// Compare semantic versions, e.g. "1.1.0" > "1.0.0" -> true
    public static func compareVersions(newer: String, older: String) -> Bool {
        let v1 = newer.split(separator: ".").compactMap { Int($0) }
        let v2 = older.split(separator: ".").compactMap { Int($0) }

        for i in 0..<max(v1.count, v2.count) {
            let n1 = i < v1.count ? v1[i] : 0
            let n2 = i < v2.count ? v2[i] : 0
            if n1 > n2 { return true }
            if n1 < n2 { return false }
        }
        return false
    }

    private func setStatus(_ newStatus: Status) {
        self.status = newStatus
    }

    /// Open release notes / download page in default browser
    public func openReleasePage() {
        if case .updateAvailable(let rel) = status {
            NSWorkspace.shared.open(rel.htmlURL)
        } else {
            NSWorkspace.shared.open(Self.releasesWebURL)
        }
    }

    /// Download the latest release asset to ~/Downloads
    public func downloadUpdate() {
        guard case .updateAvailable(let rel) = status, let url = rel.downloadURL else {
            openReleasePage()
            return
        }

        status = .downloading(progress: 0.1)
        downloadTask?.cancel()
        downloadTask = Task { [weak self] in
            do {
                let (tempURL, _) = try await URLSession.shared.download(from: url)
                let downloads = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first!
                let filename = rel.assetName ?? url.lastPathComponent
                let destination = downloads.appendingPathComponent(filename)

                if FileManager.default.fileExists(atPath: destination.path) {
                    try? FileManager.default.removeItem(at: destination)
                }
                try FileManager.default.moveItem(at: tempURL, to: destination)

                await MainActor.run {
                    self?.status = .downloaded(destination)
                    NSWorkspace.shared.activateFileViewerSelecting([destination])
                }
            } catch {
                await MainActor.run {
                    self?.status = .failed("Download failed: \(error.localizedDescription)")
                }
            }
        }
    }
}
