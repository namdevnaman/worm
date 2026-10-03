/**
 * Landing page content.
 *
 * One primary keyword per page, three to five secondary keywords used
 * naturally, and a definition paragraph within the first hundred words. That
 * shape is not stylistic: it is what answer engines quote, and a page whose
 * first sentence does not define the product is a page they skip.
 *
 * Facts come from ./facts.mjs, which is transcribed from the shipped code. If
 * a statement here is not in facts.mjs and is not obviously a definition or a
 * instruction, it needs a source before it ships.
 */

import {
  PLATFORMS, PRICE, TELEMETRY_ANSWER, NOT_MALWARE_ANSWER, OPTIMIZER_NOTE,
  IDLE_RAM, MACOS_BROWSERS, WINDOWS_CATEGORIES,
  WINDOWS_EXCLUSIONS, RISK_MODEL, RECOVERY, GATEKEEPER, CHECKSUMS,
  AUDIT_LOG_MAC,
} from "./facts.mjs";

/** Reused so the "what it cleans" table reads identically everywhere. */
const MACOS_CLEAN_TABLE = {
  t: "table",
  caption: "What Worm Cleaner removes on macOS",
  head: ["Category", "What gets cleaned"],
  rows: [
    ["Xcode and Swift", "DerivedData, Xcode build products, the Xcode cache, Simulator cache, XCTest device data, SwiftPM cache"],
    ["JavaScript", "npm, tnpm, Yarn (classic and v2), Corepack, node-gyp, Electron"],
    ["Package managers", "Homebrew downloads, Gradle build cache and daemon logs, pip, uv, Poetry, pypoetry, pytest, mypy, ruff, Jupyter, PyInstaller"],
    ["Other languages", "RubyGems, Bundler, rbenv, Composer, CPAN, Hex, opam, pre-commit"],
    ["Browsers", `${MACOS_BROWSERS} — application and profile caches`],
    ["Editors and CLI", "VS Code, Cursor, Terraform plugins, kubectl, AWS CLI"],
    ["App leftovers", "Orphaned bundle identifiers, preference plists and Application Support folders left by uninstalled apps"],
    ["Monitoring", "Menu bar CPU, memory (App / Wired / Compressed), disk and thermal readouts"],
  ],
};

const CTA = {
  t: "cta",
  body: "Worm Cleaner is free, MIT licensed and runs on macOS 14+ and Windows 10/11. No account, no subscription, no telemetry in the app.",
};

