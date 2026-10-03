/**
 * Static SEO page renderer.
 *
 * The marketing homepage is a client-rendered React SPA, which means a crawler
 * that does not execute JavaScript sees an empty <div id="root">. That is fine
 * for the homepage, which carries a no-JS fallback, but it is the wrong shape
 * for the long-tail landing pages: those exist purely to be read, quoted and
 * ranked, and they should not cost a 200 kB React bundle to render a paragraph
 * of text.
 *
 * So every landing page and blog post is a hand-shaped HTML file with its
 * content in the markup. No framework, no hydration, no layout shift. The React
 * app is untouched.
 *
 * This module owns the shared shell: <head>, header, footer, breadcrumbs and
 * the JSON-LD graph. Content lives in ./content.mjs as plain data.
 *
 * Design constraint: this file must not import anything from ../src. The
 * landing pages are a separate surface that happens to share the brand palette,
 * and coupling them to the app's token system would mean a CSS refactor could
 * silently break a page that search engines have already indexed.
 */

/* ── Site constants ────────────────────────────────────────────────────── */

export const SITE = {
  origin: "https://worm.clepsydratechnologies.com",
  name: "Worm Cleaner",
  shortName: "Worm",
  tagline: "Free open-source Mac & Windows storage cleaner",
  repo: "https://github.com/namdevnaman/worm",
  releases: "https://github.com/namdevnaman/worm/releases/latest",
  license: "MIT",
  version: "1.0.4",
  updatedISO: "2026-10-03",
  updatedHuman: "3 October 2026",
  author: "Naman Namdev",
  company: "Clepsydra Technologies",
  authorUrl: "https://github.com/namdevnaman",
  companyUrl: "https://clepsydratechnologies.com",
  ogImage: "/images/worm-og.png",
  logo: "/images/WormLogo_64.png",
};

/** Brand palette, lifted from the app's design tokens in src/index.css. */
const T = {
  bg: "#070605",
  bgSunken: "#060504",
  surface1: "#13100d",
  surface2: "#1a1512",
  surface3: "#231c18",
  n300: "#ad9f90",
  n200: "#ded3c5",
  n100: "#f5efe6",
  white: "#ffffff",
  accent: "#e07a5f",
  accentBright: "#f4978e",
  moss: "#7da572",
  mossLight: "#9dc492",
  border: "rgba(255,255,255,0.09)",
  borderStrong: "rgba(255,255,255,0.16)",
};

/* ── Escaping ──────────────────────────────────────────────────────────── */

const ESC = { "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" };

