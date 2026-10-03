# Security Policy

Worm Cleaner deletes files on your machine, so this document is the short
version of how it is built to be safe, and how to report a problem.

## Supported versions

| Version | Supported |
| --- | --- |
| 1.0.4 (current) | Yes |
| 1.0.3 and earlier | Security fixes only |

## Reporting a vulnerability

**Please use a private [security advisory](https://github.com/namdevnaman/worm/security/advisories/new)
rather than a public issue.** A public issue tells everyone about the flaw
before a fix exists, and a flaw in a file-deleting tool is worth a few days of
silence.

Include, if you can:

- what you did, step by step
- what you expected and what happened instead
- your OS and version (`sw_vers` on macOS, or Settings → About on Windows)
- the app version (shown in the app, or `defaults read /Applications/Worm.app/Contents/Info.plist CFBundleShortVersionString` on macOS)
- any crash log — on macOS, `~/Library/Logs/DiagnosticReports/Worm*`; on Windows, `%LOCALAPPDATA%\Worm\Logs\`

You can expect an acknowledgement within a few days. Reports are read and
answered by a human.

## Verifying a download

Every release publishes `SHA256SUMS.txt` next to the binaries. Compare:

```sh
# macOS
shasum -a 256 ~/Downloads/Worm-Installer.dmg

# Windows PowerShell
Get-FileHash -Algorithm SHA256 Worm-Windows-x64.zip
```

The current digests are also served from
<https://worm.clepsydratechnologies.com/SHA256SUMS.txt>.

The Windows ZIP also contains its own `SHA256SUMS.txt` covering `Worm.exe`.

Prefer building from source if you want to audit rather than trust:

```sh
git clone https://github.com/namdevnaman/worm.git
cd worm
swift build -c release
```

## Why macOS shows a Gatekeeper warning

Worm is **not notarised**. It is an independent project without a paid Apple
Developer account, so the build carries no notarisation ticket and Gatekeeper
blocks it on first launch.

This is a packaging gap, not a security finding. To open the app: **System
Settings → Privacy & Security → Security → Open Anyway**, or clear the
quarantine flag:

```sh
xattr -cr /Applications/Worm.app
```

Notarising the build is tracked as an open goal. Until it happens, treat the
checksum and the source as the trust anchor rather than a signature.

## What the app does and does not do

**Does not:**

- make network requests during a scan or clean
- contain an analytics or telemetry SDK
- self-replicate, attach to other files, or modify executables
- modify the Windows registry (it *reads* the uninstall keys to enumerate apps)
- run with administrator rights or elevation prompts mid-scan
- touch source repositories, git history, project files or `node_modules`

**Does:**

- delete only what the user has explicitly ticked
- send deletions to the macOS Trash / Windows Recycle Bin by default
- append every destructive operation to a local plain-text log
  (`~/Library/Logs/Worm/deletions.tsv`, `%LOCALAPPDATA%\Worm\Logs\deletions.tsv`)
- ship an optional update check on macOS, off until requested

## How deletion is constrained

These are the mechanisms, and all of them are in the source under
`Sources/WormCore/`.

1. **Per-item opt-in.** Cleaning touches only ticked targets. Regenerable caches
   are selected by default; content classified `Keep` is not, and requires an
   explicit per-item action.
2. **Risk tiers.** Every target is `Safe` (regenerable), `Re-download`,
   `Keep` (user content) or `Blocked`. `Blocked` targets are never offered.
3. **Protected paths.** Personal folders are resolved through the macOS
   known-folder APIs and the Windows known-folder registry keys, so a relocated
   or redirected `Documents` is still protected. Matching is prefix-aware and
   case-insensitive.
4. **Blast-radius allowlist.** Every path a scan rule produces is checked
   against a cleanable-root set derived from the rules themselves. A wrong rule
   therefore cannot delete outside a folder the catalog declares cleanable.
5. **Absence verification.** An app's leftovers are only flagged as orphans
   after the app's absence is confirmed — on macOS via system locations and
   Spotlight, on Windows via token matching against every registered app plus a
   check against each install location. Not substring matching.
6. **Recoverable disposal.** Trash on macOS, Recycle Bin on Windows.
7. **Liveness checks.** A running application's cache is flagged rather than
   deleted, and an open file handle is never removed.
8. **User protect list.** Paths in `~/.config/worm/protect.txt` are never
   touched.

## Deliberately excluded paths

Not cleanable, by design:

- `~/Library/Developer/Xcode/Archives`
- `~/Library/Developer/Xcode/iOS DeviceSupport`
- `~/Library/Developer/CoreSimulator/Profiles/Runtimes`
- `C:\Windows\SoftwareDistribution` (Windows Update download tree)
- Visual Studio, .NET runtimes and SDKs, and other Microsoft components

None of these can be rebuilt from the machine. See
`Sources/WormCore/SafetyPolicy.swift` for the full list and the reasoning.