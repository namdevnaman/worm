import { useMemo } from "react";

/**
 * WORM BURROW — the hero scene.
 *
 * A cross-section of a filesystem rendered as geology. Each stratum is a real
 * path the product actually cleans; the debris is the reclaimable bytes; the
 * worm descends through them under an X-ray cone.
 *
 * This replaced a vendored "living green" Three.js scene whose own nav was a
 * dead `href="#"` dock belonging to a different product. The scene is pure
 * HTML/CSS/SVG: no WebGL payload, crisp type at any DPI, and every part of it
 * animates via `transform`/`opacity` so it stays cheap.
 *
 * All randomness is seeded. Unseeded `Math.random()` in render would reshuffle
 * the strata on every re-render, which reads as a glitch rather than a scene.
 */
function mulberry32(seed: number) {
  let a = seed;
  return () => {
    a |= 0;
    a = (a + 0x6d2b79f5) | 0;
    let t = Math.imul(a ^ (a >>> 15), 1 | a);
    t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}

interface Stratum {
  depth: string;
  path: string;
  label: string;
  bytes: string;
  /** Share of reclaimable bytes found at this depth, 0..1 */
  weight: number;
  /** Hue anchor for the debris tint. */
  tone: "accent" | "warn" | "ok";
}

const STRATA: readonly Stratum[] = [
  { depth: "0m", path: "/", label: "Volume Root", bytes: "0.4 GB", weight: 0.04, tone: "accent" },
  { depth: "18m", path: "/System/Library", label: "OS Frame", bytes: "3.1 GB", weight: 0.09, tone: "accent" },
  { depth: "41m", path: "/Applications", label: "App Bundles", bytes: "0.0 GB", weight: 0, tone: "ok" },
  { depth: "72m", path: "~/Library/Developer/Xcode", label: "DerivedData", bytes: "28.4 GB", weight: 0.34, tone: "accent" },
  { depth: "104m", path: "~/.docker/buildx", label: "Dangling Layers", bytes: "19.8 GB", weight: 0.28, tone: "warn" },
  { depth: "137m", path: "~/.npm + ~/.cargo", label: "Package Caches", bytes: "23.8 GB", weight: 0.25, tone: "accent" },
];

const WORM_SEGMENTS = 22;

export function WormBurrow() {
  const debris = useMemo(() => {
    const rand = mulberry32(0x5eed);
    return STRATA.map((stratum) => {
      // Weight drives how much debris a layer holds, so the deepest, fattest
      // caches read as the richest seams.
      const count = stratum.weight === 0 ? 0 : 3 + Math.round(stratum.weight * 16);
      return {
        id: stratum.path,
        items: Array.from({ length: count }, () => ({
          left: 6 + rand() * 88,
          width: 18 + rand() * 54,
          opacity: 0.18 + rand() * 0.34,
          delay: rand() * 4,
        })),
      };
    });
  }, []);

  const segPositions = useMemo(() => {
    /* A dense S-curve descent. The body has to be tight enough that the
       segments overlap into a continuous form — spaced further apart they
       read as a dotted line, not a worm. Amplitude is kept clear of the
       glass panel on the left. */
    return Array.from({ length: WORM_SEGMENTS }, (_, i) => {
      const t = i / (WORM_SEGMENTS - 1);
      const y = 10 + t * 72;
      const x = 68 + Math.sin(t * Math.PI * 2.3) * 17;
      return { x, y, scale: 1 - t * 0.45 };
    });
  }, []);

  return (
    <div className="burrow" aria-hidden="true">
      {/* Strata: alternating density so the section reads as depth, not stripes.
          All metadata sits on the right — the left half belongs to the glass
          panel, and labels running underneath it were being sliced mid-word. */}
      <div className="burrow__strata">
        {STRATA.map((stratum, i) => (
          <div
            key={stratum.path}
            className="stratum"
            data-tone={stratum.tone}
            data-empty={stratum.weight === 0}
            style={{ ["--depth" as string]: i }}
          >
            <div className="stratum__rule" />

            <div className="stratum__meta">
              <span className="stratum__depth">{stratum.depth}</span>
              <span className="stratum__path">{stratum.path}</span>
              {stratum.weight > 0 && (
                <>
                  <span className="stratum__bytes">{stratum.bytes}</span>
                  <span className="stratum__reclaim">
                    {Math.round(stratum.weight * 100)}% reclaimable
                  </span>
                </>
              )}
              {stratum.weight === 0 && <span className="stratum__reclaim">nothing to reclaim</span>}
            </div>

            <div className="stratum__debris">
              {debris[i].items.map((d, j) => (
                <span
                  key={j}
                  className="debris"
                  style={{
                    left: `${d.left}%`,
                    width: `${d.width}px`,
                    opacity: d.opacity,
                    animationDelay: `${d.delay}s`,
                  }}
                />
              ))}
            </div>
          </div>
        ))}
      </div>

      {/* X-ray cone sweeping the strata behind the worm */}
      <div className="burrow__xray" />

      {/* The worm: a head plus a tapering body, each segment phase-offset so
          the wave travels head-ward instead of the whole thing pulsing. */}
      <div className="worm">
        {segPositions.map((p, i) => (
          <span
            key={i}
            className="worm__seg"
            style={{
              left: `${p.x}%`,
              top: `${p.y}%`,
              /* Transforms are owned by the keyframes so the undulation can
                 run; scale and sway ride in as custom properties instead. */
              ["--sc" as string]: p.scale,
              ["--sway" as string]: `${5 + p.scale * 5}px`,
              ["--i" as string]: i,
            }}
          />
        ))}
        <span
          className="worm__head"
          style={{
            left: `${segPositions[segPositions.length - 1].x}%`,
            top: `${segPositions[segPositions.length - 1].y}%`,
          }}
        />
      </div>

      {/* Grain: fixed and non-scrolling so it never repaints during parallax */}
      <div className="burrow__grain" />
    </div>
  );
}

export default WormBurrow;