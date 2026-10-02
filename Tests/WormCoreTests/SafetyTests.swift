import Testing
import Foundation
@testable import WormCore

/// These tests are the safety contract. Each one asserts that a path a user
/// would never want destroyed is refused, and that a legitimate cache is not.
/// A regression here means data loss, so they fail loudly.
@Suite("Safety policy")
struct SafetyPolicyTests {

    @Test("Personal folders are hard-blocked, and caches inside them too")
    func userDataRoots() {
        let home = Paths.home.path
        let cases = [
            "\(home)/Documents",
            "\(home)/Documents/notes.md",
            "\(home)/Desktop/screenshot.png",
            "\(home)/Downloads/installer.dmg",
            "\(home)/Pictures",
            "\(home)/Movies/project.fcpbundle",
            "\(home)/Music",
            "\(home)/Library/Mobile Documents/com~apple~CloudDocs/Doc",
            "\(home)/Library/CloudStorage/OneDrive/file.docx",
        ]
        for path in cases {
            let verdict = SafetyPolicy.verdict(for: path, probeLiveness: false)
            #expect(verdict.reason == .userDataRoot,
                    "\(path) should be blocked as user data, got \(verdict)")
        }
    }

    @Test("A cache folder inside Documents is still refused")
    func cacheInsideDocuments() {
        // The shape a discovery bug would actually produce.
        let path = "\(Paths.home.path)/Documents/Library/Caches/com.vendor.app"
        let verdict = SafetyPolicy.verdict(for: path, probeLiveness: false)
        #expect(verdict.reason == .userDataRoot)
    }

    @Test("System paths are hard-blocked")
    func systemPaths() {
        let cases = [
            "/",
            "/System",
            "/System/Library/CoreServices",
            "/Library/Keychains",
            "/bin/sh",
            "/usr/lib",
            "/etc/passwd",
            "/private/etc/hosts",
            "/private/var/db",
            "/Applications",
            "/Applications/Finder.app",
            "/Applications/Safari.app/Contents",
            "/Users/Shared",
            "/Volumes/Macintosh HD",
            "/opt/homebrew",
            "/private/tmp",
            "/private/var/folders/zz/T/scratch",
        ]
        for path in cases {
            let verdict = SafetyPolicy.verdict(for: path, probeLiveness: false)
            #expect(!verdict.isAllowed, "\(path) must never be cleanable")
        }
    }

    @Test("A bare /Users/<name> is refused while its children are allowed")
    func homeDirectoryRoot() {
        let home = Paths.home.path
        #expect(!SafetyPolicy.verdict(for: home, probeLiveness: false).isAllowed)
        #expect(!SafetyPolicy.verdict(for: "/Users/namannamdev", probeLiveness: false).isAllowed)
        // A child of the home folder may still be a legitimate cache.
        let cache = "\(home)/Library/Caches/com.example.app/Cache.db"
        #expect(SafetyPolicy.verdict(for: cache, probeLiveness: false).isAllowed)
    }

    @Test("APFS case variations of a protected root are refused")
    func caseInsensitiveAliases() {
        for path in ["/SYSTEM", "/System", "/sYsTeM/Library", "/OPT/HOMEBREW",
                     "/USERS/Shared", "/Private/Var/folders"] {
            #expect(!SafetyPolicy.verdict(for: path, probeLiveness: false).isAllowed,
                    "\(path) is the same inode as a protected root")
        }
    }

    @Test("The active PowerLog database is never a target")
    func activePowerLog() {
        let path = "/private/var/db/powerlog/Library/PerfPowerTelemetry/BackgroundProcessing/CurrentBackgroundProcessingDB.BGSQL"
        let verdict = SafetyPolicy.verdict(for: path, probeLiveness: false)
        #expect(verdict.reason == .activePowerLog)
    }

    @Test("Software Update staging is never a target")
    func softwareUpdateStaging() {
        for path in ["/Library/Updates", "/Library/Updates/foo.pkg", "/macOS Install Data"] {
            #expect(SafetyPolicy.verdict(for: path, probeLiveness: false)
                .reason == .softwareUpdateStaging)
        }
    }

    @Test("Credential stores are never a target")
    func credentialStores() {
        let home = Paths.home.path
        for relative in [".ssh", ".ssh/id_ed25519", ".gnupg", "1Password",
                         "Library/Keychains/login.keychain-db"] {
            let path = "\(home)/\(relative)"
            let verdict = SafetyPolicy.verdict(for: path, probeLiveness: false)
            #expect(!verdict.isAllowed, "\(relative) must not be cleanable")
        }
    }

    @Test("Independent CLI tool state is not mistaken for app cache")
    func independentCLITools() {
        let home = Paths.home.path
        // The R18 collision: uninstalling Claude.app must not touch .claude.
        // The guarantee is that these are refused; the reason varies, because
        // `~/.codex` is refused as outside a cleanable root rather than by the
        // CLI-collision rule, which is what lets its age-gated staging stay
        // reachable.
        for relative in [".claude", ".gemini", ".opencode",
                         ".local/share/opencode", ".local/share/claude"] {
            let verdict = SafetyPolicy.verdict(for: "\(home)/\(relative)",
                                              probeLiveness: false)
            #expect(verdict.reason == .independentCLITool,
                    "\(relative) should be kept")
        }

        // Durable Codex CLI state is refused by name.
        for relative in [".codex/config.toml", ".codex/auth.json",
                         ".codex/sessions/history.jsonl"] {
            #expect(SafetyPolicy.verdict(for: "\(home)/\(relative)",
                                         probeLiveness: false).reason
                    == .independentCLITool,
                    "\(relative) must be kept")
        }

        // Its staging area is deliberately reachable: the app has age-gated rules
        // for it, and a blanket block made them dead code.
        #expect(SafetyPolicy.verdict(for: "\(home)/.codex/.tmp/bundled-marketplaces/x",
                                     probeLiveness: false).isAllowed,
                "Codex marketplace staging is cleanable after 30 days")
    }

    @Test("A running app is a warning, not a refusal")
    func runningAppIsAdvisory() {
        // Blocking a running app's cache withheld 1.77 GB and made the app look
        // broken next to the CLI, which offers these and notes that closing the
        // app helps. Only genuinely dangerous state stays refused.
        let cache = "\(Paths.home.path)/Library/Caches/Microsoft Edge"
        let verdict = SafetyPolicy.verdict(for: cache, probeLiveness: true)
        #expect(verdict.isAllowed, "a running app's cache is still cleanable")
    }

    @Test("Compiled model caches are refused")
    func compiledModelCache() {
        let path = "\(Paths.home.path)/Library/Caches/com.apple.e5rt.e5bundlecache"
        #expect(SafetyPolicy.verdict(for: path, probeLiveness: false)
            .reason == .compiledModelCache)
    }

    @Test("Endpoint security caches are refused")
    func endpointSecurityCache() {
        let path = "/private/var/folders/xy/abc123/C/com.crowdstrike.falcon.Caches"
        #expect(SafetyPolicy.verdict(for: path, probeLiveness: false)
            .reason == .endpointSecurityCache)
    }

    @Test("Toolchain and archive state is refused")
    func toolchainState() {
        let home = Paths.home.path
        for relative in ["Library/Developer/Xcode/Archives/2024-01",
                         "Library/Developer/CoreSimulator/Devices/ABC",
                         ".m2/repository", ".gradle/caches/modules-2",
                         "Library/Anki2/collection.anki2",
                         "Library/Application Support/MobileSync/Backup"] {
            #expect(!SafetyPolicy.verdict(for: "\(home)/\(relative)", probeLiveness: false).isAllowed,
                    "\(relative) must be kept")
        }
    }

    @Test("Small macOS UI state is refused")
    func smallUIState() {
        let home = Paths.home.path
        for relative in ["Library/Application Support/com.apple.wallpaper/aerials/thumbnails",
                         "Library/Caches/com.apple.idleassetsd"] {
            #expect(SafetyPolicy.verdict(for: "\(home)/\(relative)", probeLiveness: false)
                .reason == .smallSystemUIState)
        }
    }

    @Test("Traversal, relative and control-character paths are refused")
    func malformedPaths() {
        for path in ["relative/path", "", "/Library/../../etc/passwd",
                     "/Library/Caches/\u{7}evil", "/Library/Caches/../../etc",
                     "/..", "/Library/Caches/a/../b"] {
            let verdict = SafetyPolicy.verdict(for: path, probeLiveness: false)
            #expect(!verdict.isAllowed, "\(path) must be refused")
        }

        // `..` only counts as a complete path component. A folder genuinely
        // named with two dots is ordinary content, not traversal, so a cache
        // that happens to be called `..hidden` stays cleanable.
        #expect(SafetyPolicy.verdict(for: "\(Paths.home.path)/Library/Caches/..hidden",
                                     probeLiveness: false).isAllowed,
                "a dotted folder name is not traversal")
    }

    @Test("Any folder inside ~/Library/Caches is liveness-gated, not just bundle IDs")
    func everyCacheFolderIsGated() {
        // The regression this locks: a blanket `~/Library/Caches/*` sweep found
        // `Microsoft Edge` and `Google` display-named folders, concluded they
        // had no owner, and offered 1.2 GB of live browser cache for cleaning.
        for name in ["Microsoft Edge", "Google", "Firefox", "Slack", "Sublime Text",
                     "com.google.Chrome", "ai.opencode.desktop"] {
            let path = "\(Paths.home.path)/Library/Caches/\(name)"
            #expect(LivenessProbe.isUserCachePath(path),
                    "\(name) must be treated as a user cache path")
            #expect(LivenessProbe.ownerDisplayName(for: path) != nil
                    || LivenessProbe.ownerBundleID(for: path) != nil,
                    "\(name) must resolve to some owner for the liveness gate")
        }
    }

    @Test("Build-tool cache folders are not mistaken for running apps")
    func toolCacheFolders() {
        // `pip`, `node-gyp` and `electron` are build tools. Gating them on a
        // same-named process would keep their caches forever with no benefit.
        for name in ["pip", "node-gyp", "electron", "typescript"] {
            let path = "\(Paths.home.path)/Library/Caches/\(name)"
            #expect(LivenessProbe.ownerDisplayName(for: path) == nil,
                    "\(name) is a tool cache, not an app cache")
        }
    }

    @Test("Process-name matching recovers an Electron app from its bundle folder")
    func electronNameRecovery() {
        // `ai.opencode.desktop` fails the reverse-DNS test on its short first
        // label, yet is owned by a process called `OpenCode`.
        let leaf = "ai.opencode.desktop"
        let candidates = LivenessProbe.candidateProcessNames(for: leaf)
        #expect(candidates.contains("OpenCode") == false,
                "candidates are lowercase; matching is case-insensitive")
        #expect(candidates.contains("opencode"),
                "the middle label must be tried, or every modern Electron app is ungated")
        #expect(LivenessProbe.matchesProcess(["OpenCode", "Finder"],
                                             candidates: candidates),
                "case differences must not hide a running app")
        #expect(!LivenessProbe.matchesProcess(["Finder", "Dock"],
                                              candidates: candidates))
    }

    @Test("A Sparkle updater cache folder is gated after the @ prefix")
    func sparkleUpdaterFolder() {
        let candidates = LivenessProbe.candidateProcessNames(for: "@opencode-aidesktop-updater")
        #expect(candidates.contains("opencode-aidesktop-updater"))
    }

    @Test("A legitimate app cache is allowed")
    func legitimateCache() {
        let home = Paths.home.path
        for relative in [
            "Library/Caches/com.google.Chrome/Default/Code Cache",
            "Library/Containers/com.microsoft.Word/Data/Library/Caches/x",
            "Library/Logs/SomeApp/app.log",
            "Library/Caches/Homebrew/downloads/pkg.tar.gz",
            ".cache/uv/archive-v0",
            "Library/Developer/Xcode/DerivedData/Project-abc/Build",
        ] {
            #expect(SafetyPolicy.verdict(for: "\(home)/\(relative)", probeLiveness: false).isAllowed,
                    "\(relative) should be cleanable")
        }
    }

    @Test("A path outside every allowed root is refused")
    func outsideAllowedRoots() {
        let verdict = SafetyPolicy.verdict(
            for: "\(Paths.home.path)/.ssh/keys/id_rsa", probeLiveness: false)
        #expect(!verdict.isAllowed)
    }

    @Test("Protected bundle IDs are refused for app data")
    func protectedBundles() {
        for bundleID in ["com.apple.finder", "com.apple.dock", "com.apple.CoreServices",
                         "com.apple.securityd", "com.apple.Passwords"] {
            #expect(ProtectedBundles.isProtected(bundleID), "\(bundleID) is protected")
        }
        #expect(!ProtectedBundles.isProtected("com.google.Chrome"))
        #expect(!ProtectedBundles.isProtected("com.apple.dt.Xcode"),
               "Xcode is user-installed and stays uninstallable")
    }

    @Test("The whitelist blocks but never unblocks a hard rule")
    func whitelistInteraction() {
        let sandbox = Whitelist.temporary(["\(Paths.home.path)/Library/Caches/allowed-only"])
        let protectedPath = "\(Paths.home.path)/Library/Caches/allowed-only"

        #expect(SafetyPolicy.verdict(for: protectedPath, whitelist: sandbox,
                                     probeLiveness: false).reason == .whitelisted)

        // A hard-blocked path stays blocked even if the whitelist somehow
        // contains it.
        let evil = Whitelist.temporary(["/System/Library/CoreServices"])
        #expect(!SafetyPolicy.verdict(for: "/System/Library/CoreServices",
                                      whitelist: evil, probeLiveness: false).isAllowed)
    }
}

