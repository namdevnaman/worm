# Worm for Windows 🪱

Native, ultra-fast, and transparent system cleaner, uninstalled app leftover shredder, and hardware monitor built with **C# / .NET 9**, **WPF**, and **ModernWpfUI** (Windows 11 Mica/Dark aesthetic).

---

## ⚡ Architecture & Design

Worm for Windows mirrors the core design and safety guarantees of the macOS version:
- **WormCore (`src/WormCore`)**:
  - `WindowsPaths.cs`: Dynamic resolution of standard Windows folders, Temp, and `%LOCALAPPDATA%`.
  - `WindowsSafetyPolicy.cs`: Enforcement-grade protection of `C:\Windows`, `C:\Program Files`, `%USERPROFILE%\Documents`, and active system partitions.
  - `WindowsScanCatalog.cs`: Targeted cleaning rules for Windows system caches, crash dumps, Visual Studio, VS Code, NuGet, npm, pnpm, cargo, pip, and browsers.
  - `WindowsHardwareSampler.cs`: High-speed Win32 kernel32/GetSystemTimes hardware metric sampler with <0.2% CPU usage.
  - `WindowsReclaimer.cs`: Moves files safely to the native **Windows Recycle Bin** via `SHFileOperation` (FO_DELETE | FOF_ALLOWUNDO) with permanent deletion option.
  - `WindowsOrphanDetector.cs`: Discovers orphaned folders left in AppData/LocalAppData by uninstalled software via Windows Registry inspection.
  - `WindowsCrashLog.cs`: Appends every unhandled UI-thread, app-domain and task-scheduler exception to `%LOCALAPPDATA%\Worm\Logs\crash.log`, so a startup failure is never silent.
- **WormUI (`src/WormUI`)**:
  - Windows 11 dark mode aesthetic using ModernWpfUI with Worm's signature **Loam Soil (`#151311`)** and **Terracotta (`#C26B47`)** theme.
  - System Tray integration (`NotifyIcon`) with background monitoring and quick clean actions.
  - Interactive Clean, Leftovers, Hardware Status, and Settings views.

---

## 📦 Packaging

Worm ships as a **self-contained folder, delivered as a ZIP**. It is deliberately
**not** published as a single-file executable.

| Option | Result | Verdict |
| --- | --- | --- |
| `PublishSingleFile` + `EnableCompressionInSingleFile` + `PublishReadyToRun` | 68 MB single `Worm.exe` | **Removed.** This is what shipped as v1.0.2 and it did not start reliably. WPF reads BAML and `.g.resources` through the resource manager; bundling those into a *compressed* single-file bundle is a startup-crash vector. |
| `PublishSingleFile` without compression | 130 MB single `Worm.exe` | Strictly worse, same class of risk. |
| Self-contained folder + ZIP (current) | ~57 MB ZIP, 241 files | **Shipped.** A plain folder extracts and runs on any Windows 10/11 x64 machine. |

`SatelliteResourceLanguages` is pinned to `en`, which drops ~200 unused locale
assemblies from the bundle.

---

## 🚀 Building & Running

### Requirements
- Windows 10 (version 1809+) or Windows 11
- [.NET 9.0 SDK](https://dotnet.microsoft.com/download/dotnet/9.0)

The `net9.0-windows` target sets `EnableWindowsTargeting`, so the Windows build can
also be produced from macOS or Linux:

```bash
dotnet publish src/WormUI/WormUI.csproj -c Release -r win-x64 --self-contained true -o dist/win-x64
```

### Quick Build (Windows)
```cmd
scripts\build.bat
```
This restores, publishes to `dist\win-x64`, then runs `scripts\package.ps1` to
produce `dist\Worm-Windows-x64.zip` and `dist\SHA256SUMS.txt`.

---

## 🛡️ Installing (unsigned builds)

Worm is open source and **not code-signed**. A binary downloaded from GitHub carries
a Mark-of-the-Web, which makes Windows SmartScreen refuse to launch it. `cmd`,
PowerShell and double-click are all affected — it is the download, not the launcher.

**Easiest:** extract the ZIP and double-click **`Install-Worm.cmd`**.

It performs, in order:

| Step | What it does |
| --- | --- |
| 1 | Clears the Mark-of-the-Web (`Unblock-File`) |
| 2 | Verifies `Worm.exe` against the in-ZIP `SHA256SUMS.txt`; aborts on mismatch |
| 3 | Installs **per-user** to `%LOCALAPPDATA%\Programs\Worm` — no admin needed |
| 4 | Start-menu, Desktop and start-up shortcuts |
| 5 | Registers an Apps & features entry (`HKCU\...\Uninstall\Worm`) so **Settings → Apps** can uninstall it |
| 6 | Launches Worm |

Why not an MSI? Because Worm is unsigned, an MSI trips `MsiExecTrust` and a UAC
"unknown publisher" prompt — a *worse* first-run experience than a portable ZIP.
A per-user install sidesteps both.

Manual equivalents:

```powershell
# clear the download mark yourself
Get-ChildItem -Recurse -File | Unblock-File
# or: right-click the ZIP -> Properties -> tick Unblock -> Apply
```

Uninstall with `Uninstall-Worm.cmd` (keeps logs/settings) or add `-Purge`.
If SmartScreen still prompts, choose **More info → Run anyway**.

---

## 📦 Package managers

A Scoop manifest is included at `packaging/scoop/worm.json`, so install is one command
and needs no administrator rights:

```powershell
scoop bucket add worm https://raw.githubusercontent.com/namdevnaman/worm/main/worm-windows/packaging/scoop/worm.json
scoop install worm
```

---

## 🧪 Testing

`scripts\build.bat` publishes, then runs `scripts\package.ps1`. CI additionally:

- asserts the ZIP contains `Worm.exe`, `Worm.dll`, `WormCore.dll`, `ModernWpf.dll`,
  both `*.cmd` wrappers and a valid in-ZIP `SHA256SUMS.txt`;
- parses every `*.ps1` with the PowerShell AST parser;
- validates the Scoop manifest.

---

## 📄 License
Licensed under the [MIT License](../../LICENSE).