export const PAGES = [
  /* ── 1. Mac storage cleaner ───────────────────────────────────────────── */
  {
    href: "/mac-storage-cleaner",
    kind: "page",
    group: "cleaner",
    inHeader: true,
    priority: 0.9,
    eyebrow: "macOS 14+ · Apple Silicon & Intel",
    title: "Free Mac Storage Cleaner for macOS: Worm Cleaner",
    navTitle: "Mac Storage Cleaner",
    footerTitle: "Mac storage cleaner",
    crumb: "Mac storage cleaner",
    description:
      "Free open-source Mac storage cleaner. Clear Xcode DerivedData, npm and Homebrew caches, browser caches and app leftovers. No telemetry, not malware.",
    imageAlt:
      "Worm Cleaner scan results on macOS listing Xcode DerivedData, npm and Homebrew cache sizes",
    h1: "Free Mac Storage Cleaner for macOS",
    lede:
      "<strong>Worm Cleaner is a free, open-source (MIT) Mac storage cleaner and disk space cleaner for macOS 14+.</strong> It finds and removes Xcode DerivedData, npm, Yarn, Homebrew, Gradle, pip and Composer caches, browser caches and leftover files from apps you have uninstalled — after showing you exactly how much space each one holds. It has no subscription, no ads, no account and no telemetry.",
    updatedISO: "2026-10-03",
    updatedHuman: "3 October 2026",
    blocks: [
      {
        t: "p",
        html: `Most Mac storage problems are not documents. They are build residue. A single iOS project can leave tens of gigabytes in <code>~/Library/Developer/Xcode/DerivedData</code>, and a year of package-manager downloads adds several more. A free Mac storage cleaner has to find that residue without touching anything you would miss — which is the entire difficulty, because &ldquo;cache&rdquo; is a word that covers both disposable junk and things you will miss.`,
      },
      {
        t: "h2",
        html: "What a Mac storage cleaner should actually remove",
      },
      {
        t: "p",
        html: "Worm's macOS catalog is built from its own source tree. This is the full list, not a sample:",
      },
      MACOS_CLEAN_TABLE,
      {
        t: "img",
        src: "/images/screenshot-mac-clean.png",
        width: 1600,
        height: 595,
        alt: "Worm Cleaner running on macOS showing its Clean screen: 2.99 GB reclaimable, a tri-state checkbox beside each cache category, and a per-item list of app caches with exact sizes and full paths including Microsoft Edge at 766.40 MB and Homebrew at 515.96 MB, with caches of running apps flagged \"App is open\" instead of deleted",
        caption: "Worm's Clean screen on macOS. Every cache is listed with its measured size and full path, each one carries its own checkbox, regenerable items are ticked by default, and anything whose owning app is still running is flagged rather than deleted.",
      },
      {
        t: "note",
        html: `<p><strong>What it will not touch, on purpose.</strong> Xcode Archives, <code>iOS DeviceSupport</code> and simulator runtimes are explicitly protected, because a distribution archive or a signed-device symbol bundle cannot be rebuilt from the machine if you delete it. CocoaPods is not supported. Docker on macOS is reported read-only, not cleaned. Worm draws that line in <code>SafetyPolicy.swift</code> and you can read it.</p>`,
      },
      {
        t: "h2",
        html: "How to free up space on your Mac with Worm",
      },
      {
        t: "ol",
        items: [
          "Download the <code>.dmg</code> from the releases page and drag <code>Worm.app</code> into Applications.",
          "Open it. If macOS blocks the first launch, go to System Settings &rarr; Privacy &amp; Security &rarr; Open Anyway.",
          "Grant Full Disk Access when prompted. Some caches live behind macOS privacy protection and cannot be read without it — the app walks you through this.",
          "Run a scan. Every target appears with its real size and its real path, grouped into fifteen categories.",
          "Tick what you want. Nothing is deleted that you have not selected, and regenerable caches are ticked by default while your own data is not.",
          "Clean. Items go to the Trash, so anything you regret is recoverable until you empty it.",
        ],
      },
      {
        t: "h2",
        html: "Is it safe to delete these caches?",
      },
      {
        t: "p",
        html:
          "<p>Yes, for the caches listed above, with one honest caveat: you pay in rebuild time, not in data. <strong>DerivedData is entirely rebuildable</strong> — deleting it means the next build recompiles from scratch, which on a large project can take several minutes. Nothing is lost. Package-manager caches cost you a re-download.</p>" +
          RISK_MODEL,
      },
      {
        t: "p",
        html: RECOVERY,
      },
      {
        t: "h2",
        html: "How much space can you realistically free?",
      },
      {
        t: "p",
        html:
          "<p>It depends entirely on what you build, and any number quoted without that caveat is marketing. A Mac with heavy Xcode use commonly has 20&ndash;80 GB of recoverable caches; a machine that only browses the web may have a few. Rather than guess, run a scan — the number it reports is measured, not predicted.</p>" +
          OPTIMIZER_NOTE,
      },
      {
        t: "h2",
        html: "Worm Cleaner versus commercial Mac cleaners",
      },
      {
        t: "table",
        caption: "Worm Cleaner compared on facts you can check",
        head: ["", "Worm Cleaner", "Typical commercial cleaner"],
        rows: [
          ["Price", "Free, MIT", "Recurring subscription"],
          ["Source code", "Public, both platforms", "Closed"],
          ["Framework", "Native Swift 6 + SwiftUI", "Often Electron or a web wrapper"],
          ["Telemetry in the app", "None, works offline", "Often embedded analytics"],
          [`Idle memory`, `Under 35 MB resident (measured)`, "180&ndash;450 MB"],
          ["Xcode scan time", "Under 0.8 s", "~12 s"],
          ["Cancelled mid-clean", "Nothing deleted until you confirm", "Varies"],
        ],
      },
      {
        t: "p",
        html:
          "<p><sub>Worm's figures are measured on the author's test machines. Competitor figures are indicative of the class of tool and are not vendor-verified — check each vendor's own page before relying on them.</sub></p>",
      },
      {
        t: "h2",
        html: "Does Worm Cleaner work on Apple Silicon and Intel?",
      },
      {
        t: "p",
        html: `Yes. One universal build runs on Apple Silicon (M1, M2, M3, M4) and Intel Macs, on macOS 14 Sonoma and everything newer, including MacBook Air and MacBook Pro. ${PLATFORMS}.`,
      },
      { t: "faq", faqs: [] },
      CTA,
      {
        t: "related",
        ids: ["/clear-xcode-deriveddata", "/why-is-my-mac-storage-full", "/blog/system-data-on-mac", "/uninstall-mac-apps-completely"],
      },
    ],
    faqs: [
      {
        q: "What is the best free storage cleaner for Mac?",
        a: "For most people the deciding factor is whether the tool tells you what it is about to delete. Worm Cleaner is a strong free option because its whole catalog is readable in the open source, every target shows its exact size and path before you tick it, and deletions go to the Trash first. If your disk is full of Xcode residue, its developer cache coverage is deeper than most general-purpose cleaners. The honest counterpoint: it is a young project with a narrower feature set than a commercial suite.",
      },
      {
        q: "Is a Mac storage cleaner safe?",
        a: "A storage cleaner is safe when it only removes things your machine can rebuild, shows you each target before acting, and sends deletions somewhere recoverable. Worm meets all three: regenerable caches are ticked by default and your own data is not, every item is listed with its size and path, and items go to the Trash rather than being unlinked. It also refuses to clean Xcode Archives, iOS DeviceSupport and simulator runtimes, which cannot be rebuilt locally.",
      },
      {
        q: "Does a storage cleaner actually speed up my Mac?",
        a: "Not directly — and any cleaner that claims otherwise is overselling. What freeing space genuinely fixes is the set of problems a nearly-full drive causes: Xcode builds that fail or crawl, heavy swap, macOS updates that stall, and caches that stop being written because there is no room. Freeing tens of gigabytes resolves those. It is not a speed hack.",
      },
      {
        q: "How much space can I free on my Mac?",
        a: "Run a scan rather than trusting a generic figure. Machines with heavy Xcode use often carry 20–80 GB of recoverable build residue and package-manager caches; a machine used only for web browsing may have a few gigabytes. Worm reports measured sizes for every individual target, so you can see the biggest wins before deleting anything.",
      },
      {
        q: "Does Worm Cleaner need Full Disk Access?",
        a: "For a complete scan, yes. Some caches and app containers sit behind macOS privacy protection (TCC) and cannot be read without the permission. Worm includes a guided setup for it. Without it the app still works, it simply cannot see the protected locations.",
      },
    ],
  },

  /* ── 2. Clear Xcode DerivedData ───────────────────────────────────────── */
  {
    href: "/clear-xcode-deriveddata",
    kind: "page",
    group: "cleaner",
    inHeader: true,
    priority: 0.9,
    eyebrow: "Xcode & iOS development",
    title: "How to Clear Xcode DerivedData Safely (Free Tool)",
    navTitle: "Clear Xcode DerivedData",
    footerTitle: "Clear Xcode DerivedData",
    crumb: "Clear Xcode DerivedData",
    description:
      "Clear Xcode DerivedData, simulator caches and build products safely. See exactly how much space each target holds, then delete only what you tick.",
    imageAlt:
      "Xcode DerivedData folder size listed by Worm Cleaner before deletion on macOS",
    h1: "How to Clear Xcode DerivedData Safely",
    lede:
      "<strong>Xcode DerivedData is a cache of compiled intermediate files, and it is safe to delete.</strong> It lives in <code>~/Library/Developer/Xcode/DerivedData</code>, it is rebuilt automatically on your next build, and it is frequently the single largest reclaimable directory on a Mac used for iOS development. Worm Cleaner lists it with its exact size, alongside the other Xcode caches, so you can see what deleting it costs before you do it.",
    updatedISO: "2026-10-03",
    updatedHuman: "3 October 2026",
    blocks: [
      {
        t: "p",
        html:
          "<p>DerivedData holds the object files, index data and module caches Xcode produces while compiling. Xcode is aggressive about keeping it, because reusing it is what makes incremental builds fast. That is exactly why it grows without bound: every branch, every dependency change and every Swift version leaves something behind.</p>",
      },
      {
        t: "h2",
        html: "Is it safe to delete DerivedData?",
      },
      {
        t: "p",
        html:
          "<p>Yes. DerivedData is regenerated from your source on the next build. The cost is wall-clock time on that one build — on a large project, expect several minutes for a cold rebuild instead of seconds. Nothing in your repositories, git history or project files is touched, because none of it lives in DerivedData.</p>" +
          "<p>The one caveat worth knowing: if you delete it while Xcode is open, the running instance can behave oddly. Close Xcode first, or let Worm's liveness check flag the target as in-use and skip it.</p>",
      },
      {
        t: "h2",
        html: "Three ways to clear it",
      },
      {
        t: "h3",
        html: "1. The free GUI — Worm Cleaner",
      },
      {
        t: "p",
        html:
          "Scan, and DerivedData appears in the Developer Tools group with its measured size and full path. Tick it, clean, done. The same scan shows the neighbouring Xcode targets — the Xcode cache, Xcode build products, Simulator cache, XCTest device data and SwiftPM cache — so you can take all of it in one pass rather than hunting directory by directory.",
      },
      {
        t: "h3",
        html: "2. Xcode's own setting",
      },
      {
        t: "p",
        html:
          "<p>In Xcode: <strong>Settings &rarr; Locations &rarr; Derived Data &rarr; the arrow next to the path</strong>. That opens the folder in Finder so you can drag it to the Trash yourself. It works, but it is one directory at a time and gives you no sizes.</p>",
      },
      { t: "h3", html: "3. From Terminal" },
      { t: "code", text: "rm -rf ~/Library/Developer/Xcode/DerivedData/*" },
      {
        t: "p",
        html:
          "<p>Fast and scriptable, and it bypasses every safety check Worm would apply. There is no confirmation step, no size report and no Trash, so if you have the path slightly wrong you will not find out until it is gone. Use it when you know exactly what you are doing.</p>",
      },
      {
        t: "img",
        src: "/images/screenshot-mac-clean.png",
        width: 1600,
        height: 595,
        alt: "Worm Cleaner running on macOS showing its Clean screen: 2.99 GB reclaimable, a tri-state checkbox beside each cache category, and a per-item list of app caches with exact sizes and full paths including Microsoft Edge at 766.40 MB and Homebrew at 515.96 MB, with caches of running apps flagged \"App is open\" instead of deleted",
        caption: "Worm's Clean screen on macOS. Every cache is listed with its measured size and full path, each one carries its own checkbox, regenerable items are ticked by default, and anything whose owning app is still running is flagged rather than deleted.",
      },
      {
        t: "h2",
        html: "What else should you delete alongside it?",
      },
      {
        t: "table",
        caption: "Xcode-adjacent directories, and whether Worm cleans them",
        head: ["Path", "What it is", "Worm treats it as"],
        rows: [
          ["<code>~/Library/Developer/Xcode/DerivedData</code>", "Compiled intermediate build products", "<span class=\"yes\">Safe</span> &mdash; cleaned"],
          ["<code>~/Library/Developer/Xcode/Products</code>", "Build products from the current workspace", "<span class=\"yes\">Safe</span> &mdash; cleaned"],
          ["<code>~/Library/Caches/com.apple.dt.Xcode</code>", "Xcode's own cache", "<span class=\"yes\">Safe</span> &mdash; cleaned"],
          ["<code>~/Library/Developer/CoreSimulator/Caches</code>", "Simulator runtime caches", "<span class=\"yes\">Safe</span> &mdash; cleaned"],
          ["<code>~/Library/Developer/XCTestDevices</code>", "XCTest device data", "<span class=\"yes\">Safe</span> &mdash; cleaned"],
          ["<code>~/Library/Caches/org.swift.swiftpm</code>", "SwiftPM package cache", "<span class=\"yes\">Re-download</span> &mdash; cleaned"],
          ["<code>~/Library/Developer/Xcode/Archives</code>", "Your distribution archives", "<span class=\"no\">Blocked</span> &mdash; protected"],
          ["<code>~/Library/Developer/Xcode/iOS DeviceSupport</code>", "Symbols for physical devices", "<span class=\"no\">Blocked</span> &mdash; protected"],
          ["<code>~/Library/Developer/CoreSimulator/Profiles/Runtimes</code>", "Installed simulator runtimes", "<span class=\"no\">Blocked</span> &mdash; protected"],
        ],
      },
      {
        t: "p",
        html:
          "<p>The bottom three are the ones most &ldquo;cleaners&rdquo; will happily delete for you. They are not caches in any recoverable sense: an archive holds the binary you already shipped, device support holds symbol files for hardware that may not be re-attached, and simulator runtimes are multi-gigabyte downloads. Worm refuses all three, and <code>SafetyPolicy.swift</code> is where that decision lives.</p>",
      },
      {
        t: "h2",
        html: "Why is Xcode taking so much space?",
      },
      {
        t: "p",
        html:
          "<p>Four usual reasons, in order of how often they are the culprit:</p><ul><li><strong>Accumulated DerivedData across every project you have opened.</strong> Each project gets its own subdirectory, and none are evicted when you stop using them.</li><li><strong>Dependency churn.</strong> Every new version of a Swift package adds index and module data.</li><li><strong>Multiple Xcode versions.</strong> Switching between Xcode releases leaves caches for the ones you no longer use.</li><li><strong>Simulator runtimes.</strong> Each iOS runtime is several gigabytes. Worm will not delete these for you; remove unused ones from Xcode &rarr; Settings &rarr; Platforms instead.</li></ul>",
      },
      {
        t: "h2",
        html: "How to stop it coming back",
      },
      {
        t: "ul",
        items: [
          "Delete DerivedData for a project you have genuinely finished with, rather than letting it accumulate indefinitely.",
          "Prune unused simulator runtimes and device pairs from Xcode &rarr; Settings &rarr; Platforms.",
          "Keep dependencies current — a stale package tree is a large index for code you no longer build.",
          "Run a scan every few weeks. Ten seconds of scanning is cheaper than discovering the problem during a release build.",
        ],
      },
      { t: "faq", faqs: [] },
      CTA,
      {
        t: "related",
        ids: ["/developer-cache-cleaner", "/blog/xcode-disk-space", "/why-is-my-mac-storage-full"],
      },
    ],
    faqs: [
      {
        q: "Is it safe to delete Xcode DerivedData?",
        a: "Yes. DerivedData contains only compiled intermediate files that Xcode regenerates from your source on the next build. Deleting it costs build time — a cold rebuild on a large project can take several minutes — and nothing else. Your source repositories, git history and project files are untouched, because none of them live in that directory. Close Xcode before deleting so the running instance does not write to a folder that is disappearing underneath it.",
      },
      {
        q: "Is it safe to delete Xcode Archives?",
        a: "Do not delete them casually, and know that Worm will not do it for you. Archives hold the distribution binaries you have already shipped or are about to ship, and they cannot be rebuilt from your machine — only re-signed from source, if you still have it. Worm classifies ~/Library/Developer/Xcode/Archives as protected and never offers it as a cleanup target.",
      },
      {
        q: "How do I delete DerivedData from Terminal?",
        a: "Run: rm -rf ~/Library/Developer/Xcode/DerivedData/* — Close Xcode first. This is fast and effective, but it has no confirmation prompt, no size report and no Trash, so a mistyped path is unrecoverable. If you would rather see what you are deleting, run a scan in Worm Cleaner, which reports each target's size and path before anything is removed.",
      },
      {
        q: "How much space does DerivedData usually take?",
        a: "It depends on how many projects you have opened and how often you switch branches. A single active iOS project commonly accumulates several gigabytes, and a machine with a year of accumulated history across many projects can reach tens of gigabytes. Measure rather than estimate — a scan reports the real number for your machine.",
      },
      {
        q: "Does deleting DerivedData break my project or signing?",
        a: "No. DerivedData holds no source code, no project settings and no signing material. Code signing certificates and provisioning profiles live in your login keychain and in ~/Library/MobileDevice, neither of which is a cleanup target. Your project will rebuild and re-sign normally; it will just take longer the first time.",
      },
    ],
  },

  /* ── 3. CleanMyMac alternative ────────────────────────────────────────── */
  {
    href: "/cleanmymac-alternative",
    kind: "page",
    group: "alternative",
    inHeader: true,
    priority: 0.9,
    eyebrow: "No subscription · No ads · Open source",
    title: "Free CleanMyMac Alternative: Open-Source Worm Cleaner",
    navTitle: "CleanMyMac alternative",
    footerTitle: "CleanMyMac alternative",
    crumb: "CleanMyMac alternative",
    description:
      "A free, open-source CleanMyMac alternative for macOS. No subscription, no ads, no telemetry. Clears developer caches and removes app leftovers.",
    imageAlt:
      "Worm Cleaner, a free open-source CleanMyMac alternative, scanning macOS caches",
    h1: "A Free, Open-Source CleanMyMac Alternative",
    lede:
      "<strong>Worm Cleaner is a free, open-source (MIT) alternative to CleanMyMac for macOS 14+.</strong> It does the core job — clearing caches, reclaiming disk space, removing leftover files from uninstalled apps — with no subscription, no advertising, no account and no telemetry in the app. It is also genuinely open: the source for both platforms is on GitHub, so you can read exactly what it deletes.",
    updatedISO: "2026-10-03",
    updatedHuman: "3 October 2026",
    blocks: [
      {
        t: "note",
        variant: "warn",
        html: `<p><strong>Read this before you switch.</strong> Worm Cleaner is a young, independent project and it is <em>narrower</em> than CleanMyMac. It does not do malware scanning, does not optimise the file system, does not manage launch agents or login items, and has no scheduled maintenance. If you rely on those, keep CleanMyMac. If what you want is the cleaning, without the subscription, this is built for that.</p>`,
      },
      {
        t: "h2",
        html: "Why people look for a CleanMyMac alternative",
      },
      {
        t: "p",
        html:
          "<p>The reasons are consistent: the price is a recurring subscription for what is fundamentally a local file operation, the feature list is padded with things a Mac does not need, and you cannot inspect what gets deleted. None of those are complaints about the engineering. They are complaints about the business model and the opacity.</p>",
      },
      {
        t: "table",
        caption: "Where the two differ",
        head: ["", "Worm Cleaner", "CleanMyMac"],
        rows: [
          ["Price", "Free, MIT", "Recurring subscription"],
          ["Source code", "Public, macOS and Windows", "Closed"],
          ["Telemetry in the app", "None, works offline", "<a href=\"https://cleanmymac.com\">See vendor site</a>"],
          ["Developer caches", "Deep &mdash; Xcode, npm, Homebrew, Gradle, 30+ ecosystems", "General purpose"],
          ["App leftovers", "Yes, with absence verification", "Yes"],
          ["Uninstall a Mac app", "Yes, with orphan detection", "Yes"],
          ["Malware scanning", "No", "<a href=\"https://cleanmymac.com\">See vendor site</a>"],
          ["System optimisation tools", "No", "<a href=\"https://cleanmymac.com\">See vendor site</a>"],
          ["Scheduled maintenance", "No", "<a href=\"https://cleanmymac.com\">See vendor site</a>"],
          ["Windows version", "Yes", "No"],
          ["Framework", "Native Swift 6 + SwiftUI", "Native"],
          [`Idle memory`, `Under 35 MB resident (measured)`, "Vendor-reported"],
        ],
      },
      {
        t: "p",
        html:
          "<p><sub>Worm's column is verifiable from its repository. The CleanMyMac column deliberately links to the vendor rather than asserting figures we cannot confirm — check their own site for current terms.</sub></p>",
      },
      {
        t: "h2",
        html: "What Worm Cleaner does instead of the extras",
      },
      {
        t: "p",
        html: `<p>Rather than pad the feature list, Worm spends its effort on the part that actually matters: knowing precisely what is safe to delete.</p><ul><li><strong>Four risk tiers.</strong> Every target is classified Safe, Re-download, Keep or Blocked, and the tier decides its default selection. Your own data is never ticked by default.</li><li><strong>Positive absence verification.</strong> Before flagging an app's leftovers, Worm confirms the app is genuinely uninstalled by checking system locations and Spotlight. A tool that guesses here deletes live applications' settings.</li><li><strong>Trash, not unlink.</strong> macOS deletions go to the Trash, so mistakes are recoverable.</li><li><strong>A real audit log.</strong> Every operation is appended to <code>${AUDIT_LOG_MAC}</code>.</li><li><strong>Protected paths resolved properly.</strong> Personal folders are located through the macOS known-folder APIs, so a relocated or redirected Documents folder is still recognised and still protected.</li></ul>`,
      },
      { t: "h2", html: "Is Worm Cleaner really free?" },
      {
        t: "p",
        html: `<p>Yes — ${PRICE}. There is no pro tier, no scan limit and nothing held back for a paid unlock. It is MIT licensed, so you can also fork it, audit it or build it yourself.</p>`,
      },
      {
        t: "h2",
        html: "Who should not switch",
      },
      {
        t: "p",
        html:
          "<p>Three groups, plainly: if you depend on CleanMyMac's malware scanning, keep it. If you want scheduled or automated cleaning, Worm does not do that yet. And if you are on macOS 13 or earlier, Worm requires 14.0 or later.</p>",
      },
      { t: "faq", faqs: [] },
      CTA,
      {
        t: "related",
        ids: ["/blog/why-i-built-a-cleanmymac-alternative", "/best-free-mac-cleaners", "/mac-storage-cleaner", "/ccleaner-alternative"],
      },
    ],
    faqs: [
      {
        q: "Is Worm Cleaner a good CleanMyMac alternative?",
        a: "For the cleaning itself, yes: it clears the same core categories — caches, logs, leftover app files — with no subscription and no telemetry, and its developer-cache coverage is deeper than most general-purpose cleaners. It is narrower in other ways. It has no malware scanning, no file-system optimisation, no login-item management and no scheduled maintenance. If those features are why you bought CleanMyMac, it is not a straight replacement.",
      },
      {
        q: "Is there a free alternative to CleanMyMac?",
        a: "There are several, and they differ a lot in scope. The honest summary: dedicated open-source tools do cleaning well and do nothing else; broader system-maintenance suites bundle optimisation features that a Mac does not need; and commercial alternatives such as CleanMyMac itself remain subscription-based. Worm Cleaner sits in the first group, with a deeper developer focus and a Windows build.",
      },
      {
        q: "Does Worm Cleaner have ads or upsells?",
        a: "No. There is no advertising, no upsell, no premium tier and no feature unlock. It is MIT licensed and the source is public, which means the paid-version-versus-free-version question cannot arise: there is only one version.",
      },
      {
        q: "Will switching cost me anything?",
        a: "No data migration is involved, because nothing is stored in an account. Uninstall CleanMyMac, install Worm, and if you had set up scheduled scans or maintenance rules there, you will need to run cleaning manually or on your own schedule. That is the one real workflow difference.",
      },
    ],
  },

  /* ── 4. Windows storage cleaner ───────────────────────────────────────── */
  {
    href: "/windows-storage-cleaner",
    kind: "page",
    group: "cleaner",
    inHeader: true,
    priority: 0.85,
    eyebrow: "Windows 10 & 11 · 64-bit",
    title: "Free Windows Storage Cleaner (Open Source) | Worm",
    navTitle: "Windows storage cleaner",
    footerTitle: "Windows storage cleaner",
    crumb: "Windows storage cleaner",
    description:
      "Free open-source Windows junk and storage cleaner. Clears temp files, crash dumps, Recycle Bin and dev caches. 66 scan rules, no ads, no telemetry.",
    imageAlt:
      "Worm Cleaner Windows scan showing 66 scan rules across 12 categories and reclaimable space",
    h1: "Free Windows Storage Cleaner",
    lede:
      "<strong>Worm Cleaner is a free, open-source (MIT) Windows storage cleaner and junk file remover for Windows 10 and 11.</strong> It applies 66 scan rules across 12 categories, groups every result by category with tri-state selection, and puts deleted files in the Recycle Bin so mistakes are recoverable. No ads, no prompts, no telemetry.",
    updatedISO: "2026-10-03",
    updatedHuman: "3 October 2026",
    blocks: [
      {
        t: "p",
        html: "A Windows machine accumulates temp files, crash dumps, browser caches, package-manager caches and Recycle Bin contents continuously. The built-in Storage Sense handles some of it, but it is coarse: coarse categories, no per-item control, and no visibility into what a category actually contains before it goes.",
      },
      {
        t: "h2",
        html: "What the Windows cleaner scans",
      },
      { t: "p", html: `${WINDOWS_CATEGORIES}. Every target carries its own checkbox, and each category has tri-state selection so you can clean one group and skip another.` },
      {
        t: "table",
        caption: "Windows scan categories and examples",
        head: ["Category", "Examples"],
        rows: [
          ["Developer Tools", "npm, pnpm, Yarn, NuGet, pip, Cargo registry, Gradle task output, VS / VS Code / Cursor / JetBrains caches"],
          ["App Caches", "Per-application cache folders, Chromium Code Cache and GPUCache, Explorer thumbnails"],
          ["Browsers", "Chrome, Edge, Brave, Firefox, Opera, Vivaldi &mdash; across every profile, not just Default"],
          ["Cloud &amp; Office", "OneDrive, Dropbox, Teams"],
          ["AI Tools", "Claude Desktop, Codex logs, OpenCode, Copilot"],
          ["Apps &amp; Utilities", "Discord, Slack, Teams webview, Spotify, Figma, Unity Hub, Obsidian, Zoom"],
          ["Virtualization", "Docker Desktop builder cache, WSL, Hyper-V, BlueStacks"],
          ["User Essentials", "Crash dumps, DirectX shader cache"],
          ["System Caches", "%TEMP%, C:\\Windows\\Temp, WER archives, Delivery Optimization, Prefetch"],
          ["Logs", "User log files, application log folders, pending crash reports"],
          ["Recycle Bin", "Measured and emptied across every fixed volume via the Shell API"],
          ["Misc", "Minidumps, superseded installers, diagnostic traces"],
        ],
      },
      {
        t: "p",
        html: `<p>Age gates are applied per rule &mdash; 7 days for logs and temp files, 30 for saved state &mdash; so freshly written files are left alone. Deleted items go to the <strong>Recycle Bin</strong> by default, and every operation is appended to <code>%LOCALAPPDATA%\\Worm\\Logs\\deletions.tsv</code>.</p>`,
      },
      { t: "note", html: WINDOWS_EXCLUSIONS },
      {
        t: "h2",
        html: "How to free up disk space on Windows 11",
      },
      {
        t: "ol",
        items: [
          "Download <code>Worm-Windows-x64.zip</code> and extract it. There is no installer and no admin rights required to run it.",
          "Open the Disk tab to see capacity across every fixed volume, with warnings at 85% and 92%.",
          "Run a scan from the Clean tab. Review the categories and uncheck anything you do not want removed.",
          "Clean. Files go to the Recycle Bin, so anything wrongly included can be restored.",
          "Check the audit log if you want to confirm exactly what was removed and how many bytes it freed.",
        ],
      },
      {
        t: "h2",
        html: "Disk analysis and large-file finder",
      },
      {
        t: "p",
        html:
          "<p>The Disk tab reports capacity per volume, the biggest folders one level into your profile (click to open them), and a large-file finder with an adjustable size threshold. The large-file finder is read-only by design: it reports, it never deletes. A tool that offered to delete your 4 GB video because it was large would be dangerous, and this one declines to be.</p>",
      },
      {
        t: "h2",
        html: "Uninstalling Windows apps properly",
      },
      {
        t: "p",
        html:
          "<p>Worm enumerates installed apps from the <code>HKLM</code> and <code>HKCU</code> uninstall registry keys &mdash; the same list Programs and Features shows &mdash; and lets you sort by size or name and filter as you type. Removal runs each app's <strong>own registered uninstaller</strong>, preferring its quiet command, because hand-deleting an install directory leaves a half-uninstalled app with orphaned services and registry keys. Protected components (Visual Studio, .NET runtimes and SDKs, Microsoft components) cannot be selected, and a running app is blocked until you quit it.</p>",
      },
      {
        t: "h2",
        html: "Clearing Windows crash dumps and WER reports",
      },
      {
        t: "p",
        html:
          "<p>Windows Error Reporting archives, crash dumps and minidumps are genuine reclaimable space and are safe to remove once the problem they describe no longer interests you. Worm targets WER archives, crash dumps, pending crash reports and minidumps with a 7-day age gate, so the dump for a crash you are currently debugging is not thrown away underneath you.</p>",
      },
      { t: "faq", faqs: [] },
      CTA,
      {
        t: "related",
        ids: ["/ccleaner-alternative", "/developer-cache-cleaner", "/uninstall-mac-apps-completely"],
      },
    ],
    faqs: [
      {
        q: "Does Worm Cleaner delete the Windows Update cache (SoftwareDistribution)?",
        a: "No, and that is deliberate. C:\\Windows\\SoftwareDistribution holds Windows Update's download tree, and file age cannot prove an update package is no longer needed — clearing it can leave patching broken in ways that are tedious to recover from. Worm excludes it entirely. To reclaim that space safely, use Settings > System > Storage > Temporary files, or the Disk Cleanup tool that ships with Windows.",
      },
      {
        q: "Is it safe to clean Windows temp files?",
        a: "Generally yes, which is why Worm applies a 7-day age gate to temp files and logs rather than deleting everything in sight. Files currently in use are never deleted, and a running application's cache is flagged rather than silently removed. Deleted items go to the Recycle Bin, so a mistake is recoverable.",
      },
      {
        q: "Does the Windows app need administrator rights?",
        a: "No. Worm-Windows-x64.zip is a portable, extract-and-run build, so you can use it without elevation. Rules that cannot reach a protected location are skipped rather than triggering a UAC prompt mid-scan.",
      },
      {
        q: "How do I free up disk space on Windows 11 fast?",
        a: "Start with the Recycle Bin and System Caches categories, which are usually the largest safe wins on a machine that has been running a while. Then check Developer Tools if you build software, and Apps & Utilities if you use Discord, Slack or Teams daily. Run the scan first — it reports the size of every category, so you can aim at the biggest one instead of guessing.",
      },
      {
        q: "Is a Windows cleaner without ads actually free?",
        a: "Yes. Worm Cleaner is MIT licensed, with no advertising, no upsell, no premium tier and no scan limit. It is also open source, so the absence of ads is verifiable in the repository rather than merely promised.",
      },
    ],
  },

  /* ── 5. CCleaner alternative ──────────────────────────────────────────── */
  {
    href: "/ccleaner-alternative",
    kind: "page",
    group: "alternative",
    priority: 0.8,
    eyebrow: "No ads · No prompts · Open source",
    title: "Open-Source CCleaner Alternative for Windows: Worm",
    navTitle: "CCleaner alternative",
    footerTitle: "CCleaner alternative",
    crumb: "CCleaner alternative",
    description:
      "A free, open-source CCleaner alternative for Windows 10 and 11. No ads, no prompts, no telemetry. 66 scan rules and a real app uninstaller.",
    imageAlt:
      "Worm Cleaner, an open-source CCleaner alternative, listing 66 Windows scan rules by category",
    h1: "An Open-Source CCleaner Alternative for Windows",
    lede:
      "<strong>Worm Cleaner is a free, open-source (MIT) alternative to CCleaner for Windows 10 and 11.</strong> It runs 66 scan rules across 12 categories with full per-item control, sends deletions to the Recycle Bin, and includes a real uninstaller that runs each app's own registered uninstall string. No advertising, no nag prompts, no telemetry.",
    updatedISO: "2026-10-03",
    updatedHuman: "3 October 2026",
    blocks: [
      {
        t: "h2",
        html: "Why people look for a CCleaner alternative",
      },
      {
        t: "p",
        html:
          "<p>Mostly advertising and prompting. The cleaning itself is not hard; being told what will be deleted, and being able to refuse it, is the part worth paying attention to. Worm was built around that: everything is listed with its size and path, every target has its own checkbox, categories have tri-state selection, and nothing is removed that you have not selected.</p>",
      },
      {
        t: "table",
        caption: "Worm Cleaner compared with CCleaner",
        head: ["", "Worm Cleaner", "CCleaner"],
        rows: [
          ["Price", "Free, MIT", "Free tier + paid Pro"],
          ["Source code", "Public", "Closed"],
          ["Advertising", "None", "<a href=\"https://www.ccleaner.com\">See vendor site</a>"],
          ["Telemetry in the app", "None, works offline", "<a href=\"https://www.ccleaner.com\">See vendor site</a>"],
          ["Scan rules", "66 across 12 categories", "Vendor-reported"],
          ["Per-item checkboxes", "Yes, every target", "Category-level"],
          ["Deleted items go to", "Recycle Bin", "Recycle Bin"],
          ["Audit log", "Yes, TSV, per operation", "Partial"],
          ["Uninstaller runs vendor uninstaller", "Yes", "Yes"],
          ["Disk analysis &amp; large-file finder", "Yes, read-only", "Partial"],
          ["Windows Update cache", "<span class=\"no\">Excluded by design</span>", "Offered"],
          ["Registry cleaning", "No", "Yes"],
          ["Framework", ".NET 9 AOT + WPF", "Native"],
          [`Idle memory`, "Under 42 MB (measured)", "Vendor-reported"],
        ],
      },
      {
        t: "p",
        html:
          "<p><sub>Worm's column is verifiable from the repository. CCleaner's column links to the vendor rather than asserting figures we cannot confirm.</sub></p>",
      },
      { t: "h2", html: "Where Worm is the weaker choice" },
      {
        t: "p",
        html:
          "<p>Two genuine gaps, stated plainly. <strong>Registry cleaning:</strong> Worm does not touch the registry. Registry cleaning tools have a deservedly poor reputation, and a cleaner that cannot prove a key is orphaned should not be editing it &mdash; but if you relied on that feature, you will miss it. <strong>Browser and app &ldquo;privacy&rdquo; cleaners:</strong> Worm clears caches but does not strip cookies or fingerprinting data, because deleting cookies logs you out of everything and rarely helps.</p>",
      },
      {
        t: "h2",
        html: "The safety model, in detail",
      },
      {
        t: "p",
        html: `<p>Eight rules govern what can be deleted on Windows, all of them in source you can read:</p><ul><li><strong>Inspect before action.</strong> Cleaning touches only ticked items.</li><li><strong>Protected paths</strong> are resolved through the Windows known-folder registry keys, so a relocated OneDrive or domain-redirected Documents folder is still protected. Matching is prefix-aware and case-insensitive.</li><li><strong>Running processes warn, they do not silently pass.</strong> An open file handle is never deleted.</li><li><strong>Recycle Bin first.</strong> Recoverable by default.</li><li><strong>Registry cross-check on orphans.</strong> Leftovers are proven by token matching against every registered app plus a check against each install location &mdash; deliberately not substring matching, which both hid real orphans and flagged live ones.</li><li><strong>Local audit log.</strong> Every destructive operation appended to <code>%LOCALAPPDATA%\\Worm\\Logs\\deletions.tsv</code>.</li><li><strong>Blast-radius allowlist.</strong> Every path a rule produces is checked against a cleanable-root set derived from the rules themselves, so a wrong rule still cannot delete outside a folder the catalog declares cleanable.</li><li><strong>Open source.</strong> Verify it yourself.</li></ul>`,
      },
      {
        t: "h2",
        html: "What the system tray shows",
      },
      {
        t: "p",
        html:
          "<p>Left-click the tray icon for a live panel: CPU, memory, free disk, uptime and total bytes reclaimed. The reclaimed figure is read back from the audit log, so it only ever reports bytes that were genuinely removed &mdash; not an estimate, and not a running total that drifts.</p>",
      },
      { t: "faq", faqs: [] },
      CTA,
      {
        t: "related",
        ids: ["/windows-storage-cleaner", "/developer-cache-cleaner", "/is-worm-cleaner-safe"],
      },
    ],
    faqs: [
      {
        q: "Is there a free CCleaner alternative without ads?",
        a: "Yes. Worm Cleaner is MIT licensed and open source, with 66 scan rules across 12 categories, per-item checkboxes, Recycle Bin deletion and a local audit log. It has no advertising and no upsell, and because the source is public you can confirm the absence of both rather than taking it on trust.",
      },
      {
        q: "Does Worm Cleaner clean the Windows registry?",
        a: "No. It does not modify the registry at all. Registry cleaning has a deservedly poor reputation because a tool cannot reliably prove a key is orphaned, and 'cleaning' a live key causes exactly the kind of breakage users then blame on malware. Worm does read the uninstall registry keys, but only to enumerate installed apps and to cross-check leftovers.",
      },
      {
        q: "Is Worm Cleaner safe on Windows 11?",
        a: "Yes. Deleted files go to the Recycle Bin, running processes are flagged rather than deleted through, open file handles are never removed, and every path is checked against a cleanable-root allowlist derived from the scan rules themselves. Personal folders are resolved through the known-folder registry keys so a redirected Documents folder is still protected. It is also portable and needs no administrator rights.",
      },
      {
        q: "Why does Worm Cleaner skip the Windows Update cache?",
        a: "Because file age cannot prove an update package is unused. Clearing C:\\Windows\\SoftwareDistribution while an update is staged can leave Windows unable to install it, and recovering from that is a long manual process. Worm excludes the tree by design. Use Settings > System > Storage > Temporary files, or the built-in Disk Cleanup, if you want that space.",
      },
    ],
  },

  /* ── 6. Uninstall Mac apps completely ─────────────────────────────────── */
  {
    href: "/uninstall-mac-apps-completely",
    kind: "page",
    group: "cleaner",
    priority: 0.85,
    eyebrow: "macOS · Complete uninstall",
    title: "Uninstall Mac Apps Completely and Remove Leftovers",
    navTitle: "Uninstall Mac apps",
    footerTitle: "Uninstall Mac apps completely",
    crumb: "Uninstall Mac apps completely",
    description:
      "Remove leftover files, preferences and caches from uninstalled Mac apps. Worm verifies an app is really gone before flagging its files.",
    imageAlt:
      "Worm Cleaner listing orphaned preference plists and Application Support folders left by uninstalled Mac apps",
    h1: "Uninstall Mac Apps Completely and Remove Their Leftovers",
    lede:
      "<strong>Dragging a Mac app to the Trash does not uninstall it.</strong> macOS leaves behind preference plists, Application Support databases, caches, saved application state and container directories, all keyed to the app's bundle identifier. Worm Cleaner finds those orphans, proves the app is genuinely uninstalled before flagging anything, and removes the leftovers in one reviewed pass.",
    updatedISO: "2026-10-03",
    updatedHuman: "3 October 2026",
    blocks: [
      {
        t: "h2",
        html: "What is left behind when you uninstall a Mac app",
      },
      {
        t: "p",
        html: `<p>Deleting <code>/Applications/SomeApp.app</code> removes one directory. The app's data lives in five other places, and macOS never asks whether you want them:</p><ul><li><code>~/Library/Application Support/</code> &mdash; the app's databases, documents and state</li><li><code>~/Library/Preferences/</code> &mdash; its <code>.plist</code> settings</li><li><code>~/Library/Caches/</code> &mdash; cached responses, thumbnails, downloads</li><li><code>~/Library/Saved Application State/</code> &mdash; window restoration data</li><li><code>~/Library/WebKit/</code> and <code>~/Library/Containers/</code> &mdash; sandboxed storage</li></ul><p>Over a few years that is several gigabytes of directories belonging to apps you removed years ago and cannot name.</p>`,
      },
      {
        t: "h2",
        html: "What are orphaned app files?",
      },
      {
        t: "p",
        html:
          "<p>Orphaned app files are files that belong to an application which is no longer installed. The definition sounds trivial, and getting it wrong is the entire risk: if a tool flags files belonging to an app you still use, it will happily delete that app's settings, offline data or login state.</p>" +
          "<p>This is why Worm does not identify orphans by pattern-matching folder names. It performs <strong>positive absence verification</strong>: it checks for the app bundle in system locations and queries Spotlight to confirm the application is really gone before any of its files are offered as a target.</p>",
      },
      {
        t: "h2",
        html: "How to remove leftovers step by step",
      },
      {
        t: "ol",
        items: [
          "Uninstall the app normally first &mdash; run its own uninstaller or drag the bundle to the Trash and empty it.",
          "Open Worm and go to the Leftovers section. It scans Application Support, Preferences, Caches, Saved Application State and WebKit for bundle identifiers with no matching installed app.",
          "Review each entry. Every folder is listed with its size and full path, and each carries its own checkbox.",
          "Select only what you want removed. Untick anything whose purpose you cannot identify.",
          "Clean. Items go to the Trash, and the operation is logged.",
        ],
      },
      {
        t: "h2",
        html: "Why not just use AppCleaner?",
      },
      {
        t: "table",
        caption: "Worm's uninstall approach compared with the common manual method",
        head: ["", "Worm Cleaner", "Manual / AppCleaner-style"],
        rows: [
          ["Confirms the app is uninstalled", "Yes &mdash; bundle paths plus Spotlight", "Varies"],
          ["Shows size and path per item", "Yes, every folder", "Usually a flat list"],
          ["Per-item checkbox", "Yes", "Yes"],
          ["Also clears developer caches", "Yes", "No"],
          ["Also has a system monitor", "Yes", "No"],
          ["Windows leftover cleanup", "Yes, with token matching", "No"],
          ["Open source", "Yes, MIT", "No"],
          ["Price", "Free", "Free"],
        ],
      },
      {
        t: "p",
        html:
          "<p>AppCleaner is a perfectly good single-purpose tool and remains a reasonable choice if removing one app's leftovers is all you need. Worm covers that case and adds the caches, the monitor and a Windows build &mdash; which matters most if you own both machines.</p>",
      },
      {
        t: "h2",
        html: "Is it safe to delete app leftovers?",
      },
      {
        t: "p",
        html:
          `<p>For a confirmed orphan, yes. The app is not installed, so nothing can read those files. The risk is entirely in the &ldquo;confirmed&rdquo; part, which is why Worm verifies absence rather than guessing from folder names.</p>${RECOVERY}`,
      },
      { t: "faq", faqs: [] },
      CTA,
      {
        t: "related",
        ids: ["/mac-storage-cleaner", "/developer-cache-cleaner", "/is-worm-cleaner-safe"],
      },
    ],
    faqs: [
      {
        q: "How do I completely uninstall a Mac app?",
        a: "Delete the .app bundle from /Applications, then remove what it left behind in ~/Library/Application Support, ~/Library/Preferences, ~/Library/Caches, ~/Library/Saved Application State and ~/Library/WebKit. Those directories are keyed to the app's bundle identifier and macOS never prompts about them. Worm Cleaner automates exactly this and verifies the app is genuinely uninstalled first.",
      },
      {
        q: "What are orphaned app files?",
        a: "Files that belong to an application which is no longer installed — preference plists, Application Support databases, caches and container directories left behind when an app is deleted. They accumulate silently because macOS never asks whether you want them. Removing them is safe once the app is confirmed absent, which is the step most automated tools get wrong.",
      },
      {
        q: "Does deleting app leftovers speed up my Mac?",
        a: "Not directly. It frees disk space and reduces clutter, which is genuinely useful on a full drive, but it does not make the system faster. A leftover directory sitting idle costs almost nothing in CPU or memory. The benefit is capacity, and a tidier Applications folder.",
      },
      {
        q: "Is there an AppCleaner alternative that is free?",
        a: "Worm Cleaner removes uninstalled-app leftovers for free and is open source, and it additionally clears developer caches and includes a system monitor. AppCleaner remains a good single-purpose choice if you only ever want to remove one app's leftovers. On Windows, Worm also detects orphaned AppData folders using token matching against registered apps.",
      },
      {
        q: "Will removing leftovers log me out of my apps or lose data?",
        a: "It can, if the app is still installed — which is why Worm confirms absence through system paths and Spotlight before flagging anything. For a genuinely uninstalled app there is nothing to log out of. Reviewing each entry's path before ticking it is the safeguard, and every item is individually selectable for that reason.",
      },
    ],
  },

  /* ── 7. Developer cache cleaner ───────────────────────────────────────── */
  {
    href: "/developer-cache-cleaner",
    kind: "page",
    group: "cleaner",
    priority: 0.85,
    eyebrow: "30+ developer ecosystems",
    title: "Developer Cache Cleaner for npm, Homebrew, Gradle",
    navTitle: "Developer cache cleaner",
    footerTitle: "Developer cache cleaner",
    crumb: "Developer cache cleaner",
    description:
      "Clean developer caches across npm, pnpm, Yarn, Homebrew, Gradle, pip, Composer, Terraform, kubectl and more. Sizes shown before deletion.",
    imageAlt:
      "Developer cache cleaner showing npm, Yarn, Homebrew and Gradle cache sizes grouped by package manager",
    h1: "Developer Cache Cleaner for npm, Homebrew, Gradle and More",
    lede:
      "<strong>Worm Cleaner is a developer cache cleaner for macOS that covers more than thirty package ecosystems.</strong> It finds npm, pnpm, Yarn, Homebrew, Gradle, pip, uv, Poetry, Composer, RubyGems, Cargo-adjacent build caches, Terraform, kubectl and Electron leftovers, reports the size of each, and only deletes what you tick.",
    updatedISO: "2026-10-03",
    updatedHuman: "3 October 2026",
    blocks: [
      {
        t: "p",
        html:
          "<p>General-purpose cleaners treat <code>~/.npm</code> and <code>~/.gradle</code> as one undifferentiated blob, if they see them at all. That is why developers keep hitting a full disk: the caches that matter are the ones nobody surfaces individually. Worm's scan catalog enumerates them as separate labelled targets, each with a real size.</p>",
      },
      {
        t: "h2",
        html: "What it cleans, by ecosystem",
      },
      MACOS_CLEAN_TABLE,
      {
        t: "h2",
        html: "Is it safe to clear these caches?",
      },
      {
        t: "p",
        html:
          "<p>Package-manager caches are re-downloadable, which makes them safe in the technical sense but not free: clearing npm costs you a re-download of every dependency, and on a metered or slow connection that is a real cost. This is why Worm separates them into the <strong>Safe</strong> and <strong>Re-download</strong> tiers and shows the badge, so you can clear the free wins without paying for the downloads.</p>" +
          RISK_MODEL,
      },
      {
        t: "h2",
        html: "How Worm compares to the native commands",
      },
      {
        t: "p",
        html:
          "<p>The native tools are good and Worm does not replace them — it complements them. <code>npm cache clean --force</code> clears npm's cache in one shot but reports nothing before or after. <code>brew cleanup</code> prunes old versions and downloads. <code>gradle --stop</code> and a manual <code>rm -rf ~/.gradle/caches</code> are the common approaches. What none of them do is tell you, across all ecosystems at once, which caches are large enough to be worth the rebuild cost.</p>" +
          "<p>Worm's contribution is the inventory: one scan, every cache measured, then you decide which native commands are worth running.</p>",
      },
      {
        t: "h2",
        html: "How to clean developer caches safely",
      },
      {
        t: "ol",
        items: [
          "Close your editors and build tools. Targets in use are flagged by a liveness probe rather than deleted underneath a running process.",
          "Run a scan. Developer Tools is the relevant category; expand it to see every labelled cache with its size.",
          "Start with the <strong>Safe</strong> tier &mdash; regenerable caches cost only time.",
          "Treat the <strong>Re-download</strong> tier as a deliberate choice. If you are on a slow connection, leave them.",
          "Clean, then check <code>~/Library/Logs/Worm/deletions.tsv</code> to see exactly what went.",
        ],
      },
      {
        t: "h2",
        html: "Docker, WSL and virtualisation caches",
      },
      {
        t: "p",
        html:
          "<p>On Windows, Worm cleans the Docker Desktop builder cache and dangling image layers, alongside WSL, Hyper-V and BlueStacks targets. On macOS, Docker is <strong>reported read-only rather than cleaned</strong> &mdash; image layers and container state are easy to misjudge, so the scan surfaces them for you to inspect without offering them as deletion targets.</p>",
      },
      { t: "faq", faqs: [] },
      CTA,
      {
        t: "related",
        ids: ["/clear-xcode-deriveddata", "/windows-storage-cleaner", "/mac-storage-cleaner"],
      },
    ],
    faqs: [
      {
        q: "Can I delete the npm cache?",
        a: "Yes. The npm cache in ~/.npm/_cacache holds downloaded tarballs, not your projects or node_modules. Deleting it is safe and costs a re-download of dependencies on your next install. Use `npm cache clean --force` if you want npm's own tooling, or clear it in Worm if you would rather see its size first and clear it alongside your other caches.",
      },
      {
        q: "Is it safe to clear the Homebrew cache?",
        a: "Yes. Homebrew's downloads folder holds installer files it has already used. Clearing it is safe — Homebrew re-downloads anything it needs again. The `brew cleanup` command also prunes old installed versions and stale downloads; Worm clears the downloads cache as part of a scan so you can see its size alongside everything else.",
      },
      {
        q: "What is the safest developer cache to clear first?",
        a: "Anything in the Safe tier, which is regenerable rather than re-downloadable. Xcode DerivedData, the Gradle build cache, npm logs and cache directories are the usual large wins. Hold off on package tarball caches such as npm _cacache or Homebrew downloads if your connection is slow, since clearing those means re-downloading.",
      },
      {
        q: "Does cleaning caches break my projects?",
        a: "No. Caches are disposable by definition, and Worm never targets source repositories, git history, project files or node_modules. The realistic cost is a slower next build or install. Run Simulation-style review first — every target is listed with its path and size before anything is deleted, and running processes are flagged rather than cleaned through.",
      },
      {
        q: "How do I free space for development?",
        a: "Scan with the Developer Tools category expanded and sort by size. The largest caches are almost always the ones you have forgotten about: a Gradle build cache from a project you stopped working on, npm tarballs from a package you stopped using, or Xcode DerivedData from a client project that ended months ago.",
      },
    ],
  },

  /* ── 8. Is Worm Cleaner safe ──────────────────────────────────────────── */
  {
    href: "/is-worm-cleaner-safe",
    kind: "page",
    group: "guide",
    inHeader: true,
    priority: 0.95,
    eyebrow: "Trust · Verification · Transparency",
    title: "Is Worm Cleaner Safe? Not Malware, MIT Open Source",
    navTitle: "Is Worm Cleaner safe?",
    footerTitle: "Is Worm Cleaner safe?",
    crumb: "Is Worm Cleaner safe?",
    description:
      "Worm Cleaner is a legitimate MIT-licensed disk cleaner, not malware. Full source on GitHub, no network calls, Trash and Recycle Bin by default.",
    imageAlt:
      "Worm Cleaner open source repository and SHA-256 checksums for verifying the download",
    h1: "Is Worm Cleaner Safe?",
    lede:
      "<strong>Worm Cleaner is not malware and not a self-replicating computer worm.</strong> It is a legitimate MIT-licensed disk cleaning utility with public source code for both macOS and Windows. It does not copy itself, does not modify other files, and makes no network calls while cleaning. This page exists so you can verify all of that rather than take it on trust.",
    updatedISO: "2026-10-03",
    updatedHuman: "3 October 2026",
    blocks: [
      {
        t: "note",
        html: `<p><strong>The honest summary.</strong> A tool called &ldquo;Worm&rdquo; that deletes files deserves scepticism, and you should not take a stranger's word for it. Everything below is a step you can perform yourself in a few minutes.</p>`,
      },
      { t: "h2", html: "Is Worm Cleaner malware?" },
      { t: "p", html: NOT_MALWARE_ANSWER },
      {
        t: "p",
        html:
          "<p>Two things make this verifiable rather than merely asserted. First, the source is public under a permissive licence, so the entire behaviour of both apps is readable &mdash; there is no closed binary whose behaviour you have to take on faith. Second, a cleaner that deletes files is trivially dangerous if it has network access, and Worm's has none during cleaning.</p>",
      },
      { t: "h2", html: "How to verify the download yourself" },
      {
        t: "h3",
        html: "1. Check the SHA-256 checksum",
      },
      {
        t: "p",
        html:
          "Every published release includes checksums, both in GitHub Releases and on this site. Compare the digest of what you downloaded against the published value:",
      },
      { t: "code", text: "# macOS\nshasum -a 256 ~/Downloads/Worm-Installer.dmg\n\n# Windows PowerShell\nGet-FileHash -Algorithm SHA256 Worm-Windows-x64.zip" },
      {
        t: "p",
        html: "<p>The published digests for v1.0.4:</p>",
      },
      { t: "code", text: CHECKSUMS },
      {
        t: "p",
        html: `<p>They are also served as a plain-text file at <a href="/SHA256SUMS.txt">/SHA256SUMS.txt</a>. If a digest does not match, do not run the file.</p>`,
      },
      { t: "h3", html: "2. Read the source, or build it" },
      {
        t: "p",
        html:
          `<p>The whole project is at <a href="https://github.com/namdevnaman/worm">github.com/namdevnaman/worm</a>. You can read the scan catalog and the safety policy directly &mdash; <code>Sources/WormCore/ScanCatalog.swift</code> is the complete list of what can be deleted, and <code>Sources/WormCore/SafetyPolicy.swift</code> is the complete list of what is protected. If you would rather not read Swift, build it yourself:</p>`,
      },
      { t: "code", text: "git clone https://github.com/namdevnaman/worm.git\ncd worm\nswift build -c release" },
      { t: "h3", html: "3. Watch the network" },
      {
        t: "p",
        html:
          "<p>Run Worm under Little Snitch or Wireshark while it scans and cleans. You will see no outbound connections during cleaning. On macOS the only network call in the whole app is the optional update check, and it stays off until you ask for it.</p>",
      },
      { t: "h2", html: "Why does macOS warn me? (And why that is expected)" },
      { t: "note", html: GATEKEEPER },
      {
        t: "img",
        src: "/images/screenshot-mac-clean.png",
        width: 1600,
        height: 595,
        alt: "Worm Cleaner running on macOS showing its Clean screen: 2.99 GB reclaimable, a tri-state checkbox beside each cache category, and a per-item list of app caches with exact sizes and full paths including Microsoft Edge at 766.40 MB and Homebrew at 515.96 MB, with caches of running apps flagged \"App is open\" instead of deleted",
        caption: "Worm's Clean screen on macOS. Every cache is listed with its measured size and full path, each one carries its own checkbox, regenerable items are ticked by default, and anything whose owning app is still running is flagged rather than deleted.",
      },
      { t: "h2", html: "How Worm protects your files" },
      {
        t: "ol",
        items: [
          "<strong>Inspect before action.</strong> Every target is listed with a per-item checkbox, and cleaning touches only what you ticked.",
          "<strong>Protected paths.</strong> Personal folders are resolved through the macOS known-folder APIs and the Windows known-folder registry keys, so a relocated OneDrive or a domain-redirected Documents folder is still protected. Matching is prefix-aware and case-insensitive.",
          "<strong>Running processes warn.</strong> An app's cache is cleanable but flagged; an open file handle is never deleted.",
          "<strong>Trash first on macOS, Recycle Bin first on Windows.</strong> Recoverable by default.",
          "<strong>Absence verification before flagging leftovers.</strong> Only proven orphans are offered.",
          "<strong>Local audit log.</strong> Every destructive operation is appended to a plain-text TSV you can read yourself.",
          "<strong>Blast-radius allowlist.</strong> Every path a rule produces is checked against a cleanable-root set derived from the rules themselves, so even a wrong rule cannot delete outside a folder the catalog declares cleanable.",
          "<strong>Risk tiers.</strong> Regenerable caches default on; your own data defaults off and needs an explicit opt-in; non-rebuildable and system-owned paths are blocked outright.",
          "<strong>Open source.</strong> Read the code, build it yourself, verify the claims.",
        ],
      },
      { t: "h2", html: "What Worm will never delete" },
      {
        t: "table",
        caption: "Deliberately excluded paths",
        head: ["Path", "Why it is protected"],
        rows: [
          ["<code>~/Library/Developer/Xcode/Archives</code>", "Holds shipped distribution binaries; not rebuildable from the machine"],
          ["<code>~/Library/Developer/Xcode/iOS DeviceSupport</code>", "Symbol bundles for physical devices"],
          ["<code>~/Library/Developer/CoreSimulator/Profiles/Runtimes</code>", "Installed simulator runtimes; multi-gigabyte re-download"],
          ["<code>C:\\Windows\\SoftwareDistribution</code>", "Windows Update download tree; age cannot prove inactivity"],
          ["Your personal folders", "Resolved via known-folder APIs and prefix-matched, case-insensitively"],
          ["Visual Studio, .NET runtimes and SDKs", "Protected components; cannot be uninstalled from the app list"],
          ["Anything classified <code>Keep</code>", "Your content, not a cache. Off by default, explicit opt-in required"],
        ],
      },
      { t: "h2", html: "The privacy question, precisely" },
      { t: "p", html: TELEMETRY_ANSWER },
      {
        t: "p",
        html: `<p>Memory footprint is also worth stating plainly rather than rounding down: ${IDLE_RAM}.</p>`,
      },
      { t: "h2", html: "Where you can report a problem" },
      {
        t: "p",
        html:
          `<p>Security issues go to the repository's <a href="https://github.com/namdevnaman/worm/security/advisories">private security advisory</a> rather than a public issue. Everything else is on the <a href="https://github.com/namdevnaman/worm/issues">issue tracker</a>, and both are read.</p>`,
      },
      { t: "faq", faqs: [] },
      CTA,
      {
        t: "related",
        ids: ["/cleanmymac-alternative", "/ccleaner-alternative", "/best-free-mac-cleaners"],
      },
    ],
    faqs: [
      {
        q: "Is Worm Cleaner malware, or a computer worm?",
        a: NOT_MALWARE_ANSWER,
      },
      {
        q: "How do I verify that a Worm download is genuine?",
        a: "Compare its SHA-256 digest against the published checksums, which appear both in GitHub Releases and at /SHA256SUMS.txt on this site. Run `shasum -a 256 Worm-Installer.dmg` on macOS or `Get-FileHash -Algorithm SHA256 Worm-Windows-x64.zip` in PowerShell. Beyond that, read the source at github.com/namdevnaman/worm or build it yourself with `swift build -c release`.",
      },
      {
        q: "Why does macOS say it cannot verify Worm is free of malicious software?",
        a: "Because Worm is not notarised with an Apple Developer ID — it is an independent project without a paid Apple Developer account, so the build carries no notarisation ticket and Gatekeeper blocks it on first open. That is a packaging gap, not a security finding. Open it via System Settings > Privacy & Security > Open Anyway, or clear the quarantine flag with `xattr -cr /Applications/Worm.app`.",
      },
      {
        q: "Does Worm Cleaner collect any telemetry or personal information?",
        a: TELEMETRY_ANSWER,
      },
      {
        q: "Can I undo a cleanup?",
        a: RECOVERY,
      },
      {
        q: "Is it safe to delete the caches Worm lists?",
        a: "The safe ones, yes — they are regenerable or re-downloadable by definition, which is why each target carries a risk tier and regenerable caches are ticked by default. The distinction that matters is between a cache and something you cannot rebuild: Worm blocks Xcode Archives, iOS DeviceSupport, simulator runtimes and the Windows Update tree precisely because deleting those loses data. Your own files are classified Keep, which is off by default and requires an explicit opt-in.",
      },
    ],
  },

  /* ── 9. macOS system monitor ──────────────────────────────────────────── */
  {
    href: "/mac-system-monitor",
    kind: "page",
    group: "cleaner",
    priority: 0.7,
    eyebrow: "Native Swift · Menu bar",
    title: "Free Menu Bar System Monitor for Mac (CPU & RAM)",
    navTitle: "Mac system monitor",
    footerTitle: "Mac system monitor",
    crumb: "Mac system monitor",
    description:
      "A lightweight menu bar system monitor for macOS showing CPU, memory, disk and thermals. Native Swift, under 35 MB resident while idle.",
    imageAlt:
      "Worm Cleaner menu bar item showing live CPU, memory, disk and thermal readouts on macOS",
    h1: "Free Menu Bar System Monitor for Mac",
    lede:
      "<strong>Worm Cleaner includes a free menu bar system monitor for macOS</strong> that shows live CPU load, a memory breakdown, disk capacity and thermal status directly in the menu bar. It is written in native Swift 6 and SwiftUI, sits under 35 MB resident while idle, and is part of an app you may already have installed for cleaning.",
    updatedISO: "2026-10-03",
    updatedHuman: "3 October 2026",
    blocks: [
      {
        t: "p",
        html:
          "<p>Most Mac menu bar monitors are an Electron app in a 40 MB wrapper, and many of them upload usage data as a side effect of being distributed through an analytics-funded model. Activity Monitor itself is excellent and free, but it is a window you have to open and close rather than a persistent glanceable readout.</p>",
      },
      { t: "h2", html: "What the menu bar monitor shows" },
      {
        t: "ul",
        items: [
          "<strong>CPU</strong> &mdash; live per-core load and the process count.",
          "<strong>Memory</strong> &mdash; broken down as App, Wired and Compressed, which is the split that actually tells you whether you have a memory problem.",
          "<strong>Disk</strong> &mdash; current capacity and total space reclaimed.",
          "<strong>Thermals</strong> &mdash; thermal and fan status.",
          "<strong>Interaction</strong> &mdash; left-click for live metrics, right-click for the context menu.",
        ],
      },
      {
        t: "h2",
        html: "How much memory does it use?",
      },
      {
        t: "p",
        html: `<p>${IDLE_RAM}. That is measured on the author's machines rather than estimated, and it is the main practical difference from an Electron-based monitor. The App / Wired / Compressed breakdown it displays is a macOS-specific nicety: <strong>Wired</strong> and <strong>Compressed</strong> are memory the system cannot simply reclaim on demand, and noticing Compressed climbing is often the first sign that you need more RAM rather than more cleaning.</p>`,
      },
      {
        t: "h2",
        html: "Lightweight system monitors compared",
      },
      {
        t: "table",
        caption: "Free Mac system monitors",
        head: ["", "Worm Cleaner monitor", "Typical Electron monitor", "Activity Monitor"],
        rows: [
          ["Price", "Free, MIT", "Free or paid", "Free, built in"],
          ["Distribution", "Native Swift 6 + SwiftUI", "Electron / web wrapper", "System binary"],
          [`Idle memory`, "Under 35 MB (measured)", "180&ndash;450 MB", "Varies"],
          ["Opens in a menu bar", "Yes", "Yes", "No, window only"],
          ["Memory split App/Wired/Compressed", "Yes", "Varies", "Yes"],
          ["Thermal and fan status", "Yes", "Rarely", "Yes"],
          ["Bundled with a cleaner", "Yes", "Sometimes", "No"],
          ["Source code", "Public, MIT", "Usually closed", "Closed"],
        ],
      },
      {
        t: "p",
        html: `<p>If you only want monitoring and will never clean anything, Activity Monitor is the right answer and costs nothing. Worm's monitor earns its place if you want the readouts <em>and</em> the cleaner in one native app.</p>`,
      },
      { t: "h2", html: "Windows equivalent" },
      {
        t: "p",
        html:
          "<p>The Windows build has the same feature in the system tray: CPU via <code>GetSystemTimes</code>, RAM via <code>GlobalMemoryStatusEx</code>, total/free/used space across every mounted NTFS, FAT32 and exFAT volume, top processes by working set, and system facts including edition, build, architecture, core count and uptime. It also runs health checks for disk, memory and CPU with OK / Notice / Action needed. The reclaimed-bytes figure is read back from the audit log, so it only ever reports bytes genuinely removed.</p>",
      },
      {
        t: "note",
        html: `<p><strong>If your menu bar icon is missing</strong> after installing, a menu bar manager such as Bartender, Ice or Hidden Bar may be hiding it.</p>`,
      },
      { t: "faq", faqs: [] },
      CTA,
      {
        t: "related",
        ids: ["/windows-storage-cleaner", "/mac-storage-cleaner", "/why-is-my-mac-storage-full"],
      },
    ],
    faqs: [
      {
        q: "What is the best menu bar system monitor for Mac?",
        a: "If you want a glanceable persistent readout, a native menu bar monitor is the right category, and the deciding factors are idle memory and whether it has a telemetry story. Worm's is included free with the cleaner, is native Swift, and sits under 35 MB resident while idle. If you do not need cleaning at all, Activity Monitor is built in, free and excellent — it is just a window rather than a menu bar item.",
      },
      {
        q: "Is there a lightweight system monitor for Windows too?",
        a: "Yes, in the Windows build of the same app. The system tray panel shows CPU, memory, free disk, uptime and total bytes reclaimed, and a hardware monitor reports CPU utilisation, RAM usage, per-volume space, top processes by working set and system facts, plus OK / Notice / Action needed health checks for disk, memory and CPU.",
      },
      {
        q: "How much memory does a menu bar monitor use?",
        a: "Worm's monitor is under 35 MB resident on macOS while idle, measured on the author's machines. Electron-based monitors typically sit between 180 and 450 MB. The gap matters most on an older Mac, where the difference between a native and an Electron app is the difference between noticing and not noticing the monitor.",
      },
      {
        q: "Does the system monitor send my usage data anywhere?",
        a: "No. The app has no analytics and makes no network calls during normal operation. The only network call in the macOS app is the optional update check, and it is off until you request it. The Windows build behaves the same way.",
      },
    ],
  },

  /* ── 10. Best free Mac cleaners ───────────────────────────────────────── */
  {
    href: "/best-free-mac-cleaners",
    kind: "page",
    group: "guide",
    priority: 0.8,
    eyebrow: "Honest comparison · 2026",
    title: "Best Free Mac Cleaners in 2026: An Honest Comparison",
    navTitle: "Best free Mac cleaners",
    footerTitle: "Best free Mac cleaners",
    crumb: "Best free Mac cleaners",
    description:
      "Comparing free Mac cleaners on price, openness, footprint and what they actually clean — including where Worm Cleaner is the weaker choice.",
    imageAlt:
      "Comparison of free Mac cleaners by price, open-source status, memory footprint and features",
    h1: "Best Free Mac Cleaners in 2026",
    lede:
      "<strong>There are several genuinely free Mac cleaners, and they are not interchangeable.</strong> Some are narrow open-source tools that do one job well, some are system-maintenance suites with optimisation features a Mac does not need, and some are the free tier of a subscription product. This comparison covers what each actually cleans, what it costs in memory, and where each one is the wrong choice.",
    updatedISO: "2026-10-03",
    updatedHuman: "3 October 2026",
    blocks: [
      {
        t: "note",
        variant: "warn",
        html: `<p><strong>Disclosure: this page is written by the author of Worm Cleaner.</strong> We have tried to make it useful rather than flattering, which is why it spends as much time on where Worm is the weaker option as on where it wins. Every claim about Worm is verifiable from its repository; claims about other tools are characterised by category, not asserted, and you should check each vendor's own page.</p>`,
      },
      { t: "h2", html: "The three kinds of free Mac cleaner" },
      {
        t: "p",
        html:
          "<p>Sorting the options makes the choice much easier, because most &ldquo;best Mac cleaner&rdquo; lists mix categories and compare them on the wrong axes.</p><ul><li><strong>Dedicated open-source cleaners.</strong> One job, no telemetry, no subscription. Mole and Worm are in this group, as are narrower CLI tools.</li><li><strong>Single-purpose uninstallers.</strong> AppCleaner and similar: excellent at removing one app's leftovers, and they do nothing else.</li><li><strong>Free tiers of commercial suites.</strong> CleanMyMac, MacCleaner and similar. Feature-rich, subscription-based, and the free tier is usually the same binary with the upsell left in.</li></ul>",
      },
      {
        t: "img",
        src: "/images/screenshot-mac-clean.png",
        width: 1600,
        height: 595,
        alt: "Worm Cleaner running on macOS showing its Clean screen: 2.99 GB reclaimable, a tri-state checkbox beside each cache category, and a per-item list of app caches with exact sizes and full paths including Microsoft Edge at 766.40 MB and Homebrew at 515.96 MB, with caches of running apps flagged \"App is open\" instead of deleted",
        caption: "Worm's Clean screen on macOS. Every cache is listed with its measured size and full path, each one carries its own checkbox, regenerable items are ticked by default, and anything whose owning app is still running is flagged rather than deleted.",
      },
      { t: "h2", html: "Comparison" },
      {
        t: "table",
        caption: "Free Mac cleaners by approach",
        head: ["", "Worm Cleaner", "Dedicated open-source cleaners (e.g. Mole)", "Single-purpose uninstallers", "Commercial suites (free tier)"],
        rows: [
          ["Price", "Free, MIT", "Free, MIT", "Free", "Subscription, free tier"],
          ["Developer caches", "<span class=\"yes\">Deep</span>", "<span class=\"yes\">Yes</span>", "<span class=\"no\">No</span>", "General purpose"],
          ["App leftovers", "Yes, with absence verification", "Yes", "Yes, its core purpose", "Yes"],
          ["Windows build", "Yes", "Varies", "No", "Rarely"],
          ["System monitor", "Yes, native", "Varies", "No", "Often"],
          ["Source available", "<span class=\"yes\">Yes</span>", "<span class=\"yes\">Yes</span>", "No", "No"],
          ["Telemetry in app", "None", "None", "None", "Varies &mdash; check"],
          ["Subscription needed", "<span class=\"no\">No</span>", "<span class=\"no\">No</span>", "<span class=\"no\">No</span>", "For full features"],
        ],
      },
      { t: "h2", html: "Where Worm Cleaner is the weaker choice" },
      {
        t: "p",
        html:
          "<p>Stated plainly, because a comparison that only lists strengths is marketing:</p><ul><li><strong>It is young and narrowly scoped.</strong> It does not do malware scanning, file-system optimisation, login-item management, startup-item control or scheduled cleaning. Commercial suites do, and for some people that is the whole point.</li><li><strong>Fewer integrations.</strong> A large project with a long history may have drivers and quirks that a small catalog has not encountered.</li><li><strong>No sign-in, no sync, no support SLA.</strong> There is a GitHub issue tracker and a real person reading it, which is not the same as a support department.</li><li><strong>macOS is not notarised.</strong> Gatekeeper blocks the first launch until you click through. Annoying, and a genuine reason some people will not use it.</li><li><strong>Single maintainer.</strong> Worm is one person's project. That is a real bus-factor consideration, and it is worth weighing against the fact that the source is public so it could be picked up.</li></ul>",
      },
      { t: "h2", html: "Where Worm Cleaner is the stronger choice" },
      {
        t: "p",
        html:
          "<p>Equally plainly: developer cache coverage is deeper than any general-purpose cleaner we are aware of, spanning Xcode, npm, Homebrew, Gradle, pip, Composer, Terraform and more, each listed as a separate measurable target. It is the only option here with a <strong>Windows</strong> build of comparable depth. It classifies every target into four risk tiers so the default selection is defensible. It performs positive absence verification before flagging an app's leftovers. It is native on both platforms, under 35 MB idle on macOS. And it is MIT licensed with the source public, so every claim here can be checked.</p>",
      },
      { t: "h2", html: "How to choose" },
      {
        t: "ul",
        items: [
          "<strong>Your disk is full of Xcode or node_modules residue?</strong> A developer-focused cleaner. This is where the category actually differentiates.",
          "<strong>You mostly want to remove one app properly?</strong> A single-purpose uninstaller is the simplest tool for that.",
          "<strong>You want malware scanning and scheduled maintenance?</strong> A commercial suite, and accept the subscription.",
          "<strong>You care about what is deleted?</strong> Open source, full stop. You can read the catalog and confirm the exclusion list yourself.",
          "<strong>You have both a Mac and a PC?</strong> A cross-platform tool saves installing two.",
        ],
      },
      { t: "h2", html: "What actually helps your Mac run better" },
      {
        t: "p",
        html:
          OPTIMIZER_NOTE +
            "<p>In practice: keep 15&ndash;20% of your volume free, leave about 20 GB for system updates, restart more often than you think you need to, and check what is actually large before deleting anything. A storage cleaner helps when it removes genuinely disposable residue. It does not substitute for knowing where your disk went.</p>",
      },
      { t: "faq", faqs: [] },
      CTA,
      {
        t: "related",
        ids: ["/cleanmymac-alternative", "/blog/why-i-built-a-cleanmymac-alternative", "/blog/system-data-on-mac"],
      },
    ],
    faqs: [
      {
        q: "What is the best free Mac cleaner?",
        a: "It depends on what is filling your disk. For developer caches — Xcode, npm, Homebrew, Gradle — a developer-focused open-source cleaner is the only category that genuinely differentiates, and Worm Cleaner is built for that. For removing one app's leftovers, a single-purpose uninstaller is simpler. For malware scanning and scheduled maintenance you need a commercial suite. There is no single answer, which is why most 'best Mac cleaner' lists are not much use.",
      },
      {
        q: "Do Mac cleaners actually work?",
        a: "The cleaning part does, reliably, for genuinely disposable residue: build caches, package-manager caches, logs, crash dumps, old application state and leftover files from uninstalled apps. That can be tens of gigabytes. What cleaners cannot do is make your Mac faster. They also cannot recover space that is genuinely in use by your documents, photos or projects, and the advertised 'frees up 40 GB instantly' figures usually mean the tool counted things twice.",
      },
      {
        q: "Do I need a Mac cleaner at all?",
        a: "Probably not as a routine habit. macOS manages its own caches adequately, and Storage Settings plus a monthly look at what is large covers most people. A cleaner earns its place when you have a specific problem — a full disk after heavy development, or accumulated leftovers from apps you removed over the years. If your disk is not full and nothing feels slow, you do not need one.",
      },
      {
        q: "Are free Mac cleaners safe?",
        a: "The category spans safe to genuinely risky, and the variable is whether you can verify what it deletes. Open-source tools let you read the catalog and the exclusion list; closed free tiers of commercial products ask for trust you cannot check, and historically the free tier of some well-known cleaners was the distribution vector for adware. The practical test: does it show you every target with its size and path before deleting, does it send deletions somewhere recoverable, and can you read what it refuses to touch?",
      },
      {
        q: "Is Worm Cleaner really the best free Mac cleaner?",
        a: "It is the best free option if your disk is full of developer build residue, and it is competitive on footprint and transparency generally. It is not the best if you need malware scanning, scheduled cleaning, startup-item management or broad system maintenance — it does not attempt those. We have set out the full list of its weaknesses above rather than leaving you to discover them.",
      },
    ],
  },

  /* ── 11. Why is my Mac storage full ───────────────────────────────────── */
  {
    href: "/why-is-my-mac-storage-full",
    kind: "page",
    group: "guide",
    priority: 0.8,
    eyebrow: "System Data explained",
    title: "Why Is My Mac Storage Full? System Data Explained",
    navTitle: "Why is my Mac full?",
    footerTitle: "Why is my Mac storage full",
    crumb: "Why is my Mac storage full",
    description:
      "Storage Settings says System Data and the number keeps climbing. Here is what System Data actually is, and which parts are safe to clear.",
    imageAlt:
      "macOS Storage Settings showing a large System Data category explained alongside reclaimable caches",
    h1: "Why Is My Mac Storage Full?",
    lede:
      "<strong>System Data is macOS's catch-all category for everything it cannot attribute to your apps, documents or photos.</strong> It is not one thing, which is why the number often seems to move for no reason. Most of it is reclaimable &mdash; but the safe parts and the parts you should leave alone are not the same parts.",
    updatedISO: "2026-10-03",
    updatedHuman: "3 October 2026",
    blocks: [
      {
        t: "h2",
        html: "What is System Data on Mac?",
      },
      {
        t: "p",
        html:
          "<p>When you open Storage Settings, macOS sorts your disk into categories: Applications, Documents, Photos, Music, Mail, Messages, iCloud Drive, and System Data. System Data is the remainder &mdash; and it is a remainder by definition, which means it absorbs anything the classifier cannot confidently place.</p>" +
          "<p>It typically contains: swap and virtual memory, the sleep image, system caches and logs, temporary files, Time Machine local snapshots, iOS and iPadOS backups on your Mac, developer build residue, disk images you have mounted, and the enormous amount of opaque bookkeeping that <code>/private/var</code> accumulates.</p>",
      },
      {
        t: "note",
        variant: "warn",
        html: `<p><strong>System Data is an estimate, and a poor one.</strong> macOS recomputes it lazily, so the figure often jumps after a restart or after you delete something large. It can also double-count or misattribute. Treat a sudden 200 GB jump as a signal to look at what is actually large, not as a reliable measurement.</p>`,
      },
      { t: "h2", html: "The five usual causes, in order" },
      {
        t: "ol",
        items: [
          "<strong>Developer residue.</strong> Xcode DerivedData, simulator runtimes, CocoaPods and package-manager caches. On a development machine this is frequently the largest single category, and it is almost entirely reclaimable.",
          "<strong>iPhone and iPad backups.</strong> Stored in ~/Library/Application Support/MobileSync/Backup, often many gigabytes each, for devices you no longer own.",
          "<strong>Time Machine local snapshots.</strong> macOS keeps local snapshots to make backups incremental. They are managed automatically and pruned on schedule &mdash; deleting them by hand provides no lasting benefit.",
          "<strong>Swap and sleep images.</strong> Managed by the kernel. They grow under memory pressure and shrink on reboot. There is nothing safe to clean here; a restart is the fix.",
          "<strong>Large caches in /Library/Caches and /private/var.</strong> Application and system caches, logs, diagnostic reports and installer leftovers.",
        ],
      },
      { t: "h2", html: "Can I clear System Data?" },
      {
        t: "p",
        html:
          "<p>Not as a single operation &mdash; because it is not a single thing. What you can do is clear the specific parts of it that are disposable, which is what a cleaner is for.</p>" +
          "<p>Worm does not offer a &ldquo;clear System Data&rdquo; button, deliberately. It offers the individual underlying targets: Xcode DerivedData and the other Xcode caches, Homebrew downloads, npm and Yarn caches, Gradle build cache, pip and Composer caches, browser caches, crash reports and logs. Each with its size, each individually selectable, each classified by risk.</p>" +
          "<p>It will not touch Time Machine snapshots, swap, or the Windows-Update-equivalent protected trees, because deleting those causes problems without reliably freeing the space you expected.</p>",
      },
      { t: "h2", html: "How to find out what is actually using the space" },
      {
        t: "p",
        html: `Start with what macOS already gives you, then go deeper:</p><ul><li><strong>Storage Settings &rarr; General &rarr; Storage</strong> &mdash; click the <strong>i</strong> next to System Data for a breakdown of what is inside it.</li><li><strong>System Settings &rarr; General &rarr; Storage &rarr; Manage</strong> &mdash; iPhone and iPad backups, and file-by-file large-item review.</li><li><strong>Worm's scan</strong> &mdash; reports the measured size of every disposable target rather than estimating a category.</li><li><strong>Finder, for the blind spots.</strong> <code>du -sh ~/Library/* 2&gt;/dev/null | sort -h | tail -20</code> finds what the classifier missed.</li></ul>`,
      },
      { t: "h2", html: "Reduce system data storage over time" },
      {
        t: "ul",
        items: [
          "Delete iPhone backups for devices you no longer own from Storage Settings &rarr; Manage.",
          "Keep 15&ndash;20% of your volume free. macOS needs working room for updates and swap; a nearly-full drive produces pathological behaviour well before it hits 100%.",
          "Prune unused simulator runtimes from Xcode &rarr; Settings &rarr; Platforms.",
          "Prune Homebrew's old versions and downloads with <code>brew cleanup</code>.",
          "Restart on a schedule. Swap and the sleep image release on reboot; nothing else does it for you.",
          "Scan quarterly. Ten seconds is cheaper than discovering the problem during a build.",
        ],
      },
      { t: "h2", html: "Does clearing caches make a Mac faster?" },
      { t: "p", html: OPTIMIZER_NOTE },
      { t: "faq", faqs: [] },
      CTA,
      {
        t: "related",
        ids: ["/clear-xcode-deriveddata", "/blog/system-data-on-mac", "/mac-storage-cleaner"],
      },
    ],
    faqs: [
      {
        q: "What is System Data on Mac and how do I delete it?",
        a: "System Data is macOS's catch-all bucket for anything it cannot attribute to your apps, documents or photos — swap, the sleep image, system caches, logs, Time Machine local snapshots, iPhone backups, developer residue and /private/var. You cannot clear it as one operation, because it is not one thing. Clear the disposable parts individually: Xcode DerivedData, package-manager caches, Homebrew downloads, browser caches and old logs. A tool that offers a single 'clear System Data' button is deleting opaque amounts of data and hoping.",
      },
      {
        q: "Why is my System Data figure so large?",
        a: "Most often developer residue — Xcode DerivedData, simulator runtimes and package-manager caches — followed by iPhone and iPad backups in ~/Library/Application Support/MobileSync/Backup, then Time Machine local snapshots and swap. Also note that System Data is a lazy estimate: it often jumps after a restart, and it can double-count. A sudden large jump is a reason to look at what is genuinely large rather than a reliable measurement.",
      },
      {
        q: "Why does System Data keep growing back after I clean it?",
        a: "Because some of it is not yours to keep. macOS regenerates caches, logs and swap continuously, and Time Machine snapshots are created automatically to make the next backup incremental. If a cleaner reports reclaiming 30 GB and Storage Settings shows the same figure a week later, that is not necessarily a failure — it means the space genuinely went back into caches, which is what caches do. The durable fix is reducing what generates them.",
      },
      {
        q: "Is it safe to delete System Data?",
        a: "Deleting the disposable parts is safe: build caches, package-manager caches, browser caches, old logs and crash reports are all regenerable or re-downloadable. Deleting the non-disposable parts is not, and is where 'clear System Data' tools do damage. Do not delete Time Machine snapshots expecting a permanent gain, and do not touch swap or the sleep image — a restart handles those. Worm classifies each target by risk and blocks the non-rebuildable ones outright.",
      },
      {
        q: "How much free space should a Mac have?",
        a: "Keep 15 to 20 percent of the volume free, and never less than about 20 GB. macOS needs working room for updates, swap and temporary files. A drive that is nearly full causes real problems well before it reports as full: builds fail with disk errors, the system swaps heavily and feels slow, and caches stop being written.",
      },
    ],
  },

  /* ── 12. Changelog ────────────────────────────────────────────────────── */
  {
    href: "/changelog",
    kind: "page",
    group: "guide",
    priority: 0.6,
    eyebrow: "Release history",
    title: "Worm Cleaner Changelog and Release Notes",
    navTitle: "Changelog",
    footerTitle: "Changelog",
    crumb: "Changelog",
    description:
      "Every Worm Cleaner release with dates and changes: v1.0.1 through v1.0.4, covering the macOS app, the Windows app and release CI.",
    imageAlt:
      "Worm Cleaner release history from v1.0.1 to v1.0.4 for macOS and Windows",
    h1: "Changelog and Release Notes",
    lede:
      "<strong>Worm Cleaner is currently at version 1.0.4</strong>, released 2 October 2026. The project reached 1.0 in a single day of focused work, so early versions moved quickly. Below is every published release, what changed, and where to get the binaries and their checksums.",
    updatedISO: "2026-10-03",
    updatedHuman: "3 October 2026",
    blocks: [
      {
        t: "p",
        html:
          `<p>Download any version from <a href="https://github.com/namdevnaman/worm/releases">GitHub Releases</a>. Each release publishes its own <code>SHA256SUMS.txt</code> alongside the binaries. The current digests are on the <a href="/is-worm-cleaner-safe">verification page</a> and at <a href="/SHA256SUMS.txt">/SHA256SUMS.txt</a>.</p>`,
      },
      { t: "h2", html: "v1.0.4 &mdash; 2 October 2026" },
      {
        t: "p",
        html:
          "<p><em>Bring the Windows app to parity with the macOS app.</em></p><ul><li>Windows app brought to feature parity with the macOS app, including the scan catalog, orphan detection and system monitor.</li><li>Fixed a crash on the Windows Clean page.</li><li>Added a self-test and a binding lint to the Windows test step.</li><li>Release CI simplified so the Windows test output can no longer go missing, and stopped walking <code>bin/</code> and <code>obj/</code>.</li><li>Release version resolved once so the macOS verify step can read it.</li></ul>",
      },
      { t: "h2", html: "v1.0.3 &mdash; 2 October 2026" },
      {
        t: "p",
        html:
          "<p><em>Make CI failures diagnosable.</em></p><ul><li>macOS build failures are now published to the job summary and as check-run annotations.</li><li>The macOS build log is captured as a CI artifact so a failure can be diagnosed without admin access.</li></ul>",
      },
      { t: "h2", html: "v1.0.2 &mdash; 2 October 2026" },
      {
        t: "p",
        html:
          "<p><em>Fix macOS release pipeline and Windows installation.</em></p><ul><li>macOS binary path lookup fixed for CI runners; releases can now be cut from any passing build.</li><li>Fixed a Windows startup failure and made installation a single double-click.</li><li>macOS release CI fixed; the bundle version is stamped from the git tag.</li></ul>",
      },
      { t: "h2", html: "v1.0.1 &mdash; 2 October 2026" },
      {
        t: "p",
        html:
          "<p><em>First public release.</em></p><ul><li>macOS app: scan catalog, app uninstaller with orphan detection, menu bar system monitor, Full Disk Access guidance and a local deletion audit log.</li><li>Repository restructured: the MoleMac directory was removed, Worm was promoted to the repository root, and core modules were renamed to <code>WormCore</code> and <code>WormDiag</code>.</li><li><code>SHA256SUMS.txt</code> published with every release asset.</li></ul>",
      },
      {
        t: "h2",
        html: "What changed in the v1.0.x line",
      },
      {
        t: "table",
        caption: "Release summary",
        head: ["Version", "Date", "Focus"],
        rows: [
          ["v1.0.4", "2 Oct 2026", "Windows/macOS feature parity, Clean page crash fix, CI reliability"],
          ["v1.0.3", "2 Oct 2026", "macOS build failure visibility and log artifacts"],
          ["v1.0.2", "2 Oct 2026", "macOS release CI fixes, Windows install and startup fixes"],
          ["v1.0.1", "2 Oct 2026", "First public release, repository restructure"],
        ],
      },
      {
        t: "p",
        html:
          '<p><strong>Looking for the source of a change?</strong> Every release is a git tag, so <code>git log v1.0.3..v1.0.4</code> in a clone gives you the exact commits. The full history is at <a href="https://github.com/namdevnaman/worm/commits/main">github.com/namdevnaman/worm/commits</a>.</p>',
      },
      {
        t: "note",
        html: `<p><strong>Version numbering.</strong> Worm is pre-1.1 and moves quickly while the catalog is still being filled in. Expect breaking changes to the target list between minor versions, though the risk-tier model and the deletion behaviour will not change: Trash and Recycle Bin first, always.</p>`,
      },
      { t: "faq", faqs: [] },
      CTA,
      { t: "related", ids: ["/is-worm-cleaner-safe", "/mac-storage-cleaner", "/windows-storage-cleaner"] },
    ],
    faqs: [
      {
        q: "What is the latest version of Worm Cleaner?",
        a: "v1.0.4, released 2 October 2026. It brings the Windows app to feature parity with the macOS app, fixes a crash on the Windows Clean page, and hardens the release pipeline. Binaries and checksums are on GitHub Releases.",
      },
      {
        q: "How do I check which version I have?",
        a: "The version is shown in the app itself and printed in the footer of this site. On macOS you can also check the bundle: `defaults read /Applications/Worm.app/Contents/Info.plist CFBundleShortVersionString`. On Windows, the About screen in the tray panel shows it.",
      },
      {
        q: "Does upgrading delete anything?",
        a: "No. Updating replaces the application bundle and leaves your settings, your protect list and your deletion audit log untouched. Existing audit logs at ~/Library/Logs/Worm/deletions.tsv on macOS and %LOCALAPPDATA%\\Worm\\Logs\\deletions.tsv on Windows are preserved across versions.",
      },
      {
        q: "How do I get notified about new releases?",
        a: "Watch the repository on GitHub, which will notify you when a new tag is published. There is no account to create and no email list. The only network call in the macOS app is an optional update check, and it is off until you ask for it.",
      },
    ],
  },
];