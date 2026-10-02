<div align="center">

<img src="Resources/worm_social_preview.png" width="100%" alt="Worm - Fast Transparent macOS Cleaner and Monitor" />

# Worm
### Ultra-Fast, Transparent System Cleaner, App Uninstaller & Hardware Monitor for macOS

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Platform](https://img.shields.io/badge/Platform-macOS%2014.0%2B%20%7C%20Apple%20Silicon%20%26%20Intel-black.svg?logo=apple)](https://github.com/namdevnaman/worm)
[![Release](https://img.shields.io/badge/Release-v1.0.1-green.svg)](https://github.com/namdevnaman/worm/releases)
[![Swift 6](https://img.shields.io/badge/Swift-6.0-orange.svg?logo=swift)](https://swift.org)
[![PRs Welcome](https://img.shields.io/badge/PRs-welcome-brightgreen.svg)](https://github.com/namdevnaman/worm/pulls)

**Worm** is a modern, lightweight, and open-source system optimizer and disk cleanup companion designed specifically for Apple Silicon (M1, M2, M3, M4) and Intel Macs running macOS 14 Sonoma, macOS 15 Sequoia, and later.

[**Download Latest Release (v1.0.1)**](https://github.com/namdevnaman/worm/releases/latest) • [**Setup & Installation Guide**](SETUP.md) • [**Contribute**](#contributing)

</div>

---

## Executive Summary

Traditional Mac cleaning utilities often operate as proprietary black boxes, impose subscription fees, run heavy Electron web shells, or transmit telemetry in the background.

Worm provides an open-source, performant alternative engineered around transparency, fail-safe user data protection, and minimal resource usage:
- **Zero Black Boxes:** Every cache file, directory, and leftover trace is inspectable before removal.
- **Fail-Safe Safety Engine:** Personal user data (`~/Documents`, `~/Desktop`, personal libraries) and running application containers are strictly protected by design.
- **Micro-Footprint:** Built in pure Swift 6 and SwiftUI. Zero Electron, zero background tracking, and negligible memory overhead.
- **High-Throughput Concurrency:** Asynchronous multi-core directory scanning with sub-millisecond evaluation.

---

## Core Capabilities

### 1. Developer & System Cache Cleanup
Reclaims gigabytes of disk space consumed by build tools, development environments, and system processes:
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

## Performance Benchmarks

| Metric | Traditional Commercial Cleaners | Worm |
| :--- | :--- | :--- |
| **Framework** | Electron / WebKit Wrapper | Native Swift 6 + SwiftUI |
| **Idle RAM Usage** | 180 MB – 450 MB | Under 35 MB |
| **Telemetry & Tracking** | Embedded Analytics / Sentry | None (100% Offline) |
| **Xcode DerivedData Scan** | ~12 seconds | Under 0.8 seconds |
| **Pricing Model** | Recurring Subscription | Free & Open Source (MIT) |

---

## Installation

### Method 1: Universal Installer (DMG)
1. Download `Worm-1.0.1.dmg` from the [Releases](https://github.com/namdevnaman/worm/releases/latest) page.
2. Drag `Worm.app` into your `/Applications` directory.
3. Open `Worm.app`. If prompted by macOS Gatekeeper:
   - Navigate to **System Settings → Privacy & Security → Scroll to Security → Click "Open Anyway"**.
   - Alternatively, remove the quarantine attribute via Terminal:
     ```bash
     xattr -cr /Applications/Worm.app
     ```
4. Grant **Full Disk Access** in **System Settings → Privacy & Security → Full Disk Access** to enable thorough container inspections.

### Method 2: Build from Source
```bash
# Clone the repository
git clone https://github.com/namdevnaman/worm.git
cd worm

# Build the release bundle
./scripts/build-app.sh

# Install to /Applications
./scripts/install.sh
```

For comprehensive configuration details, see [SETUP.md](SETUP.md).

---

## Technology Stack

- **Language:** Swift 6.0
- **User Interface:** SwiftUI (macOS 14.0+)
- **System Kernel Access:** Mach kernel APIs, Darwin IOKit, libproc
- **Build System:** Swift Package Manager (SPM)
- **Architecture:** Universal Binary (Apple Silicon M-series & Intel x86_64)

---

## Contributing

Contributions, bug reports, and pull requests are welcome. Worm is licensed under the MIT license and open for public collaboration.

To contribute:
1. Fork the repository (`https://github.com/namdevnaman/worm/fork`).
2. Create a feature branch (`git checkout -b feature/scan-rule-enhancement`).
3. Commit your changes (`git commit -m 'Add scan rule for new tool'`).
4. Push to the branch (`git push origin feature/scan-rule-enhancement`).
5. Open a Pull Request.

---

## License

Distributed under the **MIT License**. See [LICENSE](LICENSE) for full legal text.

---

<div align="center">

Maintained by [Naman Namdev](https://github.com/namdevnaman).

If Worm helped reclaim disk space on your Mac, please consider starring the project on GitHub.

</div>
