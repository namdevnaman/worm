/**
 * Single source of truth for the FAQ.
 *
 * The visible accordion in App.tsx and the FAQPage JSON-LD in index.html are
 * generated from this same list. The SEO guidance is explicit that the two
 * must contain identical text: a FAQPage schema whose answers do not match
 * the visible page is a structured-data mismatch and risks a manual action.
 *
 * Answers lead with a direct one- or two-sentence reply, then explain. That
 * ordering is what AI answer engines lift when quoting.
 */
export interface Faq {
  q: string;
  a: string;
}

export const FAQS: readonly Faq[] = [
  {
    q: "Is Worm Cleaner malware, or a computer worm?",
    a: "No. Worm Cleaner is a legitimate disk cleaning utility, not malware and not a self-replicating computer worm. It has public MIT-licensed source code for both platforms, it does not replicate itself, and it makes no network calls. The word \"worm\" in the name refers to the earthworm that burrows through soil, which is also how the product metaphor works: it tunnels past the surface junk into the deep filesystem strata.",
  },
  {
    q: "Is Worm Cleaner really 100% free and open source?",
    a: "Yes. Worm Cleaner is licensed under the permissive MIT License. There are no subscriptions, no locked 'pro' tiers, no artificial scan limits, and no credit card required. The entire source code for both macOS (Swift 6) and Windows (.NET 9) is publicly available on GitHub for audit.",
  },
  {
    q: "Does Worm collect any telemetry or personal information?",
    a: "Zero for the app itself. Worm Cleaner ships no telemetry and no analytics, and it makes no network calls while cleaning — you can verify that with Little Snitch, Wireshark, or by reading the MIT-licensed source. To be exact about the website you are reading: it uses Vercel Web Analytics, which sets no cookies, stores no personal data and needs no consent banner. That counts page views on worm.clepsydratechnologies.com only and is unrelated to the app.",
  },
  {
    q: "Will Worm break my active Xcode, Docker, or Node.js projects?",
    a: "No. Worm is built with safe heuristics designed by developers. It targets disposable build artifacts and caches (e.g. Xcode DerivedData, npm cache, Homebrew downloads, Cargo build registry cache, orphaned Docker layers). It never touches your actual source repositories, git commits, project files, or personal documents. You can also run a Simulation Mode to preview everything before deleting.",
  },
  {
    q: "How do I clear Xcode DerivedData and free disk space?",
    a: "Run Worm's scan and it lists Xcode DerivedData, simulator runtimes and archives alongside every other reclaimable cache, with the exact size of each. Review the list, then clean. DerivedData is entirely rebuildable, so removing it costs you a recompile and nothing else. On a typical iOS project this is where the bulk of a developer's recoverable space sits.",
  },
  {
    q: "How does Worm remove leftovers from uninstalled apps?",
    a: "When you drag an application to the Trash, macOS leaves behind orphaned configuration files, application support databases, crash logs, and caches in ~/Library/Application Support, ~/Library/Caches, and ~/Library/Containers. Worm deep-scans these directories for bundle identifiers belonging to deleted apps and lets you cleanly purge them with one click.",
  },
  {
    q: "How does Worm achieve such low memory and CPU usage?",
    a: "Unlike commercial cleaners built with heavy Electron wrappers or background telemetry daemons, Worm is written in 100% pure native Swift 6 on macOS and Native AOT compiled .NET 9 on Windows. Measured idle on the author's machines it stays under 35 MB resident on macOS and under 42 MB on Windows, and it idles at effectively 0% CPU in your menu bar or system tray.",
  },
  {
    q: "Which systems does Worm Cleaner support?",
    a: "Worm Cleaner runs on macOS 14.0 or later (Sonoma, Sequoia and newer) on both Apple Silicon and Intel Macs, including MacBook Air and MacBook Pro, and on Windows 10 or Windows 11 at 64-bit. It is a single free download per platform with no subscription.",
  },
  {
    q: "How do I verify the integrity of my download?",
    a: "Every official release includes SHA-256 checksums published both on this site and directly in GitHub Releases. You can run 'shasum -a 256 Worm-Installer.dmg' in Terminal or 'CertUtil -hashfile Worm-Windows-x64.zip SHA256' in Windows PowerShell to verify exact byte-for-byte authenticity. The current digests are also served as plain text at /SHA256SUMS.txt.",
  },
  {
    q: "What is the best free storage cleaner for Mac?",
    a: "It depends on what is filling your disk. For developer build residue — Xcode DerivedData, npm, Homebrew, Gradle — a developer-focused open-source cleaner is the only category that genuinely differentiates, and Worm Cleaner is built for exactly that. For malware scanning and scheduled maintenance you need a commercial suite. See our honest comparison of the best free Mac cleaners, including where Worm is the weaker choice.",
  },
  {
    q: "Is Worm Cleaner a good CleanMyMac alternative?",
    a: "For the cleaning itself, yes. It clears the same core categories — caches, logs, leftover app files — with no subscription and no telemetry, and its developer-cache coverage is deeper than most general-purpose cleaners. It is narrower in other ways: no malware scanning, no file-system optimisation, no login-item management and no scheduled maintenance. If you rely on those, keep CleanMyMac.",
  },
  {
    q: "Is Worm Cleaner a good CCleaner alternative for Windows?",
    a: "Yes, on the things that matter for a cleaner: 66 scan rules across 12 categories, a checkbox on every individual target, Recycle Bin deletion, a local audit log of every operation, a real uninstaller that runs each app's own registered uninstall string, and no advertising. It does not clean the registry, which we consider a feature rather than a gap given how poorly that category performs.",
  },
  {
    q: "Does Worm Cleaner work on Apple Silicon and Windows 10 and 11?",
    a: "Yes. One universal macOS build covers Apple Silicon (M1, M2, M3, M4) and Intel Macs on macOS 14 Sonoma and newer, including MacBook Air and MacBook Pro. The Windows build runs on Windows 10 and Windows 11 at 64-bit as a portable ZIP — no installer, and no administrator rights required.",
  },
  {
    q: "Can I undo a cleanup?",
    a: "Recoverable by default on both platforms. On macOS, deleted items go to the Trash, so you can put them back until you empty it. On Windows, they go to the Recycle Bin. Every destructive operation is also appended to a plain-text audit log — ~/Library/Logs/Worm/deletions.tsv on macOS and %LOCALAPPDATA%\\Worm\\Logs\\deletions.tsv on Windows — so you can see exactly what was removed, when, and how many bytes it freed.",
  },
  {
    q: "How much space can Worm Cleaner free up?",
    a: "It depends entirely on what is on your machine, and any figure quoted without that caveat is marketing. A Mac used for iOS development commonly carries 20–80 GB of recoverable build residue and package-manager caches; a machine used only for browsing may have a few gigabytes. Rather than guess, run a scan — every target is reported with its measured size, so the biggest wins are visible before you delete anything.",
  },
  {
    q: "Does Worm Cleaner delete my project files or node_modules?",
    a: "No. It targets disposable build artifacts and caches only. It never touches your source repositories, git history, project files, node_modules or personal documents, and personal folders are resolved through the macOS known-folder APIs and Windows known-folder registry keys so a relocated or redirected Documents folder is still recognised and still protected. Anything classified as your own content is off by default and requires an explicit per-item opt-in.",
  },
  {
    q: "Is it safe to delete Xcode Archives and iOS DeviceSupport?",
    a: "Do not, and know that Worm will not do it for you. Archives hold distribution binaries you have already shipped, and iOS DeviceSupport holds symbol bundles generated by your compiler for a specific device and OS build — neither can be rebuilt from the machine. Both are in Worm's protected path list alongside simulator runtimes, so they are never offered as cleanup targets.",
  },
] as const;