<#
.SYNOPSIS
    Installs Worm for Windows from an extracted release folder.
.DESCRIPTION
    Worm is open source and shipped WITHOUT a code-signing certificate, so files
    downloaded from GitHub arrive with a Mark-of-the-Web (Zone.Identifier). Windows
    SmartScreen and Defender then refuse to launch the binary, whether it is
    double-clicked or started from cmd/PowerShell.

    This script:
      1. Removes the Mark-of-the-Web from the Worm folder.
      2. Verifies SHA256 against SHA256SUMS.txt when present.
      3. Installs per-user into %LOCALAPPDATA%\Programs\Worm - NO admin needed.
         (An MSI is deliberately not used: unsigned MSIs trip MsiExecTrust and a
          UAC "unknown publisher" prompt, which is a worse first-run experience.)
      4. Creates Desktop, Start-menu and Start-up shortcuts.
      5. Registers an Apps & features entry so Settings -> Apps can uninstall it.
      6. Launches Worm.

    Normally invoked by double-clicking Install-Worm.cmd, which calls this script.

.PARAMETER InstallDir
    Target directory. Defaults to %LOCALAPPDATA%\Programs\Worm.

.PARAMETER NoShortcuts
    Skip Desktop and Start-menu shortcut creation.

.PARAMETER NoLaunch
    Install but do not start Worm.

.PARAMETER Purge
    Also delete logs and the protected-path configuration.

.PARAMETER Elevate
    Re-launch this script elevated. Not normally needed - Worm installs per-user.
#>
[CmdletBinding()]
param(
    [string]$InstallDir = (Join-Path $env:LOCALAPPDATA 'Programs\Worm'),
    [switch]$NoShortcuts,
    [switch]$NoLaunch,
    [switch]$Purge,
    [switch]$Elevate
)

$ErrorActionPreference = 'Stop'

$script:ProductName  = 'Worm'
$script:Publisher    = 'Naman Namdev'
$script:UninstallKey = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\Worm'

function Write-Step($m) { Write-Host "==> $m" -ForegroundColor Cyan }
function Write-Ok($m)   { Write-Host "    OK   $m" -ForegroundColor Green }
function Write-Info($m) { Write-Host "    --   $m" -ForegroundColor Gray }
function Write-Warn2($m){ Write-Host "    !!   $m" -ForegroundColor Yellow }

$source = Split-Path -Parent $MyInvocation.MyCommand.Definition
$exe = Join-Path $source 'Worm.exe'

# ------------------------------------------------------------------ guards
if ($Elevate) {
    $id = [Security.Principal.WindowsIdentity]::GetCurrent()
    $pr = New-Object Security.Principal.WindowsPrincipal($id)
    if (-not $pr.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        Write-Info 'Requesting administrator rights...'
        $argList = @(
            '-NoProfile', '-ExecutionPolicy', 'Bypass',
            '-File', ('"{0}"' -f $MyInvocation.MyCommand.Path),
            '-InstallDir', ('"{0}"' -f $InstallDir), '-Elevate', '-Wait'
        )
        if ($NoShortcuts) { $argList += '-NoShortcuts' }
        if ($NoLaunch)     { $argList += '-NoLaunch' }
        if ($Purge)        { $argList += '-Purge' }
        Start-Process powershell -Verb RunAs -ArgumentList $argList
        exit $LASTEXITCODE
    }
    Write-Ok 'running elevated'
}

if (-not (Test-Path $exe)) {
    throw "Worm.exe not found next to this script (looked in: $source)."
}

Write-Host ''
Write-Host "  Installing $script:ProductName for Windows" -ForegroundColor White
Write-Host "  ---------------------------------------------" -ForegroundColor DarkGray
Write-Host ''

# ------------------------------------------------------- 1. unblock (MOTW)
Write-Step 'Clearing the Windows download mark'
# Unblock-File has no -Recurse parameter in either Windows PowerShell 5.1 or
# PowerShell 7, and it is a no-op on files that were never marked, so piping a
# recursive file listing into it is both correct and cheap.
# Wrapped in try/catch: on volumes without alternate data streams (FAT32 USB
# drives, some network shares) the underlying call can fail outright.
$cleared = $false
try {
    Get-ChildItem -Path $source -Recurse -File -Force -ErrorAction SilentlyContinue |
        Unblock-File -ErrorAction SilentlyContinue
    $cleared = $true
} catch {
    Write-Warn2 "could not clear the download mark automatically: $($_.Exception.Message)"
    Write-Info 'right-click the ZIP -> Properties -> tick Unblock -> Apply, then retry'
}
if ($cleared) { Write-Ok 'files cleared for execution' }

# ------------------------------------------------------------ 2. checksum
Write-Step 'Verifying the download'
$sumFile = Join-Path $source 'SHA256SUMS.txt'
$verified = $false
if (Test-Path $sumFile) {
    foreach ($line in Get-Content $sumFile) {
        if ($line -match '^\s*([0-9a-fA-F]{64})\s+\*?(\S.*)$') {
            $expected = $Matches[1].ToLowerInvariant()
            $name     = $Matches[2].Trim()
            if ($name -eq 'Worm.exe') {
                $actual = (Get-FileHash -Path $exe -Algorithm SHA256).Hash.ToLowerInvariant()
                if ($actual -eq $expected) {
                    Write-Ok 'Worm.exe checksum matches'
                } else {
                    throw "Checksum mismatch for Worm.exe.`n  expected $expected`n  actual   $actual`nThe download appears to be corrupt. Delete it and download again."
                }
                $verified = $true
            }
        }
    }
}
if (-not $verified) { Write-Warn2 'SHA256SUMS.txt missing - integrity not verified' }

