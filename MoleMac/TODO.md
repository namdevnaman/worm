# MoleMac — remaining work

Reconstructed 2026-10-01. The original list existed only in chat and was never
written to disk or committed; this file is the audit trail from now on.

Status legend: **[x]** verified working · **[~]** built, not verified ·
**[ ]** not done · **[!]** blocked on user action

## Verified working

- [x] Window layout: explicit `VStack` in `RootView`; no more shrink-to-fit
- [x] Full Disk Access deep link → Privacy & Security, plus "Show App in Finder"
- [x] Stable designated requirement `identifier "dev.local.molemac"`, so the FDA
      grant survives rebuilds (was `cdhash`, silently voided on every build)
- [x] Orphan false positives: 61 groups → 11, all confirmed uninstalled via
      Spotlight. No live-app data is offered for deletion.
- [x] `Application Scripts` removed from scan (AppleScript definitions + unreadable
      without FDA, so everything measured 0 bytes)
- [x] Exclusions: Apple `group.is.*`, `io.sentry`/SDKs, Microsoft suite/updater
      IDs, generic filenames (`default.store`), team-ID container prefixes
- [x] Running-app caches are warnings, not refusals; Edge's 1.73 GB now included
- [x] 53 tests in 7 suites passing
- [x] Clean and Leftovers tabs visually verified; deletion audit steady at 201 lines

## Not done

- [ ] **Grant Full Disk Access.** Blocked on user. macOS keeps the toggle ON for a
      grant that no longer matches, so: select MoleMac → **−** → **+** → choose
      `/Applications/MoleMac.app` → quit and reopen. Until then container-based
      leftovers cannot be verified and the notice stays up.
- [ ] **Exercise the uninstall flow end-to-end.** `performRemoval(plan:traces:)`
      is implemented (`AppStore.swift:562`) but has never been run. Needs a
      throwaway test app in a scratch dir — *not* a live click. Last time a
      destructive control was clicked during UI testing it moved 7.64 GB to the
      Trash and uninstalled CapCut.
- [ ] **Verify `CleanConfirmSheet` through the UI.** Gate is source-verified
      (`requestClean` → `confirmClean` → private `cleanSelected`) but never clicked.
- [ ] **Verify "Delete permanently" toggle and Empty Trash.** Both destructive.
- [ ] **Visually verify Apps / Disk / Status / Settings tabs.** AppsView, DiskView
      and SettingsView are wired; StatusView is read-only (0 buttons, by design).
- [ ] **App icon.** `Resources/` is empty, so the bundle ships no icon and the
      `CFBundleIconFile` branch in `build-app.sh` never fires.
- [ ] **`.gitignore`.** None exists. `.build/` and `dist/` are untracked noise.
- [ ] **First git commit.** The repo has zero commits; there is no checkpoint to
      roll back to and no history for the audit log to reference.

## Known limitations

- [!] **Not distributable.** `spctl` rejects the bundle. Ad-hoc signing means
      Gatekeeper will block it on any other Mac. Shipping requires a Developer ID
      certificate and notarisation.
- `swift run MoleDiag` cannot get FDA, so the CLI harness cannot reproduce
  post-permission behaviour. Post-FDA verification has to happen in the app.
- `Box<Value>` + `@StateObject` substitutes for SwiftUI `@State` because the
  SwiftUIMacros plugin is absent under Command Line Tools only. Works, but not
  idiomatic.
- Orphan scanning takes ~20 s; the app parallelises it, but the CLI does not.