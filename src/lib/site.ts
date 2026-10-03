/**
 * Release and freshness metadata.
 *
 * Kept in one place because these values appear in several surfaces and the
 * GEO guidance is explicit that a stale version number or date is worse than
 * none: AI answer engines skip sources whose facts disagree.
 *
 * Both must be bumped together with a release. `LAST_UPDATED` is deliberately
 * a plain date string rather than anything computed at render time, so the
 * static HTML in index.html and the hydrated React tree always agree.
 */
export const APP_VERSION = "1.0.4";

/** ISO date of the last content or code change. */
export const LAST_UPDATED_ISO = "2026-10-03";

/** Human-readable form, as shown in the footer. */
export const LAST_UPDATED = "3 October 2026";
