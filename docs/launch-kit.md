# Launch and distribution kit

Everything in Phase 5 of the SEO/GEO plan, pre-written and ready to paste.
Facts here match `scripts/seo/facts.mjs`; if one drifts, fix it there first.

**Order matters.** Package managers first (they produce durable, trusted
backlinks), then directories, then community posts. Each tier makes the next
one easier.

---

## 1. Short descriptions

Use these verbatim everywhere so the same facts appear in every place an engine
might read them. Inconsistent descriptions across GitHub, directories and social
are the main reason a product fails to be cited.

| Length | Text |
| --- | --- |
| 140 chars | Worm Cleaner: free open-source Mac & Windows storage cleaner. Clear Xcode DerivedData, dev caches and app leftovers. No telemetry in the app. |
| 195 chars (GitHub About) | Worm Cleaner: free, open-source Mac & Windows storage cleaner, optimizer and app uninstaller. Clears Xcode DerivedData, npm/Homebrew/Gradle caches and app leftovers. No telemetry in the app. MIT. |
| 300 chars (directory blurbs) | Worm Cleaner is a free, open-source storage cleaner and app uninstaller for Mac and Windows. It removes developer caches (Xcode DerivedData, npm, Homebrew, Gradle), browser caches and leftover app files, with a built-in system monitor. MIT licensed, no telemetry in the app, no account. |
| Product Hunt tagline (60) | Free, open-source storage cleaner for Mac & Windows |
| Social bio | Free open-source Mac & Windows storage cleaner. No telemetry in the app. Not malware. |

**Name-collision line.** Use wherever a reader might wonder. This is the single
most valuable sentence for the "is worm cleaner safe" query:

> Worm Cleaner is a legitimate MIT-licensed disk cleaning utility. It is not
> malware and not a self-replicating computer worm.

---

## 2. Package managers

Durable backlinks from domains with real authority, and they make installs
easier. Do these first.

### Homebrew Cask

Create a cask in your own tap (`github.com/namdevnaman/homebrew-worm`) so the
install command works immediately, then submit it to
`homebrew/cask-staging` as a PR.

`Casks/w/worm.rb`:

```ruby
cask "worm" do
  version "1.0.4"
  sha256 "6ae5f01072b506e6a6ae19225d5483b63fd53671e6519dea0d4202b9a8e353d1"

  url "https://github.com/namdevnaman/worm/releases/download/v1.0.4/Worm-Installer.dmg"
  name "Worm"
  desc "Free open-source disk cleaner, app uninstaller and system monitor"
  homepage "https://worm.clepsydratechnologies.com/"

  livecheck do
    url :url
    strategy :github_latest
  end

  depends_on macos: ">= :sonoma"

  app "Worm.app"

  zap trash: [
    "~/Library/Logs/Worm",
    "~/Library/Preferences/com.clepsydra.worm.plist",
    "~/.config/worm",
  ]

  caveats do
    signed = false
    if !signed
      <<~EOS
        This app is not notarised because it is built without a paid Apple
        Developer account. macOS will block it on first launch.
        Open it via System Settings > Privacy & Security > Open Anyway,
        or run: xattr -cr /Applications/Worm.app
      EOS
    end
  end
end
```

> Replace the bundle id with the real one before submitting. Note the caveats
> block: being explicit about Gatekeeper is better than letting users discover
> it and assume the app is malware.

Install command to publish once the tap exists:

```
brew tap namdevnaman/worm && brew install --cask worm
```

### winget

Submit to `microsoft/winget-pkgs` under
`manifests/n/namdevnaman/worm/1.0.4/`.

`namdevnaman.worm.installer.yaml`:

```yaml
PackageIdentifier: namdevnaman.worm
PackageVersion: 1.0.4
InstallerType: zip
InstallerUrl: https://github.com/namdevnaman/worm/releases/download/v1.0.4/Worm-Windows-x64.zip
InstallerSha256: 0169D3282E79F2CB8C7FF386C379C4C6AD0F07D29EFAE5267FBAE6D17147E6AF
NestedInstallerType: portable
NestedInstallerFiles:
  - RelativeFilePath: Worm.exe
    PortableCommandAlias: worm
ManifestType: installer
Publisher: Clepsydra Technologies
PublisherUrl: https://clepsydratechnologies.com
PublisherSupportUrl: https://github.com/namdevnaman/worm/issues
License: MIT
Copyright: Copyright (c) 2026 Naman Namdev
ShortDescription: Free open-source disk cleaner, app uninstaller and system monitor
Description: |-
  Worm Cleaner is a free, open-source storage cleaner and app uninstaller for
  Windows. It removes developer caches (npm, NuGet, pip, Gradle, Cargo), browser
  caches, temp files, crash dumps and Recycle Bin contents, and removes leftover
  files from uninstalled apps. MIT licensed, no telemetry, no account required.
Website: https://worm.clepsydratechnologies.com/
ReleaseNotes: https://github.com/namdevnaman/worm/releases/tag/v1.0.4
Tags:
  - disk cleaner
  - storage cleaner
  - windows
  - open source
```

