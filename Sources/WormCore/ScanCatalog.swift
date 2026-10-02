import Foundation

/// The scan catalog. Ported from Mole's `lib/clean/*` with two changes:
///
/// - Every rule carries a `Risk`, which the UI uses to decide the default
///   selection. Regenerable caches default on; re-download targets default on
///   but show a badge; user data defaults off and cannot be selected without an
///   explicit per-item opt-in.
/// - Anything Mole only *reports* on (Time Machine local snapshots, PowerLog
///   size, Docker review rows) is surfaced read-only rather than as a target.
public enum ScanCatalog {

    public static let tempFileAgeDays = 7
    public static let logAgeDays = 7
    public static let crashReportAgeDays = 7
    public static let savedStateAgeDays = 30
    public static let orphanAgeDays = 30
    public static let dotdirOrphanAgeDays = 60
    public static let mailAgeDays = 30
    public static let handoffPasteboardAgeMinutes = 60
    public static let gpuCacheAgeDays = 1

    public static func rules(for category: CleanCategory) -> [ScanRule] {
        switch category {
        case .userEssentials: return userEssentials
        case .appCaches: return appCaches
        case .browsers: return browsers
        case .cloudOffice: return cloudOffice
        case .developerTools: return developerTools
        case .aiTools: return aiTools
        case .appsUtilities: return appsUtilities
        case .virtualization: return virtualization
        case .applicationSupport: return applicationSupport
        case .appLeftovers: return appLeftovers
        case .deviceFirmware: return deviceFirmware
        case .logs: return logs
        case .systemCaches: return systemCaches
        case .misc: return misc
        case .trash: return trash
        case .largeFiles: return []
        }
    }

    // MARK: - User essentials

    /// Logs, crash reports, Trash and per-user state. The blanket
    /// `~/Library/Caches/*` sweep lives in App Caches instead, because that is
    /// where a user looks for it.
    static let userEssentials: [ScanRule] = [
        .directory(path: "~/Library/Application Support/CrashReporter",
                   label: "Crash reporter reports", category: .userEssentials,
                   minAgeDays: crashReportAgeDays, risk: .regenerable, mustBeClosed: nil),

        .directory(path: "~/Library/Containers/com.apple.mail/Data/Library/Mail Downloads",
                   label: "Mail attachments", category: .userEssentials,
                   minAgeDays: mailAgeDays, risk: .reDownload, mustBeClosed: "Mail"),

        .directory(path: "~/Library/Messages/StickerCache",
                   label: "Messages sticker cache", category: .userEssentials,
                   minAgeDays: nil, risk: .reDownload, mustBeClosed: "Messages"),

        .directory(path: "~/Library/Messages/Caches/Previews/Attachments",
                   label: "Messages preview attachments", category: .userEssentials,
                   minAgeDays: nil, risk: .reDownload, mustBeClosed: "Messages"),

        .directory(path: "~/Library/Group Containers/group.com.apple.coreservices.useractivityd/shared-pasteboard",
                   label: "Handoff clipboard cache", category: .userEssentials,
                   minAgeDays: nil, risk: .regenerable, mustBeClosed: nil),
    ]

    /// DENO_DIR's leaf name, so the blanket cache sweep skips it.
    static func denoDirLeaf() -> Set<String> {
        let configured = ProcessInfo.processInfo.environment["DENO_DIR"]
        if let configured, !configured.isEmpty {
            return [URL(fileURLWithPath: configured).lastPathComponent]
        }
        return ["deno"]
    }

    // MARK: - App caches

    static let appCaches: [ScanRule] = [
        // The blanket per-user cache sweep, minus DENO_DIR which is review-only
        // because the owner command removes the whole root including the
        // downloaded runtime payloads.
        .children(of: "~/Library/Caches", label: "App cache", category: .appCaches,
                  minAgeDays: nil, risk: .regenerable, mustBeClosed: nil,
                  keepNames: denoDirLeaf()),

        // Per-app container caches and logs. These are where most of a real
        // machine's reclaimable bytes actually live, because sandboxed apps
        // never write to ~/Library/Caches.
        .glob(depth: 1, pattern: "~/Library/Containers/*/Data/Library/Caches/*",
              label: "App container cache", category: .appCaches,
              minAgeDays: nil, risk: .regenerable, mustBeClosed: nil),

        .glob(depth: 1, pattern: "~/Library/Containers/*/Data/Library/Logs/*",
              label: "App container log", category: .appCaches,
              minAgeDays: logAgeDays, risk: .regenerable, mustBeClosed: nil),

        .glob(depth: 1, pattern: "~/Library/Containers/*/Data/tmp/*",
              label: "App container temporary file", category: .appCaches,
              minAgeDays: tempFileAgeDays, risk: .regenerable, mustBeClosed: nil),

        .children(of: "~/Library/Saved Application State",
                  label: "Saved application states", category: .appCaches,
                  minAgeDays: savedStateAgeDays, risk: .regenerable, mustBeClosed: nil,
                  keepNames: []),

        .directory(path: "~/Library/Caches/com.apple.photoanalysisd",
                   label: "Photo analysis cache", category: .appCaches,
                   minAgeDays: nil, risk: .regenerable, mustBeClosed: "Photos"),

        .directory(path: "~/Library/Caches/com.apple.akd",
                   label: "Apple ID cache", category: .appCaches,
                   minAgeDays: nil, risk: .regenerable, mustBeClosed: nil),

        .directory(path: "~/Library/Caches/com.apple.WebKit.Networking",
                   label: "WebKit network cache", category: .appCaches,
                   minAgeDays: nil, risk: .regenerable, mustBeClosed: nil),

        .directory(path: "~/Library/Caches/com.apple.QuickLook.thumbnailcache",
                   label: "QuickLook thumbnails", category: .appCaches,
                   minAgeDays: nil, risk: .regenerable, mustBeClosed: nil),

        .directory(path: "~/Library/Caches/Quick Look",
                   label: "QuickLook cache", category: .appCaches,
                   minAgeDays: nil, risk: .regenerable, mustBeClosed: nil),

        .directory(path: "~/Library/Caches/com.apple.iconservices.store",
                   label: "Icon services cache", category: .appCaches,
                   minAgeDays: nil, risk: .regenerable, mustBeClosed: nil),

        .directory(path: "~/Library/IdentityCaches",
                   label: "Identity caches", category: .appCaches,
                   minAgeDays: nil, risk: .regenerable, mustBeClosed: nil),

        .directory(path: "~/Library/Suggestions",
                   label: "Siri suggestions cache", category: .appCaches,
                   minAgeDays: nil, risk: .regenerable, mustBeClosed: nil),

        // Sandboxed system agents.
        .glob(depth: 2, pattern: "~/Library/Containers/com.apple.*/Data/Library/Caches/*",
              label: "Sandboxed app cache", category: .appCaches,
              minAgeDays: nil, risk: .regenerable, mustBeClosed: nil),

        .glob(depth: 2, pattern: "~/Library/Containers/com.apple.*/Data/tmp/*",
              label: "Sandboxed temporary file", category: .appCaches,
              minAgeDays: nil, risk: .regenerable, mustBeClosed: nil),
    ]

