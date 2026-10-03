/**
 * Shared, verified facts.
 *
 * Everything here is checked against the shipped code in `Sources/WormCore`
 * and `worm-windows/src/WormCore`, not copied from marketing copy. If you
 * change a product fact, change it HERE — the landing pages, the FAQ blocks
 * and the JSON-LD all read from this module, which is the only way to keep
 * the site's claims from drifting apart page to page.
 *
 * Answer engines pick sources whose facts agree with each other. A page that
 * says "clears CocoaPods caches" while another says "CocoaPods is not
 * supported" costs more than the page earns.
 */

/* ── Platform ──────────────────────────────────────────────────────────── */

export const PLATFORMS = "macOS 14.0 or later (Apple Silicon and Intel) and Windows 10 or 11 at 64-bit";

export const PRICE = "Free, MIT licensed, no subscription, no account, no credit card";

/* ── Safety ────────────────────────────────────────────────────────────── */

/**
 * The telemetry answer, used verbatim in the homepage accordion, the homepage
 * FAQPage JSON-LD, the no-JS fallback and the /is-worm-cleaner-safe page.
 *
 * Note the deliberate two-scope structure: the app genuinely makes no network
 * calls, while this website uses cookieless aggregate analytics. Collapsing
 * those into one sentence is what would make the claim false.
 */
export const TELEMETRY_ANSWER =
  "Zero for the app itself. Worm Cleaner ships no telemetry and no analytics, and it makes no network calls while cleaning — you can verify that with Little Snitch, Wireshark, or by reading the MIT-licensed source. To be exact about the website you are reading: it uses Vercel Web Analytics, which sets no cookies, stores no personal data and needs no consent banner. That counts page views on worm.clepsydratechnologies.com only and is unrelated to the app.";

export const NOT_MALWARE_ANSWER =
  "No. Worm Cleaner is a disk cleaning utility, not malware and not a self-replicating computer worm. It does not copy itself, does not attach to other files, and has no payload. Its entire source code is public under the MIT licence, so every claim on this page can be checked line by line. The name refers to the earthworm that burrows through soil, which is also the product metaphor: it tunnels past the surface junk into the deeper filesystem strata.";

/**
 * The honest framing of "optimizer".
 *
 * People search "mac optimizer", so the word belongs on the page. But a disk
 * cleaner frees space; it does not make hardware faster. Overclaiming here is
 * the fastest way to lose the trust this product trades on, so every page uses
 * this wording rather than promising speed gains.
 */
export const OPTIMIZER_NOTE =
  "<p><strong>About the word &ldquo;optimizer&rdquo;.</strong> People search for it, so Worm uses it — but be clear about what it means. A storage cleaner frees disk space and reduces clutter. It does not make your Mac faster, and no cleaner honestly can promise that. What a nearly-full drive does is cause real problems: Xcode builds fail, macOS swaps heavily, updates stall, and caches stop being written. Freeing space fixes those. It is not a speed hack.</p>";

/* ── Footprint ─────────────────────────────────────────────────────────── */

/**
 * Idle memory, as measured on the author's machines and reported in README.md.
 *
 * The site previously claimed "under 15 MB". The measured figures in the
 * README are 35 MB (macOS) and 42 MB (Windows), and the README is the source
 * that documents how they were taken. Use these.
 */
export const IDLE_RAM = "under 35 MB resident on macOS and under 42 MB on Windows, measured while idle";

/* ── What is actually cleaned ──────────────────────────────────────────── */

/**
 * macOS developer targets, transcribed from Sources/WormCore/ScanCatalog.swift.
 *
 * Deliberately NOT listed, because the code explicitly refuses them:
 *   - ~/Library/Developer/Xcode/Archives
 *   - ~/Library/Developer/Xcode/iOS DeviceSupport
 *   - ~/Library/Developer/CoreSimulator/Profiles/Runtimes
 *   - CocoaPods (no rule exists for it anywhere in the project)
 * README.md currently claims archives, simulator runtimes and CocoaPods. Those
 * three claims are contradicted by SafetyPolicy.swift and are being corrected.
 */
export const MACOS_DEVELOPER = [
  "Xcode DerivedData, Xcode build products and the Xcode cache",
  "Simulator cache and XCTest device data",
  "SwiftPM cache",
  "npm, tnpm, Yarn (classic and v2), Corepack and node-gyp",
  "Homebrew downloads, Gradle build cache and daemon logs",
  "pip, uv, Poetry, pypoetry, pytest, mypy, ruff, Jupyter and PyInstaller",
  "RubyGems, Bundler, rbenv, Composer, CPAN, Hex, opam and pre-commit",
  "Electron, VS Code, Cursor and Terraform, kubectl and AWS CLI caches",
];

export const MACOS_BROWSERS =
  "Chrome, Edge, Brave, Firefox, Opera, Comet, Arc, Vivaldi, Helium, Yandex, Kagi and Dia";

