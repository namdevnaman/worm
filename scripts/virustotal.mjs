#!/usr/bin/env node
/**
 * Upload release binaries to VirusTotal and record the resulting report URLs.
 *
 * Why: "is worm cleaner safe" is one of the queries this product lives or dies
 * on, and a clean VirusTotal report is the single most checkable trust signal
 * available. A scan that only runs on the author's machine proves nothing to a
 * sceptical user.
 *
 * Setup, once:
 *
 *   1. Sign in at https://www.virustotal.com/gui/join-us
 *   2. Open your profile -> API key (or https://www.virustotal.com/gui/my-apikey)
 *   3. Store it:  export VIRUSTOTAL_API_KEY=<64-char-key>
 *
 * Usage:
 *   VIRUSTOTAL_API_KEY=<key> npm run virustotal
 *   VIRUSTOTAL_API_KEY=<key> npm run virustotal -- --file release-artifacts/Worm-Installer.dmg
 *   VIRUSTOTAL_API_KEY=<key> npm run virustotal -- --check-only
 *
 * Size limit: the free API accepts files up to 32 MB. Worm-Windows-x64.zip is
 * around 60 MB and will be skipped here — upload that one through the web UI at
 * https://www.virustotal.com/gui and paste the resulting permalink into
 * docs/virustotal.md by hand.
 */

import { readFile, writeFile, stat, mkdir } from "node:fs/promises";
import { existsSync } from "node:fs";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const ROOT = resolve(dirname(fileURLToPath(import.meta.url)), "..");
const RELEASES = join(ROOT, "release-artifacts");
const OUT = join(ROOT, "docs", "virustotal.md");

const API = "https://www.virustotal.com/api/v3";
const FREE_API_MAX_BYTES = 32 * 1024 * 1024;

const key = process.env.VIRUSTOTAL_API_KEY;
const checkOnly = process.argv.includes("--check-only");
const fileArgs = process.argv.slice(2).filter((a) => !a.startsWith("--"));

if (!key && !checkOnly) {
  console.error(
    "VIRUSTOTAL_API_KEY is not set.\n" +
      "  Get one from https://www.virustotal.com/gui/my-apikey\n" +
      "  Then: export VIRUSTOTAL_API_KEY=<key> && npm run virustotal",
  );
  process.exit(1);
}

async function api(path, init = {}) {
  const res = await fetch(`${API}${path}`, {
    ...init,
    headers: { "x-apikey": key, ...(init.headers || {}) },
  });
  const body = await res.json().catch(() => ({}));
  if (!res.ok) {
    const detail = body?.error?.message || `HTTP ${res.status}`;
    throw new Error(`${init.method || "GET"} ${path} failed: ${detail}`);
  }
  return body;
}

/** Submit a file for analysis. Returns the analysis id. */
async function uploadFile(path) {
  const buf = await readFile(path);
  const form = new FormData();
  form.append("file", new Blob([buf]), path.split("/").pop());

  const body = await api("/files", { method: "POST", body: form });
  return body.data.id;
}

/** Poll an analysis until it completes. */
async function waitForAnalysis(id, { attempts = 40, intervalMs = 7500 } = {}) {
  for (let i = 0; i < attempts; i++) {
    const body = await api(`/analyses/${id}`);
    const attrs = body.data.attributes;
    if (attrs.status === "completed") return attrs;
    process.stdout.write(`  analysing… ${attrs.status}\r`);
    await new Promise((r) => setTimeout(r, intervalMs));
  }
  throw new Error(`analysis ${id} did not complete in time`);
}

/** Look up an existing analysis by checksum. Returns null when unknown. */
async function findByHash(sha256) {
  try {
    return await api(`/files/${sha256}`);
  } catch {
    return null;
  }
}

function verdictLine(stats) {
  const { malicious, suspicious } = stats;
  return malicious === 0 && suspicious === 0
    ? `**${malicious} malicious / ${suspicious} suspicious** across ${Object.values(stats).reduce((a, b) => a + b, 0)} engines`
    : `${malicious} malicious, ${suspicious} suspicious`;
}

function permalink(sha256) {
  return `https://www.virustotal.com/gui/file/${sha256}`;
}

/* ── Pick files ────────────────────────────────────────────────────────── */

let targets;
if (fileArgs.length) {
  targets = fileArgs.map((f) => resolve(ROOT, f));
} else if (existsSync(RELEASES)) {
  const { readdir } = await import("node:fs/promises");
  targets = (await readdir(RELEASES))
    .filter((f) => /\.(dmg|zip|exe)$/i.test(f) && !/-TEST\./i.test(f))
    .map((f) => join(RELEASES, f));
} else {
  console.error(`No ${RELEASES} directory and no --file given.`);
  process.exit(1);
}