    // MARK: - Browsers

    static let browsers: [ScanRule] = [
        .children(of: "~/Library/Caches/Google/Chrome",
                  label: "Chrome cache", category: .browsers,
                  minAgeDays: nil, risk: .regenerable, mustBeClosed: "Google Chrome",
                  keepNames: []),

        .glob(depth: 3, pattern: "~/Library/Application Support/Google/Chrome/*/Service Worker/CacheStorage",
              label: "Chrome service worker cache", category: .browsers,
              minAgeDays: nil, risk: .reDownload, mustBeClosed: "Google Chrome"),

        .glob(depth: 2, pattern: "~/Library/Application Support/Google/Chrome/*/*Cache",
              label: "Chrome profile cache", category: .browsers,
              minAgeDays: nil, risk: .regenerable, mustBeClosed: "Google Chrome"),

        .children(of: "~/Library/Caches/com.microsoft.edgemac",
                  label: "Edge cache", category: .browsers,
                  minAgeDays: nil, risk: .regenerable, mustBeClosed: "Microsoft Edge",
                  keepNames: []),

        .glob(depth: 2, pattern: "~/Library/Application Support/Microsoft Edge/*/*Cache",
              label: "Edge profile cache", category: .browsers,
              minAgeDays: nil, risk: .regenerable, mustBeClosed: "Microsoft Edge"),

        .children(of: "~/Library/Caches/BraveSoftware/Brave-Browser",
                  label: "Brave cache", category: .browsers,
                  minAgeDays: nil, risk: .regenerable, mustBeClosed: "Brave Browser",
                  keepNames: []),

        .glob(depth: 2, pattern: "~/Library/Application Support/BraveSoftware/Brave-Browser/*/*Cache",
              label: "Brave profile cache", category: .browsers,
              minAgeDays: nil, risk: .regenerable, mustBeClosed: "Brave Browser"),

        .children(of: "~/Library/Caches/Firefox",
                  label: "Firefox cache", category: .browsers,
                  minAgeDays: nil, risk: .regenerable, mustBeClosed: "Firefox",
                  keepNames: []),

        .glob(depth: 3, pattern: "~/Library/Application Support/Firefox/Profiles/*/cache2",
              label: "Firefox profile cache", category: .browsers,
              minAgeDays: nil, risk: .regenerable, mustBeClosed: "Firefox"),

        .children(of: "~/Library/Caches/com.operasoftware.Opera",
                  label: "Opera cache", category: .browsers,
                  minAgeDays: nil, risk: .regenerable, mustBeClosed: "Opera",
                  keepNames: []),

        .children(of: "~/Library/Caches/Comet",
                  label: "Comet cache", category: .browsers,
                  minAgeDays: nil, risk: .regenerable, mustBeClosed: "Comet",
                  keepNames: []),

        .children(of: "~/Library/Caches/company.thebrowser.Browser",
                  label: "Arc cache", category: .browsers,
                  minAgeDays: nil, risk: .regenerable, mustBeClosed: "Arc",
                  keepNames: []),

        .glob(depth: 3, pattern: "~/Library/Application Support/Arc/User Data/*/*Cache",
              label: "Arc profile cache", category: .browsers,
              minAgeDays: nil, risk: .regenerable, mustBeClosed: "Arc"),

        .children(of: "~/Library/Caches/com.vivaldi.Vivaldi",
                  label: "Vivaldi cache", category: .browsers,
                  minAgeDays: nil, risk: .regenerable, mustBeClosed: "Vivaldi",
                  keepNames: []),

        .children(of: "~/Library/Caches/net.imput.helium",
                  label: "Helium cache", category: .browsers,
                  minAgeDays: nil, risk: .regenerable, mustBeClosed: "Helium",
                  keepNames: []),

        .children(of: "~/Library/Caches/Yandex/YandexBrowser",
                  label: "Yandex cache", category: .browsers,
                  minAgeDays: nil, risk: .regenerable, mustBeClosed: "Yandex Browser",
                  keepNames: []),

        .children(of: "~/Library/Caches/com.kagi.kagimacOS",
                  label: "Kagi cache", category: .browsers,
                  minAgeDays: nil, risk: .regenerable, mustBeClosed: "Kagi",
                  keepNames: []),

        .children(of: "~/Library/Caches/Dia/User Data",
                  label: "Dia cache", category: .browsers,
                  minAgeDays: nil, risk: .regenerable, mustBeClosed: "Dia",
                  keepNames: []),
    ]

