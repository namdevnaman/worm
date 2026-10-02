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
- **WormUI (`src/WormUI`)**:
  - Windows 11 dark mode aesthetic using ModernWpfUI with Worm's signature **Loam Soil (`#151311`)** and **Terracotta (`#C26B47`)** theme.
  - System Tray integration (`NotifyIcon`) with background monitoring and quick clean actions.
  - Interactive Clean, Leftovers, Hardware Status, and Settings views.

---

## 🚀 Building & Running

### Requirements
- Windows 10 (version 1809+) or Windows 11
- [.NET 9.0 SDK](https://dotnet.microsoft.com/download/dotnet/9.0)

### Quick Build (Single-File Self-Contained Binary)
Run the included build script:
```cmd
scripts\build.bat
```
Or compile via the .NET CLI:
```bash
dotnet publish src/WormUI/WormUI.csproj -c Release -r win-x64 --self-contained true -p:PublishSingleFile=true -o dist/win-x64
```
The resulting `Worm.exe` is completely self-contained (~15MB compressed), requiring no external .NET runtime installation on the target machine.

---

## 📄 License
Licensed under the [MIT License](../../LICENSE).