/** Escape for use in an HTML text node or a double-quoted attribute value. */
export function esc(value) {
  return String(value).replace(/[&<>"']/g, (c) => ESC[c]);
}

/**
 * Escape for use inside a <script> block holding JSON.
 *
 * The sequence `</script` inside a string value would otherwise terminate the
 * block early, and `<` / `&` need escaping so the JSON stays valid if the file
 * is ever served through a transformation that decodes entities.
 */
function jsonForScript(value) {
  return JSON.stringify(value, null, 2)
    .replace(/</g, "\\u003c")
    .replace(/>/g, "\\u003e")
    .replace(/&/g, "\\u0026")
    .replace(/\u2028/g, "\\u2028")
    .replace(/\u2029/g, "\\u2029");
}

/* ── Stylesheet ─────────────────────────────────────────────────────────── */

function stylesheet() {
  return `
:root {
  --bg: ${T.bg};
  --sunken: ${T.bgSunken};
  --s1: ${T.surface1};
  --s2: ${T.surface2};
  --s3: ${T.surface3};
  --ink: ${T.white};
  --body: ${T.n100};
  --muted: ${T.n300};
  --accent: ${T.accentBright};
  --accent-bright: ${T.accentBright};
  --accent-dim: ${T.accent};
  --moss: ${T.mossLight};
  --line: ${T.border};
  --line-strong: ${T.borderStrong};
  --maxw: 74ch;
}
* { box-sizing: border-box; }
html { -webkit-text-size-adjust: 100%; scroll-behavior: smooth; }
body {
  margin: 0;
  background: var(--bg);
  color: var(--body);
  font-family: 'Plus Jakarta Sans', -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
  font-size: 17px;
  line-height: 1.72;
  -webkit-font-smoothing: antialiased;
}
img { max-width: 100%; height: auto; display: block; }
a { color: var(--accent); text-decoration-color: rgba(244,151,142,0.4); text-underline-offset: 3px; }
a:hover { text-decoration-color: currentColor; }
code {
  font-family: 'JetBrains Mono', ui-monospace, SFMono-Regular, Menlo, monospace;
  font-size: 0.88em;
  background: var(--s3);
  border: 1px solid var(--line);
  border-radius: 6px;
  padding: 0.12em 0.4em;
  overflow-wrap: anywhere;
}
pre {
  font-family: 'JetBrains Mono', ui-monospace, SFMono-Regular, Menlo, monospace;
  font-size: 0.9rem;
  line-height: 1.6;
  background: var(--s1);
  border: 1px solid var(--line);
  border-radius: 12px;
  padding: 1.1rem 1.25rem;
  overflow-x: auto;
  margin: 1.5rem 0;
}
pre code { background: none; border: 0; padding: 0; font-size: inherit; }

.skip {
  position: absolute; left: -9999px;
}
.skip:focus {
  left: 1rem; top: 1rem; z-index: 10;
  background: var(--s2); color: var(--ink);
  padding: 0.7rem 1.1rem; border-radius: 8px; border: 1px solid var(--line-strong);
}

.wrap { width: 100%; max-width: 1000px; margin: 0 auto; padding: 0 1.5rem; }

/* ── Header ── */
.site-head {
  position: sticky; top: 0; z-index: 20;
  background: rgba(7, 6, 5, 0.88);
  backdrop-filter: saturate(160%) blur(12px);
  border-bottom: 1px solid var(--line);
}
.site-head__in {
  display: flex; align-items: center; gap: 1.25rem;
  min-height: 4rem; padding: 0.7rem 0;
}
.brand { display: flex; align-items: center; gap: 0.6rem; text-decoration: none; color: var(--ink); flex-shrink: 0; }
.brand img { width: 26px; height: 26px; border-radius: 7px; }
.brand span {
  font-family: Lexend, 'Plus Jakarta Sans', sans-serif;
  font-weight: 800; letter-spacing: -0.02em; font-size: 1rem;
  white-space: nowrap;
}
/* Kept on one line at every width. An earlier version used flex-wrap, which
   dropped the nav onto its own row and left the Download button floating away
   from the links it belongs with. Below 860px the links collapse entirely and
   the footer carries navigation, which beats a cramped scrolling strip. */
.site-nav {
  display: flex; gap: 1.1rem; align-items: center;
  margin-left: auto; min-width: 0; flex-wrap: nowrap;
}
.site-nav a { color: var(--muted); text-decoration: none; font-size: 0.88rem; font-weight: 600; white-space: nowrap; }
.site-nav a:hover { color: var(--body); }
.btn {
  display: inline-flex; align-items: center; gap: 0.45rem;
  font-size: 0.88rem; font-weight: 700; text-decoration: none;
  padding: 0.55rem 1rem; border-radius: 10px;
  border: 1px solid transparent; white-space: nowrap; flex-shrink: 0;
}
.btn--primary { background: var(--accent-dim); color: #1b0f0a; }
.btn--primary:hover { background: var(--accent-bright); }
.btn--ghost { border-color: var(--line-strong); color: var(--body); }
.btn--ghost:hover { border-color: var(--accent); color: var(--accent); }

/* ── Main ── */
main { padding: 3rem 0 5rem; }
.crumbs { font-size: 0.85rem; color: var(--muted); margin-bottom: 1.75rem; }
.crumbs a { color: var(--muted); text-decoration: none; }
.crumbs a:hover { color: var(--accent); }
.crumbs span[aria-hidden] { margin: 0 0.45rem; opacity: 0.5; }

article { max-width: var(--maxw); }

h1 {
  font-family: Lexend, 'Plus Jakarta Sans', sans-serif;
  font-size: clamp(2rem, 5vw, 2.9rem);
  line-height: 1.14; letter-spacing: -0.03em;
  color: var(--ink); margin: 0 0 1.25rem;
}
h2 {
  font-family: Lexend, 'Plus Jakarta Sans', sans-serif;
  font-size: clamp(1.35rem, 3vw, 1.75rem);
  line-height: 1.25; letter-spacing: -0.02em;
  color: var(--ink); margin: 3rem 0 1rem;
  padding-top: 1.5rem; border-top: 1px solid var(--line);
}
h3 {
  font-family: Lexend, 'Plus Jakarta Sans', sans-serif;
  font-size: 1.15rem; letter-spacing: -0.01em;
  color: var(--ink); margin: 2rem 0 0.6rem;
}
p { margin: 0 0 1.15rem; }
ul, ol { margin: 0 0 1.25rem; padding-left: 1.3rem; }
li { margin-bottom: 0.5rem; }
li::marker { color: var(--accent-dim); }
strong { color: var(--ink); font-weight: 700; }

.lede { font-size: 1.16rem; color: ${T.n200}; margin-bottom: 1.5rem; }
.eyebrow {
  display: inline-block; font-size: 0.78rem; font-weight: 700;
  letter-spacing: 0.09em; text-transform: uppercase;
  color: var(--moss); background: rgba(125,165,114,0.12);
  border: 1px solid rgba(125,165,114,0.32);
  border-radius: 999px; padding: 0.3rem 0.75rem; margin-bottom: 1.25rem;
}
.byline {
  display: flex; flex-wrap: wrap; gap: 0.4rem 0.9rem; align-items: center;
  font-size: 0.86rem; color: var(--muted);
  padding: 0.9rem 0; margin: 1.75rem 0;
  border-top: 1px solid var(--line); border-bottom: 1px solid var(--line);
}
.byline b { color: var(--body); font-weight: 700; }

.note {
  border: 1px solid rgba(125,165,114,0.34);
  background: rgba(125,165,114,0.1);
  border-radius: 12px; padding: 1rem 1.2rem; margin: 1.75rem 0;
}
.note p:last-child { margin-bottom: 0; }
.note--warn {
  border-color: rgba(228,196,106,0.34);
  background: rgba(228,196,106,0.09);
}

table { width: 100%; border-collapse: collapse; margin: 1.5rem 0 1.75rem; font-size: 0.94rem; display: block; overflow-x: auto; }
caption { caption-side: top; text-align: left; font-size: 0.82rem; color: var(--muted); padding-bottom: 0.6rem; }
th, td { text-align: left; padding: 0.65rem 0.8rem; border-bottom: 1px solid var(--line); vertical-align: top; }
th { color: var(--ink); font-weight: 700; white-space: nowrap; }
td { color: ${T.n200}; }
tbody tr:last-child td { border-bottom: 0; }
.yes { color: var(--moss); font-weight: 700; }
.no { color: var(--accent); font-weight: 700; }

figure { margin: 2rem 0; }
figure img { border: 1px solid var(--line-strong); border-radius: 14px; }
figcaption { font-size: 0.85rem; color: var(--muted); margin-top: 0.7rem; }

.faq-item { border: 1px solid var(--line); border-radius: 12px; margin-bottom: 0.8rem; background: var(--s1); }
.faq-item > summary {
  cursor: pointer; list-style: none;
  padding: 1rem 1.2rem; font-weight: 700; color: var(--ink); font-size: 1.02rem;
}
.faq-item > summary::-webkit-details-marker { display: none; }
.faq-item > summary::after { content: "+"; float: right; color: var(--accent); font-weight: 400; }
.faq-item[open] > summary::after { content: "\\2212"; }
.faq-item > div { padding: 0 1.2rem 1.15rem; color: ${T.n200}; }

.cta {
  margin: 3rem 0 0; padding: 1.75rem;
  background: var(--s1); border: 1px solid var(--line-strong); border-radius: 16px;
}
.cta h2 { margin: 0 0 0.6rem; padding: 0; border: 0; font-size: 1.3rem; }
.cta p { color: ${T.n200}; }
.cta__actions { display: flex; gap: 0.75rem; flex-wrap: wrap; margin-top: 1.1rem; }

.related { margin-top: 3rem; padding-top: 2rem; border-top: 1px solid var(--line); }
.related h2 { margin-top: 0; border: 0; padding-top: 0; font-size: 1.15rem; }
.related ul { list-style: none; padding: 0; display: grid; gap: 0.7rem; }
.related li { margin: 0; }
.related a {
  display: block; padding: 0.85rem 1rem;
  border: 1px solid var(--line); border-radius: 10px; background: var(--s1);
  text-decoration: none;
}
.related a:hover { border-color: var(--accent); }
.related b { display: block; color: var(--ink); font-size: 0.98rem; }
.related span { font-size: 0.86rem; color: var(--muted); }

/* ── Footer ── */
.site-foot {
  border-top: 1px solid var(--line); background: var(--sunken);
  padding: 2.5rem 0 3rem; font-size: 0.9rem; color: var(--muted);
}
.site-foot__grid {
  display: grid; gap: 2rem; margin-bottom: 2rem;
  grid-template-columns: repeat(auto-fit, minmax(210px, 1fr));
}
.site-foot h3 {
  font-size: 0.78rem; letter-spacing: 0.09em; text-transform: uppercase;
  color: ${T.n200}; margin: 0 0 0.75rem; font-family: inherit;
}
.site-foot ul { list-style: none; padding: 0; margin: 0; }
.site-foot li { margin-bottom: 0.4rem; }
.site-foot a { color: var(--muted); text-decoration: none; }
.site-foot a:hover { color: var(--accent); }
.site-foot__bar {
  border-top: 1px solid var(--line); padding-top: 1.25rem;
  display: flex; flex-wrap: wrap; gap: 0.75rem 1.5rem; justify-content: space-between;
  font-size: 0.82rem;
}

@media (max-width: 860px) {
  .site-nav a:not(.btn) { display: none; }
}
@media (max-width: 720px) {
  body { font-size: 16.5px; }
  main { padding: 2rem 0 3.5rem; }
  .brand span { font-size: 0.95rem; }
}
@media (prefers-reduced-motion: reduce) {
  html { scroll-behavior: auto; }
}
`.trim();
}

/* ── Block renderer ─────────────────────────────────────────────────────── */

/**
 * Render one content block.
 *
 * `html` values are trusted author input (this file is not a user-facing
 * surface), so they pass through verbatim. Everything interpolated from a
 * variable goes through esc() or is already known-safe markup.
 */
function renderBlock(block, allPages, page) {
  switch (block.t) {
    case "p":
      return `<p>${block.html}</p>`;

    case "h2":
      return `<h2 id="${esc(block.id || slugify(stripTags(block.html)))}">${block.html}</h2>`;

    case "h3":
      return `<h3>${block.html}</h3>`;

    case "ul":
      return `<ul>${block.items.map((i) => `<li>${i}</li>`).join("\n")}</ul>`;

    case "ol":
      return `<ol>${block.items.map((i) => `<li>${i}</li>`).join("\n")}</ol>`;

    case "table":
      return renderTable(block);

    case "note":
      return `<div class="note${block.variant === "warn" ? " note--warn" : ""}">${block.html}</div>`;

    case "code":
      return `<pre><code>${esc(block.text)}</code></pre>`;

    case "img":
      return renderFigure(block);

    case "faq": {
      // Blocks declare { t: "faq" } with no list; the questions live on the page
      // so the visible accordion and the FAQPage JSON-LD read the same source.
      const faqs = block.faqs && block.faqs.length ? block.faqs : page.faqs;
      if (!faqs || !faqs.length) return "";
      return (
        `<h2 id="faq">Frequently asked questions</h2>\n` +
        renderFaq(faqs.map((f) => ({ q: f.q, a: f.a })))
      );
    }

    case "cta":
      return renderCta(block);

    case "related": {
      // Resolved by href so a page can cross-link without repeating titles, and
      // a rename in one place cannot leave a dangling reference elsewhere.
      const wanted = new Set(block.ids);
      const found = allPages.filter((p) => wanted.has(p.href));
      const missing = [...wanted].filter((h) => !found.some((p) => p.href === h));
      if (missing.length) {
        throw new Error(`Unknown related href(s) on ${currentHref}: ${missing.join(", ")}`);
      }
      return renderRelated(found);
    }

    default:
      throw new Error(`Unknown block type: ${block.t}`);
  }
}

// Set for the duration of one renderPage call so renderBlock can report which
// page had the bad reference.
let currentHref = "(unknown)";

function renderTable({ caption, head, rows }) {
  const headHtml = head
    ? `<thead><tr>${head.map((h) => `<th scope="col">${h}</th>`).join("")}</tr></thead>`
    : "";
  const bodyHtml = rows
    .map(
      (r) =>
        `<tr>${r.map((cell, i) => (i === 0 ? `<th scope="row">${cell}</th>` : `<td>${cell}</td>`)).join("")}</tr>`,
    )
    .join("\n");
  const capHtml = caption ? `<caption>${caption}</caption>` : "";
  return `<table>${capHtml}${headHtml}<tbody>\n${bodyHtml}\n</tbody></table>`;
}

function renderFigure({ src, alt, caption, width, height }) {
  const dims = width && height ? ` width="${width}" height="${height}"` : "";
  return `<figure><img src="${esc(src)}" alt="${esc(alt)}"${dims} loading="lazy" decoding="async" />${
    caption ? `<figcaption>${caption}</figcaption>` : ""
  }</figure>`;
}

function renderFaq(faqs) {
  return faqs
    .map(
      (f) =>
        `<details class="faq-item"><summary>${esc(f.q)}</summary><div>${f.a}</div></details>`,
    )
    .join("\n");
}

function renderCta({ title = "Download Worm Cleaner", body }) {
  return `<div class="cta">
  <h2>${esc(title)}</h2>
  <p>${body}</p>
  <div class="cta__actions">
    <a class="btn btn--primary" href="${esc(SITE.releases)}">Download for Mac &amp; Windows</a>
    <a class="btn btn--ghost" href="${esc(SITE.repo)}">View source code</a>
  </div>
</div>`;
}

function renderRelated(pages) {
  if (!pages || pages.length === 0) return "";
  const items = pages
    .map(
      (p) =>
        `<li><a href="${esc(p.href)}"><b>${esc(p.title)}</b><span>${esc(p.blurb)}</span></a></li>`,
    )
    .join("\n");
  return `<nav class="related" aria-label="Related pages">
  <h2>Related reading</h2>
  <ul>
${items}
  </ul>
</nav>`;
}

/* ── Text helpers ───────────────────────────────────────────────────────── */

function stripTags(html) {
  return String(html).replace(/<[^>]*>/g, "");
}

export function slugify(text) {
  return String(text)
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, "-")
    .replace(/^-+|-+$/g, "")
    .slice(0, 60);
}

/* ── JSON-LD ───────────────────────────────────────────────────────────── */

/**
 * The graph every page carries.
 *
 * SoftwareApplication appears on every page with the same @id, so the entity
 * facts (name, licence, price, platforms, version) are stated once for the
 * whole site instead of drifting per page. Disagreeing facts across pages are
 * exactly what makes an answer engine drop a source.
 */
function jsonLd(page, allPages) {
  const url = `${SITE.origin}${page.href}`;
  const graph = [
    {
      "@type": "WebPage",
      "@id": `${url}#webpage`,
      url,
      name: page.title,
      description: page.description,
      inLanguage: "en",
      isPartOf: { "@id": `${SITE.origin}/#website` },
      about: { "@id": `${SITE.origin}/#app` },
      datePublished: page.publishedISO || SITE.updatedISO,
      dateModified: page.updatedISO || SITE.updatedISO,
      author: { "@id": `${SITE.origin}/#person` },
      breadcrumb: { "@id": `${url}#breadcrumb` },
    },
    {
      "@type": "BreadcrumbList",
      "@id": `${url}#breadcrumb`,
      itemListElement: [
        { "@type": "ListItem", position: 1, name: "Home", item: `${SITE.origin}/` },
        ...(page.href === "/" ? [] : [{ "@type": "ListItem", position: 2, name: page.crumb || page.navTitle || page.title, item: url }]),
      ],
    },
    {
      "@type": "SoftwareApplication",
      "@id": `${SITE.origin}/#app`,
      name: SITE.name,
      alternateName: ["Worm", "Worm Mac Cleaner", "Worm MacBook Cleaner", "Worm Disk Cleaner", "Worm Cleaner for Mac", "Worm Cleaner for Windows"],
      url: `${SITE.origin}/`,
      description:
        "Worm Cleaner is a free, open-source (MIT) disk cleaner, storage cleaner, app uninstaller and system monitor for macOS 14+ and Windows 10/11. It clears developer caches such as Xcode DerivedData, npm, pnpm, yarn, Homebrew, Cargo, Gradle and CocoaPods, Docker build cache, browser caches and leftover files from uninstalled apps. No telemetry, no account, no subscription. Not malware.",
      applicationCategory: "UtilitiesApplication",
      applicationSubCategory: "System Cleaner",
      operatingSystem: "macOS 14 or later, Windows 10, Windows 11",
      softwareVersion: SITE.version,
      isAccessibleForFree: true,
      license: "https://opensource.org/licenses/MIT",
      downloadUrl: SITE.releases,
      installUrl: SITE.releases,
      codeRepository: SITE.repo,
      image: `${SITE.origin}${SITE.ogImage}`,
      // A real screenshot of the app, which is what SoftwareApplication.screenshot
      // is for. Distinct from `image`, which is the social sharing card.
      screenshot: [`${SITE.origin}/images/screenshot-mac-clean.png`],
      softwareRequirements: "macOS 14+ (Apple Silicon or Intel) or Windows 10/11 64-bit",
      offers: { "@type": "Offer", price: "0", priceCurrency: "USD", availability: "https://schema.org/InStock" },
      featureList: [
        "Clear Xcode DerivedData, simulator runtimes and archives",
        "Clean npm, pnpm, yarn, Cargo, pip, Go, Gradle, Homebrew and CocoaPods caches",
        "Clear Docker buildx cache and dangling image layers",
        "Clear browser and Electron application caches",
        "Remove leftover files from uninstalled Mac apps",
        "Windows temp, Windows Update and crash dump cleanup",
        "Menu bar and system tray CPU, memory, disk and thermal monitor",
        "Simulation mode previews every deletion before it happens",
        "No telemetry, works fully offline",
        "Not malware: public MIT source, no self-replication, no network calls",
      ],
      author: { "@id": `${SITE.origin}/#person` },
      publisher: { "@id": `${SITE.origin}/#org` },
    },
    {
      "@type": "Person",
      "@id": `${SITE.origin}/#person`,
      name: SITE.author,
      url: SITE.authorUrl,
      jobTitle: "Creator",
      worksFor: { "@id": `${SITE.origin}/#org` },
      sameAs: [SITE.authorUrl, "https://www.instagram.com/namdevnaman/"],
    },
    {
      "@type": "Organization",
      "@id": `${SITE.origin}/#org`,
      name: SITE.company,
      url: SITE.companyUrl,
      logo: `${SITE.origin}/images/WormLogo@2x.png`,
      sameAs: [SITE.companyUrl, "https://www.instagram.com/clepsydra_technologies/", SITE.repo],
    },
  ];

  // The FAQPage block is emitted only when the page actually renders those
  // questions further down. A schema whose answers are not on the page is a
  // structured-data mismatch, which is worse than having no schema at all.
  if (page.faqs && page.faqs.length) {
    graph.push({
      "@type": "FAQPage",
      "@id": `${url}#faq`,
      mainEntity: page.faqs.map((f) => ({
        "@type": "Question",
        name: f.q,
        acceptedAnswer: { "@type": "Answer", text: stripTags(f.a).replace(/\s+/g, " ").trim() },
      })),
    });
  }

  if (page.kind === "article") {
    graph.push({
      "@type": "BlogPosting",
      "@id": `${url}#article`,
      headline: page.title,
      description: page.description,
      url,
      datePublished: page.publishedISO || SITE.updatedISO,
      dateModified: page.updatedISO || SITE.updatedISO,
      inLanguage: "en",
      author: { "@id": `${SITE.origin}/#person` },
      publisher: { "@id": `${SITE.origin}/#org` },
      isPartOf: { "@id": `${SITE.origin}/#website` },
      mainEntityOfPage: { "@id": `${url}#webpage` },
      keywords: page.keywords || "",
    });
  }

  return jsonForScript({ "@context": "https://schema.org", "@graph": graph });
}

/* ── Page shell ─────────────────────────────────────────────────────────── */

function header(allPages, current) {
  // A short, curated subset. Every page links to every other page through its
  // footer, so internal linking does not depend on this bar.
  const bar = allPages
    .filter((p) => p.href !== current.href && p.inHeader)
    .slice(0, 4);

  const links = bar
    .map((p) => `<a href="${esc(p.href)}">${esc(p.navTitle || p.title)}</a>`)
    .join("\n        ");

  return `<header class="site-head">
  <div class="wrap site-head__in">
    <a class="brand" href="/">
      <img src="${esc(SITE.logo)}" alt="" width="26" height="26" />
      <span>${esc(SITE.name)}</span>
    </a>
    <nav class="site-nav" aria-label="Main">
        ${links}
      <a class="btn btn--primary" href="${esc(SITE.releases)}">Download</a>
    </nav>
  </div>
</header>`;
}

function footer(allPages, current) {
  const cols = [
    {
      title: "Cleaners",
      links: allPages.filter((p) => p.group === "cleaner"),
    },
    {
      title: "Alternatives",
      links: allPages.filter((p) => p.group === "alternative"),
    },
    {
      title: "Guides",
      links: allPages.filter((p) => p.group === "guide"),
    },
    {
      // Articles appear in every page footer, not just their own topic pages.
      // A post reachable only from a sibling post is an orphan: crawlers weight
      // it far less and it will not be discovered promptly after publishing.
      title: "From the blog",
      links: allPages.filter((p) => p.group === "blog"),
    },
    { title: "Elsewhere", links: [] },
  ];

  const html = cols
    .map((col) => {
      const items = col.links
        .filter((p) => p.href !== current.href)
        .map((p) => `<li><a href="${esc(p.href)}">${esc(p.footerTitle || p.navTitle || p.title)}</a></li>`)
        .join("\n          ");
      const extra =
        col.title === "Elsewhere"
          ? `<li><a href="${esc(SITE.releases)}">Releases &amp; checksums</a></li>
          <li><a href="${esc(SITE.repo)}">Source code (MIT)</a></li>
          <li><a href="/llms.txt">llms.txt</a></li>
          <li><a href="/sitemap.xml">sitemap.xml</a></li>`
          : "";
      return `<div>
        <h3>${esc(col.title)}</h3>
        <ul>
          ${items}${extra}
        </ul>
      </div>`;
    })
    .join("\n");

  return `<footer class="site-foot">
  <div class="wrap">
    <div class="site-foot__grid">
${html}
    </div>
    <p><strong>${esc(SITE.name)}</strong> is a free, open-source (MIT) disk cleaner, storage cleaner, app uninstaller and system monitor for macOS 14+ and Windows 10/11. It is not malware and not a self-replicating computer worm. Built by ${esc(SITE.author)} at ${esc(SITE.company)}.</p>
    <div class="site-foot__bar">
      <span>&copy; 2026 ${esc(SITE.company)}. v${esc(SITE.version)} &middot; Updated ${esc(SITE.updatedHuman)}</span>
      <span>No telemetry &middot; Works offline &middot; No account required</span>
    </div>
  </div>
</footer>`;
}

/* ── Public entry point ─────────────────────────────────────────────────── */

/**
 * Render one page to a complete HTML document.
 *
 * @param {object} page      Page definition from content.mjs
 * @param {object[]} allPages Every page, for header/footer cross-links
 * @returns {string} A full HTML document
 */
export function renderPage(page, allPages) {
  const url = `${SITE.origin}${page.href}`;
  const canonical = page.href === "/" ? `${SITE.origin}/` : url;
  const ogType = page.kind === "article" ? "article" : "website";

  currentHref = page.href;
  const bodyBlocks = (page.blocks || []).map((b) => renderBlock(b, allPages, page)).join("\n\n");

  const crumbs =
    page.href === "/"
      ? ""
      : `<nav class="crumbs" aria-label="Breadcrumb"><a href="/">Home</a><span aria-hidden="&rsaquo;</span>${esc(
          page.crumb || page.navTitle || page.title,
        )}</nav>`;

  return `<!DOCTYPE html>
<html lang="en">
<head>
<!-- Generated by scripts/build-seo-pages.mjs from scripts/seo/content-*.mjs.
     Edits to this file are overwritten. Change the content module and re-run
     \`npm run build:seo\`. The marker below is load-bearing: pruning only ever
     deletes pages carrying it, so hand-authored files that happen to sit in
     public/ (404.html, the Search Console verification file) are never touched. -->
<meta charset="UTF-8" />
<meta name="viewport" content="width=device-width, initial-scale=1.0, viewport-fit=cover" />
<title>${esc(page.title)}</title>
<meta name="description" content="${esc(page.description)}" />
<meta name="author" content="${esc(SITE.author)}" />
<meta name="robots" content="index, follow, max-image-preview:large, max-snippet:-1, max-video-preview:-1" />
<link rel="canonical" href="${esc(canonical)}" />
<link rel="alternate" hreflang="en" href="${esc(canonical)}" />
<link rel="alternate" hreflang="x-default" href="${esc(canonical)}" />

<meta property="og:type" content="${ogType}" />
<meta property="og:site_name" content="${esc(SITE.name)}" />
<meta property="og:title" content="${esc(page.ogTitle || page.title)}" />
<meta property="og:description" content="${esc(page.description)}" />
<meta property="og:url" content="${esc(canonical)}" />
<meta property="og:image" content="${esc(SITE.origin + SITE.ogImage)}" />
<meta property="og:image:alt" content="${esc(page.imageAlt || `${SITE.name}: free open-source Mac and Windows storage cleaner`)}" />
<meta property="og:locale" content="en_US" />
${page.publishedISO ? `<meta property="article:published_time" content="${esc(page.publishedISO)}" />` : ""}
${page.updatedISO ? `<meta property="article:modified_time" content="${esc(page.updatedISO)}" />` : ""}
<meta name="twitter:card" content="summary_large_image" />
<meta name="twitter:title" content="${esc(page.ogTitle || page.title)}" />
<meta name="twitter:description" content="${esc(page.description)}" />
<meta name="twitter:image" content="${esc(SITE.origin + SITE.ogImage)}" />
<meta name="twitter:creator" content="@namdevnaman" />

<meta name="theme-color" content="#070605" />
<meta name="color-scheme" content="dark light" />
<meta name="google-site-verification" content="3RmWqxtk0xhQrXPBm7SVNzQ6lgASm7jD9Om8csiS9Nc" />

<link rel="icon" href="/favicon.ico" sizes="any" />
<link rel="icon" type="image/svg+xml" href="/favicon.svg" />
<link rel="apple-touch-icon" sizes="180x180" href="/apple-touch-icon.png" />
<link rel="manifest" href="/site.webmanifest" />
<link rel="alternate" type="text/plain" href="${esc(SITE.origin)}/llms.txt" title="LLM-readable summary of ${esc(SITE.name)}" />

<link rel="preconnect" href="https://fonts.googleapis.com" />
<link rel="preconnect" href="https://fonts.gstatic.com" crossorigin />
<link rel="preconnect" href="https://github.com" crossorigin />

<style>${stylesheet()}</style>
<script type="application/ld+json">${jsonLd(page, allPages)}</script>
</head>
<body>
<a class="skip" href="#main">Skip to content</a>
${header(allPages, page)}
<main id="main">
  <div class="wrap">
${crumbs}
<article>
${page.eyebrow ? `  <p class="eyebrow">${esc(page.eyebrow)}</p>\n` : ""}  <h1>${page.h1}</h1>
  <p class="lede">${page.lede}</p>
  <div class="byline">
    <span>By <b><a href="${esc(SITE.authorUrl)}" rel="author">${esc(SITE.author)}</a></b></span>
    <span>${esc(SITE.company)}</span>
    <span>Updated <b><time datetime="${esc(page.updatedISO || SITE.updatedISO)}">${esc(page.updatedHuman || SITE.updatedHuman)}</time></b></span>
    <span>Version <b>${esc(SITE.version)}</b></span>
  </div>

${bodyBlocks}
</article>
  </div>
</main>
${footer(allPages, page)}
</body>
</html>
`;
}

/* ── sitemap ────────────────────────────────────────────────────────────── */

export function renderSitemap(pages) {
  const urls = pages
    .map((p) => {
      const loc = p.href === "/" ? `${SITE.origin}/` : `${SITE.origin}${p.href}`;
      return `  <url>
    <loc>${esc(loc)}</loc>
    <lastmod>${esc(p.updatedISO || SITE.updatedISO)}</lastmod>
    <changefreq>${p.kind === "article" ? "monthly" : "weekly"}</changefreq>
    <priority>${(p.priority ?? 0.7).toFixed(1)}</priority>
  </url>`;
    })
    .join("\n");

  return `<?xml version="1.0" encoding="UTF-8"?>
<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">
${urls}
</urlset>
`;
}