const rows = [];
const skipped = [];

for (const path of targets) {
  if (!existsSync(path)) {
    skipped.push([path, "file not found"]);
    continue;
  }
  const { size } = await stat(path);
  const name = path.split("/").pop();

  if (size > FREE_API_MAX_BYTES) {
    skipped.push([
      name,
      `${(size / 1024 / 1024).toFixed(1)} MB exceeds the ${FREE_API_MAX_BYTES / 1024 / 1024} MB free API limit — upload via https://www.virustotal.com/gui and paste the permalink into docs/virustotal.md`,
    ]);
    continue;
  }

  rows.push({ name, path, size });
}

/* ── Check-only: report existing verdicts without re-uploading ─────────── */

if (checkOnly) {
  const { createHash } = await import("node:crypto");
  console.log("Checking existing VirusTotal verdicts...\n");
  for (const f of rows) {
    const sha = createHash("sha256").update(await readFile(f.path)).digest("hex");
    const existing = await findByHash(sha);
    if (!existing) {
      console.log(`  ${f.name}: not previously uploaded`);
      continue;
    }
    const s = existing.data.attributes.last_analysis_stats;
    console.log(`  ${f.name}: ${verdictLine(s)}`);
    console.log(`    ${permalink(sha)}`);
  }
  process.exit(0);
}

/* ── Upload ────────────────────────────────────────────────────────────── */

console.log(`Uploading ${rows.length} file(s) to VirusTotal...\n`);

const results = [];
for (const f of rows) {
  const { createHash } = await import("node:crypto");
  const sha = createHash("sha256").update(await readFile(f.path)).digest("hex");

  process.stdout.write(`${f.name}\n`);
  const existing = await findByHash(sha);
  let stats;
  if (existing) {
    console.log("  already known, reusing verdict");
    stats = existing.data.attributes.last_analysis_stats;
  } else {
    const id = await uploadFile(f.path);
    const attrs = await waitForAnalysis(id);
    stats = attrs.stats;
  }

  const clean = stats.malicious === 0 && stats.suspicious === 0;
  console.log(`  ${verdictLine(stats)}`);
  console.log(`  ${permalink(sha)}\n`);

  results.push({ name: f.name, sha, stats, clean, permalink: permalink(sha) });
}

/* ── Write the report file ─────────────────────────────────────────────── */

await mkdir(dirname(OUT), { recursive: true });

const generated = new Date().toISOString().slice(0, 10);
const total = results.reduce(
  (acc, r) => {
    for (const k of Object.keys(r.stats)) acc[k] = (acc[k] || 0) + r.stats[k];
    return acc;
  },
  {},
);

const body = `# VirusTotal reports

Generated by \`npm run virustotal\` on ${generated}. Re-run after each release.

Paste the VirusTotal report URL for **Worm Cleaner — Not Malware** into the
homepage, the README, and \`/is-worm-cleaner-safe\`. It is the most directly
checkable trust signal available for the "is worm cleaner safe" query.

| File | SHA-256 | Engines | Malicious | Suspicious | Report |
| --- | --- | --- | --- | --- | --- |
${results
  .map(
    (r) =>
      `| \`${r.name}\` | \`${r.sha.slice(0, 16)}…\` | ${Object.values(r.stats).reduce((a, b) => a + b, 0)} | ${r.stats.malicious} | ${r.stats.suspicious} | [report](${r.permalink}) |`,
  )
  .join("\n")}

**Aggregate across all scanned files:** ${Object.values(total).reduce((a, b) => a + b, 0)} engine verdicts, ${total.malicious || 0} malicious, ${total.suspicious || 0} suspicious.
${
  skipped.length
    ? `\n## Not scanned by the API\n\n${skipped.map(([n, why]) => `- \`${n}\` — ${why}`).join("\n")}\n`
    : ""
}
## If a vendor flags it falsely

False positives on a small unsigned binary are common. Submit them:
https://www.virustotal.com/gui/file/${results[0]?.sha || "<sha256>"}/detection

Do not argue in the comments. Attach the SHA-256, the MIT licence, the source
link, and note that the file is portable and unsigned.`;

await writeFile(OUT, body, "utf8");
console.log(`Wrote ${OUT}`);

if (skipped.length) {
  console.log("\nNeeds manual upload:");
  for (const [n, why] of skipped) console.log(`  ${n}: ${why}`);
}

const anyFlagged = results.some((r) => !r.clean);
if (anyFlagged) {
  console.log("\nAt least one file has detections. See docs/virustotal.md.");
}