@Suite("Path identity")
struct PathIdentityTests {

    @Test("Identity distinguishes two files at different paths")
    func distinctFiles() {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("worm-test-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let a = dir.appendingPathComponent("a")
        let b = dir.appendingPathComponent("b")
        FileManager.default.createFile(atPath: a.path, contents: Data("one".utf8))
        FileManager.default.createFile(atPath: b.path, contents: Data("two".utf8))

        let ia = PathIdentity.capture(a)
        let ib = PathIdentity.capture(b)
        #expect(ia != nil && ib != nil)
        #expect(!(ia!.matches(ib!)))
    }

    @Test("A missing path captures nil rather than a zero identity")
    func missingPath() {
        #expect(PathIdentity.capture(
            URL(fileURLWithPath: "/definitely/not/here-\(UUID().uuidString)")) == nil)
    }

    @Test("Capturing the same path twice matches")
    func stableCapture() {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("worm-stable-\(UUID().uuidString)")
        FileManager.default.createFile(atPath: url.path, contents: Data(repeating: 7, count: 32))
        defer { try? FileManager.default.removeItem(at: url) }

        let first = PathIdentity.capture(url)
        let second = PathIdentity.capture(url)
        #expect(first != nil && second != nil)
        #expect(first!.matches(second!))
    }
}

