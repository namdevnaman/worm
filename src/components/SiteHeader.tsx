import { useCallback, useEffect, useLayoutEffect, useMemo, useRef, useState } from "react";
import { Download, Menu, X } from "lucide-react";
import { NAV_SECTIONS, REPO_URL, SECTION_IDS } from "../lib/nav";
import { useActiveSection } from "../hooks/useActiveSection";

function GithubIcon({ size = 16 }: { size?: number }) {
  return (
    <svg width={size} height={size} viewBox="0 0 24 24" fill="currentColor" aria-hidden="true">
      <path
        fillRule="evenodd"
        clipRule="evenodd"
        d="M12 2C6.477 2 2 6.484 2 12.017c0 4.425 2.865 8.18 6.839 9.504.5.092.682-.217.682-.483 0-.237-.008-.868-.013-1.703-2.782.605-3.369-1.343-3.369-1.343-.454-1.158-1.11-1.466-1.11-1.466-.908-.62.069-.608.069-.608 1.003.07 1.53 1.032 1.53 1.032.892 1.53 2.341 1.088 2.91.832.092-.647.35-1.088.636-1.338-2.22-.253-4.555-1.113-4.555-4.951 0-1.093.39-1.988 1.029-2.688-.103-.253-.446-1.272.098-2.65 0 0 .84-.27 2.75 1.026A9.564 9.564 0 0112 6.844c.85.004 1.705.115 2.504.337 1.909-1.296 2.747-1.027 2.747-1.027.546 1.379.202 2.398.1 2.651.64.7 1.028 1.595 1.028 2.688 0 3.848-2.339 4.695-4.566 4.943.359.309.678.92.678 1.855 0 1.338-.012 2.419-.012 2.747 0 .268.18.58.688.482A10.019 10.019 0 0022 12.017C22 6.484 17.522 2 12 2z"
      />
    </svg>
  );
}

