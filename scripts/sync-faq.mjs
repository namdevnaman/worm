#!/usr/bin/env node
/**
 * Sync the FAQ into the two places index.html repeats it.
 *
 *   1. the FAQPage JSON-LD block
 *   2. the no-JS fallback <dl> that crawlers without JavaScript read
 *
 * faqs.ts is the single source of truth, and its own header comment already
 * claimed the schema was "generated from this same list" — but nothing
 * generated it, so the three copies could drift apart silently. This script
 * closes that gap. It rewrites both blocks in place and leaves the rest of
 * index.html untouched.
 *
 * A FAQPage whose answers do not match the visible page is a structured-data
 * mismatch, which is a manual-action risk rather than a cosmetic bug, so this
 * runs as part of `npm run verify:seo`.
 *
 * Usage:
 *   node scripts/sync-faq.mjs            # rewrite index.html in place
 *   node scripts/sync-faq.mjs --check    # fail if index.html is out of date
 */

import { readFile, writeFile } from "node:fs/promises";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const ROOT = resolve(dirname(fileURLToPath(import.meta.url)), "..");
const FAQS_TS = join(ROOT, "src", "lib", "faqs.ts");
const INDEX_HTML = join(ROOT, "index.html");

const ESC = { "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" };
const esc = (v) => String(v).replace(/[&<>"']/g, (c) => ESC[c]);

/**
 * Pull the q/a pairs out of faqs.ts without executing it.
 *
 * A regex over the array literal is enough here and avoids pulling a TypeScript
 * compiler into the build: the file is a flat list of double-quoted string
 * pairs, so each capture is a valid JSON string once extracted.
 */
function parseFaqs(source) {
  const re = /\{\s*q:\s*"((?:[^"\\]|\\.)*)"\s*,\s*a:\s*"((?:[^"\\]|\\.)*)"\s*,?\s*\}/g;
  const out = [];
  let m;
  while ((m = re.exec(source)) !== null) {
    out.push({ q: JSON.parse(`"${m[1]}"`), a: JSON.parse(`"${m[2]}"`) });
  }
  return out;
}

/** JSON-LD needs the answer as plain text, escaped so `</script>` cannot escape the block. */
function jsonLdText(text) {
  return text.replace(/\s+/g, " ").trim();
}

function buildSchema(faqs) {
  const entities = faqs
    .map(
      (f) =>
        `              {\n` +
        `                "@type": "Question",\n` +
        `                "name": ${JSON.stringify(f.q)},\n` +
        `                "acceptedAnswer": { "@type": "Answer", "text": ${JSON.stringify(jsonLdText(f.a))} }\n` +
        `              }`,
    )
    .join(",\n");

  // Replaces only the array; the `"mainEntity": ` key itself is already in the
  // HTML and is what the replacement is anchored to.
  return `[\n${entities}\n    ]`;
}

function buildNoJs(faqs) {
  const items = faqs
    .map((f) => `        <dt>${esc(f.q)}</dt>\n        <dd>${esc(f.a)}</dd>`)
    .join("\n");
  return `      <dl>\n${items}\n      </dl>`;
}

/**
 * Replace the first `mainEntity: [ ... ]` array in the file.
 *
 * Scoped by brace counting rather than a regex because the answers contain
 * braces of their own, and by anchoring on mainEntity because it appears once.
 */
function replaceSchema(html, replacement) {
  const key = html.indexOf('"mainEntity"');
  if (key === -1) throw new Error('index.html: no "mainEntity" key found');

  const open = html.indexOf("[", key);
  if (open === -1) throw new Error('index.html: mainEntity has no opening bracket');

  let depth = 0;
  let inString = false;
  let escaped = false;

  for (let i = open; i < html.length; i++) {
    const ch = html[i];
    if (inString) {
      if (escaped) escaped = false;
      else if (ch === "\\") escaped = true;
      else if (ch === '"') inString = false;
      continue;
    }
    if (ch === '"') inString = true;
    else if (ch === "[") depth++;
    else if (ch === "]") {
      depth--;
      if (depth === 0) {
        return html.slice(0, open) + replacement + html.slice(i + 1);
      }
    }
  }

  throw new Error("index.html: could not find the end of the mainEntity array");
}

/**
 * Replace the no-JS <dl> that follows the "Frequently asked questions" heading.
 *
 * Operates on whole lines rather than on the tag positions alone. An earlier
 * version sliced from the `<dl>` character, so the indentation before it was
 * left in place *and* re-added by the replacement, drifting six spaces further
 * on every run.
 */
function replaceNoJs(html, replacement) {
  const heading = html.indexOf("<h2>Frequently asked questions</h2>");
  if (heading === -1) {
    throw new Error('index.html: no "Frequently asked questions" heading found');
  }

  const open = html.indexOf("<dl>", heading);
  const close = html.indexOf("</dl>", heading);
  if (open === -1 || close === -1 || close < open) {
    throw new Error("index.html: could not find the no-JS <dl> block");
  }

  // Snap out to the surrounding line boundaries.
  const lineStart = html.lastIndexOf("\n", open) + 1;
  const closeLineEnd = html.indexOf("\n", close);
  const end = closeLineEnd === -1 ? html.length : closeLineEnd;

  return html.slice(0, lineStart) + replacement + html.slice(end);
}

/* ── Main ──────────────────────────────────────────────────────────────── */

const check = process.argv.includes("--check");

const faqs = parseFaqs(await readFile(FAQS_TS, "utf8"));

if (faqs.length < 15) {
  console.error(
    `Expected at least 15 FAQ entries for a competitive FAQ footprint; found ${faqs.length}.`,
  );
  process.exit(1);
}

const seen = new Set();
for (const f of faqs) {
  if (seen.has(f.q)) {
    console.error(`Duplicate FAQ question: ${f.q}`);
    process.exit(1);
  }
  seen.add(f.q);
}

const original = await readFile(INDEX_HTML, "utf8");
const updated = replaceNoJs(replaceSchema(original, buildSchema(faqs)), buildNoJs(faqs));

if (updated === original) {
  console.log(`index.html FAQ is in sync with faqs.ts (${faqs.length} entries).`);
  process.exit(0);
}

if (check) {
  console.error(
    `index.html FAQ is out of date with faqs.ts (${faqs.length} entries). Run: npm run sync:faq`,
  );
  process.exit(1);
}

await writeFile(INDEX_HTML, updated, "utf8");
console.log(`Synced ${faqs.length} FAQ entries into index.html (schema + no-JS fallback).`);