    // MARK: - Cloud & Office

    static let cloudOffice: [ScanRule] = [
        .children(of: "~/Library/Caches/com.dropbox.client",
                  label: "Dropbox cache", category: .cloudOffice,
                  minAgeDays: nil, risk: .regenerable, mustBeClosed: "Dropbox",
                  keepNames: []),
        .directory(path: "~/Library/Caches/com.dropbox.dropbox",
                   label: "Dropbox cache", category: .cloudOffice,
                   minAgeDays: nil, risk: .regenerable, mustBeClosed: "Dropbox"),
        .directory(path: "~/Library/Caches/com.google.GoogleDrive",
                   label: "Google Drive cache", category: .cloudOffice,
                   minAgeDays: nil, risk: .regenerable, mustBeClosed: "Google Drive"),
        .directory(path: "~/Library/Caches/com.microsoft.OneDrive",
                   label: "OneDrive cache", category: .cloudOffice,
                   minAgeDays: nil, risk: .regenerable, mustBeClosed: "OneDrive"),
        .directory(path: "~/Library/Caches/com.box.desktop",
                   label: "Box cache", category: .cloudOffice,
                   minAgeDays: nil, risk: .regenerable, mustBeClosed: "Box"),
        .directory(path: "~/Library/Caches/com.baidu.netdisk",
                   label: "Baidu Netdisk cache", category: .cloudOffice,
                   minAgeDays: nil, risk: .regenerable, mustBeClosed: "BaiduNetdisk"),

        .glob(depth: 2, pattern: "~/Library/Containers/com.microsoft.Word/Data/Library/Caches/*",
              label: "Word cache", category: .cloudOffice,
              minAgeDays: nil, risk: .regenerable, mustBeClosed: "Microsoft Word"),
        .glob(depth: 2, pattern: "~/Library/Containers/com.microsoft.Excel/Data/Library/Caches/*",
              label: "Excel cache", category: .cloudOffice,
              minAgeDays: nil, risk: .regenerable, mustBeClosed: "Microsoft Excel"),
        .glob(depth: 2, pattern: "~/Library/Containers/com.microsoft.Powerpoint/Data/Library/Caches/*",
              label: "PowerPoint cache", category: .cloudOffice,
              minAgeDays: nil, risk: .regenerable, mustBeClosed: "Microsoft PowerPoint"),
        .directory(path: "~/Library/Caches/com.microsoft.Outlook",
                   label: "Outlook cache", category: .cloudOffice,
                   minAgeDays: nil, risk: .regenerable, mustBeClosed: "Microsoft Outlook"),
        .children(of: "~/Library/Caches/com.apple.iWork",
                  label: "iWork cache", category: .cloudOffice,
                  minAgeDays: nil, risk: .regenerable, mustBeClosed: nil,
                  keepNames: []),
        .directory(path: "~/Library/Caches/org.mozilla.thunderbird",
                   label: "Thunderbird cache", category: .cloudOffice,
                   minAgeDays: nil, risk: .regenerable, mustBeClosed: "Thunderbird"),
        .directory(path: "~/Library/Caches/com.kingsoft.wpsoffice.mac",
                   label: "WPS Office cache", category: .cloudOffice,
                   minAgeDays: nil, risk: .regenerable, mustBeClosed: "wpsoffice"),
    ]

    // MARK: - Developer tools