export function SiteHeader() {
  const [drawerOpen, setDrawerOpen] = useState(false);
  const [scrolled, setScrolled] = useState(false);
  const navRef = useRef<HTMLElement | null>(null);

  // Tracks every section, including ones with no bar entry.
  const activeSectionId = useActiveSection(SECTION_IDS, 72);

  /* Not every section is in the bar (the Storage Calculator is not). When the
     reader is inside one of those, keep the worm on the nearest bar entry
     above it rather than blanking the indicator — otherwise it appears to
     lose track of where you are the moment you pass a hidden section. */
  const activeNavId = useMemo(() => {
    if (activeSectionId === null) return null;
    if (NAV_SECTIONS.some((s) => s.id === activeSectionId)) return activeSectionId;

    const allIndex = SECTION_IDS.indexOf(activeSectionId);
    for (let i = allIndex; i >= 0; i--) {
      const candidate = SECTION_IDS[i];
      if (NAV_SECTIONS.some((s) => s.id === candidate)) return candidate;
    }
    return null;
  }, [activeSectionId]);

  /* ── Worm indicator: park the track under the active link ────────────── */
  useLayoutEffect(() => {
    const nav = navRef.current;
    if (!nav) return;

    const place = () => {
      const activeLink = nav.querySelector<HTMLElement>('[aria-current="true"]');
      if (!activeLink) {
        nav.dataset.hasActive = "false";
        return;
      }
      nav.dataset.hasActive = "true";
      nav.style.setProperty("--worm-x", `${activeLink.offsetLeft}px`);
      nav.style.setProperty("--worm-w", `${activeLink.offsetWidth}px`);
    };

    place();

    // Re-place on resize, and on font load (webfont swap changes label widths,
    // which would otherwise leave the track under the wrong link).
    const ro = new ResizeObserver(place);
    ro.observe(nav);
    const fonts = (document as Document & { fonts?: FontFaceSet }).fonts;
    fonts?.ready.then(place).catch(() => {});

    return () => ro.disconnect();
  }, [activeNavId]);

  /* ── Header condense on scroll ───────────────────────────────────────── */
  useEffect(() => {
    const onScroll = () => setScrolled(window.scrollY > 24);
    onScroll();
    window.addEventListener("scroll", onScroll, { passive: true });
    return () => window.removeEventListener("scroll", onScroll);
  }, []);

  /* ── Drawer: lock scroll, close on Escape ────────────────────────────── */
  useEffect(() => {
    if (!drawerOpen) return;

    const onKey = (e: KeyboardEvent) => {
      if (e.key === "Escape") setDrawerOpen(false);
    };
    document.addEventListener("keydown", onKey);
    document.body.style.overflow = "hidden";

    return () => {
      document.removeEventListener("keydown", onKey);
      document.body.style.overflow = "";
    };
  }, [drawerOpen]);

  const closeDrawer = useCallback(() => setDrawerOpen(false), []);

  return (
    <>
      <header className="site-header" data-scrolled={scrolled}>
        <div className="container site-header__bar">
          {/* Brand — a real home link, not href="#". Using "/" keeps the URL
              clean and does not append an empty fragment to history. */}
          <a className="brand" href="#hero-scene" aria-label="Worm Cleaner — back to top">
            <span className="brand__mark">
              <img src="/images/NavMascot@2x.png" alt="" width={26} height={26} />
            </span>
            <span>
              <span style={{ display: "flex", alignItems: "center", gap: "0.4rem" }}>
                <span className="brand__word">WORM</span>
                <span className="brand__tag">CLEANER</span>
              </span>
              <span className="brand__sub">by Clepsydra Technologies</span>
            </span>
          </a>

          {/* Desktop nav — single line, condensed labels so it never wraps */}
          <nav className="site-nav" ref={navRef} aria-label="Primary">
            <ul className="site-nav__list">
              {NAV_SECTIONS.map((section) => (
                <li key={section.id}>
                  <a
                    className="site-nav__link"
                    href={`#${section.id}`}
                    aria-current={activeNavId === section.id ? "true" : undefined}
                  >
                    {section.short}
                  </a>
                </li>
              ))}
            </ul>
            <span className="site-nav__worm" aria-hidden="true" />
          </nav>

          <div className="site-header__actions">
            <a
              className="btn-secondary btn-github"
              href={REPO_URL}
              target="_blank"
              rel="noopener noreferrer"
              style={{ padding: "0.6rem 1rem", fontSize: "0.875rem" }}
            >
              <GithubIcon size={15} />
              <span>GitHub</span>
            </a>

            <a className="btn-primary" href="#downloads">
              <Download size={16} />
              <span>Download</span>
            </a>

            <button
              className="nav-toggle"
              onClick={() => setDrawerOpen((v) => !v)}
              aria-expanded={drawerOpen}
              aria-controls="nav-drawer"
              aria-label={drawerOpen ? "Close menu" : "Open menu"}
            >
              {drawerOpen ? <X size={18} /> : <Menu size={18} />}
            </button>
          </div>
        </div>
      </header>

      {/* Mobile drawer — the only in-page nav small screens get, so it has to
          be complete: every section plus both actions. */}
      {drawerOpen && (
        <div className="nav-drawer" id="nav-drawer">
          {NAV_SECTIONS.map((section) => (
            <a
              key={section.id}
              className="nav-drawer__link"
              href={`#${section.id}`}
              aria-current={activeNavId === section.id ? "true" : undefined}
              onClick={closeDrawer}
            >
              <span>{section.label}</span>
              <span style={{ fontFamily: "var(--font-mono)", fontSize: "0.75rem", color: "var(--ink-faint)" }}>
                {String(SECTION_IDS.indexOf(section.id) + 1).padStart(2, "0")}
              </span>
            </a>
          ))}

          <div className="nav-drawer__actions">
            <a
              className="btn-secondary"
              href={REPO_URL}
              target="_blank"
              rel="noopener noreferrer"
              style={{ width: "100%" }}
            >
              <GithubIcon size={16} />
              <span>View Source on GitHub</span>
            </a>
            <a className="btn-primary" href="#downloads" onClick={closeDrawer} style={{ width: "100%" }}>
              <Download size={17} />
              <span>Download Free</span>
            </a>
          </div>
        </div>
      )}
    </>
  );
}

export default SiteHeader;