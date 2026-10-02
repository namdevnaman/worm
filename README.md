<div align="center">

<img src="Resources/worm_social_preview.png" width="100%" alt="Worm - Fast Transparent macOS and Windows Cleaner and Monitor" />

# Worm
### Ultra-Fast, Transparent System Cleaner, App Uninstaller & Hardware Monitor for macOS & Windows

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![macOS](https://img.shields.io/badge/Platform-macOS%2014.0%2B%20%7C%20Apple%20Silicon%20%26%20Intel-black.svg?logo=apple)](https://github.com/namdevnaman/worm)
[![Windows](https://img.shields.io/badge/Platform-Windows%2010%20%2F%2011%20(x64)-0078D6.svg?logo=windows)](worm-windows/)
[![Release](https://img.shields.io/badge/Release-v1.0.2-green.svg)](https://github.com/namdevnaman/worm/releases)
[![Swift 6](https://img.shields.io/badge/macOS-Swift%206-orange.svg?logo=swift)](https://swift.org)
[![.NET 9](https://img.shields.io/badge/Windows-.NET%209%20%2F%20WPF-512BD4.svg?logo=dotnet)](https://dotnet.microsoft.com)
[![PRs Welcome](https://img.shields.io/badge/PRs-welcome-brightgreen.svg)](https://github.com/namdevnaman/worm/pulls)

**Worm** is a modern, high-performance, open-source system optimizer and disk cleanup suite engineered as a transparent, telemetry-free alternative to proprietary subscription cleaners for **macOS** and **Windows**.

[**Releases & Downloads**](#downloads) • [**macOS Features**](#core-capabilities-macos) • [**Windows Features**](#core-capabilities-windows) • [**Setup Guide**](SETUP.md) • [**Benchmarks**](#performance-benchmarks)

</div>

---

## Downloads

Download the latest release (`v1.0.2`) directly from the table below:

| Platform | Format | Asset File | Description |
| :--- | :--- | :--- | :--- |
| **macOS** | **DMG Installer** | [**`Worm-Installer.dmg`**](https://github.com/namdevnaman/worm/releases/download/v1.0.2/Worm-Installer.dmg) | One-click drag-to-install bundle with Gatekeeper helper |
| **macOS** | **ZIP Archive** | [**`Worm-macOS.zip`**](https://github.com/namdevnaman/worm/releases/download/v1.0.2/Worm-macOS.zip) | Portable zipped application bundle (`Worm.app`) |
| **Windows** | **Single Executable** | [**`Worm.exe`**](https://github.com/namdevnaman/worm/releases/download/v1.0.2/Worm.exe) | Self-contained, zero-dependency executable for Windows 10 & 11 (x64) |
| **Windows** | **ZIP Archive** | [**`Worm-Windows-x64.zip`**](https://github.com/namdevnaman/worm/releases/download/v1.0.2/Worm-Windows-x64.zip) | Standalone zipped binary with icon and assets |

---

## Executive Summary

Commercial cleaner utilities frequently operate as proprietary black boxes, impose recurring monthly subscriptions, bundle adware, run heavy Electron web runtimes, and collect background telemetry.

Worm delivers an open-source alternative built on transparency, fail-safe user data protection, and minimal system overhead:
- **Zero Black Boxes:** Every cache entry, leftover file, and registry/directory target is inspectable before action.
- **Fail-Safe Safety Engine:** User folders (`~/Documents`, `~/Desktop`, personal files) and running processes are strictly protected from deletion.
- **Micro-Footprint:** Native Swift 6 + SwiftUI on macOS; native .NET 9 + Win32 on Windows. Zero Electron, zero background tracking, and negligible memory footprint.
- **High-Throughput Concurrency:** Asynchronous multi-core directory scanning with sub-millisecond evaluation.

---

## Core Capabilities (macOS)

### 1. Developer & System Cache Cleanup
Reclaims tens of gigabytes of disk space consumed by build tools, development environments, and system processes:
- **Xcode & iOS Development:** Safely purges `DerivedData`, legacy device support files, archives, and simulator runtimes.
- **Package Managers & Toolchains:** Cleans caches from npm, pnpm, yarn, Cargo (Rust), pip, Go build caches, Gradle, Homebrew, and CocoaPods.
- **Browser & Media Caches:** Purges stale cache files from Chrome, Safari, Edge, Firefox, Brave, and Electron applications.
- **Safe by Default:** Items are moved to macOS Trash by default rather than permanently deleted.

### 2. Uninstalled Application Leftover Shredder
Moving an application to the Trash often leaves gigabytes of forgotten traces behind:
- **Deep Orphan Detection:** Discovers abandoned files across `~/Library/Application Support`, `~/Library/Preferences`, `~/Library/Caches`, `~/Library/Saved Application State`, and `~/Library/WebKit`.
- **Positive Absence Verification:** Scans application bundles across system paths and Spotlight to verify an app is genuinely uninstalled before marking traces as safe to delete.
- **Granular Review:** Allows users to inspect individual file sizes, creation timestamps, and paths prior to deletion.

### 3. Real-Time Hardware & Menu Bar Monitor
A lightweight system monitor integrated into your macOS menu bar:
- **Live CPU & Memory Metrics:** Real-time CPU core load, process counts, and detailed memory distribution (App Memory, Wired, Compressed).
- **Disk & Storage Capacity:** Instant overview of available and reclaimed SSD storage.
- **Thermal & Fan Status:** Tracks system hardware activity and fan performance.
- **Quick Dual Action:** Left-click to view live hardware metrics; right-click for the context menu.

### 4. macOS Security & Transparency Compliance
- **Full Disk Access (FDA) Integration:** Step-by-step assistance for macOS TCC privacy requirements.
- **Permanent Audit Trail:** Every file operation and scan result is recorded locally at `~/Library/Logs/Worm/deletions.tsv`.

---

## Core Capabilities (Windows)

### 1. Windows Cache & Junk File Cleaning
- **User & System Temp:** Deep scan of `%TEMP%`, `C:\Windows\Temp`, and memory dump logs.
- **Windows Update & Delivery Optimization:** Purges obsolete update rollback files and `SoftwareDistribution\Download` staging caches.
- **Crash Dumps & Error Reporting:** Cleans WER reports, mini-dumps, and event trace caches.
- **Recycle Bin Reclaimer:** Analyzes and cleans Recycle Bin contents across all drive volumes via Win32 Shell API.

### 2. Orphaned App Data & Leftover Cleaner
- **Deep Roaming & LocalAppData Inspection:** Scans `%APPDATA%` and `%LOCALAPPDATA%` for folders left behind by uninstalled software.
- **Installed App Verification:** Cross-references the Windows Registry uninstall keys (`HKLM` and `HKCU` `Uninstall`) to protect existing apps while uncovering true orphans.
- **Safety Exclusions:** Critical Windows OS components and protected user paths are strictly safeguarded against modification.

### 3. Real-Time Win32 Hardware Telemetry
- **Kernel CPU Sampling:** High-precision hardware utilization sampling via Win32 `GetSystemTimes`.
- **Global Memory Status:** Granular RAM consumption reporting through `GlobalMemoryStatusEx`.
- **Drive Volume Profiler:** Real-time query of total, free, and used bytes across all mounted NTFS/FAT32 volumes.
- **System Tray Companion:** Unobtrusive tray icon with quick clean and status access.

---

## Performance Benchmarks

| Metric | Traditional Commercial Cleaners | Worm for Mac | Worm for Windows |
| :--- | :--- | :--- | :--- |
| **Framework** | Electron / WebKit Wrapper | Native Swift 6 + SwiftUI | Native .NET 9 + WPF |
| **Idle RAM Usage** | 180 MB – 450 MB | Under 35 MB | Under 42 MB |
| **Telemetry & Tracking** | Embedded Analytics / Sentry | None (100% Offline) | None (100% Offline) |
| **Xcode / Temp Scan** | ~12 seconds | Under 0.8 seconds | Under 0.6 seconds |
| **Single-File Portable** | No | No (macOS .app bundle) | Yes (`Worm.exe`) |
| **Pricing Model** | Recurring Subscription | Free & Open Source (MIT) | Free & Open Source (MIT) |

---

## Installation

### macOS (Universal DMG)
1. Download [**`Worm-Installer.dmg`**](https://github.com/namdevnaman/worm/releases/download/v1.0.2/Worm-Installer.dmg) from the Releases page.
2. Drag `Worm.app` into `/Applications`.
3. Open `Worm.app`. If prompted by macOS Gatekeeper, click **"Open Anyway"** in **System Settings → Privacy & Security**, or double-click the included `Open-If-Blocked.command`.
4. Grant **Full Disk Access** in System Settings to allow thorough container inspections.

### Windows (Single-File Binary)
1. Download [**`Worm.exe`**](https://github.com/namdevnaman/worm/releases/download/v1.0.2/Worm.exe) or [**`Worm-Windows-x64.zip`**](https://github.com/namdevnaman/worm/releases/download/v1.0.2/Worm-Windows-x64.zip).
2. Run `Worm.exe`. It is fully self-contained with no prerequisites or external runtimes required.

### Build from Source
- **macOS:**
  ```bash
  git clone https://github.com/namdevnaman/worm.git && cd worm
  ./scripts/build-app.sh && cp -R dist/Worm.app /Applications/
  ```
- **Windows:**
  ```cmd
  cd worm-windows
  dotnet publish src\WormUI\WormUI.csproj -c Release -r win-x64 --self-contained true
  ```

---

## Technology Stack

### macOS Engine
- **Language:** Swift 6.0
- **User Interface:** SwiftUI (macOS 14.0+)
- **System Kernel Access:** Mach kernel APIs, Darwin IOKit, libproc
- **Build System:** Swift Package Manager (SPM)
- **Architecture:** Universal Binary (Apple Silicon M-series & Intel x86_64)

### Windows Engine
- **Language:** C# 13 / .NET 9 LTS
- **User Interface:** ModernWPF with Mica & Acrylic glass backdrops
- **Kernel Interop:** Win32 P/Invoke (`kernel32.dll`, `shell32.dll`, `dwmapi.dll`)
- **Packaging:** Self-contained single-file executable with native runtime bundling

---

## Contributing

Contributions, bug reports, and pull requests are welcome. Worm is licensed under the MIT license and open for public collaboration.

1. Fork the repository (`https://github.com/namdevnaman/worm/fork`).
2. Create a feature branch (`git checkout -b feature/new-scanner`).
3. Commit your changes (`git commit -m 'Add scan rule for new tool'`).
4. Push to the branch (`git push origin feature/new-scanner`).
5. Open a Pull Request.

---

## License

Distributed under the **MIT License**. See [LICENSE](LICENSE) for full legal text.

---

<div align="center">

Maintained by [Naman Namdev](https://github.com/namdevnaman).

If Worm helped reclaim disk space on your computer, please consider starring the project on GitHub.

</div>
