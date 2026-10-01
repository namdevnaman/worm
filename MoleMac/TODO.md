# MoleMac — remaining work

Reconstructed 2026-10-01. The original list existed only in chat and was never
written to disk or committed; this file is the audit trail from now on.

Status legend: **[x]** verified working · **[~]** built, not verified ·
**[ ]** not done · **[!]** blocked on user action

## Verified working

- [x] **Fix stuck notification banner (auto-dismiss)** — `AppStore.notify` +
      auto-dismiss task, plus a manual close in the tab bar
- [x] **Rewrite LeftoverDetector: locations, bundle-ID matching, positive absence
      proof** — 11 locations (Application Scripts deliberately excluded), trace
      suffixes, team-ID prefixes, `presenceProves` absence proof
- [x] **Leftovers nav tab with auto-detect + detail view** — `LeftoversView.swift`
- [x] **Per-item leftover popup on uninstall** — `UninstallLeftoverSheet.swift`,
      rebuildable traces preselected, settings/data left for review
- [x] Window layout: explicit `VStack` in `RootView`; no more shrink-to-fit
- [x] Full Disk Access deep link → Privacy & Security, plus "Show App in Finder"
- [x] Stable designated requirement `identifier "dev.local.molemac"`, so the FDA
      grant survives rebuilds (was `cdhash`, silently voided on every build)
- [x] Orphan false positives: 61 groups → 11, all confirmed uninstalled via
      Spotlight. No live-app data is offered for deletion.
- [x] Exclusions: Apple `group.is.*`, `io.sentry`/SDKs, Microsoft suite/updater
      IDs, generic filenames (`default.store`), team-ID container prefixes
- [x] Running-app caches are warnings, not refusals; Edge's 1.73 GB now included
- [x] 53 tests in 7 suites passing

## In progress

- [ ] **Menu bar panel — needs a human click to confirm.** The `MenuBarExtra`
      registers and its label is live (AX reads `AXMenuBarItem "1.28 GB"` with a
      tooltip), and `MenuBarPanel` is wired to the same `AppStore` as the window.
      But automation could not open it: pixel clicks on a status item did not land,
      and the AX press path needs a `snapshot_id` this session never exposed. The
      panel's appearance is therefore **unverified**. Click the sparkle in the menu
      bar and tell me if it renders wrong.
- [ ] **Uninstall flow end-to-end.** `performRemoval(plan:traces:)`
      (`AppStore.swift:562`) is implemented but has never been run. Needs a
      throwaway test app in a scratch dir — *not* a live click. Last time a
      destructive control was clicked during UI testing it moved 7.64 GB to the
      Trash and uninstalled CapCut.
- [ ] **`CleanConfirmSheet` through the UI.** Gate is source-verified
      (`requestClean` → `confirmClean` → private `cleanSelected`) but never clicked.
- [ ] **"Delete permanently" toggle and Empty Trash.** Both destructive.
- [ ] **Apps / Settings / Status tabs.** Apps and Settings verified reachable;
      the Settings segmented control was fixed. Apps list still unchecked.

## Fixed this round

- [x] **Disk view fonts/contrast.** `inkTertiary` was 3.2:1 on white — below the
      WCAG AA 4.5:1 floor and the reason the labels read as washed-out grey. Now
      ~5:1. The size column was also being compressed by long paths into
      "5.48 G"; the path column now yields instead.
- [x] **Selective cleaning.** Category rows carry a tri-state checkbox; one click
      selects exactly that category, a second clears it. Right-click offers
      "Clean only this category". Cleaning just App Caches is one click, not 79.
- [x] **Delete-mode control made visible.** It was a 10pt checkbox whose label
      read "Switch to Delete permanently" beside text saying "Move to Trash" — two
      different meanings, and the irreversible option was easy to miss. Now a
      two-segment control.
- [x] **Delete mode had two sources of truth.** `deleteModeIsPermanentBox` and
      `deleteModeBox` both wrote `deleteMode` and neither read it back, so
      changing the mode in Settings left the Clean tab still displaying
      "Move to Trash" — promising a recoverable clean while the run was
      permanent. Reduced to one box; both screens share `DeleteModeSegments`.
- [x] **Settings picker rendered an empty segment.** The native segmented Picker
      drew its selection white-on-white, so "Permanent" looked like a blank box.
- [x] **Menu bar label never updated.** The `App` body does not depend on
      `store`, so `MenuBarExtra`'s label was never invalidated and sat on the
      icon after every scan. The label now observes the store directly.
- [x] **Post-uninstall leftover reporting.** Anything the user chose not to tick
      is now reported by name and size instead of silently reappearing later.

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