    static let developerTools: [ScanRule] = [
        // Node. npm's `_cacache` is a content-addressed tarball store that
        // `npm ci` rebuilds from the registry, and `_logs` is pure diagnostics.
        .children(of: "~/.npm/_cacache", label: "npm cache", category: .developerTools,
                  minAgeDays: nil, risk: .reDownload, mustBeClosed: nil, keepNames: []),
        .children(of: "~/.npm/_logs", label: "npm log", category: .developerTools,
                  minAgeDays: logAgeDays, risk: .regenerable, mustBeClosed: nil,
                  keepNames: []),
        .children(of: "~/.tnpm/_cacache", label: "tnpm cache", category: .developerTools,
                  minAgeDays: nil, risk: .reDownload, mustBeClosed: nil, keepNames: []),
        .children(of: "~/.tnpm/_logs", label: "tnpm log", category: .developerTools,
                  minAgeDays: logAgeDays, risk: .regenerable, mustBeClosed: nil,
                  keepNames: []),
        .children(of: "~/Library/Caches/Yarn", label: "Yarn cache", category: .developerTools,
                  minAgeDays: nil, risk: .reDownload, mustBeClosed: nil, keepNames: []),
        .children(of: "~/Library/Caches/Homebrew/downloads",
                  label: "Homebrew downloads", category: .developerTools,
                  minAgeDays: nil, risk: .reDownload, mustBeClosed: "brew",
                  keepNames: ["Cask", "api"]),
        .children(of: "~/.cache/corepack", label: "Corepack cache", category: .developerTools,
                  minAgeDays: nil, risk: .reDownload, mustBeClosed: nil, keepNames: []),
        .children(of: "~/.cache/node-gyp", label: "node-gyp cache", category: .developerTools,
                  minAgeDays: nil, risk: .reDownload, mustBeClosed: nil, keepNames: []),
        .children(of: "~/.cache/yarn", label: "Yarn v2 cache", category: .developerTools,
                  minAgeDays: nil, risk: .reDownload, mustBeClosed: nil, keepNames: []),

        // Python
        .children(of: "~/.cache/pip", label: "pip cache", category: .developerTools,
                  minAgeDays: nil, risk: .reDownload, mustBeClosed: nil, keepNames: []),
        .children(of: "~/.cache/uv", label: "uv cache", category: .developerTools,
                  minAgeDays: nil, risk: .reDownload, mustBeClosed: nil, keepNames: []),
        .children(of: "~/.cache/poetry", label: "Poetry cache", category: .developerTools,
                  minAgeDays: nil, risk: .reDownload, mustBeClosed: nil, keepNames: []),
        .children(of: "~/Library/Caches/pypoetry", label: "Poetry artifacts", category: .developerTools,
                  minAgeDays: nil, risk: .reDownload, mustBeClosed: nil, keepNames: []),
        .children(of: "~/.cache/ruff", label: "Ruff cache", category: .developerTools,
                  minAgeDays: nil, risk: .regenerable, mustBeClosed: nil, keepNames: []),
        .children(of: "~/.cache/mypy", label: "mypy cache", category: .developerTools,
                  minAgeDays: nil, risk: .regenerable, mustBeClosed: nil, keepNames: []),
        .children(of: "~/.pytest_cache", label: "pytest cache", category: .developerTools,
                  minAgeDays: nil, risk: .regenerable, mustBeClosed: nil, keepNames: []),
        .children(of: "~/.jupyter/runtime", label: "Jupyter runtime", category: .developerTools,
                  minAgeDays: nil, risk: .regenerable, mustBeClosed: nil, keepNames: []),
        .children(of: "~/.pyenv/cache", label: "pyenv cache", category: .developerTools,
                  minAgeDays: nil, risk: .reDownload, mustBeClosed: nil, keepNames: []),
        .directory(path: "~/Library/Application Support/pyinstaller/bincache",
                   label: "PyInstaller bincache", category: .developerTools,
                   minAgeDays: nil, risk: .regenerable, mustBeClosed: nil),

        // Go. registry/src and the module cache stay out: `go clean -modcache`
        // is a maintenance command, not a blanket delete.
        .children(of: "~/Library/Caches/go-build", label: "Go build cache",
                  category: .developerTools, minAgeDays: nil, risk: .regenerable,
                  mustBeClosed: nil, keepNames: []),
        .children(of: "~/.cache/go-build", label: "Go build cache",
                  category: .developerTools, minAgeDays: nil, risk: .regenerable,
                  mustBeClosed: nil, keepNames: []),

        // Rust: only the compressed registry cache. sources, index, git,
        // toolchains and bin are deliberately absent.
        .children(of: "~/.cargo/registry/cache", label: "Cargo registry cache",
                  category: .developerTools, minAgeDays: nil, risk: .reDownload,
                  mustBeClosed: nil, keepNames: []),
        .children(of: "~/.rustup/downloads", label: "Rust toolchain downloads",
                  category: .developerTools, minAgeDays: nil, risk: .reDownload,
                  mustBeClosed: nil, keepNames: []),

        // Ruby, Perl, PHP, Java, JS tooling
        .children(of: "~/.rbenv/cache", label: "rbenv cache", category: .developerTools,
                  minAgeDays: nil, risk: .reDownload, mustBeClosed: nil, keepNames: []),
        .children(of: "~/.gem/specs", label: "RubyGems specs", category: .developerTools,
                  minAgeDays: nil, risk: .reDownload, mustBeClosed: nil, keepNames: []),
        .children(of: "~/.bundle/cache", label: "Bundler cache", category: .developerTools,
                  minAgeDays: nil, risk: .reDownload, mustBeClosed: nil, keepNames: []),
        .children(of: "~/.cpan/build", label: "CPAN build cache", category: .developerTools,
                  minAgeDays: nil, risk: .reDownload, mustBeClosed: nil, keepNames: []),
        .children(of: "~/.composer/cache", label: "Composer cache", category: .developerTools,
                  minAgeDays: nil, risk: .reDownload, mustBeClosed: nil, keepNames: []),
        .children(of: "~/Library/Caches/composer", label: "Composer cache", category: .developerTools,
                  minAgeDays: nil, risk: .reDownload, mustBeClosed: nil, keepNames: []),
        .children(of: "~/.gradle/caches/build-cache-1", label: "Gradle build cache",
                  category: .developerTools, minAgeDays: nil, risk: .reDownload,
                  mustBeClosed: nil, keepNames: []),
        .children(of: "~/.gradle/notifications", label: "Gradle notifications",
                  category: .developerTools, minAgeDays: nil, risk: .regenerable,
                  mustBeClosed: nil, keepNames: []),
        .children(of: "~/.gradle/daemon", label: "Gradle daemon logs", category: .developerTools,
                  minAgeDays: nil, risk: .regenerable, mustBeClosed: "GradleDaemon", keepNames: []),
        .children(of: "~/.gradle/workers", label: "Gradle workers", category: .developerTools,
                  minAgeDays: nil, risk: .regenerable, mustBeClosed: "GradleDaemon", keepNames: []),

        // Frontend build caches
        .children(of: "~/.cache/typescript", label: "TypeScript cache", category: .developerTools,
                  minAgeDays: nil, risk: .regenerable, mustBeClosed: nil, keepNames: []),
        .children(of: "~/.cache/electron", label: "Electron cache", category: .developerTools,
                  minAgeDays: nil, risk: .regenerable, mustBeClosed: nil, keepNames: []),
        .children(of: "~/.cache/turbo", label: "Turborepo cache", category: .developerTools,
                  minAgeDays: nil, risk: .regenerable, mustBeClosed: nil, keepNames: []),
        .children(of: "~/.cache/vite", label: "Vite cache", category: .developerTools,
                  minAgeDays: nil, risk: .regenerable, mustBeClosed: nil, keepNames: []),
        .children(of: "~/.cache/webpack", label: "webpack cache", category: .developerTools,
                  minAgeDays: nil, risk: .regenerable, mustBeClosed: nil, keepNames: []),
        .children(of: "~/.parcel-cache", label: "Parcel cache", category: .developerTools,
                  minAgeDays: nil, risk: .regenerable, mustBeClosed: nil, keepNames: []),
        .children(of: "~/.cache/eslint", label: "ESLint cache", category: .developerTools,
                  minAgeDays: nil, risk: .regenerable, mustBeClosed: nil, keepNames: []),
        .children(of: "~/.cache/prettier", label: "Prettier cache", category: .developerTools,
                  minAgeDays: nil, risk: .regenerable, mustBeClosed: nil, keepNames: []),
        .children(of: "~/.cache/bazel", label: "Bazel cache", category: .developerTools,
                  minAgeDays: nil, risk: .regenerable, mustBeClosed: nil, keepNames: []),
        .children(of: "~/.cache/zig", label: "Zig cache", category: .developerTools,
                  minAgeDays: nil, risk: .regenerable, mustBeClosed: nil, keepNames: []),
        .children(of: "~/.cache/curl", label: "curl cache", category: .developerTools,
                  minAgeDays: nil, risk: .regenerable, mustBeClosed: nil, keepNames: []),
        .children(of: "~/.cache/wget", label: "wget cache", category: .developerTools,
                  minAgeDays: nil, risk: .regenerable, mustBeClosed: nil, keepNames: []),
        .children(of: "~/.hex/cache", label: "Hex cache", category: .developerTools,
                  minAgeDays: nil, risk: .reDownload, mustBeClosed: nil, keepNames: []),
        .children(of: "~/.opam/download-cache", label: "opam download cache",
                  category: .developerTools, minAgeDays: nil, risk: .reDownload,
                  mustBeClosed: nil, keepNames: []),
        .children(of: "~/.cache/pre-commit", label: "pre-commit cache", category: .developerTools,
                  minAgeDays: nil, risk: .regenerable, mustBeClosed: nil, keepNames: []),
        .children(of: "~/.terraform.d/plugin-cache", label: "Terraform plugin cache",
                  category: .developerTools, minAgeDays: nil, risk: .reDownload,
                  mustBeClosed: nil, keepNames: []),
        .children(of: "~/.kube/cache", label: "kubectl cache", category: .developerTools,
                  minAgeDays: nil, risk: .regenerable, mustBeClosed: nil, keepNames: []),
        .children(of: "~/.aws/cli/cache", label: "AWS CLI cache", category: .developerTools,
                  minAgeDays: nil, risk: .regenerable, mustBeClosed: nil, keepNames: []),

        // Xcode
        .children(of: "~/Library/Developer/Xcode/DerivedData",
                  label: "Xcode derived data", category: .developerTools,
                  minAgeDays: nil, risk: .regenerable, mustBeClosed: nil, keepNames: []),
        .children(of: "~/Library/Developer/CoreSimulator/Caches",
                  label: "Simulator cache", category: .developerTools,
                  minAgeDays: nil, risk: .regenerable, mustBeClosed: "CoreSimulator", keepNames: []),
        .children(of: "~/Library/Developer/XCTestDevices", label: "XCTest device data",
                  category: .developerTools, minAgeDays: nil, risk: .regenerable,
                  mustBeClosed: "XCTRunner", keepNames: []),
        .directory(path: "~/Library/Caches/org.swift.swiftpm",
                   label: "SwiftPM cache", category: .developerTools,
                   minAgeDays: nil, risk: .reDownload, mustBeClosed: "Xcode"),
        .children(of: "~/Library/Caches/com.apple.dt.Xcode",
                  label: "Xcode cache", category: .developerTools,
                  minAgeDays: nil, risk: .regenerable, mustBeClosed: "Xcode", keepNames: []),
        .directory(path: "~/Library/Developer/Xcode/Products",
                   label: "Xcode build products", category: .developerTools,
                   minAgeDays: nil, risk: .regenerable, mustBeClosed: "Xcode"),

        // Editors
        .directory(path: "~/Library/Application Support/Code/logs",
                   label: "VS Code logs", category: .developerTools,
                   minAgeDays: logAgeDays, risk: .regenerable, mustBeClosed: "Code"),
        .directory(path: "~/Library/Application Support/Code/Cache",
                   label: "VS Code cache", category: .developerTools,
                   minAgeDays: nil, risk: .regenerable, mustBeClosed: "Code"),
        .directory(path: "~/Library/Application Support/Code/CachedData",
                   label: "VS Code cached data", category: .developerTools,
                   minAgeDays: nil, risk: .regenerable, mustBeClosed: "Code"),
        .directory(path: "~/Library/Application Support/Cursor/CachedData",
                   label: "Cursor cached data", category: .developerTools,
                   minAgeDays: nil, risk: .regenerable, mustBeClosed: "Cursor"),
        .directory(path: "~/Library/Application Support/Zed/node/cache",
                   label: "Zed cache", category: .developerTools,
                   minAgeDays: nil, risk: .regenerable, mustBeClosed: "Zed"),
        .children(of: "~/Library/Logs/JetBrains", label: "JetBrains logs",
                  category: .developerTools, minAgeDays: logAgeDays, risk: .regenerable,
                  mustBeClosed: nil, keepNames: []),
    ]

