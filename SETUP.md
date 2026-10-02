# Setup & Installation Guide for Worm 🪱

This guide provides complete instructions on how to install, build, and configure **Worm** on macOS (Sonoma 14.0, Sequoia 15.0, and newer).

---

## 📋 System Requirements
- **Operating System:** macOS 14.0 (Sonoma) or newer
- **Architecture:** Apple Silicon (M1/M2/M3/M4) or Intel (x86_64)
- **Tools (for building from source):** Xcode Command Line Tools or Xcode 15+ (`xcode-select --install`)

---

## 📦 Method 1: Installing the Pre-built App

1. Download the latest release from the [GitHub Releases](https://github.com/namdevnaman/worm/releases/latest) page.
2. Drag `Worm.app` into `/Applications`.
3. Launch Worm from Spotlight or `/Applications/Worm.app`.

### Resolving macOS Gatekeeper Warnings
Because Worm is built independently without an Apple Developer ID notarization certificate, macOS Gatekeeper may show a warning on first launch:
> *"Worm cannot be opened because Apple cannot check it for malicious software"*

**Fix in 5 seconds:**
- Open **System Settings → Privacy & Security**.
- Scroll down to the **Security** section.
- You will see *"Worm was blocked from use because it is not from an identified developer"*.
- Click **"Open Anyway"** and enter your password/Touch ID.

**Or via Terminal (Quarantine Removal):**
```bash
xattr -cr /Applications/Worm.app
```

---

## 🔒 Granting Full Disk Access (FDA)

Worm needs Full Disk Access to scan app containers and system caches (such as Mail containers, Messages caches, or sandboxed developer tools) that macOS TCC shields.

1. Open **System Settings → Privacy & Security → Full Disk Access**.
2. Toggle the switch next to **Worm** to **ON**.
3. If Worm is not listed:
   - Click the **`+`** icon at the bottom of the list.
   - Select `/Applications/Worm.app` and click **Open**.
4. Restart Worm. The Full Disk Access banner in the app will automatically disappear.

---

## 🛠️ Method 2: Building from Source

### Prerequisites
Make sure you have Swift 6.0+ installed (included with Xcode 15 or 16):
```bash
swift --version
```

### Build Steps
```bash
# 1. Clone the repository
git clone https://github.com/namdevnaman/worm.git
cd worm/MoleMac

# 2. Build the optimized release bundle
./scripts/build-app.sh

# 3. Install directly into /Applications
./scripts/install.sh
```

### Packaging a Disk Image (.dmg)
If you wish to create a distributable `.dmg` file:
```bash
cd MoleMac
./scripts/create-dmg.sh
```
The output disk image will be placed in `MoleMac/dist/Worm-1.0.1.dmg`.

---

## ⚙️ Configuration & Customization

- **Protect List:** Worm includes a user-controlled protect list. You can add paths that should *never* be touched (e.g., specific cache dirs) directly in the in-app **Settings** tab or in `~/.config/worm/protect.txt`.
- **Activity Logs:** All cleaning and skipped operations are transparently logged to:
  ```
  ~/Library/Logs/Worm/deletions.tsv
  ```

---

## ❓ Troubleshooting & Support

- If the Menu Bar icon is not showing, ensure Worm is actively running and you haven't hidden it via menu bar management tools (e.g., Bartender, Ice, Hidden Bar).
- Need help or encountered a bug? [Submit an Issue](https://github.com/namdevnaman/worm/issues) on GitHub!