# -------------------------------------------------------------- 3. install
Write-Step "Installing to $InstallDir"
if (Test-Path (Join-Path $InstallDir 'Worm.exe')) {
    Get-Process -Name 'Worm' -ErrorAction SilentlyContinue | Stop-Process -Force
    Start-Sleep -Milliseconds 600
}

New-Item -ItemType Directory -Force -Path $InstallDir | Out-Null
Copy-Item -Path (Join-Path $source '*') -Destination $InstallDir -Recurse -Force

# Never carry the zone mark into the installed copy.
try {
    Get-ChildItem -Path $InstallDir -Recurse -File -Force -ErrorAction SilentlyContinue |
        Unblock-File -ErrorAction SilentlyContinue
} catch {
    Write-Warn2 'installed files may still carry a download mark; run Install-Worm.ps1 again from the installed folder to clear it'
}
Write-Ok 'application files copied'

$installedExe = Join-Path $InstallDir 'Worm.exe'

# ------------------------------------------------------------- 4. shortcuts
# Known folders can come back empty (folder redirection to an offline network
# path, hardened/kiosk profiles), so each shortcut is attempted independently
# and a failure never aborts the installation.
function Get-KnownFolder([string]$name) {
    try {
        $p = [Environment]::GetFolderPath($name)
        if ([string]::IsNullOrWhiteSpace($p)) { return $null }
        return $p
    } catch { return $null }
}

if (-not $NoShortcuts) {
    Write-Step 'Creating shortcuts'
    $ws = $null
    try { $ws = New-Object -ComObject WScript.Shell } catch { }

    if (-not $ws) {
        Write-Warn2 'could not create shortcuts (Shell.Application unavailable)'
        Write-Info "you can launch Worm directly from: $InstallDir\Worm.exe"
    } else {
        function New-Shortcut([string]$folder, [string]$file, [string]$desc) {
            if (-not $folder) { return }
            $path = Join-Path $folder $file
            try {
                New-Item -ItemType Directory -Force -Path $folder -ErrorAction SilentlyContinue | Out-Null
                $s = $ws.CreateShortcut($path)
                $s.TargetPath       = $installedExe
                $s.WorkingDirectory = $InstallDir
                $s.IconLocation     = "$installedExe,0"
                $s.Description      = $desc
                $s.Save()
                Write-Ok $path
            } catch {
                Write-Warn2 "skipped shortcut $path - $($_.Exception.Message)"
            }
        }

        $programs = Get-KnownFolder 'Programs'
        $desktop  = Get-KnownFolder 'Desktop'
        $startup  = Get-KnownFolder 'Startup'

        $desc = 'Worm - system cleaner and monitor'
        New-Shortcut $programs 'Worm.lnk'       $desc
        New-Shortcut $programs 'Worm\Worm.lnk'  $desc
        New-Shortcut $desktop  'Worm.lnk'       $desc
        New-Shortcut $startup  'Worm.lnk'       $desc
    }
}

# -------------------------------------- 5. register in Apps & features
Write-Step 'Registering in Windows (Apps & features)'
# Read the version from the built assembly so it can never drift from the csproj.
$ver = '1.0.3'
try {
    $vi = (Get-Item $installedExe).VersionInfo.ProductVersion
    if ($vi) { $ver = $vi.Trim() }
} catch { }
try {
    New-Item -Path $script:UninstallKey -Force | Out-Null
    Set-ItemProperty -Path $script:UninstallKey -Name 'DisplayName'     -Value $script:ProductName
    Set-ItemProperty -Path $script:UninstallKey -Name 'DisplayVersion'  -Value $ver
    Set-ItemProperty -Path $script:UninstallKey -Name 'Publisher'       -Value $script:Publisher
    Set-ItemProperty -Path $script:UninstallKey -Name 'InstallLocation' -Value $InstallDir
    Set-ItemProperty -Path $script:UninstallKey -Name 'DisplayIcon'     -Value "$installedExe,0"
    Set-ItemProperty -Path $script:UninstallKey -Name 'NoModify'        -Value 1 -Type DWord
    Set-ItemProperty -Path $script:UninstallKey -Name 'NoRepair'        -Value 1 -Type DWord
    Set-ItemProperty -Path $script:UninstallKey -Name 'UninstallString' -Value ('"{0}\Uninstall.cmd"' -f $InstallDir)
    Set-ItemProperty -Path $script:UninstallKey -Name 'QuietUninstallString' -Value ('powershell -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File "{0}\Uninstall-Worm.ps1" -Quiet' -f $InstallDir)
    Set-ItemProperty -Path $script:UninstallKey -Name 'URLInfoAbout'    -Value 'https://github.com/namdevnaman/worm'
    Write-Ok 'Settings -> Apps -> Installed apps'
} catch {
    Write-Warn2 "could not register the uninstall entry: $($_.Exception.Message)"
}

# --------------------------------------------------------------- 6. launch
if (-not $NoLaunch) {
    Write-Step 'Starting Worm'
    Start-Process -FilePath $installedExe
    Write-Ok 'running'
}

Write-Host ''
Write-Host "  $script:ProductName is installed." -ForegroundColor Green
Write-Host "  Installed : $InstallDir" -ForegroundColor DarkGray
$logDir = if ($env:LOCALAPPDATA) { Join-Path $env:LOCALAPPDATA 'Worm\Logs' } else { 'not available' }
Write-Host "  Logs      : $logDir" -ForegroundColor DarkGray
Write-Host '  Uninstall : Settings -> Apps -> Installed apps -> Worm' -ForegroundColor DarkGray
Write-Host '            or run Uninstall-Worm.cmd' -ForegroundColor DarkGray
Write-Host ''