/** Windows, per README.md and WindowsScanCatalog.cs. */
export const WINDOWS_CATEGORIES =
  "66 scan rules across 12 categories: Developer Tools, App Caches, Browsers, Cloud &amp; Office, AI Tools, Apps &amp; Utilities, Virtualization, User Essentials, System Caches, Logs, Recycle Bin and Misc";

/**
 * What Worm will not touch on Windows.
 *
 * This is a selling point, not a gap. Windows Update's SoftwareDistribution
 * tree cannot be aged into safety, so the catalog excludes it outright, and
 * app removal always runs the vendor's own registered uninstaller rather than
 * deleting an install folder by hand.
 */
export const WINDOWS_EXCLUSIONS =
  "<p><strong>What Worm deliberately does not clean on Windows:</strong> <code>C:\\Windows\\SoftwareDistribution</code> (the Windows Update download tree) is excluded by design. Its files cannot be aged into proven-inactive, and a half-cleared update cache breaks patching in ways that are tedious to recover from. If you want that space, the supported route is Settings &rarr; System &rarr; Storage &rarr; Temporary files, or the Disk Cleanup tool that ships with Windows.</p>";

/** Cleanup paths, verbatim from the README and SETUP.md. */
export const AUDIT_LOG_MAC = "~/Library/Logs/Worm/deletions.tsv";
export const AUDIT_LOG_WIN = "%LOCALAPPDATA%\\Worm\\Logs\\deletions.tsv";

/**
 * How each platform disposes of what it deletes. Load-bearing for the
 * "can I undo this?" question, and the single most reassuring fact on the site.
 */
export const RECOVERY =
  "<p>Recoverable by default on both platforms. On macOS, deleted items go to the Trash, so you can put them back until you empty it. On Windows, they go to the Recycle Bin. Every destructive operation is also appended to a plain-text audit log — " +
  "<code>~/Library/Logs/Worm/deletions.tsv</code> on macOS and <code>%LOCALAPPDATA%\\Worm\\Logs\\deletions.tsv</code> on Windows — so you can see exactly what was removed, when, and how many bytes it freed.</p>";

/* ── Risk model ────────────────────────────────────────────────────────── */

/**
 * Every macOS target carries a risk tier that decides its default selection
 * state. Naming the tiers is a strong trust signal and it is accurate.
 */
export const RISK_MODEL =
  "<p>Every target carries one of four risk tiers, and the tier decides what is ticked by default:</p><ul><li><strong>Safe</strong> — rebuilt automatically by the app. Deleting costs only time.</li><li><strong>Re-download</strong> — fetched again from the network. Anything expired in there is gone for good.</li><li><strong>Keep</strong> — your content, not a cache. Off by default, and needs an explicit per-item opt-in.</li><li><strong>Blocked</strong> — system-owned or not rebuildable. Never offered as a target at all.</li></ul>";

/* ── Verification ──────────────────────────────────────────────────────── */

/**
 * macOS Gatekeeper reality.
 *
 * SETUP.md is explicit that Worm ships without Apple Developer ID
 * notarisation, because there is no paid certificate behind the project. Any
 * page that implies the build is notarised or signed is lying. This is the
 * honest version, and naming the reason is more convincing than a signature
 * badge would be.
 */
export const GATEKEEPER =
  "<p><strong>Why does macOS warn me on first launch?</strong> Because Worm is not notarised with an Apple Developer ID. It is an independent project without a paid Apple Developer account, so the build carries no notarisation ticket and Gatekeeper blocks it on first open. This is a packaging gap, not a security finding — it is exactly what an unnotarised binary looks like.</p><p>To open it: <strong>System Settings &rarr; Privacy &amp; Security &rarr; Security</strong>, then click <strong>Open Anyway</strong> and authenticate. From Terminal, <code>xattr -cr /Applications/Worm.app</code> clears the quarantine flag.</p><p>If you would rather judge the binary than the badge, verify its SHA-256 against the published checksum, read the source, or build it yourself with <code>swift build -c release</code>.</p>";

/** SHA-256 digests for the published v1.0.4 assets, from the release itself. */
export const CHECKSUMS = `6ae5f01072b506e6a6ae19225d5483b63fd53671e6519dea0d4202b9a8e353d1  Worm-Installer.dmg
8addf36453262d6227d1b1c924a253563974e7d0637ed3fda374c007b1232b43  Worm-macOS.zip
0169d3282e79f2cb8c7ff386c379c4c6ad0f07d29efae5267fbae6d17147e6af  Worm-Windows-x64.zip`;

/* ── Comparison claims ─────────────────────────────────────────────────── */

/**
 * Only claims verifiable from Worm's own repository. Every competitor cell is
 * left as a link to that vendor's own page rather than an assertion, because
 * unverifiable third-party claims are the fastest route to a bad-faith finding.
 */
export const COMPARISON_ROW_SOURCE = "Open (MIT)";