    // MARK: - AI tools

    /// Deliberately conservative. AI tools hold conversations, projects,
    /// credentials and local models in the same neighbourhood as their caches,
    /// so only proven rebuildable leaves are targeted.
    static let aiTools: [ScanRule] = [
        .children(of: "~/Library/Caches/com.anthropic.claudefordesktop",
                  label: "Claude Desktop cache", category: .aiTools,
                  minAgeDays: nil, risk: .regenerable, mustBeClosed: "Claude",
                  keepNames: []),
        .glob(depth: 2, pattern: "~/Library/Containers/com.anthropic.claudefordesktop/Data/Library/Caches/*",
              label: "Claude Desktop sandboxed cache", category: .aiTools,
              minAgeDays: nil, risk: .regenerable, mustBeClosed: "Claude"),
        .directory(path: "~/Library/Application Support/Codex/Crashpad/pending",
                   label: "Codex pending crash reports", category: .aiTools,
                   minAgeDays: 30, risk: .regenerable, mustBeClosed: nil),
        .directory(path: "~/Library/Caches/Codex/Default/Partitions/codex-browser-app/Cache",
                   label: "Codex in-app browser cache", category: .aiTools,
                   minAgeDays: nil, risk: .regenerable, mustBeClosed: "Codex"),
        .directory(path: "~/Library/Caches/Codex/Default/Partitions/codex-browser-app/Code Cache",
                   label: "Codex in-app browser code cache", category: .aiTools,
                   minAgeDays: nil, risk: .regenerable, mustBeClosed: "Codex"),
        .children(of: "~/.cache/opencode", label: "OpenCode cache", category: .aiTools,
                  minAgeDays: nil, risk: .regenerable, mustBeClosed: "OpenCode", keepNames: []),
        .children(of: "~/.cache/chrome-devtools-mcp", label: "DevTools MCP cache",
                  category: .aiTools, minAgeDays: nil, risk: .regenerable,
                  mustBeClosed: nil, keepNames: []),
        .children(of: "~/.cache/prisma", label: "Prisma cache", category: .aiTools,
                  minAgeDays: nil, risk: .regenerable, mustBeClosed: nil, keepNames: []),
        .children(of: "~/.cache/huggingface/hub",
                  label: "Hugging Face model cache", category: .aiTools,
                  minAgeDays: nil, risk: .reDownload, mustBeClosed: nil,
                  keepNames: []),  // kept: toolchainState blocks the delete path
        .directory(path: "~/.codex/.tmp/bundled-marketplaces",
                   label: "Codex marketplace staging", category: .aiTools,
                   minAgeDays: 30, risk: .regenerable, mustBeClosed: nil),
        .children(of: "~/.local/share/cursor-agent", label: "Cursor Agent logs",
                  category: .aiTools, minAgeDays: logAgeDays, risk: .regenerable,
                  mustBeClosed: "cursor-agent", keepNames: []),
    ]

