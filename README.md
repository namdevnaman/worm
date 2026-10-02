<div align="center">

<img src="Resources/worm_social_preview.png" alt="Worm: free open-source Mac and Windows cleaner, app uninstaller and system monitor" width="100%">


# Worm: Free, Open-Source Mac & Windows Cleaner


**Clean developer caches, uninstall apps completely, and monitor your hardware. Native, transparent, and zero telemetry.**


[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![macOS 14+](https://img.shields.io/badge/macOS-14.0%2B-black.svg?logo=apple)](https://github.com/namdevnaman/worm/releases)
[![Windows 10/11](https://img.shields.io/badge/Windows-10%20%2F%2011%20(x64)-0078D6.svg?logo=windows)](https://github.com/namdevnaman/worm/releases)
[![Release](https://img.shields.io/github/v/release/namdevnaman/worm?color=green)](https://github.com/namdevnaman/worm/releases)
[![Swift 6](https://img.shields.io/badge/Swift-6-orange.svg?logo=swift)](https://swift.org)
[![.NET 9](https://img.shields.io/badge/.NET-9-512BD4.svg?logo=dotnet)](https://dotnet.microsoft.com)
[![PRs Welcome](https://img.shields.io/badge/PRs-welcome-brightgreen.svg)](https://github.com/namdevnaman/worm/pulls)


[**Download**](#download-worm) · [**Features**](#features) · [**How it compares**](#worm-vs-commercial-cleaners) · [**FAQ**](#faq) · [**Setup guide**](SETUP.md)


</div>

---

## What is Worm?

**Worm is a free, open-source disk cleaner, app uninstaller and system monitor for macOS and Windows.** It frees up storage by removing developer caches (Xcode DerivedData, npm, Homebrew, Cargo, Gradle and more), browser caches, and the leftover files that uninstalled apps leave behind. It also shows live CPU, memory, disk and thermal stats from your menu bar (macOS) or system tray (Windows).

Worm is built as a transparent alternative to subscription cleaners such as CleanMyMac and CCleaner:

- **Free forever.** MIT licensed, no subscription, no upsell.
- **No telemetry.** It runs fully offline and sends nothing anywhere.
- **Native and lightweight.** Swift 6 + SwiftUI on macOS, .NET 9 on Windows. No Electron.
- **Safe by default.** You review every item before deletion, and personal folders are protected.

> **Who is it for?** Developers whose Mac is full of Xcode and package manager caches, and anyone who wants a cleaner they can audit instead of trusting a black box.

---

## Download Worm

Latest release: **v1.0.3**

| Platform | Format | Download | Notes |
| --- | --- | --- | --- |
| macOS 14+ (Apple Silicon & Intel) | DMG installer | [**Worm-Installer.dmg**](https://github.com/namdevnaman/worm/releases/download/v1.0.3/Worm-Installer.dmg) | Drag to Applications. Includes a Gatekeeper helper. |
| macOS 14+ (Apple Silicon & Intel) | ZIP | [**Worm-macOS.zip**](https://github.com/namdevnaman/worm/releases/download/v1.0.3/Worm-macOS.zip) | Portable `Worm.app` bundle. |
| Windows 10 / 11 (x64) | ZIP | [**Worm-Windows-x64.zip**](https://github.com/namdevnaman/worm/releases/download/v1.0.3/Worm-Windows-x64.zip) | Self-contained, no runtime required. Includes `Install-Worm.ps1`. |

> **Windows note:** Worm is not code-signed, so SmartScreen may block it on first
> launch. Extract the ZIP and run `Install-Worm.ps1` — it removes the Mark-of-the-Web
> and installs without admin rights. See [Windows: if SmartScreen blocks Worm](#windows-if-smartscreen-blocks-worm).

See all versions on the [Releases page](https://github.com/namdevnaman/worm/releases).

---

## Features

### Mac cleaner for developers (macOS)

Reclaim tens of gigabytes taken up by build tools and system processes.

| Category | What Worm cleans |
| --- | --- |
| **Xcode & iOS** | `DerivedData`, legacy device support files, archives, simulator runtimes |
| **Package managers** | npm, pnpm, yarn, Cargo (Rust), pip, Go build cache, Gradle, Homebrew, CocoaPods |
| **Browsers & Electron apps** | Chrome, Safari, Edge, Firefox, Brave and Electron app caches |

Items go to the macOS **Trash** by default, so nothing is permanently deleted unless you choose it.

### Uninstall Mac apps and remove leftovers

Dragging an app to the Trash leaves files behind. Worm finds them.

- **Orphan detection** across `~/Library/Application Support`, `Preferences`, `Caches`, `Saved Application State` and `WebKit`.
- **Positive absence verification.** Worm checks app bundles in system paths and Spotlight to confirm an app is really uninstalled before flagging its files.
- **Granular review.** Inspect each file's size, creation date and path before deleting.

### Menu bar system monitor (macOS)

- Live CPU core load and process count
- Memory breakdown: App, Wired, Compressed
- Disk capacity and reclaimed storage
- Thermal and fan status
- Left-click for live metrics, right-click for the context menu

### Security and auditability (macOS)

- Guided **Full Disk Access** setup for macOS privacy (TCC) permissions
- Every operation is logged locally to `~/Library/Logs/Worm/deletions.tsv`

### Windows cleaner and junk file remover

- **Temp and system junk:** `%TEMP%`, `C:\Windows\Temp`, memory dump logs
- **Windows Update leftovers:** old rollback files and `SoftwareDistribution\Download`
- **Crash dumps:** WER reports, mini-dumps, event trace caches
- **Recycle Bin:** analysis and cleanup across all volumes via the Win32 Shell API

### Windows uninstaller leftovers and orphaned app data

- Scans `%APPDATA%` and `%LOCALAPPDATA%` for folders left by uninstalled software
- Cross-checks the Windows Registry uninstall keys (`HKLM` and `HKCU`) so installed apps are never touched
- Critical Windows components and protected user paths are excluded

### Windows hardware monitor

- CPU utilization via `GetSystemTimes`
- RAM usage via `GlobalMemoryStatusEx`
- Total, free and used space on every mounted NTFS/FAT32 volume
- System tray icon with quick clean and status

---

## Safety: how Worm protects your data

1. **Inspect before action.** Every cache entry and leftover is listed before anything is removed.
2. **Protected paths.** `~/Documents`, `~/Desktop` and other personal folders are never deleted.
3. **Running processes are protected.**
4. **Trash first on macOS.** Recoverable by default.
5. **Registry cross-check on Windows.** Only true orphans are flagged.
6. **Local audit log.** A permanent record of operations stays on your machine.
7. **Open source.** Read the code, build it yourself, verify the claims.

---

## Worm vs commercial cleaners

| | Typical commercial cleaners | Worm for Mac | Worm for Windows |
| --- | --- | --- | --- |
| **Price** | Recurring subscription | Free (MIT) | Free (MIT) |
| **Source code** | Closed | Open | Open |
| **Framework** | Often Electron / web wrapper | Swift 6 + SwiftUI | .NET 9 + WPF |
| **Telemetry** | Often embedded analytics | None (offline) | None (offline) |
| **Idle RAM** | 180 to 450 MB | Under 35 MB | Under 42 MB |
| **Xcode / temp scan** | ~12 s | Under 0.8 s | Under 0.6 s |
| **Portable** | No | No (`.app` bundle) | Yes (extract-and-run ZIP) |

<sub>Figures are measured on the author's test machines. See [SETUP.md](SETUP.md) for how to reproduce them.</sub>

---

## Installation

### macOS

1. Download [`Worm-Installer.dmg`](https://github.com/namdevnaman/worm/releases/download/v1.0.3/Worm-Installer.dmg).
2. Drag `Worm.app` into `/Applications`.
3. Open it. If Gatekeeper blocks it, go to **System Settings → Privacy & Security → Open Anyway**, or double-click `Open-If-Blocked.command`.
4. Grant **Full Disk Access** in System Settings so Worm can scan app containers thoroughly.

### Windows

Three ways, easiest first.

**1. Double-click (no admin needed)**

1. Download and extract [`Worm-Windows-x64.zip`](https://github.com/namdevnaman/worm/releases/download/v1.0.3/Worm-Windows-x64.zip).
2. Double-click **`Install-Worm.cmd`**.

That clears the Mark-of-the-Web that makes SmartScreen block an unsigned build, verifies the download against `SHA256SUMS.txt`, installs to `%LOCALAPPDATA%\Programs\Worm`, adds Start-menu / Desktop / start-up shortcuts, registers Worm under **Settings → Apps → Installed apps**, and launches it. Uninstall with **`Uninstall.cmd`** or from Settings.

**2. Scoop**

```powershell
scoop bucket add worm https://raw.githubusercontent.com/namdevnaman/worm/main/worm-windows/packaging/scoop/worm.json
scoop install worm
```

**3. PowerShell**

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\Install-Worm.ps1
```

Add `-Purge` to also delete logs and settings, or `-InstallDir 'D:\Apps\Worm'` to relocate. Worm installs per-user, so **no administrator rights are required** — deliberately, because an unsigned MSI would trigger a UAC "unknown publisher" prompt and MsiExecTrust block, which is a worse first-run experience than a portable ZIP.

### Build from source

**macOS**

```bash
git clone https://github.com/namdevnaman/worm.git && cd worm
./scripts/build-app.sh && cp -R dist/Worm.app /Applications/
```

**Windows**

```powershell
cd worm-windows
scripts\build.bat
```

That produces `worm-windows\dist\win-x64\` and a packaged
`worm-windows\dist\Worm-Windows-x64.zip` with checksums.

---

## FAQ

### Is Worm safe to use?
Yes. Worm lists everything before deletion, protects personal folders and running processes, moves files to the Trash on macOS, and logs every operation locally. The full source is open for review.

### Is Worm really free?
Yes. It is MIT licensed with no subscription, ads or paid tier.

### Does Worm collect data or use telemetry?
No. Worm works fully offline and has no analytics or tracking.

### How do I clear Xcode DerivedData on a Mac?
Open Worm, run a scan, select **Xcode & iOS** items such as `DerivedData`, review the list, and clean. Items go to the Trash by default.

### How do I completely uninstall a Mac app and remove its leftover files?
Delete the app as usual, then run Worm's leftover scan. It finds orphaned files in `~/Library` and lets you review each one before removal.

### Which package manager caches can Worm clean?
npm, pnpm, yarn, Cargo, pip, Go build cache, Gradle, Homebrew and CocoaPods.

### Is Worm an alternative to CleanMyMac or CCleaner?
It covers similar ground (cache cleanup, uninstall leftovers, system monitoring) as a free, open-source tool with no telemetry. It is younger and has a narrower feature set, so compare it against what you need.

### Which systems does Worm support?
macOS 14.0 or later (Apple Silicon and Intel) and Windows 10 / 11 (x64).

### Why does macOS block Worm on first launch?
The app is not distributed through the App Store. Use **Open Anyway** in System Settings → Privacy & Security, or run `Open-If-Blocked.command` from the DMG.

### Windows: if SmartScreen blocks Worm
Worm is open source and **not code-signed**, so its binaries carry a Mark-of-the-Web and Windows SmartScreen treats them as unknown. This happens on double-click *and* when launching from `cmd` or PowerShell — the block is caused by the download, not the launcher.

Easiest fix — extract the ZIP and double-click **`Install-Worm.cmd`**. It clears the Mark-of-the-Web and installs for you.

Or do it manually: right-click the ZIP → **Properties** → tick **Unblock** → **Apply**, or after extracting run:

```powershell
Get-ChildItem -Recurse -File | Unblock-File
```

If SmartScreen still prompts, choose **More info → Run anyway**.

A fully click-through, warning-free install requires a paid code-signing certificate; Worm is MIT open source, so it ships un-signed by design.

### Worm.exe is gone from the Windows download, why?
The single-file `Worm.exe` from v1.0.2 was 68 MB and unreliable: it bundled WPF's compiled XAML and `.g.resources` into a *compressed* single-file bundle, which WPF cannot reliably read, so the app could exit before drawing a window. Windows now ships a self-contained **folder inside `Worm-Windows-x64.zip`**. It is a larger download but has no bundling layer to fail.

### Why does Worm need Full Disk Access?
macOS protects some app container folders. Without Full Disk Access, Worm cannot see them, so scans would miss leftovers.

---

## Technology stack

| | macOS | Windows |
| --- | --- | --- |
| **Language** | Swift 6.0 | C# 13 / .NET 9 LTS |
| **UI** | SwiftUI (macOS 14+) | ModernWpfUI with Mica & Acrylic |
| **System access** | Mach kernel APIs, IOKit, libproc | Win32 P/Invoke (`kernel32`, `shell32`, `dwmapi`) |
| **Build / packaging** | Swift Package Manager, Universal Binary | Self-contained folder, shipped as a ZIP |

---

## Contributing

Bug reports, new scan rules and pull requests are welcome.

1. Fork the repo.
2. Create a branch: `git checkout -b feature/new-scanner`
3. Commit: `git commit -m "Add scan rule for new tool"`
4. Push and open a Pull Request.

Have an idea for a new cache target? [Open an issue](https://github.com/namdevnaman/worm/issues).

---

## License

Released under the [MIT License](LICENSE).

## Author

Built and maintained by [Naman Namdev](https://github.com/namdevnaman).

If Worm freed up space on your machine, please **star the repo**. It helps others find it.

<!--
Search keywords: free mac cleaner, open source mac cleaner, macOS disk cleanup, clear Xcode DerivedData,
developer cache cleaner, uninstall mac apps completely, remove app leftovers, CleanMyMac alternative,
CCleaner alternative, Windows junk file cleaner, free up disk space, menu bar system monitor, no telemetry cleaner
-->
