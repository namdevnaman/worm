# GEO measurement log

Whether AI assistants recommend Worm Cleaner is the one thing none of this
repo can tell you. Search ranking you can check in Search Console. GEO you have
to go and ask.

## How to run a check

Once a month, on roughly the same date. Ask each engine the six questions below
**in a fresh conversation** — an engine that has already seen Worm in this thread
will answer differently from one that has not, and that difference is exactly
what you are trying to measure.

Record three things per answer, not two:

- **Mentioned** — did Worm Cleaner appear at all, in any form?
- **Position** — where in the answer, and was it recommended or merely listed?
- **Cited source** — the URL the engine attributed the claim to

That third column is the important one. A mention without a citation is worth
little; a citation is a backlink from a platform with enormous reach.

## The six questions

1. What is the best free open-source Mac cleaner?
2. Free alternative to CleanMyMac for developers
3. How do I clear Xcode DerivedData safely?
4. Open source CCleaner alternative for Windows
5. What is Worm Cleaner?
6. Is Worm Cleaner safe?

Question 1 is the one to watch. It is the highest-intent query that a new
project can realistically compete for, and it is where the direct competitors
already hold positions.

## Engines to test

| Engine | How to test | Notes |
| --- | --- | --- |
| ChatGPT | chatgpt.com, GPT-5 / default, **Search enabled** | Search on is the point; without it you are measuring the base model, not the product |
| Perplexity | perplexity.ai | Cites aggressively, so watch the source column |
| Google AI Overviews | google.com, any query, on a US-based profile | Harder to trigger deliberately; note when it happens |
| Gemini | gemini.google.com | Uses Google's index, so it lags Search Console by weeks |
| Claude | claude.ai | Does not browse by default — say "search the web" or you are measuring training data, not GEO |
| Copilot | copilot.microsoft.com | Bing index, so IndexNow matters here more than elsewhere |

That last column is the practical reason for the IndexNow setup: three of these
lean on indexes you can push to directly, and a two-day crawl delay is a
two-day citation delay.

## Baseline

Filled in once the site is live and the pages are indexed. New sites are not
expected to appear at all on the first run — a run where Worm is absent from
every engine is a normal starting point, not a failure.

| Date | Engine | Query | Mentioned | Position | Cited source |
| --- | --- | --- | --- | --- | --- |
| 2026-10-03 | _(pre-launch baseline: expect no mentions)_ | all six | No | — | — |

## Run log

Copy this block for each monthly run.

```
## 2026-11-03

| Engine | Q1 | Q2 | Q3 | Q4 | Q5 | Q6 |
| --- | --- | --- | --- | --- | --- | --- |
| ChatGPT | | | | | | |
| Perplexity | | | | | | |
| AI Overviews | | | | | | |
| Gemini | | | | | | |
| Claude | | | | | | |
| Copilot | | | | | | |

Cited sources this run:
Worm mentioned in N of 30 answers.
```

## What to expect

Being named by an assistant takes far longer than ranking on Google, and it is
not fully in your control. A reasonable first target is being cited in one or two
of the six queries by month three, which in practice means:

- the pages are indexed (Search Console → URL Inspection → Request Indexing)
- GitHub, Reddit and Hacker News carry the same facts as the site, because that
  is where assistants mostly learn
- the six questions are genuinely answered somewhere with clear facts to quote

## Still missing

Tracked here so they are not quietly dropped.

### Screenshots

One real macOS screenshot is live at
`public/images/screenshot-mac-clean.png`, referenced by `/mac-storage-cleaner`,
`/clear-xcode-deriveddata`, `/is-worm-cleaner-safe` and
`/best-free-mac-cleaners`.

Still to capture, each needing a matching `{ t: "img" }` block in the relevant
page in `scripts/seo/content-pages.mjs`, then `npm run build:seo`:

| File | View | Goes on |
| --- | --- | --- |
| `screenshot-mac-leftovers.png` | Leftovers tab | `/uninstall-mac-apps-completely` |
| `screenshot-mac-apps.png` | Apps tab (uninstaller) | `/uninstall-mac-apps-completely` |
| `screenshot-mac-disk.png` | Disk tab | `/windows-storage-cleaner`, `/why-is-my-mac-storage-full` |
| `screenshot-mac-menubar.png` | Awake / menu bar panel | `/mac-system-monitor` |
| `screenshot-windows-clean.png` | Windows Clean tab | `/windows-storage-cleaner` |
| `screenshot-windows-tray.png` | Windows tray panel | `/windows-storage-cleaner` |

The two Windows ones have to be taken on a Windows machine; there is no way to
produce them here, and a mockup would be worse than nothing.

Alt text should describe what is visible in the frame — the real sizes, the real
paths, the real badges — not repeat the filename.

### VirusTotal

`npm run virustotal` writes `docs/virustotal.md` with report permalinks. Once it
exists, paste the Windows-zip permalink in by hand (the free API caps uploads at
32 MB and that file is about 60 MB), then link the report from the README,
`/is-worm-cleaner-safe` and the homepage.

### Search Console baselines

Fill in, once pages are indexed:

| Metric | Baseline | 1 month | 3 months |
| --- | --- | --- | --- |
| Pages indexed | | | |
| Impressions / clicks | | | |
| Position, `worm cleaner` | | | |
| Position, `clear xcode deriveddata` | | | |
| Position, `cleanmymac alternative open source` | | | |