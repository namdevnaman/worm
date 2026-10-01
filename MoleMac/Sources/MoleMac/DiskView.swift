import MoleCore
import SwiftUI

/// Readable Disk screen.
///
/// Two problems fixed here: the text was set at 10–13pt with low-contrast grey
/// on a light surface, which is unreadable at 1x and poor on any display; and
/// the big-folder and large-file lists had no hierarchy, so a 40-row list of
/// equal-weight rows gave the eye nowhere to land.
///
/// Sizes are now the loudest element on each row, labels are full-size, and
/// secondary detail drops to a muted but legible grey.
struct DiskView: View {
    @EnvironmentObject var store: AppStore
    @StateObject private var roots = Box<[FolderSize]>([])
    @StateObject private var largeFiles = Box<[LargeFile]>([])
    @StateObject private var isScanning = Box(false)
    @StateObject private var minimumSize = Box(Int64(500 * 1024 * 1024))

    struct FolderSize: Identifiable {
        let id = UUID()
        let url: URL
        let bytes: Int64
    }

    struct LargeFile: Identifiable {
        let id = UUID()
        let url: URL
        let bytes: Int64
        let modified: Date
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                gauge
                rootFolders
                largeFilesList
            }
            .padding(20)
        }
        .background(Theme.background)
        .task { if roots.value.isEmpty { scan() } }
    }

    // MARK: Volume gauge

    @ViewBuilder
    private var gauge: some View {
        if let snapshot = store.metrics {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(ByteFormat.compact(snapshot.disk.usedBytes))
                            .font(.system(size: 32, weight: .semibold, design: .rounded))
                            .foregroundStyle(Theme.ink)
                            .monospacedDigit()
                        Text("used of \(ByteFormat.compact(snapshot.disk.totalBytes))")
                            .font(.system(size: 13))
                            .foregroundStyle(Theme.inkSecondary)
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 2) {
                        Text(ByteFormat.compact(snapshot.disk.freeBytes))
                            .font(.system(size: 20, weight: .medium, design: .rounded))
                            .foregroundStyle(Theme.accent)
                            .monospacedDigit()
                        Text("available")
                            .font(.system(size: 11))
                            .foregroundStyle(Theme.inkSecondary)
                    }
                }

                // APFS and the system volume share space, so this reports against
                // the volume that actually holds user data.
                ProportionBar(fraction: snapshot.disk.usedFraction,
                              color: gaugeColor(snapshot.disk.usedFraction),
                              height: 10)

                HStack {
                    Text(String(format: "%.0f%% used", snapshot.disk.usedFraction * 100))
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Theme.inkSecondary)
                        .monospacedDigit()
                    Spacer()
                    Text(gaugeNote(snapshot.disk.usedFraction))
                        .font(.system(size: 12))
                        .foregroundStyle(gaugeColor(snapshot.disk.usedFraction))
                }
            }
            .padding(16)
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: Theme.radiusLarge,
                                                            style: .continuous))
        } else {
            ProgressView()
                .controlSize(.small)
                .frame(maxWidth: .infinity)
                .padding(20)
        }
    }

    private func gaugeColor(_ fraction: Double) -> Color {
        if fraction > 0.92 { return Theme.danger }
        if fraction > 0.85 { return Theme.warn }
        return Theme.accent
    }

    private func gaugeNote(_ fraction: Double) -> String {
        if fraction > 0.92 { return "macOS needs working space to swap and update" }
        if fraction > 0.85 { return "cleaning now keeps macOS responsive" }
        return "healthy"
    }

    // MARK: Root folders

    private var rootFolders: some View {
        section("Biggest Folders",
                subtitle: "One level into your home folder. Click a row to reveal it in Finder.") {
            if isScanning.value {
                placeholder("Measuring your home folder…")
            } else if roots.value.isEmpty {
                placeholder("Nothing large enough to list.")
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(roots.value.enumerated()), id: \.element.id) { index, folder in
                        Button {
                            store.revealInFinder(folder.url.path)
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: "folder.fill")
                                    .font(.system(size: 13))
                                    .foregroundStyle(Theme.accent)

                                VStack(alignment: .leading, spacing: 1) {
                                    Text(folder.url.lastPathComponent)
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundStyle(Theme.ink)
                                    Text(folder.url.path)
                                        .font(.system(size: 11))
                                        .foregroundStyle(Theme.inkTertiary)
                                        .lineLimit(1)
                                        .truncationMode(.head)
                                }

                                Spacer(minLength: 10)

                                // Size is the decision-relevant number, so it is
                                // the largest text on the row.
                                Text(ByteFormat.compact(folder.bytes))
                                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                                    .foregroundStyle(Theme.ink)
                                    .monospacedDigit()
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 9)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .contextMenu {
                            Button("Reveal in Finder") { store.revealInFinder(folder.url.path) }
                            Button("Open") { store.openInFinder(folder.url.path) }
                        }

                        if index < roots.value.count - 1 {
                            Divider2().padding(.leading, 40)
                        }
                    }
                }
            }
        }
    }

    // MARK: Large files

    private var largeFilesList: some View {
        section("Large Files",
                subtitle: "Read-only. Nothing here is deleted from this screen.") {
            Picker("Minimum size", selection: minimumSize.binding) {
                Text("100 MB").tag(Int64(100 * 1024 * 1024))
                Text("500 MB").tag(Int64(500 * 1024 * 1024))
                Text("1 GB").tag(Int64(1024 * 1024 * 1024))
                Text("5 GB").tag(Int64(5 * 1024 * 1024 * 1024))
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .padding(.horizontal, 14)
            .padding(.bottom, 10)
            .onChange(of: minimumSize.value) { _, _ in scan() }

            if largeFiles.value.isEmpty {
                placeholder(isScanning.value
                            ? "Looking for large files…"
                            : "No files above that size outside your caches.")
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(largeFiles.value.prefix(40).enumerated()),
                            id: \.element.id) { index, file in
                        Button {
                            store.revealInFinder(file.url.path)
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: "doc.fill")
                                    .font(.system(size: 12))
                                    .foregroundStyle(Theme.inkTertiary)

                                VStack(alignment: .leading, spacing: 1) {
                                    Text(file.url.lastPathComponent)
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundStyle(Theme.ink)
                                        .lineLimit(1)
                                        .truncationMode(.middle)
                                    Text(file.url.deletingLastPathComponent().path)
                                        .font(.system(size: 11))
                                        .foregroundStyle(Theme.inkTertiary)
                                        .lineLimit(1)
                                        .truncationMode(.head)
                                }

                                Spacer(minLength: 10)

                                VStack(alignment: .trailing, spacing: 1) {
                                    Text(ByteFormat.compact(file.bytes))
                                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                                        .foregroundStyle(Theme.ink)
                                        .monospacedDigit()
                                    Text(file.modified, style: .relative)
                                        .font(.system(size: 11))
                                        .foregroundStyle(Theme.inkTertiary)
                                }
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .contextMenu {
                            Button("Reveal in Finder") { store.revealInFinder(file.url.path) }
                            Button("Open") { store.openInFinder(file.url.path) }
                        }

                        if index < min(largeFiles.value.count, 40) - 1 {
                            Divider2().padding(.leading, 40)
                        }
                    }
                }
            }
        }
    }

    // MARK: Shared pieces

    private func section<Content: View>(_ title: String, subtitle: String,
                                       @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Theme.ink)
                Text(subtitle)
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.inkSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            content()
        }
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: Theme.radiusLarge,
                                                        style: .continuous))
    }

    private func placeholder(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 12))
            .foregroundStyle(Theme.inkTertiary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
    }

    // MARK: Scanning

    private func scan() {
        isScanning.value = true
        let minimum = minimumSize.value
        Task.detached(priority: .utility) {
            var folders: [FolderSize] = []
            let home = Paths.home
            let names = (try? FileManager.default.contentsOfDirectory(atPath: home.path)) ?? []
            for name in names {
                let url = home.appendingPathComponent(name)
                var isDir: ObjCBool = false
                guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir),
                      isDir.boolValue else { continue }
                // Hidden folders are configuration, not disk usage to browse,
                // with the exception of `.cache`, which is frequently huge.
                if name.hasPrefix(".") && name != ".cache" { continue }
                folders.append(FolderSize(url: url,
                                          bytes: SizeMeasurer.measure(url.path, timeout: 3)))
            }
            folders.sort { $0.bytes > $1.bytes }

            let files = DiskView.findLargeFiles(in: home, minimum: minimum)
            await MainActor.run {
                self.roots.value = Array(folders.prefix(14))
                self.largeFiles.value = files
                self.isScanning.value = false
            }
        }
    }

    /// Walk the home folder for files above `minimum`. Nonisolated because the
    /// scan runs off the main actor; it touches only value types.
    nonisolated private static func findLargeFiles(in root: URL, minimum: Int64) -> [LargeFile] {
        let skipRoots = ["Library/Caches", "Library/Logs", ".Trash", ".cache",
                         "Library/Developer/Xcode/DerivedData", "node_modules"]
        var results: [LargeFile] = []
        let deadline = Date().addingTimeInterval(20)

        guard let enumerator = FileManager.default.enumerator(
            at: root,
            includingPropertiesForKeys: [.isRegularFileKey, .fileSizeKey,
                                         .contentModificationDateKey],
            options: [.skipsHiddenFiles]
        ) else { return [] }

        while let next = enumerator.nextObject() as? URL {
            if Date() > deadline { break }
            let path = next.path
            // Skip whole app bundles: their internals are not "large files" a
            // user would recognise, and walking them costs seconds.
            if next.pathExtension == "app" {
                enumerator.skipDescendants()
                continue
            }
            if skipRoots.contains(where: { path.contains("/\($0)/") || path.hasSuffix("/\($0)") }) {
                enumerator.skipDescendants()
                continue
            }
            guard let values = try? next.resourceValues(forKeys: [
                .isRegularFileKey, .fileSizeKey, .contentModificationDateKey
            ]), values.isRegularFile == true else { continue }
            let size = Int64(values.fileSize ?? 0)
            if size >= minimum {
                results.append(LargeFile(url: next, bytes: size,
                                         modified: values.contentModificationDate ?? .distantPast))
            }
        }
        return results.sorted { $0.bytes > $1.bytes }
    }
}