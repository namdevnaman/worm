# Contributing to Worm Cleaner

Thanks for considering it. Worm is a small, deliberately boring project: a
scanner with a catalog of paths, and a safety layer that decides which of them
it is willing to delete. Most contributions fall into one of three groups.

## Before you start

Read these two files first. They are short and they explain most of the design:

- **`Sources/WormCore/ScanCatalog.swift`** — every path the app can target, one
  labelled entry each, with its category, age gate and risk tier.
- **`Sources/WormCore/SafetyPolicy.swift`** — every path the app refuses to
  touch, and why.

Adding a cleanup target means adding one entry to `ScanCatalog.swift`. If you
find yourself adding logic elsewhere, that is usually a sign the entry belongs
in the catalog.

## Reporting a bug

Open an issue with:

- what you did, step by step
- what you expected, and what happened instead
- OS and version, app version
- the relevant lines from the deletion audit log
  (`~/Library/Logs/Worm/deletions.tsv` or `%LOCALAPPDATA%\Worm\Logs\deletions.tsv`)

**If a bug caused data loss or would have, use a
[private security advisory](https://github.com/namdevnaman/worm/security/advisories/new)
instead of a public issue.** Please do not report a deletion bug publicly until
a fix is out.

## Adding a cleanup target

1. Add the rule to `ScanCatalog.swift` in the appropriate category.
2. Choose the risk tier honestly:
   - `regenerable` — the app rebuilds it; deleting costs time only.
   - `reDownload` — content is fetched from the network again.
   - `userData` — it is the user's content, not a cache. **Defaults to off and
     must not be selected without an explicit per-item action.**
   - `unsafe` — not a cleanup target. Do not add rules with this tier.
3. Set `minAgeDays` for anything that might still be in active use. Logs and
   temp files use 7; saved state uses 30.
4. Set `mustBeClosed` if the owning app must not be running. A liveness probe
   uses this to flag rather than delete.
5. Confirm the path is not, and does not resolve into, a protected path.
6. Add a test in `Tests/WormCoreTests`.

If a path can only be deleted safely under conditions you cannot verify, do not
add a rule for it. Report it as a feature request explaining what would need to
be true.

## Changing the safety layer

Changes to `SafetyPolicy.swift` and the allowlist logic get extra scrutiny,
because a mistake there is the difference between a cleaner and an incident.
Expect to be asked for the reasoning, not just the diff.

Specifically: do not relax a protected path, widen the cleanable-root set
beyond what the catalog declares, or remove the prefix-aware/case-insensitive
matching on known folders. If you believe one of those is wrong, open an issue
describing the failure mode first.

## Style

Swift and C# follow the surrounding file. The short version:

- Comments explain *why*, not *what*. Most rules already have a comment giving
  the reason they exist; keep that up.
- No new dependencies without discussion. The apps are deliberately
  dependency-light so the audit surface stays small.
- Match the existing naming (`regenerable`, `mustBeClosed`, `minAgeDays`).
- Run the tests before opening a PR: `swift test` for macOS and
  `dotnet test` under `worm-windows/`.

## Commit and PR

- One logical change per PR.
- Describe what you changed and why in the body. If it touches deletion
  behaviour, say explicitly which paths are affected.
- If it adds or changes a cleanup target, say so in the PR title — it needs a
  second pair of eyes.

## Reporting security issues

Not a contribution question, but worth knowing: security reports go through
GitHub's private advisory flow, not the issue tracker. See
[SECURITY.md](SECURITY.md).

## Code of conduct

Be direct, be technically honest, and assume good faith. Disagreeing about
which risk tier a path deserves is normal and welcome — arguing about it in
public is how the tiers end up correct.