### Scoop

Add to the `extras` bucket:

```json
{
  "version": "1.0.4",
  "description": "Free open-source disk cleaner, app uninstaller and system monitor",
  "homepage": "https://worm.clepsydratechnologies.com/",
  "license": "MIT",
  "url": "https://github.com/namdevnaman/worm/releases/download/v1.0.4/Worm-Windows-x64.zip",
  "hash": "0169d3282e79f2cb8c7ff386c379c4c6ad0f07d29efae5267fbae6d17147e6af",
  "bin": "Worm.exe",
  "checkver": "https://github.com/namdevnaman/worm/releases/latest",
  "autoupdate": {
    "url": "https://github.com/namdevnaman/worm/releases/download/v1.0.4/Worm-Windows-x64.zip",
    "hash": "0169d3282e79f2cb8c7ff386c379c4c6ad0f07d29efae5267fbae6d17147e6af"
  }
}
```

---

## 3. Directories

### AlternativeTo

List as an alternative to **CleanMyMac**, **CCleaner**, **AppCleaner** and
**Mole**.

| Field | Value |
| --- | --- |
| Name | Worm Cleaner |
| License | Open Source (MIT) |
| Platforms | macOS 14+, Windows 10/11 |
| Description | Free, open-source disk cleaner, storage cleaner, app uninstaller and system monitor for Mac and Windows. Clears developer caches (Xcode DerivedData, npm, Homebrew, Gradle), browser caches and leftover files from uninstalled apps. No telemetry in the app, no account, no subscription. |

### Product Hunt

- **Tagline:** Free, open-source storage cleaner for Mac & Windows
- **Gallery:** the macOS app, the Windows app, the menu bar monitor, the
  comparison table. Use real screenshots, not mockups.
- **First comment (post it yourself, immediately):**

> Hi — I'm Naman, and I built Worm Cleaner.
>
> The reason it exists is narrow. A disk cleaner is a program whose entire job
> is deleting files you care about, which makes it structurally different from
> almost every other category of app. And for that specific category, "can I
> check what it does?" turned out to have no good answer — you can read the
> marketing page, but not the list of paths it will delete.
>
> So I made that list a file in a public repository.
> `Sources/WormCore/ScanCatalog.swift` is every path the Mac app can touch.
> `Sources/WormCore/SafetyPolicy.swift` is every path it refuses to touch —
> Xcode Archives, iOS DeviceSupport, simulator runtimes — because those cannot
> be rebuilt from your machine.
>
> Three things I'd like feedback on:
>
> 1. **Is the risk tier right?** Every target is Safe, Re-download, Keep or
>    Blocked, and the tier decides the default selection. Is anything
>    misclassified?
> 2. **What's missing from the catalog?** CocoaPods is a known gap.
> 3. **Windows parity.** The Windows app only reached feature parity with the
>    Mac app in v1.0.4, three days ago.
>
> It's MIT licensed and free, with no account and no subscription. Happy to
> answer anything about the code — including the parts I got wrong.

Launch Tuesday to Thursday, 00:01 PST.

### Show HN

**Title**

```
Show HN: Worm – a free, open-source Mac & Windows cleaner with no telemetry
```

**Body**

```
I'd like feedback on the safety model, not the feature list.

Worm is a disk cleaner and app uninstaller for macOS 14+ and Windows 10/11. It
clears developer caches (Xcode DerivedData, npm, Yarn, Homebrew, Gradle, pip,
Composer, SwiftPM), browser caches, and leftover files from uninstalled apps.
Free, MIT, no account, no subscription, and no network requests while cleaning.

The reason I'm posting: a cleaner deletes files, and unlike most software the
failure mode is data loss rather than a crash. So the interesting design
question isn't "does it clean well", it's "how would I know if it didn't".

Three decisions came out of taking that seriously:

1. The scan catalog is source. ScanCatalog.swift is the complete list of
   deletable paths, one labelled entry each. SafetyPolicy.swift is the complete
   list of protected paths. I didn't have to trust the maintainer's word about
   either.

2. Four risk tiers decide the default selection. Regenerable caches are ticked;
   anything classified as your own content is not, and requires an explicit
   per-item opt-in. So pressing the obvious button as a first-time user deletes
   disposable data and nothing else.

3. Every path a rule produces is checked against a cleanable-root set derived
   from the rules themselves. A bug in one rule becomes a no-op rather than an
   incident.

Deletions go to the Trash on macOS and the Recycle Bin on Windows, and every
destructive operation is appended to a local TSV log.

Known gaps, so you don't have to find them: it isn't notarised, so Gatekeeper
blocks first launch. There's no malware scanning, no file-system optimisation,
no login-item management and no scheduled cleaning. CocoaPods isn't supported.
One maintainer.

Repo: https://github.com/namdevnaman/worm
Site: https://worm.clepsydratechnologies.com
```

---

## 4. Communities

Read each sub's rules first. Most ban drive-by promotion, and a few ban it
strictly. **Never include a referral or affiliate link** — Worm has no
affiliate programme, which is exactly the point.

