import { useEffect, useState } from "react";

/**
 * Tracks which section is currently under the header.
 *
 * Generic over the id type so callers keep their literal union instead of
 * widening to `string`.
 *
 * Uses IntersectionObserver against a band just below the header rather than
 * a scroll listener: no per-frame work, no layout thrash, and the browser
 * batches the callbacks. The header sits `var(--header-h)` tall, so the
 * detection band is offset to match — otherwise a section reads as "active"
 * while its title is still hidden behind the bar.
 */
export function useActiveSection<T extends string>(ids: readonly T[], offsetPx: number): T | null {
  const [active, setActive] = useState<T | null>(null);

  useEffect(() => {
    const elements = ids
      .map((id) => document.getElementById(id))
      .filter((el): el is HTMLElement => el !== null);

    if (elements.length === 0) return;

    // How far past the top of the band a section must travel to count.
    const activationLine = Math.max(offsetPx + 8, 120);

    const pick = () => {
      // The active section is the last one whose top has crossed the line.
      let current: T | null = null;
      for (const el of elements) {
        if (el.getBoundingClientRect().top - activationLine <= 0) {
          current = el.id as T;
        }
      }

      // At the very bottom of the page the last section can be shorter than
      // the activation line, so nothing ever crosses it. Pin it explicitly.
      const scrolledToEnd =
        window.innerHeight + window.scrollY >= document.body.scrollHeight - 2;
      if (scrolledToEnd) {
        current = elements[elements.length - 1].id as T;
      }

      setActive(current);
    };

    pick();

    const observer = new IntersectionObserver(pick, {
      // Band from the activation line down to the activation line + 1px:
      // fires whenever any section top crosses it.
      rootMargin: `-${activationLine}px 0px -${window.innerHeight - activationLine - 1}px 0px`,
      threshold: 0,
    });

    elements.forEach((el) => observer.observe(el));
    window.addEventListener("resize", pick, { passive: true });

    return () => {
      observer.disconnect();
      window.removeEventListener("resize", pick);
    };
  }, [ids, offsetPx]);

  return active;
}