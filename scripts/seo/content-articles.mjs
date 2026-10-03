/**
 * Blog articles.
 *
 * Deliberately cut at a different angle from the matching landing page, because
 * two pages targeting one phrase splits the signal rather than reinforcing it.
 *
 *   /clear-xcode-deriveddata      → how to do it, safely, today
 *   /blog/xcode-disk-space        → the full map: every directory, what is in it,
 *                                   whether it is safe, how large it gets
 *
 *   /why-is-my-mac-storage-full   → the quick answer and the usual causes
 *   /blog/system-data-on-mac      → the mechanism: how macOS computes System Data,
 *                                   why the number lies, and how to diagnose it
 *
 * No fabricated first-person results. These are written as guides with
 * reproducible measurements the reader can take themselves.
 */

import { OPTIMIZER_NOTE, RISK_MODEL, NOT_MALWARE_ANSWER } from "./facts.mjs";

const CTA = {
  t: "cta",
  body: "Worm Cleaner is free, MIT licensed and runs on macOS 14+ and Windows 10/11. No account, no subscription, no telemetry in the app.",
};

export const ARTICLES = [
  /* ── Article 1: the Xcode disk map ────────────────────────────────────── */
  {
    href: "/blog/xcode-disk-space",
    kind: "article",
    group: "blog",
    priority: 0.7,
    eyebrow: "Field guide",
    title: "Xcode Disk Space: What You Can Delete and What You Can't",
    ogTitle: "Xcode Disk Space: What You Can Delete and What You Can't",
    navTitle: "Xcode disk space guide",
    footerTitle: "Xcode disk space guide",
    crumb: "Xcode disk space",
    description:
      "A complete map of every directory Xcode writes to on macOS: what each one contains, whether it is safe to delete, and how large each typically gets.",
    imageAlt:
      "Map of Xcode directories on macOS with sizes and safety classifications for each",
    h1: "Xcode Disk Space: What You Can Delete and What You Can't",
    lede:
      "<strong>Xcode is one of the largest single consumers of disk space on a Mac, and almost none of it is your code.</strong> This is a directory-by-directory map of everything Xcode writes under <code>~/Library/Developer</code> and <code>~/Library/Caches</code>, what each one actually contains, whether deleting it is safe, and what it costs you. Written for people who have run out of space and want to make an informed decision rather than guess.",
    publishedISO: "2026-09-28",
    updatedISO: "2026-10-03",
    updatedHuman: "3 October 2026",
    keywords:
      "xcode disk space, xcode deriveddata size, xcode cache, simulator runtimes disk space, ios device support, free up space xcode",
    blocks: [
      {
        t: "p",
        html:
          "<p>Start by measuring rather than guessing. This finds the ten largest directories Xcode has created, which is a more useful first move than any cleanup tool:</p>",
      },
      { t: "code", text: "du -sh ~/Library/Developer/* ~/Library/Caches/com.apple.dt.Xcode 2>/dev/null | sort -h | tail -10" },
      {
        t: "p",
        html:
          "<p>On a machine that has been developing iOS for a couple of years, expect the answer to be dominated by four directories, and to be measured in tens of gigabytes rather than hundreds of megabytes.</p>",
      },

      { t: "h2", html: "The safe to delete group" },
      {
        t: "h3",
        html: "~/Library/Developer/Xcode/DerivedData",
      },
      {
        t: "p",
        html:
          "<p><strong>What it is:</strong> per-project compiled intermediates &mdash; object files, module caches, generated headers, Swift module data and the incremental build index. Xcode creates one subdirectory per project, identified by a hash of the project path, and never evicts them.</p>" +
          "<p><strong>Size:</strong> commonly 2&ndash;10 GB for a single active project, and easily 40&ndash;60 GB once several finished projects, branches and dependency changes have accumulated. This is the directory that catches people out, because it grows silently and is never mentioned.</p>" +
          "<p><strong>Safe?</strong> Yes. Entirely rebuilt from source on the next build. The cost is a cold rebuild &mdash; minutes rather than seconds on a large project. Close Xcode first, because a running instance writing into a directory that is being deleted produces confusing errors.</p>",
      },
      { t: "h3", html: "~/Library/Developer/Xcode/Products" },
      {
        t: "p",
        html:
          "<p><strong>What it is:</strong> build products from the current workspace, a legacy location that predates DerivedData. <strong>Size:</strong> usually small on modern setups, occasionally enormous on older ones. <strong>Safe?</strong> Yes &mdash; regenerated on the next build.</p>",
      },
      { t: "h3", html: "~/Library/Caches/com.apple.dt.Xcode" },
      {
        t: "p",
        html:
          "<p><strong>What it is:</strong> Xcode's own cache: module validation data, Swift compilation caching, and assorted transient state. <strong>Size:</strong> 1&ndash;5 GB. <strong>Safe?</strong> Yes. Xcode rebuilds it, at the cost of a slower first build after clearing.</p>",
      },
      { t: "h3", html: "~/Library/Developer/CoreSimulator/Caches" },
      {
        t: "p",
        html:
          "<p><strong>What it is:</strong> caches belonging to the simulator subsystem, not the runtimes themselves. <strong>Size:</strong> 1&ndash;10 GB depending on how much simulator testing you do. <strong>Safe?</strong> Yes. Note carefully that this is <em>Caches</em>, not <code>Profiles/Runtimes</code>, which is on the protected list below.</p>",
      },
      { t: "h3", html: "~/Library/Developer/XCTestDevices" },
      {
        t: "p",
        html:
          "<p><strong>What it is:</strong> temporary device data created for UI and unit testing. <strong>Size:</strong> variable, occasionally large after a test run that generated many screenshots. <strong>Safe?</strong> Yes.</p>",
      },
      { t: "h3", html: "~/Library/Caches/org.swift.swiftpm" },
      {
        t: "p",
        html:
          "<p><strong>What it is:</strong> the SwiftPM package cache &mdash; checked-out and downloaded dependency repositories. <strong>Size:</strong> 0.5&ndash;5 GB. <strong>Safe?</strong> Yes, but it is re-download rather than regenerate: expect every dependency to be fetched again on the next resolve.</p>",
      },

      { t: "h2", html: "The group you must not delete" },
      {
        t: "p",
        html:
          "<p>This is where most third-party &ldquo;Xcode cleaners&rdquo; do damage. These three are not caches in any recoverable sense, and several popular tools will happily remove them:</p>",
      },
      {
        t: "table",
        caption: "Xcode paths that are protected, and why",
        head: ["Path", "What it holds", "What you lose"],
        rows: [
          ["<code>~/Library/Developer/Xcode/Archives</code>", "Distribution binaries for apps you shipped or are about to ship", "The archive. Re-shippable only by re-archiving and re-signing from source."],
          ["<code>~/Library/Developer/Xcode/iOS DeviceSupport</code>", "Symbol bundles for physical devices", "Symbols for that device version. Re-obtained only by re-attaching the device and rebuilding."],
          ["<code>~/Library/Developer/CoreSimulator/Profiles/Runtimes</code>", "Installed iOS simulator runtimes", "A multi-gigabyte download, and a working simulator."],
        ],
      },
      {
        t: "note",
        variant: "warn",
        html: `<p><strong>Device support in particular.</strong> It is easy to assume it is regenerable because Xcode appears to manage it. It is not &mdash; the symbols are generated by your compiler for a specific device and OS build, and cannot be reproduced without that exact toolchain and device. If you have a device you can no longer attach, deleting its symbols can cost you a debugging session you cannot repeat.</p>`,
      },

      { t: "h2", html: "The group that is not Xcode's fault" },
      {
        t: "p",
        html:
          "<p>A common misdiagnosis. If the space is not under <code>~/Library/Developer</code>, Xcode is not the cause, even though you were last building an iOS app when the disk filled. Three frequent culprits:</p><ul><li><strong>CocoaPods and Carthage</strong> &mdash; <code>~/Library/Caches/CocoaPods</code> and <code>~/Library/Caches/org.carthage.CarthageKit</code> hold downloaded pod sources. Large, and re-downloadable. (Note: Worm Cleaner does not currently have a CocoaPods rule, so manage these yourself with <code>pod cache clean --all</code>.)</li><li><strong>Node and package managers</strong> &mdash; <code>node_modules</code> inside projects, plus <code>~/.npm/_cacache</code>, <code>~/.yarn</code> and <code>~/.gradle</code>. Frequently larger than all of Xcode combined.</li><li><strong>Device backups and simulators on the Mac itself</strong> &mdash; <code>~/Library/Developer/Xcode/Archives</code> is the archive store, but iPhone backups live under <code>~/Library/Application Support/MobileSync/Backup</code> and belong to the backup system, not Xcode.</li></ul>",
      },

      { t: "h2", html: "A reasonable clearing order" },
      {
        t: "ol",
        items: [
          "Close Xcode entirely. Check no <code>Xcode</code>, <code>CoreSimulator</code> or <code>XCTRunner</code> process is running.",
          "Measure first with the <code>du</code> command above, so you know what you are dealing with.",
          "Clear <code>DerivedData</code> for projects you are finished with first &mdash; they are usually the largest and cost you nothing you still need.",
          "Clear <code>com.apple.dt.Xcode</code> and the simulator <code>Caches</code> directory.",
          "Decide separately on SwiftPM: clearing it is safe but means re-downloading every dependency.",
          "Leave Archives, DeviceSupport and simulator Runtimes alone.",
          "Rebuild once and note how long it takes. That is the real cost, and now you know it.",
        ],
      },
      {
        t: "h2",
        html: "Making it stop coming back",
      },
      {
        t: "p",
        html:
          "<p>DerivedData accumulates because Xcode has no eviction policy: it keeps one directory per project path, forever. Three habits genuinely reduce it:</p><ul><li><strong>Delete on project completion.</strong> When a client project ends, remove its DerivedData subdirectory then, not eighteen months later.</li><li><strong>Prune unused runtimes and devices.</strong> Xcode &rarr; Settings &rarr; Platforms. Each runtime is several GB.</li><li><strong>Keep your volume 15&ndash;20% free.</strong> A nearly-full SSD makes builds fail and slows the whole system, well before macOS reports the disk as full.</li></ul>" +
          OPTIMIZER_NOTE,
      },
      {
        t: "p",
        html: `<p>${RISK_MODEL}</p>`,
      },
      { t: "faq", faqs: [] },
      CTA,
      { t: "related", ids: ["/clear-xcode-deriveddata", "/developer-cache-cleaner", "/mac-storage-cleaner"] },
    ],
    faqs: [
      {
        q: "Is it safe to delete Xcode DerivedData?",
        a: "Yes. It contains only compiled intermediate files that Xcode regenerates from source on the next build, so the cost is a slower cold rebuild and nothing else. Your repositories, project files and signing material are all stored elsewhere. Close Xcode before deleting so a running instance is not writing into a directory that is disappearing underneath it.",
      },
      {
        q: "Why is my Xcode folder so large?",
        a: "Almost always DerivedData accumulating across projects. Xcode creates one subdirectory per project path and never evicts them, so a machine that has worked on a dozen projects over two years accumulates the sum of all of them. Add the Xcode cache, the simulator caches, SwiftPM, and any CocoaPods or node_modules directories in the same projects, and tens of gigabytes is normal.",
      },
      {
        q: "What is the difference between DerivedData and the Xcode cache?",
        a: "DerivedData is per-project compiled output: object files, module data and the incremental build index, in a subdirectory named after a hash of the project path. The Xcode cache in ~/Library/Caches/com.apple.dt.Xcode is application-level state that is shared across all your projects — module validation data and Swift compilation caching. Both are safe to delete; DerivedData is usually much larger.",
      },
      {
        q: "Can I delete iOS DeviceSupport?",
        a: "Technically you can, but it is a bad idea, and Worm Cleaner refuses to do it. Device support holds symbol bundles generated by your compiler for a specific device and OS build. They cannot be reproduced without that exact toolchain and that device attached. If you still have the device, re-attaching it once regenerates them — and if you no longer do, you have lost the ability to symbolicate crashes from that device.",
      },
      {
        q: "How do I find out which Xcode directories are taking up space?",
        a: "Run: du -sh ~/Library/Developer/* ~/Library/Caches/com.apple.dt.Xcode 2>/dev/null | sort -h | tail -10 — that lists the ten largest, sorted. Alternatively a scan in Worm Cleaner reports the measured size of each Xcode target individually, including DerivedData, build products, the Xcode cache, simulator cache and XCTest device data as separate entries.",
      },
    ],
  },

  /* ── Article 2: why it was built ──────────────────────────────────────── */
  {
    href: "/blog/why-i-built-a-cleanmymac-alternative",
    kind: "article",
    group: "blog",
    priority: 0.7,
    eyebrow: "Behind the project",
    title: "Why I Built a Free, Open-Source CleanMyMac Alternative",
    ogTitle: "Why I Built a Free, Open-Source CleanMyMac Alternative",
    navTitle: "Why I built Worm",
    footerTitle: "Why I built Worm",
    crumb: "Why I built Worm",
    description:
      "The reasoning behind Worm Cleaner: why a cleaner should be auditable, why the scan catalog is public source, and what a subscription is actually paying for.",
    imageAlt:
      "The scan catalog and safety policy source files that make Worm Cleaner auditable",
    h1: "Why I Built a Free, Open-Source CleanMyMac Alternative",
    lede:
      "<strong>Worm Cleaner started as a disagreement about one design decision:</strong> a tool that deletes your files should not ask you to trust it. I wanted a Mac cleaner where the complete list of what gets deleted is a file in a public repository, so I could read it before running it &mdash; and so could you.",
    publishedISO: "2026-09-20",
    updatedISO: "2026-10-03",
    updatedHuman: "3 October 2026",
    keywords:
      "cleanmymac alternative, open source mac cleaner, free mac cleaner, build a mac cleaner, mac cleaner privacy",
    blocks: [
      {
        t: "p",
        html:
          "<p>I am not going to argue that commercial cleaners are badly made. Several are excellent pieces of software, and the people who build them are good at what they do. My objection was narrower, and it is a design objection rather than a business one.</p>",
      },
      {
        t: "h2",
        html: "The problem with trusting a cleaner",
      },
      {
        t: "p",
        html:
          "<p>A disk cleaner is a program whose entire purpose is to delete files you care about. That makes it structurally unlike almost every other category of software, where the failure mode is a crash rather than data loss.</p>" +
          "<p>So the important question is not &ldquo;is this cleaner good?&rdquo; It is <strong>&ldquo;can I check what it does?&rdquo;</strong> And for a closed-source cleaner, the honest answer is no. You can read the marketing page, the privacy policy and the permissions it requests. You cannot read the list of paths it will delete, the conditions under which it deletes them, or what happens when a path does not match expectations.</p>",
      },
      {
        t: "note",
        variant: "warn",
        html: `<p><strong>This is not a security allegation.</strong> I have no evidence that any commercial Mac cleaner deletes files it should not. The point is that you cannot check, and for a tool in this category, &ldquo;cannot check&rdquo; is a permanent tax on trust rather than a temporary inconvenience.</p>`,
      },
      { t: "h2", html: "What open source actually buys you" },
      {
        t: "p",
        html:
          "<p>Worm's scan catalog is <code>Sources/WormCore/ScanCatalog.swift</code>. That single file is the complete list of everything the Mac app can delete, one labelled entry per target with its path, category, age gate and risk tier. The protected paths are <code>Sources/WormCore/SafetyPolicy.swift</code>.</p>" +
          "<p>You can read both before installing. That is not a small thing. It means the security question has an answer that does not involve trusting me: if a rule in that file could delete something you care about, you can see it.</p>" +
          "<p>It also made development better, which I did not anticipate. Because the catalog is one readable list rather than logic scattered through the UI, adding a target is a single entry, and reasoning about what the app deletes is a normal code review rather than an archaeology exercise.</p>",
      },
      { t: "h2", html: "Four risk tiers, and why the default matters" },
      {
        t: "p",
        html:
          "<p>Most cleaners present a binary choice: clean this category, or do not. That pushes the decision onto you for categories with mixed contents, so people either clean everything or nothing.</p>" +
          RISK_MODEL +
          "<p>The consequence I was after: a first-time user who presses the obvious button deletes genuinely disposable data and nothing else. No tutorial required.</p>",
      },
      { t: "h2", html: "Positive absence verification" },
      {
        t: "p",
        html:
          "<p>The bug I most wanted to avoid is the one that makes people afraid of uninstall tools. Identify an app's leftovers by pattern-matching folder names, and you will eventually delete the settings of an application that is still installed &mdash; wiping offline data, saved logins, or local databases.</p>" +
          "<p>So Worm does not guess. Before flagging anything as an orphan it performs <strong>positive absence verification</strong>: it checks for the app bundle in system locations and queries Spotlight to confirm the application is genuinely gone. On Windows the equivalent uses token matching against every registered app plus a check against each install location &mdash; deliberately not substring matching, which both hid real orphans and flagged live ones.</p>" +
          "<p>That is slower than pattern matching and it occasionally misses an orphan. Both are the right trade.</p>",
      },
      { t: "h2", html: "The blast-radius allowlist" },
      {
        t: "p",
        html:
          "<p>Rules should be trustworthy, but a mistake in one rule should not be catastrophic. So every path a rule produces is checked against a cleanable-root set derived from the rules themselves, before anything is deleted.</p>" +
          "<p>The practical effect: even if a rule constructs a path incorrectly, it still cannot delete outside a folder the catalog declares cleanable. A bug becomes a no-op rather than an incident.</p>",
      },
      { t: "h2", html: "Recoverable by default" },
      {
        t: "p",
        html:
          "<p>macOS deletions go to the Trash. Windows deletions go to the Recycle Bin. Every destructive operation is also appended to a plain-text TSV log &mdash; <code>~/Library/Logs/Worm/deletions.tsv</code> on macOS, <code>%LOCALAPPDATA%\\Worm\\Logs\\deletions.tsv</code> on Windows.</p>" +
          "<p>This was the second decision I cared most about. &ldquo;Undo&rdquo; in a cleaner is usually not offered, which pushes all the risk onto you getting it right the first time. Making the default path recoverable means a mistake costs one click rather than the afternoon it would take to reconstruct a working environment.</p>",
      },
      { t: "h2", html: "On the name, and the obvious question" },
      {
        t: "p",
        html: NOT_MALWARE_ANSWER,
      },
      {
        t: "p",
        html:
          "<p>The name was settled before the code existed, which is why it needed a page like this one. A tool called &ldquo;Worm&rdquo; that deletes files will be searched for as malware by definition, and the answer has to be verifiable rather than reassuring.</p>",
      },
      { t: "h2", html: "What I got wrong" },
      {
        t: "p",
        html:
          "<p>Being honest here because a post like this that lists only successes is not useful.</p><ul><li><strong>The macOS build is not notarised.</strong> There is no paid Apple Developer account behind this project, so Gatekeeper blocks the first launch until the user clicks through. That is a genuine adoption cost and it is entirely self-inflicted.</li><li><strong>Scope is narrow.</strong> No malware scanning, no scheduled cleaning, no login-item management. Some people need those and this is not a substitute.</li><li><strong>One maintainer.</strong> A real bus-factor consideration. The source being public mitigates it somewhat, since anyone can continue it.</li><li><strong>The Windows app arrived late.</strong> It reached feature parity with the Mac app only in v1.0.4.</li></ul>",
      },
      { t: "h2", html: "What is next" },
      {
        t: "p",
        html:
          "<p>The catalog is the product, and it is incomplete. CocoaPods is not supported yet, which is an obvious gap given how much space it occupies. macOS is where the interesting residue is; Windows has broader surface area but less to offer any single user.</p>" +
          "<p>If you find a cleanup target that is missing, or a rule that looks wrong, the issue tracker is the right place &mdash; and if you would rather fix it yourself, it is one entry in one file.</p>",
      },
      { t: "faq", faqs: [] },
      CTA,
      {
        t: "related",
        ids: ["/cleanmymac-alternative", "/is-worm-cleaner-safe", "/best-free-mac-cleaners"],
      },
    ],
    faqs: [
      {
        q: "Why is Worm Cleaner free?",
        a: "Because the interesting part is trust, and a subscription is a poor fit for it. Charging for a cleaner makes the reader wonder what the money is for, and if the answer is a business that needs revenue, that business will eventually want data or advertising. Keeping it free and MIT licensed means the incentive is aligned with the tool remaining auditable and quiet.",
      },
      {
        q: "Is Worm Cleaner open source in the strict sense?",
        a: "Yes. Both apps are in one public repository under the MIT licence: the macOS app in Swift 6 with SwiftUI, the Windows app in .NET 9 with WPF. The scan catalog and safety policy are readable source, so you can confirm exactly what is deleted and what is protected before installing anything.",
      },
      {
        q: "Why call it Worm if that sounds like malware?",
        a: "The name was chosen first, for the metaphor of an earthworm tunnelling past surface junk into deeper strata, and it stuck. The obvious consequence is that people search for 'is worm cleaner malware' — so the answer has to be verifiable rather than a reassurance: no self-replication, no payload, no network calls during cleaning, and the entire source public.",
      },
      {
        q: "What did you learn building a Mac cleaner?",
        a: "Mostly that the hard part is not deletion, it is deciding what is safe to delete and proving it. The risk-tier model, positive absence verification for orphans, and the blast-radius allowlist were all harder to get right than the reclaimer itself, and they are the parts that actually determine whether the tool deserves to be trusted with a system directory.",
      },
    ],
  },

  /* ── Article 3: System Data mechanism ─────────────────────────────────── */
  {
    href: "/blog/system-data-on-mac",
    kind: "article",
    group: "blog",
    priority: 0.7,
    eyebrow: "Deep dive",
    title: "What Is 'System Data' on Mac, and How to Clear It",
    ogTitle: "What Is 'System Data' on Mac, and How to Clear It",
    navTitle: "System Data on Mac",
    footerTitle: "System Data on Mac",
    crumb: "System Data on Mac",
    description:
      "How macOS computes the System Data category, why the figure is unreliable, what actually lives inside it, and how to reclaim space without gambling.",
    imageAlt:
      "How macOS computes the System Data storage category and which underlying directories it covers",
    h1: "What Is 'System Data' on Mac, and How to Clear It",
    lede:
      "<strong>System Data is a remainder, not a category.</strong> macOS sorts your disk into Applications, Documents, Photos and friends, and System Data absorbs everything the classifier cannot confidently attribute. That is why it grows for reasons you never caused, and why no tool can clear it as a single operation.",
    publishedISO: "2026-09-14",
    updatedISO: "2026-10-03",
    updatedHuman: "3 October 2026",
    keywords:
      "system data mac, reduce system data storage mac, clear system data mac, mac storage full, mac disk space",
    blocks: [
      {
        t: "p",
        html:
          "<p>If you have ever opened Storage Settings, watched System Data sit stubbornly at 90 GB, deleted something obvious, and found the number unchanged &mdash; this is why. You were not doing anything wrong. You were reasoning about a measurement that does not mean what it appears to mean.</p>",
      },

      { t: "h2", html: "What the category actually is" },
      {
        t: "p",
        html:
          "<p>macOS attributes storage to categories using a combination of the <code>/System/Volumes/Data</code> directory structure, Spotlight metadata, app bundle locations and disk images. Anything that resists attribution lands in System Data.</p>" +
          "<p>Concretely, the bucket tends to contain:</p><ul><li><strong>Swap files</strong> &mdash; <code>/private/var/vm</code>. The kernel pages memory out here under pressure.</li><li><strong>The sleep image</strong> &mdash; roughly the size of your RAM, written so sleep is instant.</li><li><strong>Time Machine local snapshots</strong> &mdash; <code>/private/var/db/TimeMachine</code>. Created automatically to make the next backup incremental.</li><li><strong>iOS and iPadOS backups</strong> &mdash; <code>~/Library/Application Support/MobileSync/Backup</code>. One folder per device, often several GB.</li><li><strong>Logs, diagnostics and installer leftovers</strong> &mdash; <code>/private/var/log</code>, <code>/Library/Logs</code>, diagnostic reports.</li><li><strong>Developer residue</strong> &mdash; Xcode DerivedData, simulator data, package-manager caches, if you build software.</li><li><strong>Mounted disk images</strong> and assorted <code>/private/var</code> bookkeeping.</li></ul>",
      },
      {
        t: "note",
        variant: "warn",
        html: `<p><strong>The number is an estimate, and a lazy one.</strong> macOS recomputes the breakdown on a schedule and after certain events, not continuously. This produces the two behaviours that make the category infuriating: the figure can <em>jump upward</em> dramatically after a restart or a large deletion, and it can attribute the same bytes to two categories at once. Treat a sudden 200 GB jump as a prompt to investigate, never as a measurement.</p>`,
      },

      { t: "h2", html: "The five usual causes, ordered by how often they turn out to be it" },
      {
        t: "ol",
        items: [
          "<strong>Developer residue.</strong> On any machine used for iOS or backend development, this is the most common cause by a wide margin. Entirely reclaimable, and Xcode rebuilds what it needs.",
          "<strong>Stale iPhone and iPad backups.</strong> Check Storage Settings &rarr; General &rarr; Storage &rarr; Manage. Backups for devices you no longer own are pure waste.",
          "<strong>Accumulated logs and diagnostics.</strong> <code>/Library/Logs</code> and <code>~/Library/Logs/DiagnosticReports</code> grow over years and are almost never worth keeping beyond a few weeks.",
          "<strong>Time Machine local snapshots.</strong> Large, and entirely managed by macOS on a schedule. Deleting them by hand buys you nothing durable.",
          "<strong>Swap and the sleep image.</strong> Both scale with your RAM and shrink on reboot. There is nothing safe to clean here &mdash; restarting is the fix, and it is genuinely effective.",
        ],
      },
      { t: "h2", html: "Why &ldquo;clear System Data&rdquo; is not a safe button" },
      {
        t: "p",
        html:
          "<p>Because the bucket contains both disposable caches and things you cannot rebuild, a single &ldquo;clear System Data&rdquo; action has to treat them identically. That is the failure mode: the operation either leaves most of the space on the disk while reporting success, or removes something you needed.</p>" +
          "<p>This is why Worm Cleaner deliberately does not have a &ldquo;Clear System Data&rdquo; button. It has the individual targets instead &mdash; Xcode DerivedData, the Xcode cache, simulator caches, Homebrew downloads, npm and Yarn caches, Gradle build cache, pip and Composer caches, browser caches, crash reports and logs &mdash; each with a measured size, each individually selectable, each classified by risk.</p>" +
          "<p>What it will not touch is the interesting half: Time Machine snapshots, swap, the sleep image, or anything else it cannot prove is disposable.</p>",
      },
      { t: "h2", html: "Diagnosing it properly instead of guessing" },
      {
        t: "p",
        html:
          "<p>macOS gives you one useful disclosure: the <strong>i</strong> button next to System Data in Storage Settings shows a further breakdown, and it is frequently more revealing than the top-level number. After that, go below the abstraction layer:</p>",
      },
      { t: "code", text: "# Largest top-level directories in your home folder\ndu -sh ~/* ~/Library 2>/dev/null | sort -h | tail -20\n\n# The specific paths System Data usually hides\ndu -sh ~/Library/Developer ~/Library/Application\\ Support/MobileSync/Backup \\\n      ~/Library/Logs /private/var/vm /private/var/db/TimeMachine 2>/dev/null | sort -h\n\n# Largest individual files anywhere under your home folder\nfind ~ -type f -size +500M -print 2>/dev/null | head -30" },
      {
        t: "p",
        html:
          "<p>The middle command is the useful one. It measures the specific paths that the System Data bucket absorbs, so you get real numbers instead of an estimate you cannot act on.</p>",
      },
      { t: "h2", html: "What to clear, and what to leave" },
      {
        t: "table",
        caption: "System Data components by action",
        head: ["Component", "Action", "Cost"],
        rows: [
          ["Xcode DerivedData and build caches", "Clear", "Slower next build"],
          ["Package-manager caches", "Clear selectively", "Re-download of dependencies"],
          ["Browser caches", "Clear", "Slower first page load"],
          ["Old logs and crash reports", "Clear", "None"],
          ["iPhone / iPad backups for devices you no longer own", "Clear", "Cannot restore that device without re-backing-up"],
          ["Time Machine local snapshots", "Leave to macOS", "Pruned automatically"],
          ["Swap files", "Leave &mdash; restart instead", "Reboot"],
          ["Sleep image", "Leave", "None &mdash; it is required for instant sleep"],
          ["Files you cannot identify", "<span class=\"no\">Leave</span>", "Unknown, possibly expensive"],
        ],
      },
      {
        t: "p",
        html:
          "<p>The last row is the one most tools get wrong. If you cannot identify what a large directory is, do not delete it. Move it somewhere else first, confirm your machine still works, and only then remove it.</p>",
      },
      { t: "h2", html: "Reducing it for good" },
      {
        t: "p",
        html:
          "<ul><li><strong>Delete device backups you do not need</strong>, and set up iCloud or a scheduled backup for the device you do.</li><li><strong>Keep 15&ndash;20% of the volume free.</strong> This is the highest-leverage change. A drive at 95% full causes build failures, heavy swapping, stalled updates and caches that stop being written &mdash; all of which land in System Data.</li><li><strong>Restart on a schedule.</strong> Swap and the sleep image release on reboot. Nothing else does that for you.</li><li><strong>Prune dev residue on a schedule</strong>, not just when the disk is full.</li><li><strong>Do not chase the number.</strong> System Data will always be large. Judge success by free space you can see in <code>df -h /</code>, which is exact.</li></ul>" +
          OPTIMIZER_NOTE,
      },
      { t: "h2", html: "What this all adds up to" },
      {
        t: "p",
        html:
          "<p>System Data is not a bug and not a secret. It is a bucket, and buckets are filled with whatever does not fit elsewhere. Treating it as an opaque quantity you must &ldquo;clear&rdquo; is what produces disappointing results. Treating it as a list of identifiable directories, measuring each one, and clearing the disposable ones is what actually frees space.</p>",
      },
      { t: "faq", faqs: [] },
      CTA,
      {
        t: "related",
        ids: ["/why-is-my-mac-storage-full", "/mac-storage-cleaner", "/clear-xcode-deriveddata"],
      },
    ],
    faqs: [
      {
        q: "What is System Data on a Mac?",
        a: "System Data is macOS's catch-all storage category for anything it cannot attribute to Applications, Documents, Photos or another named bucket. It typically contains swap files, the sleep image, Time Machine local snapshots, iPhone and iPad backups, logs, diagnostic reports, developer build residue and assorted /private/var bookkeeping. It is a remainder rather than a category, which is why it grows for reasons you did not cause.",
      },
      {
        q: "How do I reduce System Data storage on a Mac?",
        a: "Clear the identifiable parts rather than the bucket. The biggest wins, in order, are developer residue (Xcode DerivedData and package-manager caches), stale iPhone and iPad backups under ~/Library/Application Support/MobileSync/Backup, and accumulated logs and diagnostic reports. Leave Time Machine snapshots and swap to macOS — they are pruned on a schedule and released on reboot, and deleting them by hand buys nothing durable.",
      },
      {
        q: "Can I clear System Data on macOS?",
        a: "Not safely as a single action, because System Data is not a single thing — it holds both disposable caches and things that cannot be rebuilt, so any blanket operation either frees less than it claims or removes something you needed. Clear the specific underlying targets instead, and leave Time Machine snapshots, swap and the sleep image alone. Worm Cleaner exposes those individual targets with sizes and risk tiers precisely instead of offering one dangerous button.",
      },
      {
        q: "Why does System Data keep growing back after I clean it?",
        a: "Because much of it is regenerated by design: macOS rewrites logs, caches and swap continuously, and creates Time Machine local snapshots automatically to make the next backup incremental. If a cleaner reports reclaiming 30 GB and the figure returns a week later, that usually means the space genuinely went back into caches — which is what caches do. The durable fix is reducing what generates them, not clearing more often.",
      },
      {
        q: "Is System Data a sign of malware or a virus?",
        a: "Almost never. A very large or rapidly growing System Data value is far more commonly explained by developer residue, old device backups, Time Machine snapshots or accumulated logs. If you suspect malware specifically, look for the actual indicators — an unfamiliar login item, a browser extension you did not install, a new system extension, unexpected outbound connections — rather than inferring from a storage figure that macOS itself estimates loosely.",
      },
    ],
  },
];