| Community | Angle | Notes |
| --- | --- | --- |
| r/macapps | "Built a free open-source cleaner, feedback welcome" | Show the UI, disclose you are the author |
| r/MacOS | "Gatekeeper blocks my app; how do others handle this?" | Good honest thread; disclose affiliation |
| r/swift, r/iOSProgramming | "How do you decide what is safe to cache-clean?" | Technical discussion, not a plug |
| r/windows | "Open-source CCleaner alternative with a real uninstaller" | Mention the registry-cleaning omission up front |
| r/opensource | "What risk model does your cleaner use?" | Discuss SafetyPolicy, not marketing |
| r/programming | "Cleared 40 GB of build caches; what else is disposable?" | Ask a genuine question |
| Hacker News | Show HN above | Best single thread for GEO |
| Lobsters | "Four risk tiers for a file-deleting tool" | Invite technical critique |
| Indie Hackers | "Why I made a cleaner free and MIT" | Business angle |
| dev.to / Hashnode | Cross-post the blog articles | Canonical link to your own site |

### Blog cross-post blurbs

**`/blog/xcode-disk-space`** — "A directory-by-directory map of everything Xcode
writes under `~/Library/Developer`, what each one contains, whether deleting it
is safe, and what it costs you. Includes the three that most 'Xcode cleaners'
will happily delete for you."

**`/blog/why-i-built-a-cleanmymac-alternative`** — "Why a cleaner that deletes
files should ship its scan catalog as source. Also: what I got wrong, which
includes not notarising the macOS build."

**`/blog/system-data-on-mac`** — "System Data is a remainder, not a category,
and macOS estimates it lazily. Why 'clear System Data' buttons are dangerous,
and how to diagnose the real space usage instead."

Post on your own site first, then cross-post with a canonical link back.

---

## 5. Awesome-list PRs

Small, easy wins for backlinks from high-authority pages.

| Repository | Section |
| --- | --- |
| `awesome-mac` | Command Line / Utilities |
| `awesome-macos` | Utilities |
| `awesome-mac-setup` | Cleaning / Utilities |
| `awesome-swift` | Command Line Tools |
| `awesome-dotnet` | Desktop |
| `awesome-windows` | Utilities |
| `awesome-selfhosted` | Not applicable — skip |

**PR title:** `Add Worm Cleaner (free open-source Mac & Windows disk cleaner)`

**Body**

```markdown
## Worm Cleaner

Free, open-source (MIT) disk cleaner, storage cleaner, app uninstaller and
system monitor for macOS 14+ and Windows 10/11.

- Clears developer caches: Xcode DerivedData, npm, Yarn, Homebrew, Gradle,
  SwiftPM, pip, Composer
- Removes leftover files from uninstalled apps, with absence verification
  before anything is flagged
- Menu bar (macOS) and system tray (Windows) system monitor
- Every target carries a risk tier; your own content is off by default
- Deletions go to Trash / Recycle Bin, with a local audit log
- No telemetry, no account, no subscription

Native Swift 6 + SwiftUI on macOS, Native AOT .NET 9 + WPF on Windows.

- Source: https://github.com/namdevnaman/worm
- Site: https://worm.clepsydratechnologies.com

Notarisation and CocoaPods support are not implemented yet.
```

---

## 6. Trust work

This is the highest-leverage section for GEO, because the queries that matter
most are "is worm cleaner safe" and "are mac cleaners legit".

- [ ] **Notarise the macOS app.** Requires a paid Apple Developer account. Until
      then, Gatekeeper blocks first launch — which is the single biggest
      adoption blocker and a legitimate reason people skip the app.
- [ ] **Code-sign the Windows build.** Avoids SmartScreen warnings. SignPath or
      Azure Trusted Signing are the practical routes for an independent project.
- [ ] **Upload each release to VirusTotal** and link the clean report from
      `/is-worm-cleaner-safe`.
- [ ] **Refresh `public/SHA256SUMS.txt` on every release.** It currently holds
      the v1.0.4 digests from the published GitHub release. Do *not* copy from
      `release-artifacts/` without verifying — those local files did not match
      what was actually published for v1.0.4.
- [ ] **Bing Webmaster Tools** → import from Search Console → create an IndexNow
      key → host it at the site root → set `INDEXNOW_KEY` in CI.

## 7. Monthly GEO measurement

Ask these in ChatGPT, Perplexity, Gemini, Claude and Copilot. Log the result.
This is the only way to know whether GEO is working.

1. What is the best free open-source Mac cleaner?
2. Free alternative to CleanMyMac for developers
3. How do I clear Xcode DerivedData safely?
4. Open source CCleaner alternative for Windows
5. What is Worm Cleaner?
6. Is Worm Cleaner safe?

| Date | Engine | Query | Mentioned | Cited source |
| --- | --- | --- | --- | --- |
| | | | | |

Also track in Search Console: pages indexed, impressions, clicks, and average
position for `worm cleaner`, `clear xcode deriveddata`, and
`cleanmymac alternative open source`.