    // MARK: - Apps & utilities

    static let appsUtilities: [ScanRule] = [
        .children(of: "~/Library/Caches/com.tinyspeck.slackmacgap",
                  label: "Slack cache", category: .appsUtilities,
                  minAgeDays: nil, risk: .reDownload, mustBeClosed: "Slack", keepNames: []),
        .children(of: "~/Library/Caches/com.hnc.Discord",
                  label: "Discord cache", category: .appsUtilities,
                  minAgeDays: nil, risk: .reDownload, mustBeClosed: "Discord", keepNames: []),
        .children(of: "~/Library/Caches/com.telegram.desktop",
                  label: "Telegram cache", category: .appsUtilities,
                  minAgeDays: nil, risk: .reDownload, mustBeClosed: "Telegram", keepNames: []),
        .children(of: "~/Library/Caches/com.whatsapp",
                  label: "WhatsApp cache", category: .appsUtilities,
                  minAgeDays: nil, risk: .reDownload, mustBeClosed: "WhatsApp", keepNames: []),
        .directory(path: "~/Library/Containers/com.tencent.xinWeChat/Data/Documents/app_data/log",
                   label: "WeChat logs", category: .appsUtilities,
                   minAgeDays: nil, risk: .regenerable, mustBeClosed: "WeChat"),
        .directory(path: "~/Library/Containers/com.tencent.WeWorkMac/Data/Library/Application Support/WXWork/Log",
                   label: "WeCom logs", category: .appsUtilities,
                   minAgeDays: nil, risk: .regenerable, mustBeClosed: "WeCom"),
        .glob(depth: 5, pattern: "~/Library/Application Support/LarkShell/aha/users/*/profile_explorer/Service Worker/CacheStorage",
              label: "Feishu service worker cache", category: .appsUtilities,
              minAgeDays: nil, risk: .reDownload, mustBeClosed: "Feishu"),
        .glob(depth: 3, pattern: "~/Library/Application Support/Notion/Partitions/*/Service Worker/CacheStorage",
              label: "Notion service worker cache", category: .appsUtilities,
              minAgeDays: nil, risk: .reDownload, mustBeClosed: "Notion"),
        .directory(path: "~/Library/Caches/com.spotify.client",
                   label: "Spotify cache", category: .appsUtilities,
                   minAgeDays: nil, risk: .regenerable, mustBeClosed: "Spotify"),
        .directory(path: "~/Library/Caches/com.figma.Desktop",
                   label: "Figma cache", category: .appsUtilities,
                   minAgeDays: nil, risk: .regenerable, mustBeClosed: "Figma"),
        .directory(path: "~/Library/Caches/com.unity3d.unityhub",
                   label: "Unity Hub cache", category: .appsUtilities,
                   minAgeDays: nil, risk: .regenerable, mustBeClosed: "Unity Hub"),
        .directory(path: "~/Library/Caches/Slack",
                   label: "Slack cache", category: .appsUtilities,
                   minAgeDays: nil, risk: .reDownload, mustBeClosed: "Slack"),
        .directory(path: "~/Library/Caches/Notion",
                   label: "Notion cache", category: .appsUtilities,
                   minAgeDays: nil, risk: .reDownload, mustBeClosed: "Notion"),
        .directory(path: "~/Library/Caches/com.mitchellh.ghostty",
                   label: "Ghostty cache", category: .appsUtilities,
                   minAgeDays: nil, risk: .regenerable, mustBeClosed: "Ghostty"),
        .directory(path: "~/Library/Caches/dev.warp.Warp-Stable",
                   label: "Warp cache", category: .appsUtilities,
                   minAgeDays: nil, risk: .regenerable, mustBeClosed: "Warp"),
        .directory(path: "~/Library/Caches/JetBrains",
                   label: "JetBrains cache", category: .appsUtilities,
                   minAgeDays: nil, risk: .regenerable, mustBeClosed: nil),
    ]