@Suite("Risk classification")
struct RiskTests {

    @Test("Risk ordering puts regenerable cache below user data")
    func ordering() {
        #expect(Risk.regenerable < Risk.reDownload)
        #expect(Risk.reDownload < Risk.userData)
        #expect(Risk.userData < Risk.unsafe)
    }

    @Test("Every rule's risk is explicit and never unsafe")
    func rulesAreRiskTagged() {
        for category in CleanCategory.allCases where !category.isReviewOnly {
            for rule in ScanCatalog.rules(for: category) {
                #expect(rule.risk != .unsafe,
                        "\(category.rawValue)/\(rule.ruleLabel) is marked unsafe and must not ship as a rule")
            }
        }
    }

    @Test("Review-only categories expose no cleaning rules")
    func reviewOnly() {
        #expect(ScanCatalog.rules(for: .largeFiles).isEmpty)
        #expect(CleanCategory.largeFiles.isReviewOnly)
    }
}

@Suite("Scanner")
struct ScannerTests {

    @Test("A scan returns targets and never throws on this Mac")
    func scanRuns() async throws {
        let scanner = ScanEngine()
        let result = await scanner.scan(categories: [.appCaches, .logs], includeBlocked: true)
        // Whatever this machine has, the contract is that scanning is bounded
        // and structurally sound rather than that it finds a specific number.
        #expect(result.duration >= 0)
        for target in result.targets {
            #expect(target.path.hasPrefix("/"))
            #expect(target.bytes >= 0)
        }
    }

    @Test("Blocked targets carry a reason that explains itself")
    func blockedHaveReasons() async throws {
        let scanner = ScanEngine()
        let result = await scanner.scan(categories: [.appCaches], includeBlocked: true)
        for blocked in result.blocked {
            #expect(!blocked.reason.title.isEmpty)
            #expect(!blocked.reason.detail.isEmpty)
        }
    }
}

@Suite("Byte formatting")
struct ByteFormatTests {

    @Test("Formatting covers the units a user sees")
    func formatting() {
        #expect(ByteFormat.compact(0) == "0 bytes")
        #expect(ByteFormat.compact(512) == "512 bytes")
        #expect(ByteFormat.compact(1536).contains("KB"))
        #expect(ByteFormat.compact(5_590_000_000).contains("GB"))
        #expect(ByteFormat.string(0) == "Zero KB")
    }
}

extension Whitelist {
    /// A whitelist with fixed contents, for tests that must not read or write
    /// the real protect list.
    static func temporary(_ patterns: [String]) -> Whitelist {
        Whitelist(testPatterns: patterns)
    }
}