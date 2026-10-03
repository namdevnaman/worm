import { useEffect } from "react";

/**
 * Reveals `.reveal` elements as they enter the viewport.
 *
 * IntersectionObserver rather than a scroll listener: the browser batches
 * these callbacks off the main scroll path, so a long page costs nothing
 * while scrolling. The CSS in index.css owns the actual transition, and
 * collapses it entirely under `prefers-reduced-motion`.
 *
 * Elements already in view on first paint are revealed immediately so the
 * hero never flashes in late.
 */
export function useScrollReveal() {
  useEffect(() => {
    const targets = Array.from(document.querySelectorAll<HTMLElement>(".reveal"));
    if (targets.length === 0) return;

    if (typeof IntersectionObserver === "undefined") {
      targets.forEach((el) => el.classList.add("is-revealed"));
      return;
    }

    const observer = new IntersectionObserver(
      (entries) => {
        entries.forEach((entry) => {
          if (!entry.isIntersecting) return;
          entry.target.classList.add("is-revealed");
          observer.unobserve(entry.target);
        });
      },
      { root: null, rootMargin: "0px 0px -12% 0px", threshold: 0.08 }
    );

    targets.forEach((el) => observer.observe(el));
    return () => observer.disconnect();
  }, []);
}