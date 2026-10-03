/**
 * Single source of truth for in-page navigation.
 *
 * The header, the mobile drawer, the footer, and the sitemap all read from
 * this list. The previous navbar drifted out of sync with its own markup
 * (phantom Tailwind classes, `href="#"`, anchors hidden under the sticky
 * header) precisely because there was no registry to validate against —
 * adding a section meant hand-editing four unrelated places.
 *
 * Two separate lists on purpose:
 *   SECTIONS      every real section on the page. Drives the footer, the
 *                 sitemap, and active-section tracking.
 *   NAV_SECTIONS  the subset promoted into the header bar and the drawer.
 *
 * A section can exist without being in the bar. The Storage Calculator is
 * reachable from the footer and from its own inline CTA, but promoting all
 * eight pushed the bar past the point where it fits on one line.
 */
export type SectionId =
  | "hero-scene"
  | "interactive-demo"
  | "downloads"
  | "features"
  | "calculator"
  | "comparison"
  | "faq";

export interface NavSection {
  id: SectionId;
  /** Full label for the mobile drawer and footer. */
  label: string;
  /** Condensed label for the desktop bar, which must stay on one line. */
  short: string;
  /** Promoted into the header bar / drawer? */
  inNav: boolean;
}

export const SECTIONS: readonly NavSection[] = [
  { id: "hero-scene", label: "X-Ray Burrow", short: "Burrow", inNav: true },
  { id: "interactive-demo", label: "Live App Demo", short: "Demo", inNav: true },
  { id: "downloads", label: "Downloads", short: "Download", inNav: true },
  { id: "features", label: "Features", short: "Features", inNav: true },
  { id: "calculator", label: "Storage Calculator", short: "Calculator", inNav: false },
  { id: "comparison", label: "Comparison", short: "Compare", inNav: true },
  { id: "faq", label: "FAQ", short: "FAQ", inNav: true },
] as const;

/** The subset rendered in the header bar and the mobile drawer. */
export const NAV_SECTIONS: readonly NavSection[] = SECTIONS.filter((s) => s.inNav);

/** Every section id — used for active-section tracking and anchor validation. */
export const SECTION_IDS: readonly SectionId[] = SECTIONS.map((s) => s.id);

export const REPO_URL = "https://github.com/namdevnaman/worm";
export const RELEASES_URL = `${REPO_URL}/releases`;

/**
 * Off-site profiles. Keep in sync with the `sameAs` arrays in index.html —
 * these are the entity links that let search engines and AI tools connect the
 * product to its author and its company.
 */
export const SOCIAL = {
  author: "https://www.instagram.com/namdevnaman/",
  company: "https://www.instagram.com/clepsydra_technologies/",
  authorHandle: "@namdevnaman",
  companyHandle: "@clepsydra_technologies",
} as const;