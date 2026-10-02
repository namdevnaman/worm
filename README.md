<div align="center">

<img src="Resources/AppIcon_512.png" width="128" height="128" alt="Worm App Icon" />

# Worm 🪱
### Ultra-Fast, Safe & Transparent System Cleaner & Monitor for macOS

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Platform](https://img.shields.io/badge/Platform-macOS%2014.0%2B%20%7C%20Apple%20Silicon%20%26%20Intel-black.svg?logo=apple)](https://github.com/namdevnaman/worm)
[![Release](https://img.shields.io/badge/Release-v1.0.1-green.svg)](https://github.com/namdevnaman/worm/releases)
[![Swift 6](https://img.shields.io/badge/Swift-6.0-orange.svg?logo=swift)](https://swift.org)
[![PRs Welcome](https://img.shields.io/badge/PRs-welcome-brightgreen.svg)](https://github.com/namdevnaman/worm/pulls)

**Worm** is a native, lightweight, and blazingly fast system optimizer and cleanup companion engineered for macOS (Sonoma, Sequoia & beyond). It delivers transparent cache purging, uninstalled app leftover shredding, interactive live system metrics, and strict fail-safe data safety.

[**Download Latest Release (v1.0.1)**](https://github.com/namdevnaman/worm/releases/latest) • [**Setup & Installation Guide**](SETUP.md) • [**Contribute**](#contributing)

</div>

---

## ⚡ Why Worm?

Most Mac cleaners are bloated, require subscription traps, or operate as black boxes that risk deleting user data. 

**Worm** is built with different principles:
- **Zero Black Boxes:** Every single file, cache directory, and leftover trace is inspectable before deletion.
- **Fail-Safe Safety Engine:** Your `~/Documents`, `~/Desktop`, personal files, and running app containers are strictly protected by design.
- **Micro-Footprint:** Native SwiftUI + Swift 6 implementation. No Electron, no background telemetry, zero tracking.
- **High Performance:** Multi-threaded async scanning with sub-millisecond per-path evaluation.

---

## ✨ Features

### 🧹 1. Smart & Selective Deep Clean
- **Comprehensive Clean Catalog:** Reclaims gigabytes from system caches, Xcode build artifacts (`DerivedData`, archives, device logs), simulator runtimes, development package managers (npm, pnpm, yarn, cargo, pip, go-build, gradle, pub, homebrew, cocoapods), browser caches, and orphaned logs.
- **Safe by Default:** Items are moved to macOS Trash by default rather than permanently deleted.
- **Enforcement-Grade Safety:** Critical macOS directories, SIP protected paths, and active app containers are strictly blocked from removal.

### 🔍 2. Uninstalled App Leftover Shredder
- **Orphan Detection:** Discovers forgotten remnants left behind when apps were moved to Trash (Application Support, Preferences, Caches, Saved Application State, WebKit data, LaunchAgents).
- **Positive Absence Verification:** Verifies app bundles are genuinely uninstalled across `/Applications`, `~/Applications`, and Spotlight before marking traces.
- **Interactive Review:** Inspect paths, sizes, and file types before reclaiming disk space.

### 📊 3. Live Menu Bar & Status Monitor
- **Real-Time Metrics:** Live CPU utilization, active process counters, Memory breakdown (App, Wired, Compressed), SSD storage capacity, Network throughput, and hardware fan/thermal status.
- **Integrated Menu Bar Extra:** Quick status glance with smooth segmented views, live animated Worm mascot, and contextual options.

### 🛡️ 4. macOS Privacy & Transparency
- Built-in **Gatekeeper & Privacy Guide** assisting with macOS 14/15 Full Disk Access (FDA) and quarantine resolution.
- Permanent **Activity Audit Log** recording all operations locally at `~/Library/Logs/Worm/deletions.tsv`.

---

## 🚀 Quick Install

### Option 1: Pre-built Binary
1. Download `Worm-1.0.1.dmg` or `Worm.app.zip` from [**Releases**](https://github.com/namdevnaman/worm/releases).
2. Drag `Worm.app` to your `/Applications` folder.
3. Open `Worm.app`. If macOS displays an unidentified developer prompt:
   - Go to **System Settings → Privacy & Security → Click "Open Anyway"**, or
   - Right-click `Worm.app` and choose **Open**.
4. Grant **Full Disk Access** in **System Settings → Privacy & Security → Full Disk Access** to enable thorough system container scans.

### Option 2: Build from Source
```bash
# Clone the repository
git clone https://github.com/namdevnaman/worm.git
cd worm

# Build and package Worm.app
./scripts/build-app.sh

# Install to /Applications
./scripts/install.sh
```

See [**SETUP.md**](SETUP.md) for full step-by-step instructions.

---

## 🛠️ Tech Stack & Architecture

- **Language:** Swift 6.0
- **UI Framework:** SwiftUI (macOS 14.0+)
- **Build System:** Swift Package Manager (`swift build`)
- **Modules:**
  - `MoleCore`: Low-level system introspection engine, Mach kernel sampling, safety policies, orphan detection, and reclamation logic.
  - `Worm`: Native SwiftUI frontend, MenuBarExtra status component, dynamic theme styling, and interactive workflow sheets.

---

## 🤝 Contributing

We welcome contributions from the community! Worm is completely open source and free to collaborate.

Whether you want to:
- Add scan definitions for popular developer tools or apps.
- Improve performance or UI design.
- Report bugs or suggest new features.
- Help localize the app into different languages.

### How to Get Started:
1. Fork the repo (`https://github.com/namdevnaman/worm/fork`).
2. Create your feature branch (`git checkout -b feature/cool-feature`).
3. Commit your changes (`git commit -m 'Add cool feature'`).
4. Push to the branch (`git push origin feature/cool-feature`).
5. Open a **Pull Request**.

Check out our issue tracker to find tasks or join ongoing discussions!

---

## 📄 License

Distributed under the **MIT License**. See [LICENSE](LICENSE) for more information.

---

<div align="center">

Crafted with care by [Naman Namdev](https://github.com/namdevnaman).

If Worm helped free up space on your Mac, please consider giving us a ⭐ on GitHub!

</div>