    // MARK: - Virtualization

    static let virtualization: [ScanRule] = [
        .directory(path: "~/Library/Caches/com.utmapp.UTM", label: "UTM cache",
                   category: .virtualization, minAgeDays: nil, risk: .regenerable,
                   mustBeClosed: "UTM"),
        .glob(depth: 2, pattern: "~/Library/Containers/com.utmapp.UTM/Data/Library/Caches/*",
              label: "UTM sandboxed cache", category: .virtualization,
              minAgeDays: nil, risk: .regenerable, mustBeClosed: "UTM"),
        .directory(path: "~/Library/Caches/com.vmware.fusion", label: "VMware Fusion cache",
                   category: .virtualization, minAgeDays: nil, risk: .regenerable,
                   mustBeClosed: "VMware Fusion"),
        .glob(depth: 1, pattern: "~/Library/Caches/com.parallels.*",
              label: "Parallels cache", category: .virtualization,
              minAgeDays: nil, risk: .regenerable, mustBeClosed: "Parallels Desktop"),
        .directory(path: "~/.lima", label: "Lima VM data", category: .virtualization,
                   minAgeDays: nil, risk: .reDownload, mustBeClosed: "lima"),
        .children(of: "~/.vagrant.d/tmp", label: "Vagrant temporary files",
                  category: .virtualization, minAgeDays: nil, risk: .regenerable,
                  mustBeClosed: "vagrant", keepNames: []),
    ]

    // MARK: - Application Support caches

    /// The per-app leaf caches Mole looks for inside `~/Library/Application
    /// Support/<app>/`. Exposed as leaf names so the scanner can walk real app
    /// directories rather than a fixed path list.
    public static let applicationSupportLeaves = [
        "Code Cache", "GPUCache", "DawnCache", "GrShaderCache", "GraphiteDawnCache",
        "DawnGraphiteCache", "DawnWebGPUCache", "Crashpad", "Cache", "CachedData",
        "CachedExtensionVSIXs", "logs", "GPUPersistentCache",
        "component_crx_cache", "extensions_crx_cache",
    ]

    static let applicationSupport: [ScanRule] = [
        .children(of: "~/Library/Application Support/CrashReporter",
                  label: "Application support crash reports", category: .applicationSupport,
                  minAgeDays: 30, risk: .regenerable, mustBeClosed: nil, keepNames: []),
    ]

    // MARK: - App leftovers

    static let appLeftovers: [ScanRule] = [
        .children(of: "~/Library/Saved Application State",
                  label: "Orphaned saved state", category: .appLeftovers,
                  minAgeDays: orphanAgeDays, risk: .regenerable, mustBeClosed: nil,
                  keepNames: []),
    ]

    // MARK: - Device firmware

