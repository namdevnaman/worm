<#
.SYNOPSIS
    Removes Worm for Windows.
.DESCRIPTION
    Stops the app, removes the install folder, all shortcuts, and the
    Apps & features registration. Logs and protected-path settings are kept
    unless -Purge is supplied.

    Normally invoked by double-clicking Uninstall-Worm.cmd.

.PARAMETER InstallDir
    Install location. Defaults to %LOCALAPPDATA%\Programs\Worm.

.PARAMETER Purge
    Also delete %LOCALAPPDATA%\Worm (logs) and %USERPROFILE%\.config\worm.

.PARAMETER Quiet
    Suppress output. Used by the Apps & features "quiet uninstall" string.
#>
[CmdletBinding()]
param(
    [string]$InstallDir = (Join-Path $env:LOCALAPPDATA 'Programs\Worm'),
    [switch]$Purge,
    [switch]$Quiet
)

$ErrorActionPreference = 'Continue'

$ProductName  = 'Worm'
$UninstallKey = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\Worm'

function Say($m) { if (-not $Quiet) { Write-Host $m } }

Say ''
Say "  Uninstalling $ProductName" -ForegroundColor White
Say ''

# ------------------------------------------------------------------- stop
Get-Process -Name 'Worm' -ErrorAction SilentlyContinue | Stop-Process -Force
Start-Sleep -Milliseconds 600
Say '    OK   Worm stopped'

# -------------------------------------------------------------- shortcuts
# Known folders can resolve to empty (folder redirection, hardened profiles),
# so nulls are filtered rather than passed to Join-Path.
function Get-KnownFolder([string]$name) {
    try {
        $p = [Environment]::GetFolderPath($name)
        if ([string]::IsNullOrWhiteSpace($p)) { return $null }
        return $p
    } catch { return $null }
}

$programs = Get-KnownFolder 'Programs'
$desktop  = Get-KnownFolder 'Desktop'
$startup  = Get-KnownFolder 'Startup'

$paths = @()
foreach ($base in @($programs, $desktop, $startup)) {
    if ($base) { $paths += (Join-Path $base 'Worm.lnk') }
}
if ($programs) { $paths += (Join-Path $programs 'Worm\Worm.lnk') }

foreach ($lnk in $paths) {
    try {
        if (Test-Path -LiteralPath $lnk) {
            Remove-Item -LiteralPath $lnk -Force -ErrorAction SilentlyContinue
            Say "    OK   removed $lnk"
        }
    } catch {
        Say "    !!   could not remove $lnk" -ForegroundColor Yellow
    }
}

if ($programs) {
    $startMenuDir = Join-Path $programs 'Worm'
    if (Test-Path -LiteralPath $startMenuDir) {
        Remove-Item -LiteralPath $startMenuDir -Recurse -Force -ErrorAction SilentlyContinue
        Say "    OK   removed $startMenuDir"
    }
}

# ----------------------------------------------------------- uninstall key
if (Test-Path $UninstallKey) {
    Remove-Item $UninstallKey -Recurse -Force -ErrorAction SilentlyContinue
    Say '    OK   removed the Apps & features entry'
}

# ------------------------------------------------------------- app folder
if (Test-Path $InstallDir) {
    Remove-Item $InstallDir -Recurse -Force -ErrorAction SilentlyContinue
}
if (Test-Path $InstallDir) {
    Say "    !!   could not fully remove $InstallDir - close Worm and retry" -ForegroundColor Yellow
} else {
    Say "    OK   removed $InstallDir"
}

# ----------------------------------------------------------------- purge
if ($Purge) {
    $data = Join-Path $env:LOCALAPPDATA 'Worm'
    if (Test-Path $data) {
        Remove-Item $data -Recurse -Force -ErrorAction SilentlyContinue
        Say "    OK   purged $data"
    }
    $cfg = Join-Path $env:USERPROFILE '.config\worm'
    if (Test-Path $cfg) {
        Remove-Item $cfg -Recurse -Force -ErrorAction SilentlyContinue
        Say "    OK   purged $cfg"
    }
}

Say ''
Say "  $ProductName uninstalled." -ForegroundColor Green
Say ''
