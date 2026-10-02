<#
.SYNOPSIS
    Packages a published Worm folder build into a release ZIP, with checksums.
.DESCRIPTION
    Produces two different checksum files on purpose:

      * SHA256SUMS.txt INSIDE the ZIP - covers Worm's own assemblies. This is what
        Install-Worm.ps1 reads to verify the download before installing.
      * SHA256SUMS.txt OUTSIDE the ZIP - covers the ZIP itself, published next to
        the release asset so a user can check the download they pulled.

    Every helper script is copied into the ZIP so users always have a supported
    path that clears the Mark-of-the-Web (MOTW) which makes Windows SmartScreen
    block an unsigned download.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$PublishDir,
    [Parameter(Mandatory = $true)][string]$OutDir
)

$ErrorActionPreference = 'Stop'

if (-not (Test-Path $PublishDir)) { throw "Publish dir not found: $PublishDir" }
New-Item -ItemType Directory -Force -Path $OutDir | Out-Null

$staging = Join-Path $OutDir 'staging'
if (Test-Path $staging) { Remove-Item $staging -Recurse -Force }
New-Item -ItemType Directory -Force -Path $staging | Out-Null

Write-Host '  staging publish output...'
Copy-Item (Join-Path $PublishDir '*') $staging -Recurse -Force

# Ship every helper script next to the binaries.
# NB: Get-ChildItem -Include only works when -Path contains a wildcard, so filter
# with -like instead. Using -Include here silently matches nothing.
Write-Host '  copying installer scripts...'
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$helpers = Get-ChildItem -Path $scriptDir -File | Where-Object {
    $_.Name -like '*.cmd' -or $_.Name -like '*-Worm.ps1'
}
foreach ($h in $helpers) { Copy-Item $h.FullName (Join-Path $staging $h.Name) -Force }
if ($helpers.Count -eq 0) { throw "no installer scripts found in $scriptDir" }
Write-Host ("    {0} helper script(s): {1}" -f $helpers.Count, (($helpers.Name) -join ', '))

# ---------------------------------------------------------------------------
# In-ZIP manifest: only Worm's own assemblies, so the file stays small and
# every entry is something Install-Worm.ps1 can meaningfully verify.
# ---------------------------------------------------------------------------
Write-Host '  hashing application assemblies...'
$appFiles = @('Worm.exe', 'Worm.dll', 'WormCore.dll')
$inner = foreach ($name in $appFiles) {
    $f = Join-Path $staging $name
    if (Test-Path $f) {
        '{0}  {1}' -f (Get-FileHash $f -Algorithm SHA256).Hash.ToLowerInvariant(), $name
    }
}
if (-not $inner) { throw "none of $($appFiles -join ', ') were found in $PublishDir" }
Set-Content -Path (Join-Path $staging 'SHA256SUMS.txt') -Value $inner -Encoding ascii
Write-Host ("    {0} assemblies hashed" -f $inner.Count)

$zip = Join-Path $OutDir 'Worm-Windows-x64.zip'
if (Test-Path $zip) { Remove-Item $zip -Force }
Write-Host "  zipping -> $zip"
Compress-Archive -Path (Join-Path $staging '*') -DestinationPath $zip -CompressionLevel Optimal

Remove-Item $staging -Recurse -Force

# ---------------------------------------------------------------------------
# Release manifest: the ZIP itself, published alongside the release asset.
# ---------------------------------------------------------------------------
Write-Host '  hashing release archive...'
$releaseAssets = Get-ChildItem -Path $OutDir -File |
    Where-Object { $_.Extension -in '.zip', '.exe' }
$outer = foreach ($f in $releaseAssets) {
    '{0}  {1}' -f (Get-FileHash $f.FullName -Algorithm SHA256).Hash.ToLowerInvariant(), $f.Name
}
Set-Content -Path (Join-Path $OutDir 'SHA256SUMS.txt') -Value $outer -Encoding ascii

$sizeMb = [math]::Round((Get-Item $zip).Length / 1MB, 1)
Write-Host "  done: Worm-Windows-x64.zip ($sizeMb MB)"