    static let deviceFirmware: [ScanRule] = [
        .files(in: "~/Library/iTunes/iPhone Software Updates", extensions: ["ipsw"],
               label: "iOS firmware image", category: .deviceFirmware,
               minAgeDays: 0, risk: .userData, mustBeClosed: nil),
        .files(in: "~/Library/iTunes/iPad Software Updates", extensions: ["ipsw"],
               label: "iPadOS firmware image", category: .deviceFirmware,
               minAgeDays: 0, risk: .userData, mustBeClosed: nil),
        .files(in: "~/Library/iTunes/iPod Software Updates", extensions: ["ipsw"],
               label: "watchOS firmware image", category: .deviceFirmware,
               minAgeDays: 0, risk: .userData, mustBeClosed: nil),
    ]

    // MARK: - Logs

    static let logs: [ScanRule] = [
        .files(in: "~/Library/Logs", extensions: ["log", "txt", "gz", "asl"],
               label: "User log", category: .logs,
               minAgeDays: logAgeDays, risk: .regenerable, mustBeClosed: nil),
        .children(of: "~/Library/Logs", label: "Log folder", category: .logs,
                  minAgeDays: logAgeDays, risk: .regenerable, mustBeClosed: nil,
                  keepNames: []),
        .children(of: "~/Library/Containers/com.apple.Safari/Data/Library/Logs",
                  label: "Safari log", category: .logs, minAgeDays: logAgeDays,
                  risk: .regenerable, mustBeClosed: nil, keepNames: []),
    ]

    // MARK: - System caches (requires admin)

    static let systemCaches: [ScanRule] = [
        .files(in: "/Library/Logs/DiagnosticReports", extensions: [""],
               label: "System crash report", category: .systemCaches,
               minAgeDays: crashReportAgeDays, risk: .regenerable, mustBeClosed: nil),
        .files(in: "/private/var/log", extensions: ["log", "gz", "asl"],
               label: "System log", category: .systemCaches,
               minAgeDays: logAgeDays, risk: .regenerable, mustBeClosed: nil),
        .files(in: "/Library/Caches", extensions: ["cache", "tmp"],
               label: "System cache file", category: .systemCaches,
               minAgeDays: tempFileAgeDays, risk: .regenerable, mustBeClosed: nil),
    ]

    // MARK: - Misc

    static let misc: [ScanRule] = [
        .children(of: "~/Library/Caches/com.apple.parsecd",
                  label: "Parse cache", category: .misc, minAgeDays: nil,
                  risk: .regenerable, mustBeClosed: nil, keepNames: []),
        .directory(path: "~/Library/Caches/com.apple.python",
                   label: "Python cache", category: .misc, minAgeDays: nil,
                   risk: .regenerable, mustBeClosed: nil),
        .directory(path: "~/Library/Caches/GeoServices",
                   label: "GeoServices cache", category: .misc, minAgeDays: nil,
                   risk: .regenerable, mustBeClosed: "GeoServices"),
        .directory(path: "~/Library/Caches/com.apple.helpd",
                   label: "Help viewer cache", category: .misc, minAgeDays: nil,
                   risk: .regenerable, mustBeClosed: nil),
        .children(of: "~/Library/Caches/Google/AndroidStudio",
                  label: "Android Studio cache", category: .misc, minAgeDays: nil,
                  risk: .regenerable, mustBeClosed: "Android Studio", keepNames: []),
        .children(of: "~/.android/build-cache", label: "Android build cache",
                  category: .misc, minAgeDays: nil, risk: .regenerable,
                  mustBeClosed: nil, keepNames: []),
        .children(of: "~/.android/cache", label: "Android SDK cache",
                  category: .misc, minAgeDays: nil, risk: .regenerable,
                  mustBeClosed: nil, keepNames: []),
    ]

    // MARK: - Trash

    static let trash: [ScanRule] = [
        .children(of: "~/.Trash", label: "Trash item", category: .trash,
                  minAgeDays: nil, risk: .userData, mustBeClosed: nil, keepNames: []),
    ]
}
extension ScanCatalog {
    /// Every directory a rule can produce a target inside.
    ///
    /// Computed from the rules themselves rather than maintained separately.
    /// A glob rule's static parent is included, so
    /// `~/Library/Containers/*/Data/Library/Caches/*` contributes
    /// `~/Library/Containers`, and every path a rule can reach is therefore
    /// inside a cleanable root by construction.
    public static let cleanableRoots: [URL] = {
        var roots: Set<String> = []

        func add(_ expression: String) {
            roots.insert(Paths.expand(expression).standardizedFileURL.path)
        }

        for category in CleanCategory.allCases {
            for rule in rules(for: category) {
                switch rule {
                case .directory(let path, _, _, _, _, _):
                    add(path)
                case .children(let base, _, _, _, _, _, _):
                    add(base)
                case .files(let dir, _, _, _, _, _, _):
                    add(dir)
                case .glob(_, let pattern, _, _, _, _, _):
                    // The literal parent of the wildcard component. A deeper root
                    // is not needed because only one level of the wildcard is
                    // ever expanded.
                    let components = pattern.split(separator: "/").map(String.init)
                    guard let last = components.last,
                          last.contains("*") || last.contains("?"),
                          components.count > 1 else {
                        add(pattern)
                        continue
                    }
                    add("/" + components.dropLast().joined(separator: "/"))
                }
            }
        }
        return roots.map { URL(fileURLWithPath: $0, isDirectory: true) }
            .sorted { $0.path < $1.path }
    }()
}
