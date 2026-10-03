import React, { useState, useRef, useEffect, useCallback } from "react";
import { SiteHeader } from "./components/SiteHeader";
import { WormBurrow } from "./components/WormBurrow";
import { useScrollReveal } from "./hooks/useScrollReveal";
import { REPO_URL, RELEASES_URL, SECTIONS, SOCIAL } from "./lib/nav";
import { FAQS } from "./lib/faqs";
import { APP_VERSION, LAST_UPDATED } from "./lib/site";
import {
  Download,
  Terminal,
  ShieldCheck,
  Zap,
  CheckCircle2,
  Copy,
  Check,
  ChevronDown,
  Layers,
  Sparkles,
  ExternalLink,
  Laptop,
  Cpu,
  HardDrive,
  EyeOff,
  Flame,
  FileCode,
  Scan,
  Activity,
  FolderSync,
  Trash2,
  Clock,
  CheckCheck,
  Package,
  Layers3,
  Search,
  RotateCcw,
  Gauge,
  Radar
} from "lucide-react";

function InstagramIcon({ size = 16 }: { size?: number }) {
  return (
    <svg
      width={size}
      height={size}
      viewBox="0 0 24 24"
      fill="none"
      stroke="currentColor"
      strokeWidth="2"
      strokeLinecap="round"
      strokeLinejoin="round"
      aria-hidden="true"
    >
      <rect x="2" y="2" width="20" height="20" rx="5" ry="5" />
      <path d="M16 11.37A4 4 0 1 1 12.63 8 4 4 0 0 1 16 11.37z" />
      <line x1="17.5" y1="6.5" x2="17.51" y2="6.5" />
    </svg>
  );
}

function GithubIcon({ size = 16 }: { size?: number }) {
  return (
    <svg width={size} height={size} viewBox="0 0 24 24" fill="currentColor">
      <path fillRule="evenodd" clipRule="evenodd" d="M12 2C6.477 2 2 6.484 2 12.017c0 4.425 2.865 8.18 6.839 9.504.5.092.682-.217.682-.483 0-.237-.008-.868-.013-1.703-2.782.605-3.369-1.343-3.369-1.343-.454-1.158-1.11-1.466-1.11-1.466-.908-.62.069-.608.069-.608 1.003.07 1.53 1.032 1.53 1.032.892 1.53 2.341 1.088 2.91.832.092-.647.35-1.088.636-1.338-2.22-.253-4.555-1.113-4.555-4.951 0-1.093.39-1.988 1.029-2.688-.103-.253-.446-1.272.098-2.65 0 0 .84-.27 2.75 1.026A9.564 9.564 0 0112 6.844c.85.004 1.705.115 2.504.337 1.909-1.296 2.747-1.027 2.747-1.027.546 1.379.202 2.398.1 2.651.64.7 1.028 1.595 1.028 2.688 0 3.848-2.339 4.695-4.566 4.943.359.309.678.92.678 1.855 0 1.338-.012 2.419-.012 2.747 0 .268.18.58.688.482A10.019 10.019 0 0022 12.017C22 6.484 17.522 2 12 2z" />
    </svg>
  );
}

export function App() {
  const [copiedInstall, setCopiedInstall] = useState(false);
  const [copiedSha, setCopiedSha] = useState<string | null>(null);
  const [activeFaq, setActiveFaq] = useState<number | null>(null);

  useScrollReveal();

  /* Retire the no-JS fallback once React has actually mounted.
     Leaving it in the DOM gave the page two <h1> elements: the static one and
     the real one. Removing it here (rather than eagerly at boot) means a failed
     bundle still leaves readable content for anyone without JavaScript. */
  useEffect(() => {
    document.querySelectorAll(".nojs-only").forEach((el) => el.remove());
  }, []);

  // The scan ticker is held in a ref and torn down on unmount. The previous
  // version leaked an interval that kept calling setState after the component
  // went away.
  const scanTimer = useRef<ReturnType<typeof setInterval> | null>(null);
  useEffect(
    () => () => {
      if (scanTimer.current) clearInterval(scanTimer.current);
    },
    []
  );

  // Interactive Live App Simulator States
  const [simState, setSimState] = useState<"idle" | "scanning" | "scanned" | "cleaned">("scanned");
  const [simProgress, setSimProgress] = useState(100);
  const [activeTab, setActiveTab] = useState<"scan" | "caches" | "leftovers" | "telemetry">("scan");
  const [activeTerminalTab, setActiveTerminalTab] = useState<"curl" | "brew" | "powershell" | "source">("curl");

  // Space estimation calculator states
  const [selectedTools, setSelectedTools] = useState<string[]>([
    "xcode", "npm", "docker", "homebrew", "cargo"
  ]);

  const toggleTool = (tool: string) => {
    if (selectedTools.includes(tool)) {
      setSelectedTools(selectedTools.filter((t) => t !== tool));
    } else {
      setSelectedTools([...selectedTools, tool]);
    }
  };

  const toolSizes: Record<string, number> = {
    xcode: 28.5,
    npm: 14.2,
    docker: 22.8,
    cargo: 9.6,
    homebrew: 7.4,
    gradle: 6.2,
    browsers: 4.8,
    leftovers: 8.5
  };

  const totalCalculatedSavings = selectedTools
    .reduce((sum, tool) => sum + (toolSizes[tool] || 0), 0)
    .toFixed(1);

  // Scanning simulation runner
  const runScanSimulation = useCallback(() => {
    if (scanTimer.current) clearInterval(scanTimer.current);

    setSimState("scanning");
    setSimProgress(0);

    let curr = 0;
    scanTimer.current = setInterval(() => {
      curr += 12;
      if (curr >= 100) {
        if (scanTimer.current) clearInterval(scanTimer.current);
        scanTimer.current = null;
        setSimProgress(100);
        setSimState("scanned");
      } else {
        setSimProgress(curr);
      }
    }, 180);
  }, []);

  const runCleanSimulation = useCallback(() => {
    setSimState("cleaned");
  }, []);

  const installCommands = {
    curl: "curl -fsSL https://raw.githubusercontent.com/namdevnaman/worm/main/scripts/install.sh | bash",
    brew: "brew tap namdevnaman/worm && brew install --cask worm",
    powershell: "irm https://raw.githubusercontent.com/namdevnaman/worm/main/scripts/install.ps1 | iex",
    source: "git clone https://github.com/namdevnaman/worm.git && cd worm && swift build -c release"
  };

  const copyToClipboard = (text: string, type: "install" | "sha", id?: string) => {
    navigator.clipboard.writeText(text);
    if (type === "install") {
      setCopiedInstall(true);
      setTimeout(() => setCopiedInstall(false), 2200);
    } else if (id) {
      setCopiedSha(id);
      setTimeout(() => setCopiedSha(null), 2200);
    }
  };

  const releases = [
    {
      os: "macOS",
      name: "Worm for macOS (Apple Silicon & Intel Universal)",
      version: "v1.0.4",
      filename: "Worm-Installer.dmg",
      type: "DMG Installer (Drag & Drop)",
      size: "3.8 MB",
      req: "macOS 14.0+ (Sonoma & Sequoia)",
      url: "https://github.com/namdevnaman/worm/releases/latest/download/Worm-Installer.dmg",
      secondaryUrl: "https://github.com/namdevnaman/worm/releases/latest/download/Worm-macOS.zip",
      secondaryLabel: "Portable .ZIP (3.1 MB)",
      sha: "e4a1fd13a4e6b377f8901c42c8102c93cd56d8a0f05a0b8601bfe426e1e6db70",
      badge: "Recommended for Mac",
      icon: "apple"
    },
    {
      os: "Windows",
      name: "Worm for Windows 10 / 11",
      version: "v1.0.4",
      filename: "Worm-Windows-x64.zip",
      type: "Standalone Zip (Native AOT)",
      size: "12.4 MB",
      req: "Windows 10 / 11 (64-bit)",
      url: "https://github.com/namdevnaman/worm/releases/latest/download/Worm-Windows-x64.zip",
      secondaryUrl: "https://github.com/namdevnaman/worm/releases/latest",
      secondaryLabel: "View Release Assets",
      sha: "0169d3282e79f2cb8c7ff386c379c4c6ad0f07d29efae5267fbae6d17147e6af",
      badge: "Native .NET 9 AOT",
      icon: "windows"
    }
  ];

  const simFoundItems = [
    { name: "Xcode DerivedData & Module Caches", path: "~/Library/Developer/Xcode/DerivedData", size: "28.4 GB", icon: FileCode, type: "Developer" },
    { name: "Docker Buildx Cache & Dangling Images", path: "~/.docker/buildx/refs", size: "19.8 GB", icon: HardDrive, type: "Containers" },
    { name: "npm & pnpm Global Cache Trees", path: "~/.npm/_cacache", size: "14.2 GB", icon: Package, type: "Package Manager" },
    { name: "Rust Cargo Shared Target Registry", path: "~/.cargo/registry/cache", size: "9.6 GB", icon: Cpu, type: "Compilers" },
    { name: "Slack & Electron Residual Datastores", path: "~/Library/Application Support/Slack/Cache", size: "4.1 GB", icon: Trash2, type: "Leftovers" }
  ];

  /* The remaining three simulator modules used to share one "Live Module
     Active" placeholder, so three of four sidebar buttons resolved to
     identical dead content. Each now has its own real payload. */

  const cacheBreakdown = [
    { name: "Xcode DerivedData", path: "~/Library/Developer/Xcode/DerivedData", size: "28.4 GB", pct: 100, icon: FileCode },
    { name: "Docker Buildx Layers", path: "~/.docker/buildx", size: "19.8 GB", pct: 70, icon: Layers },
    { name: "npm + pnpm Global", path: "~/.npm/_cacache", size: "14.2 GB", pct: 50, icon: Package },
    { name: "Cargo Registry Cache", path: "~/.cargo/registry/cache", size: "9.6 GB", pct: 34, icon: Cpu },
    { name: "Homebrew Downloads", path: "~/Library/Caches/Homebrew", size: "7.4 GB", pct: 26, icon: Download },
    { name: "Gradle + Maven", path: "~/.gradle/caches", size: "6.2 GB", pct: 22, icon: Layers3 }
  ];

  const ghostApps = [
    { app: "Sketch 2023.2", bundle: "com.bohemiancoding.sketch3", residue: "1.9 GB", age: "14 months", icon: Trash2 },
    { app: "Adobe Photoshop 2022", bundle: "com.adobe.Photoshop", residue: "3.4 GB", age: "22 months", icon: Trash2 },
    { app: "Spotify (old build)", bundle: "com.spotify.client", residue: "842 MB", age: "9 months", icon: Trash2 },
    { app: "TablePlus", bundle: "io.tableplusplus", residue: "310 MB", age: "11 months", icon: Trash2 },
    { app: "Postman (pre-9)", bundle: "com.getpostman.postman", residue: "1.2 GB", age: "31 months", icon: Trash2 }
  ];

  const hardwareTelemetry = [
    { label: "CPU Load", value: "0.4 %", detail: "idle in menu bar", pct: 4, tone: "ok" as const, icon: Cpu },
    { label: "Resident Memory", value: "12.8 MB", detail: "of 16 GB unified", pct: 0.8, tone: "ok" as const, icon: Activity },
    { label: "SSD Health", value: "99 %", detail: "1,412 power-on hours", pct: 99, tone: "ok" as const, icon: HardDrive },
    { label: "Free Space", value: "412 GB", detail: "of 994 GB capacity", pct: 41, tone: "warn" as const, icon: Gauge },
    { label: "Thermal Pressure", value: "Nominal", detail: "no throttling detected", pct: 8, tone: "ok" as const, icon: Radar }
  ];

  // Shared with the FAQPage JSON-LD in index.html — see src/lib/faqs.ts.
  const faqs = FAQS;

  return (
    <div style={{ backgroundColor: "var(--soil-void)", color: "var(--text-primary)" }}>
      {/* ── TOP ANNOUNCEMENT BAR ── */}
      <div
        className="announce"
        style={{
          background: "linear-gradient(90deg, #130f0d 0%, #201712 50%, #130f0d 100%)",
          borderBottom: "1px solid rgba(255, 255, 255, 0.08)",
          padding: "0.6rem 1rem",
          fontSize: "0.88rem",
          textAlign: "center",
          color: "var(--n-200)",
          display: "flex",
          alignItems: "center",
          justifyContent: "center",
          gap: "0.85rem",
          flexWrap: "wrap",
        }}
      >
        <span className="worm-badge" style={{ padding: "0.2rem 0.65rem", fontSize: "0.78rem" }}>
          <span className="dot dot--live" />
          Worm v1.0.4 Released
        </span>
        {/* Hidden below 600px — it repeated the page's own value proposition
            and was pushing the hero CTAs under the fold. */}
        <span className="announce__detail" style={{ color: "var(--ink)", fontWeight: 600 }}>
          Native macOS &amp; Windows deep disk cleaner • Zero telemetry • MIT Open Source
        </span>
        <a
          href={RELEASES_URL}
          target="_blank"
          rel="noopener noreferrer"
          style={{ color: "var(--worm-pink)", fontWeight: 700, textDecoration: "none", display: "inline-flex", alignItems: "center", gap: "0.3rem" }}
        >
          View Release Notes <ExternalLink size={13} />
        </a>
      </div>

      <SiteHeader />

      {/* ── HERO · WORM BURROW ──────────────────────────────────────────────
          Replaces the vendored "living green" ThreeUI scene. That scene shipped
          its own navigation — a dead `href="#"` dock for a different product —
          and its green clashed with the terracotta identity. This is the same
          idea built from the brand: a filesystem cross-section, a worm
          burrowing it, and glass instrumentation over the top.            */}
      <section id="hero-scene" className="hero">
        <WormBurrow />

        <div className="hero__inner">
          <div className="container">
            <div className="glass hero__panel reveal is-revealed">
              {/* One eyebrow, per the eyebrow-restraint rule. */}
              <div className="hero__eyebrow">
                <span className="worm-badge">
                  <span className="dot dot--live" />
                  Deep Cleaner · v1.0.4 · macOS &amp; Windows
                </span>
              </div>

              <h1 className="hero__title">
                {/* Names the product: an H1 that does not identify what the
                    page is about is a ranking signal left on the table. Kept
                    word-for-word identical to the H1 in index.html. */}
                Worm: your SSD is full of <em>dead</em> build residue.
              </h1>

              <p className="hero__lede">
                Worm burrows into the strata that actually fill your disk,
                then shows you every byte before it deletes.
              </p>

              <div className="hero__cta">
                <a className="btn-primary" href="#downloads">
                  <Download size={18} />
                  <span>Download Free</span>
                </a>
                <a className="btn-secondary" href="#interactive-demo">
                  <Sparkles size={17} color="var(--worm-pink)" />
                  <span>Live Demo</span>
                </a>
              </div>
            </div>
          </div>
        </div>

        {/* Instrumentation. Hidden below 1024px — the cross-section needs the
            horizontal room more than the readouts do. */}
        <div className="hero__hud">
          <div className="glass hud-row">
            <span className="hud-row__key">scan.depth</span>
            <span className="hud-row__val">137 m</span>
          </div>
          <div className="glass hud-row">
            <span className="hud-row__key">reclaimable</span>
            <span className="hud-row__val" style={{ color: "var(--worm-pink)" }}>76.1 GB</span>
          </div>
          <div className="glass hud-row">
            <span className="hud-row__key">active.projects</span>
            <span className="hud-row__val" style={{ color: "var(--moss-light)" }}>0</span>
          </div>
          <div className="glass hud-row">
            <span className="hud-row__key">telemetry.sent</span>
            <span className="hud-row__val">
              <span className="dot dot--ok" />
              0 bytes
            </span>
          </div>
        </div>
      </section>

      {/* ── INTERACTIVE LIVE APP SIMULATOR (HIGHLY ANIMATED & USEFUL) ── */}
      <section
        id="interactive-demo"
        style={{
          padding: "6rem 0",
          background: "linear-gradient(180deg, var(--soil-void) 0%, var(--soil-base) 100%)",
          borderBottom: "1px solid rgba(255, 255, 255, 0.08)",
          position: "relative",
        }}
      >
        <div className="container">
          <div className="section-head reveal">
            <span className="worm-badge" style={{ marginBottom: "0.85rem" }}>
              Interactive Live Simulator
            </span>
            <h2
              style={{
                fontFamily: "var(--font-lexend)",
                fontSize: "clamp(2rem, 3.8vw, 3rem)",
                fontWeight: 700,
                letterSpacing: "-0.03em",
                color: "#ffffff",
                marginBottom: "1rem",
              }}
            >
              See Worm In Action Before You Install
            </h2>
            <p style={{ color: "#ded3c5", fontSize: "1.1rem", lineHeight: 1.6 }}>
              Click below to test Worm&apos;s subterranean scanner in a live interactive simulator. Watch how it targets developer caches, uninstalled app ghosts, and SSD bloat.
            </p>
          </div>

          {/* Desktop App Window Frame */}
          <div
            className="soil-card-premium"
            style={{
              maxWidth: "1040px",
              margin: "0 auto",
              borderRadius: "20px",
              border: "1px solid rgba(244, 151, 142, 0.3)",
              boxShadow: "0 28px 80px rgba(0, 0, 0, 0.8), 0 0 40px rgba(224, 122, 95, 0.1)",
              overflow: "hidden",
            }}
          >
            {/* macOS Window Titlebar */}
            <div
              style={{
                background: "linear-gradient(90deg, #181310 0%, #201915 100%)",
                borderBottom: "1px solid rgba(255, 255, 255, 0.08)",
                padding: "0.85rem 1.25rem",
                display: "flex",
                alignItems: "center",
                justifyContent: "space-between",
              }}
            >
              {/* Traffic Lights */}
              <div style={{ display: "flex", alignItems: "center", gap: "0.5rem" }}>
                <span className="traffic-dot traffic-red" />
                <span className="traffic-dot traffic-yellow" />
                <span className="traffic-dot traffic-green" />
                <span style={{ marginLeft: "0.75rem", fontSize: "0.82rem", color: "#b5a899", fontFamily: "var(--font-mono)" }}>
                  Worm Cleaner — Native Swift 6.0 (Apple Silicon)
                </span>
              </div>

              {/* Menu Bar Telemetry Stats */}
              <div style={{ display: "flex", alignItems: "center", gap: "1rem", fontSize: "0.78rem", fontFamily: "var(--font-mono)" }}>
                <span style={{ color: "var(--moss-light)" }}><span className="dot dot--ok" />CPU: 0.4%</span>
                <span style={{ color: "var(--worm-pink)" }}>RAM: 12.8 MB</span>
                <span style={{ color: "var(--worm-amber)" }}>SSD Health: 99%</span>
              </div>
            </div>

            {/* Window Body Layout */}
            <div className="reveal" style={{ display: "grid", gridTemplateColumns: "repeat(auto-fit, minmax(280px, 1fr))", minHeight: "480px" }}>
              {/* Left Sidebar */}
              <div
                style={{
                  background: "#100d0a",
                  borderRight: "1px solid rgba(255, 255, 255, 0.06)",
                  padding: "1.5rem",
                  display: "flex",
                  flexDirection: "column",
                  justifyContent: "space-between",
                }}
              >
                <div>
                  <div style={{ fontSize: "0.75rem", fontWeight: 700, color: "#8a7e70", textTransform: "uppercase", letterSpacing: "0.08em", marginBottom: "1rem" }}>
                    Navigation
                  </div>

                  <div style={{ display: "flex", flexDirection: "column", gap: "0.45rem" }}>
                    {[
                      { id: "scan", label: "Deep System Scan", icon: Search },
                      { id: "caches", label: "Developer Caches", icon: FileCode },
                      { id: "leftovers", label: "Ghost App Hunter", icon: Trash2 },
                      { id: "telemetry", label: "Hardware Telemetry", icon: Activity }
                    ].map((tab) => {
                      const Icon = tab.icon;
                      const active = activeTab === tab.id;
                      return (
                        <button
                          key={tab.id}
                          onClick={() => setActiveTab(tab.id as any)}
                          style={{
                            background: active ? "rgba(224, 122, 95, 0.2)" : "transparent",
                            border: active ? "1px solid var(--worm-pink)" : "1px solid transparent",
                            borderRadius: "10px",
                            padding: "0.75rem 1rem",
                            display: "flex",
                            alignItems: "center",
                            gap: "0.75rem",
                            color: active ? "#ffffff" : "#ded3c5",
                            fontWeight: active ? 700 : 500,
                            fontSize: "0.9rem",
                            cursor: "pointer",
                            textAlign: "left",
                            transition: "all 0.2s",
                          }}
                        >
                          <Icon size={17} color={active ? "var(--worm-pink)" : "#8a7e70"} />
                          <span>{tab.label}</span>
                        </button>
                      );
                    })}
                  </div>
                </div>

                {/* Subterranean Health Card in Sidebar */}
                <div
                  style={{
                    background: "rgba(255, 255, 255, 0.03)",
                    borderRadius: "12px",
                    padding: "1rem",
                    border: "1px solid rgba(255, 255, 255, 0.08)",
                  }}
                >
                  <div style={{ display: "flex", alignItems: "center", gap: "0.5rem", marginBottom: "0.4rem" }}>
                    <ShieldCheck size={16} color="var(--moss-light)" />
                    <span style={{ fontSize: "0.82rem", fontWeight: 700, color: "#ffffff" }}>
                      Non-Destructive Mode
                    </span>
                  </div>
                  <p style={{ fontSize: "0.75rem", color: "#b5a899", lineHeight: 1.4 }}>
                    SIP Protected • Simulation Ready • Trash Fallback
                  </p>
                </div>
              </div>

              {/* Right Content Area */}
              <div style={{ padding: "2rem", display: "flex", flexDirection: "column", justifyContent: "space-between" }}>
                {activeTab === "scan" && (
                  <div>
                    <div style={{ display: "flex", justifyContent: "space-between", alignItems: "flex-start", marginBottom: "1.5rem" }}>
                      <div>
                        <h3 style={{ fontSize: "1.45rem", fontWeight: 800, color: "#ffffff", marginBottom: "0.3rem" }}>
                          Subterranean System Sweep
                        </h3>
                        <p style={{ color: "#b5a899", fontSize: "0.9rem" }}>
                          Targets disposable developer caches, build trees, and orphaned software databases.
                        </p>
                      </div>

                      {/* Interactive Trigger Button */}
                      <button
                        onClick={simState === "scanning" ? undefined : runScanSimulation}
                        disabled={simState === "scanning"}
                        className="btn-primary"
                        style={{ padding: "0.65rem 1.25rem", fontSize: "0.85rem" }}
                      >
                        {/* `animate-spin` was a Tailwind class in a project with
                            no Tailwind: the icon never moved during a scan. */}
                        <RotateCcw size={15} className={simState === "scanning" ? "anim-spin" : ""} />
                        <span>{simState === "scanning" ? "Scanning..." : "Re-Scan System"}</span>
                      </button>
                    </div>

                    {/* Progress Bar */}
                    <div style={{ marginBottom: "1.5rem" }}>
                      <div style={{ display: "flex", justifyContent: "space-between", fontSize: "0.8rem", marginBottom: "0.5rem", color: "#b5a899" }}>
                        <span>
                          {simState === "scanning" ? `Burrowing directories (${simProgress}%)...` : simState === "cleaned" ? "Cleanup Complete!" : "Scan Completed (76.1 GB Found)"}
                        </span>
                        <span style={{ fontWeight: 700, color: simState === "cleaned" ? "var(--moss-light)" : "var(--worm-pink)" }}>
                          {simProgress}%
                        </span>
                      </div>
                      <div style={{ height: "8px", background: "rgba(255,255,255,0.08)", borderRadius: "4px", overflow: "hidden" }}>
                        <div
                          style={{
                            height: "100%",
                            width: `${simProgress}%`,
                            background: simState === "cleaned" ? "linear-gradient(90deg, var(--moss-light), var(--moss-primary))" : "linear-gradient(90deg, #f4978e, #e07a5f)",
                            transition: "width 0.2s ease",
                            boxShadow: "0 0 12px rgba(224, 122, 95, 0.5)",
                          }}
                        />
                      </div>
                    </div>

                    {/* List of Detected Cleanable Items */}
                    <div style={{ display: "flex", flexDirection: "column", gap: "0.75rem", marginBottom: "2rem" }}>
                      {simFoundItems.map((item, idx) => {
                        const Icon = item.icon;
                        return (
                          <div
                            key={idx}
                            style={{
                              background: "rgba(255, 255, 255, 0.03)",
                              border: "1px solid rgba(255, 255, 255, 0.06)",
                              borderRadius: "10px",
                              padding: "0.85rem 1.15rem",
                              display: "flex",
                              alignItems: "center",
                              justifyContent: "space-between",
                            }}
                          >
                            <div style={{ display: "flex", alignItems: "center", gap: "0.85rem" }}>
                              <div style={{ padding: "0.45rem", borderRadius: "8px", background: "rgba(224, 122, 95, 0.12)", color: "var(--worm-pink)" }}>
                                <Icon size={16} />
                              </div>
                              <div>
                                <div style={{ fontSize: "0.92rem", fontWeight: 700, color: "#ffffff" }}>
                                  {item.name}
                                </div>
                                <div style={{ fontSize: "0.75rem", color: "#8a7e70", fontFamily: "var(--font-mono)" }}>
                                  {item.path}
                                </div>
                              </div>
                            </div>
                            <div style={{ textAlign: "right" }}>
                              <span style={{ fontSize: "0.95rem", fontWeight: 800, color: simState === "cleaned" ? "var(--moss-light)" : "var(--worm-pink)" }}>
                                {simState === "cleaned" ? "0 MB (Purged)" : item.size}
                              </span>
                            </div>
                          </div>
                        );
                      })}
                    </div>

                    {/* Bottom Action Footer */}
                    <div
                      style={{
                        background: "linear-gradient(90deg, rgba(224, 122, 95, 0.15) 0%, rgba(200, 90, 67, 0.08) 100%)",
                        border: "1px solid rgba(244, 151, 142, 0.3)",
                        borderRadius: "14px",
                        padding: "1.25rem 1.5rem",
                        display: "flex",
                        alignItems: "center",
                        justifyContent: "space-between",
                        flexWrap: "wrap",
                        gap: "1rem",
                      }}
                    >
                      <div>
                        <div style={{ fontSize: "1.15rem", fontWeight: 800, color: "#ffffff" }}>
                          {simState === "cleaned" ? "System Purged Successfully!" : "76.1 GB Total Storage Recoverable"}
                        </div>
                        <div style={{ fontSize: "0.82rem", color: "#ded3c5" }}>
                          {simState === "cleaned" ? "All build artifacts safely recycled in 1.4s" : "Zero active checkouts or documents will be impacted"}
                        </div>
                      </div>

                      {simState !== "cleaned" ? (
                        <button
                          onClick={runCleanSimulation}
                          className="btn-primary"
                          style={{ padding: "0.8rem 1.6rem", fontSize: "0.95rem" }}
                        >
                          <Trash2 size={16} />
                          <span>Purge 76.1 GB Junk</span>
                        </button>
                      ) : (
                        <div style={{ display: "inline-flex", alignItems: "center", gap: "0.5rem", color: "var(--moss-light)", fontWeight: 700 }}>
                          <CheckCheck size={20} />
                          <span>Purged!</span>
                        </div>
                      )}
                    </div>
                  </div>
                )}

                {/* ── Developer Caches ─────────────────────────────────── */}
                {activeTab === "caches" && (
                  <div>
                    <h3 style={{ fontSize: "1.35rem", fontWeight: 800, color: "var(--ink)", marginBottom: "0.3rem" }}>
                      Developer Cache Breakdown
                    </h3>
                    <p style={{ color: "var(--ink-muted)", fontSize: "0.9rem", marginBottom: "1.5rem" }}>
                      Ranked by reclaimable bytes. Every entry is a rebuildable
                      artefact — none of it is source.
                    </p>

                    <div style={{ display: "flex", flexDirection: "column", gap: "1rem" }}>
                      {cacheBreakdown.map((row) => {
                        const Icon = row.icon;
                        return (
                          <div key={row.name}>
                            <div style={{ display: "flex", alignItems: "center", justifyContent: "space-between", gap: "0.75rem", marginBottom: "0.4rem" }}>
                              <span style={{ display: "flex", alignItems: "center", gap: "0.6rem", fontSize: "0.9rem", fontWeight: 600, color: "var(--ink-body)" }}>
                                <Icon size={15} color="var(--accent-bright)" />
                                {row.name}
                              </span>
                              <span style={{ fontFamily: "var(--font-mono)", fontSize: "0.85rem", fontWeight: 700, color: "var(--accent-bright)" }}>
                                {row.size}
                              </span>
                            </div>
                            <div className="meter">
                              <div className="meter__fill" style={{ width: `${row.pct}%` }} />
                            </div>
                            <div style={{ fontFamily: "var(--font-mono)", fontSize: "0.7rem", color: "var(--text-faint)", marginTop: "0.3rem" }}>
                              {row.path}
                            </div>
                          </div>
                        );
                      })}
                    </div>
                  </div>
                )}

                {/* ── Ghost App Hunter ──────────────────────────────────── */}
                {activeTab === "leftovers" && (
                  <div>
                    <h3 style={{ fontSize: "1.35rem", fontWeight: 800, color: "var(--ink)", marginBottom: "0.3rem" }}>
                      Orphaned Bundle Identifiers
                    </h3>
                    <p style={{ color: "var(--ink-muted)", fontSize: "0.9rem", marginBottom: "1.5rem" }}>
                      Applications you removed, matched to the support
                      databases they left behind.
                    </p>

                    <div style={{ display: "flex", flexDirection: "column", gap: "0.7rem" }}>
                      {ghostApps.map((ghost) => {
                        const Icon = ghost.icon;
                        return (
                          <div
                            key={ghost.bundle}
                            style={{
                              display: "flex",
                              alignItems: "center",
                              justifyContent: "space-between",
                              gap: "1rem",
                              padding: "0.8rem 1rem",
                              borderRadius: "var(--r-sm)",
                              background: "rgba(255, 255, 255, 0.03)",
                              border: "1px solid var(--border-subtle)",
                            }}
                          >
                            <span style={{ display: "flex", alignItems: "center", gap: "0.75rem", minWidth: 0 }}>
                              <Icon size={16} color="var(--worm-amber)" style={{ flexShrink: 0 }} />
                              <span style={{ minWidth: 0 }}>
                                <span style={{ display: "block", fontSize: "0.9rem", fontWeight: 700, color: "var(--ink)" }}>
                                  {ghost.app}
                                </span>
                                <span style={{ display: "block", fontFamily: "var(--font-mono)", fontSize: "0.7rem", color: "var(--text-faint)", overflow: "hidden", textOverflow: "ellipsis", whiteSpace: "nowrap" }}>
                                  {ghost.bundle}
                                </span>
                              </span>
                            </span>
                            <span style={{ textAlign: "right", flexShrink: 0 }}>
                              <span style={{ display: "block", fontFamily: "var(--font-mono)", fontSize: "0.85rem", fontWeight: 700, color: "var(--worm-amber)" }}>
                                {ghost.residue}
                              </span>
                              <span style={{ display: "block", fontSize: "0.68rem", color: "var(--text-faint)" }}>
                                gone {ghost.age}
                              </span>
                            </span>
                          </div>
                        );
                      })}
                    </div>

                    <p style={{ marginTop: "1.25rem", fontSize: "0.78rem", color: "var(--text-faint)", lineHeight: 1.55 }}>
                      Worm never touches an application that is still installed.
                      The bundle list above was read from Launch Services and
                      cross-checked against every running process.
                    </p>
                  </div>
                )}

                {/* ── Hardware Telemetry ────────────────────────────────── */}
                {activeTab === "telemetry" && (
                  <div>
                    <h3 style={{ fontSize: "1.35rem", fontWeight: 800, color: "var(--ink)", marginBottom: "0.3rem" }}>
                      Live Hardware Telemetry
                    </h3>
                    <p style={{ color: "var(--ink-muted)", fontSize: "0.9rem", marginBottom: "1.5rem" }}>
                      Read from the kernel in-process. No agent, no daemon, no
                      network call.
                    </p>

                    <div style={{ display: "grid", gridTemplateColumns: "repeat(auto-fit, minmax(210px, 1fr))", gap: "0.85rem" }}>
                      {hardwareTelemetry.map((metric) => {
                        const Icon = metric.icon;
                        const ok = metric.tone === "ok";
                        return (
                          <div
                            key={metric.label}
                            className="soil-glass"
                            style={{ padding: "1rem", borderRadius: "var(--r-md)" }}
                          >
                            <div style={{ display: "flex", alignItems: "center", gap: "0.5rem", marginBottom: "0.5rem" }}>
                              <Icon size={15} color={ok ? "var(--moss-light)" : "var(--worm-amber)"} />
                              <span style={{ fontSize: "0.78rem", fontWeight: 700, color: "var(--ink-muted)" }}>
                                {metric.label}
                              </span>
                            </div>
                            <div
                              style={{
                                fontFamily: "var(--font-mono)",
                                fontSize: "1.25rem",
                                fontWeight: 700,
                                color: ok ? "var(--moss-light)" : "var(--worm-amber)",
                                marginBottom: "0.6rem",
                              }}
                            >
                              {metric.value}
                            </div>
                            <div className="meter" style={{ height: "4px", marginBottom: "0.5rem" }}>
                              <div
                                className="meter__fill"
                                style={{
                                  width: `${Math.max(metric.pct, 2)}%`,
                                  background: ok
                                    ? "linear-gradient(90deg, var(--g-300), var(--g-500))"
                                    : "linear-gradient(90deg, var(--w-300), var(--w-500))",
                                  boxShadow: "none",
                                }}
                              />
                            </div>
                            <div style={{ fontSize: "0.7rem", color: "var(--text-faint)" }}>{metric.detail}</div>
                          </div>
                        );
                      })}
                    </div>
                  </div>
                )}
              </div>
            </div>
          </div>
        </div>
      </section>

      {/* ── DOWNLOAD MATRIX SECTION ── */}
      <section
        id="downloads"
        style={{
          padding: "6rem 0 5rem",
          background: "var(--soil-base)",
          borderBottom: "1px solid rgba(255, 255, 255, 0.08)",
        }}
      >
        <div className="container">
          <div className="section-head reveal">
            <span className="worm-badge" style={{ marginBottom: "0.85rem" }}>
              Official Binaries
            </span>
            <h2
              style={{
                fontFamily: "var(--font-lexend)",
                fontSize: "clamp(2rem, 3.8vw, 3rem)",
                fontWeight: 700,
                letterSpacing: "-0.03em",
                color: "#ffffff",
                marginBottom: "1rem",
              }}
            >
              Get Worm for macOS &amp; Windows
            </h2>
            <p style={{ color: "#ded3c5", fontSize: "1.1rem", lineHeight: 1.6 }}>
              Direct binaries compiled with full compiler optimizations. Free forever, self-contained, no bloatware or background daemons.
            </p>
          </div>

          <div className="reveal"
            style={{
              display: "grid",
              gridTemplateColumns: "repeat(auto-fit, minmax(340px, 1fr))",
              gap: "2.5rem",
              marginBottom: "3.5rem",
            }}
          >
            {releases.map((rel) => (
              <div
                key={rel.os}
                className="soil-card-premium"
                style={{
                  display: "flex",
                  flexDirection: "column",
                  justifyContent: "space-between",
                  padding: "2.5rem",
                }}
              >
                <div>
                  <div style={{ display: "flex", justifyContent: "space-between", alignItems: "flex-start", marginBottom: "1.75rem" }}>
                    <div style={{ display: "flex", alignItems: "center", gap: "1rem" }}>
                      <div
                        style={{
                          width: "56px",
                          height: "56px",
                          borderRadius: "16px",
                          background: "rgba(224, 122, 95, 0.15)",
                          border: "1px solid rgba(224, 122, 95, 0.35)",
                          display: "flex",
                          alignItems: "center",
                          justifyContent: "center",
                          color: "var(--worm-pink)",
                          boxShadow: "0 0 20px rgba(224, 122, 95, 0.2)",
                        }}
                      >
                        {rel.icon === "apple" ? <Laptop size={28} /> : <HardDrive size={28} />}
                      </div>
                      <div>
                        <h3 style={{ fontSize: "1.35rem", fontWeight: 800, color: "#ffffff" }}>
                          {rel.os}
                        </h3>
                        <div style={{ fontSize: "0.84rem", color: "#b5a899", fontWeight: 600 }}>
                          {rel.version} • {rel.type}
                        </div>
                      </div>
                    </div>
                    <span className="worm-badge" style={{ fontSize: "0.75rem" }}>
                      {rel.badge}
                    </span>
                  </div>

                  <p style={{ color: "#ded3c5", fontSize: "1rem", lineHeight: 1.65, marginBottom: "1.5rem" }}>
                    {rel.name}. Native performance with zero background battery drain.
                  </p>

                  <div
                    style={{
                      background: "#0a0807",
                      borderRadius: "14px",
                      padding: "1.1rem",
                      fontSize: "0.9rem",
                      marginBottom: "1.75rem",
                      border: "1px solid rgba(255, 255, 255, 0.08)",
                    }}
                  >
                    <div style={{ display: "flex", justifyContent: "space-between", marginBottom: "0.6rem" }}>
                      <span style={{ color: "#b5a899" }}>Requirement:</span>
                      <span style={{ color: "#ffffff", fontWeight: 600 }}>{rel.req}</span>
                    </div>
                    <div style={{ display: "flex", justifyContent: "space-between", marginBottom: "0.6rem" }}>
                      <span style={{ color: "#b5a899" }}>Download Size:</span>
                      <span style={{ color: "#ffffff", fontWeight: 600 }}>{rel.size}</span>
                    </div>
                    <div style={{ display: "flex", justifyContent: "space-between" }}>
                      <span style={{ color: "#b5a899" }}>Artifact:</span>
                      <span style={{ color: "var(--worm-pink)", fontFamily: "var(--font-mono)", fontSize: "0.85rem", fontWeight: 700 }}>
                        {rel.filename}
                      </span>
                    </div>
                  </div>
                </div>

                <div>
                  <div style={{ display: "flex", flexDirection: "column", gap: "0.85rem", marginBottom: "1.25rem" }}>
                    <a
                      href={rel.url}
                      className="btn-primary"
                      style={{ width: "100%", padding: "1rem" }}
                    >
                      <Download size={19} />
                      <span>Download {rel.filename}</span>
                    </a>

                    <a
                      href={rel.secondaryUrl}
                      className="btn-secondary"
                      style={{ width: "100%", fontSize: "0.9rem", padding: "0.8rem 1rem" }}
                    >
                      <span>{rel.secondaryLabel}</span>
                    </a>
                  </div>

                  {/* SHA-256 Checksum block with copy */}
                  <div
                    style={{
                      padding: "0.75rem 0.95rem",
                      background: "#080706",
                      border: "1px solid rgba(255, 255, 255, 0.08)",
                      borderRadius: "10px",
                      fontSize: "0.78rem",
                      fontFamily: "var(--font-mono)",
                      color: "#b5a899",
                      display: "flex",
                      alignItems: "center",
                      justifyContent: "space-between",
                      gap: "0.5rem",
                    }}
                  >
                    {/* Deliberately elided — a 64-char hash cannot fit a card. The full digest
                        stays reachable via the title and the copy button. */}
                    <span
                      title={rel.sha}
                      style={{ overflow: "hidden", textOverflow: "ellipsis", whiteSpace: "nowrap" }}
                    >
                      SHA256: {rel.sha.substring(0, 16)}...{rel.sha.substring(rel.sha.length - 8)}
                    </span>
                    <button
                      onClick={() => copyToClipboard(rel.sha, "sha", rel.os)}
                      style={{
                        background: "transparent",
                        border: "none",
                        color: copiedSha === rel.os ? "var(--moss-light)" : "var(--worm-pink)",
                        cursor: "pointer",
                        display: "flex",
                        alignItems: "center",
                        gap: "0.3rem",
                        fontSize: "0.78rem",
                        fontWeight: 700,
                      }}
                    >
                      {copiedSha === rel.os ? <Check size={14} /> : <Copy size={14} />}
                      <span>{copiedSha === rel.os ? "Copied" : "Copy"}</span>
                    </button>
                  </div>
                </div>
              </div>
            ))}
          </div>

          {/* Interactive Terminal Install Tabs */}
          <div
            className="soil-card-premium"
            style={{
              padding: "2.5rem",
              borderRadius: "20px",
            }}
          >
            <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center", flexWrap: "wrap", gap: "1rem", marginBottom: "1.5rem" }}>
              <div style={{ display: "flex", alignItems: "center", gap: "0.75rem" }}>
                <Terminal size={24} color="var(--worm-pink)" />
                <div>
                  <h3 style={{ fontSize: "1.3rem", fontWeight: 700, color: "#ffffff" }}>
                    Developer CLI &amp; Package Managers
                  </h3>
                  <p style={{ color: "#b5a899", fontSize: "0.9rem" }}>
                    Install Worm directly through your favorite terminal shell or build from source:
                  </p>
                </div>
              </div>

              {/* Terminal Tabs */}
              <div style={{ display: "flex", gap: "0.4rem", background: "#0a0807", padding: "0.3rem", borderRadius: "10px", border: "1px solid rgba(255,255,255,0.08)" }}>
                {[
                  { id: "curl", label: "cURL (macOS)" },
                  { id: "brew", label: "Homebrew" },
                  { id: "powershell", label: "PowerShell (Win)" },
                  { id: "source", label: "Swift Source" }
                ].map((t) => (
                  <button
                    key={t.id}
                    onClick={() => setActiveTerminalTab(t.id as any)}
                    style={{
                      background: activeTerminalTab === t.id ? "rgba(224, 122, 95, 0.25)" : "transparent",
                      color: activeTerminalTab === t.id ? "#ffffff" : "#ad9f90",
                      border: activeTerminalTab === t.id ? "1px solid var(--worm-pink)" : "1px solid transparent",
                      borderRadius: "8px",
                      padding: "0.35rem 0.75rem",
                      fontSize: "0.8rem",
                      fontWeight: 600,
                      cursor: "pointer",
                      transition: "all 0.2s",
                    }}
                  >
                    {t.label}
                  </button>
                ))}
              </div>
            </div>

            <div
              style={{
                background: "#080605",
                borderRadius: "14px",
                padding: "1.1rem 1.4rem",
                border: "1px solid rgba(255, 255, 255, 0.1)",
                display: "flex",
                alignItems: "center",
                justifyContent: "space-between",
                fontFamily: "var(--font-mono)",
                fontSize: "0.95rem",
              }}
            >
              <div style={{ display: "flex", alignItems: "center", gap: "0.75rem", overflowX: "auto" }}>
                <span style={{ color: "var(--worm-pink)", fontWeight: 700 }}>$</span>
                <span style={{ color: "#f5efe6", whiteSpace: "nowrap" }}>{installCommands[activeTerminalTab]}</span>
              </div>

              <button
                onClick={() => copyToClipboard(installCommands[activeTerminalTab], "install")}
                className="btn-secondary"
                style={{ padding: "0.55rem 1rem", fontSize: "0.82rem", flexShrink: 0 }}
              >
                {copiedInstall ? <Check size={15} color="var(--moss-light)" /> : <Copy size={15} />}
                <span>{copiedInstall ? "Copied!" : "Copy"}</span>
              </button>
            </div>
          </div>
        </div>
      </section>

      {/* ── CORE SUBTERRANEAN FEATURES ── */}
      <section
        id="features"
        style={{
          padding: "6rem 0",
          background: "var(--soil-void)",
          borderBottom: "1px solid rgba(255, 255, 255, 0.08)",
        }}
      >
        <div className="container">
          <div className="section-head reveal">
            <span className="moss-badge" style={{ marginBottom: "0.85rem" }}>
              Engineered Subterranean Mechanics
            </span>
            <h2
              style={{
                fontFamily: "var(--font-lexend)",
                fontSize: "clamp(2rem, 3.8vw, 3rem)",
                fontWeight: 700,
                letterSpacing: "-0.03em",
                color: "#ffffff",
                marginBottom: "1rem",
              }}
            >
              Where Commercial Cleaners Stop, Worm Begins.
            </h2>
            <p style={{ color: "#ded3c5", fontSize: "1.1rem", lineHeight: 1.65 }}>
              Most cleaners only sweep surface-level browser cookies. Worm is tuned for software engineers, power users, and creators whose SSDs are suffocated by heavy build artifacts.
            </p>
          </div>

          <div className="reveal"
            style={{
              display: "grid",
              gridTemplateColumns: "repeat(auto-fit, minmax(340px, 1fr))",
              gap: "2.5rem",
            }}
          >
            {/* Feature 1 */}
            <div className="soil-card-premium" style={{ padding: "2.5rem" }}>
              <div
                style={{
                  width: "56px",
                  height: "56px",
                  borderRadius: "16px",
                  background: "rgba(224, 122, 95, 0.15)",
                  border: "1px solid rgba(224, 122, 95, 0.35)",
                  display: "flex",
                  alignItems: "center",
                  justifyContent: "center",
                  color: "var(--worm-pink)",
                  marginBottom: "1.75rem",
                  boxShadow: "0 0 20px rgba(224, 122, 95, 0.2)",
                }}
              >
                <FileCode size={28} />
              </div>
              <h3 style={{ fontSize: "1.4rem", fontWeight: 800, color: "#ffffff", marginBottom: "0.85rem" }}>
                Developer Cache Burrower
              </h3>
              <p style={{ color: "#ded3c5", lineHeight: 1.7, fontSize: "1rem", marginBottom: "1.5rem" }}>
                Deep-scans and purges massive developer build residue: <strong>Xcode DerivedData</strong>, simulator runtime logs, <strong>npm &amp; pnpm</strong> global caches, <strong>Cargo</strong> target trees, <strong>Homebrew</strong> downloads, <strong>Gradle / Maven</strong> wrappers, and Go module build files.
              </p>
              <div style={{ display: "flex", gap: "0.5rem", flexWrap: "wrap" }}>
                <span className="worm-badge">Xcode 30GB+</span>
                <span className="worm-badge">Docker Layers</span>
                <span className="worm-badge">npm / Cargo</span>
              </div>
            </div>

            {/* Feature 2 */}
            <div className="soil-card-premium" style={{ padding: "2.5rem" }}>
              <div
                style={{
                  width: "56px",
                  height: "56px",
                  borderRadius: "16px",
                  background: "rgba(85, 120, 73, 0.18)",
                  border: "1px solid rgba(125, 165, 114, 0.4)",
                  display: "flex",
                  alignItems: "center",
                  justifyContent: "center",
                  color: "var(--moss-light)",
                  marginBottom: "1.75rem",
                  boxShadow: "0 0 20px rgba(85, 120, 73, 0.2)",
                }}
              >
                <Layers size={28} />
              </div>
              <h3 style={{ fontSize: "1.4rem", fontWeight: 800, color: "#ffffff", marginBottom: "0.85rem" }}>
                Ghost App &amp; Leftover Hunter
              </h3>
              <p style={{ color: "#ded3c5", lineHeight: 1.7, fontSize: "1rem", marginBottom: "1.5rem" }}>
                Deleting an app never cleans its roots. Worm tracks down orphaned support databases in <code>~/Library/Application Support</code>, preferences plists, application caches, and Windows AppData/Registry orphans left by deleted software.
              </p>
              <div style={{ display: "flex", gap: "0.5rem", flexWrap: "wrap" }}>
                <span className="moss-badge">Orphan Detection</span>
                <span className="moss-badge">Zero Residue</span>
              </div>
            </div>

            {/* Feature 3 */}
            <div className="soil-card-premium" style={{ padding: "2.5rem" }}>
              <div
                style={{
                  width: "56px",
                  height: "56px",
                  borderRadius: "16px",
                  background: "rgba(212, 163, 115, 0.18)",
                  border: "1px solid rgba(212, 163, 115, 0.4)",
                  display: "flex",
                  alignItems: "center",
                  justifyContent: "center",
                  color: "var(--worm-amber)",
                  marginBottom: "1.75rem",
                  boxShadow: "0 0 20px rgba(212, 163, 115, 0.2)",
                }}
              >
                <Cpu size={28} />
              </div>
              <h3 style={{ fontSize: "1.4rem", fontWeight: 800, color: "#ffffff", marginBottom: "0.85rem" }}>
                Live Menu Bar / Tray Monitor
              </h3>
              <p style={{ color: "#ded3c5", lineHeight: 1.7, fontSize: "1rem", marginBottom: "1.5rem" }}>
                Keeps a vigilant eye on your system from the macOS menu bar or Windows tray. Shows real-time CPU per-core load, memory pressure, active swap, SSD write endurance, and thermal zones without taxing your battery.
              </p>
              <div style={{ display: "flex", gap: "0.5rem", flexWrap: "wrap" }}>
                <span className="worm-badge">Real-time Stats</span>
                <span className="worm-badge">Sub-15MB RAM</span>
              </div>
            </div>

            {/* Feature 4 */}
            <div className="soil-card-premium" style={{ padding: "2.5rem" }}>
              <div
                style={{
                  width: "56px",
                  height: "56px",
                  borderRadius: "16px",
                  background: "rgba(85, 120, 73, 0.18)",
                  border: "1px solid rgba(125, 165, 114, 0.4)",
                  display: "flex",
                  alignItems: "center",
                  justifyContent: "center",
                  color: "var(--moss-light)",
                  marginBottom: "1.75rem",
                  boxShadow: "0 0 20px rgba(85, 120, 73, 0.2)",
                }}
              >
                <ShieldCheck size={28} />
              </div>
              <h3 style={{ fontSize: "1.4rem", fontWeight: 800, color: "#ffffff", marginBottom: "0.85rem" }}>
                100% Zero Telemetry
              </h3>
              <p style={{ color: "#ded3c5", lineHeight: 1.7, fontSize: "1rem", marginBottom: "1.5rem" }}>
                No tracking tokens, no Google Analytics, no phone-home servers, no user profiling. Worm is completely offline during its operations. What happens on your machine stays on your machine.
              </p>
              <div style={{ display: "flex", gap: "0.5rem", flexWrap: "wrap" }}>
                <span className="moss-badge">Air-Gap Safe</span>
                <span className="moss-badge">No Cloud Logs</span>
              </div>
            </div>

            {/* Feature 5 */}
            <div className="soil-card-premium" style={{ padding: "2.5rem" }}>
              <div
                style={{
                  width: "56px",
                  height: "56px",
                  borderRadius: "16px",
                  background: "rgba(224, 122, 95, 0.15)",
                  border: "1px solid rgba(224, 122, 95, 0.35)",
                  display: "flex",
                  alignItems: "center",
                  justifyContent: "center",
                  color: "var(--worm-pink)",
                  marginBottom: "1.75rem",
                  boxShadow: "0 0 20px rgba(224, 122, 95, 0.2)",
                }}
              >
                <Flame size={28} />
              </div>
              <h3 style={{ fontSize: "1.4rem", fontWeight: 800, color: "#ffffff", marginBottom: "0.85rem" }}>
                Simulation &amp; Safe Dry Runs
              </h3>
              <p style={{ color: "#ded3c5", lineHeight: 1.7, fontSize: "1rem", marginBottom: "1.5rem" }}>
                Never fear unintended deletions. Worm provides an interactive Dry Run preview showing exact byte counts, directory paths, and file ages before any action is executed. Supports system trash rollback.
              </p>
              <div style={{ display: "flex", gap: "0.5rem", flexWrap: "wrap" }}>
                <span className="worm-badge">Dry Run Mode</span>
                <span className="worm-badge">Trash Rollback</span>
              </div>
            </div>

            {/* Feature 6 */}
            <div className="soil-card-premium" style={{ padding: "2.5rem" }}>
              <div
                style={{
                  width: "56px",
                  height: "56px",
                  borderRadius: "16px",
                  background: "rgba(212, 163, 115, 0.18)",
                  border: "1px solid rgba(212, 163, 115, 0.4)",
                  display: "flex",
                  alignItems: "center",
                  justifyContent: "center",
                  color: "var(--worm-amber)",
                  marginBottom: "1.75rem",
                  boxShadow: "0 0 20px rgba(212, 163, 115, 0.2)",
                }}
              >
                <Zap size={28} />
              </div>
              <h3 style={{ fontSize: "1.4rem", fontWeight: 800, color: "#ffffff", marginBottom: "0.85rem" }}>
                Pure Native Swift &amp; .NET 9
              </h3>
              <p style={{ color: "#ded3c5", lineHeight: 1.7, fontSize: "1rem", marginBottom: "1.5rem" }}>
                Zero Chromium overhead. Worm is hand-coded in pure Swift 6 with SwiftUI on macOS, and C# with .NET 9 Native AOT on Windows. Instant startup in 80 milliseconds.
              </p>
              <div style={{ display: "flex", gap: "0.5rem", flexWrap: "wrap" }}>
                <span className="worm-badge">No Electron</span>
                <span className="worm-badge">80ms Startup</span>
              </div>
            </div>
          </div>
        </div>
      </section>

      {/* ── INTERACTIVE SPACE SAVINGS CALCULATOR ── */}
      <section
        id="calculator"
        style={{
          padding: "6rem 0",
          background: "linear-gradient(180deg, var(--soil-void) 0%, var(--soil-base) 100%)",
          borderBottom: "1px solid rgba(255, 255, 255, 0.08)",
        }}
      >
        <div className="container">
          <div
            className="soil-card-premium"
            style={{
              padding: "clamp(2.5rem, 5vw, 4rem)",
              border: "1px solid rgba(244, 151, 142, 0.35)",
            }}
          >
            <div className="reveal" style={{ display: "grid", gridTemplateColumns: "repeat(auto-fit, minmax(320px, 1fr))", gap: "3.5rem", alignItems: "center" }}>
              <div>
                <span className="worm-badge" style={{ marginBottom: "0.85rem" }}>
                  Interactive Storage Estimator
                </span>
                <h2
                  style={{
                    fontFamily: "var(--font-lexend)",
                    fontSize: "clamp(2rem, 3.4vw, 2.75rem)",
                    fontWeight: 700,
                    letterSpacing: "-0.03em",
                    color: "#ffffff",
                    marginBottom: "1rem",
                  }}
                >
                  Estimate Your Recoverable Storage
                </h2>
                <p style={{ color: "#ded3c5", fontSize: "1.05rem", lineHeight: 1.65, marginBottom: "2.2rem" }}>
                  Select the toolchains, runtimes, and developer environments you use. Worm burrows into their hidden caches to reclaim lost storage.
                </p>

                {/* Tool Selection Grid */}
                <div style={{ display: "grid", gridTemplateColumns: "repeat(2, 1fr)", gap: "1rem" }}>
                  {[
                    { id: "xcode", label: "Xcode & Simulators", est: "~28.5 GB" },
                    { id: "npm", label: "npm / Yarn / pnpm", est: "~14.2 GB" },
                    { id: "docker", label: "Docker Unused Layers", est: "~22.8 GB" },
                    { id: "cargo", label: "Rust & Cargo Targets", est: "~9.6 GB" },
                    { id: "homebrew", label: "Homebrew Caches", est: "~7.4 GB" },
                    { id: "gradle", label: "Gradle & Maven Caches", est: "~6.2 GB" },
                    { id: "browsers", label: "Browser Shards", est: "~4.8 GB" },
                    { id: "leftovers", label: "App Leftovers", est: "~8.5 GB" },
                  ].map((tool) => {
                    const active = selectedTools.includes(tool.id);
                    return (
                      <button
                        key={tool.id}
                        onClick={() => toggleTool(tool.id)}
                        style={{
                          background: active ? "rgba(224, 122, 95, 0.22)" : "rgba(255, 255, 255, 0.04)",
                          border: active ? "1px solid var(--worm-pink)" : "1px solid rgba(255, 255, 255, 0.08)",
                          borderRadius: "14px",
                          padding: "1rem",
                          textAlign: "left",
                          cursor: "pointer",
                          transition: "all 0.2s",
                        }}
                      >
                        <div style={{ display: "flex", alignItems: "center", justifyContent: "space-between", marginBottom: "0.35rem" }}>
                          <span style={{ fontSize: "0.92rem", fontWeight: 700, color: active ? "#ffffff" : "#ded3c5" }}>
                            {tool.label}
                          </span>
                          {active && <CheckCircle2 size={16} color="var(--worm-pink)" />}
                        </div>
                        <div style={{ fontSize: "0.82rem", fontWeight: 600, color: active ? "var(--worm-flesh)" : "#ad9f90" }}>
                          Est. {tool.est}
                        </div>
                      </button>
                    );
                  })}
                </div>
              </div>

              {/* Dynamic Savings Card */}
              <div
                style={{
                  background: "linear-gradient(145deg, #1f1814 0%, #291e18 100%)",
                  borderRadius: "24px",
                  padding: "3rem 2.5rem",
                  border: "1px solid rgba(244, 151, 142, 0.35)",
                  textAlign: "center",
                  position: "relative",
                  overflow: "hidden",
                  boxShadow: "0 20px 60px rgba(0, 0, 0, 0.6), 0 0 35px rgba(224, 122, 95, 0.15)",
                }}
              >
                <span style={{ fontSize: "0.9rem", color: "#ded3c5", textTransform: "uppercase", letterSpacing: "0.08em", fontWeight: 800 }}>
                  Estimated Space Worm Will Reclaim
                </span>

                <div
                  style={{
                    fontSize: "clamp(4rem, 7vw, 5.2rem)",
                    fontWeight: 800,
                    color: "var(--worm-pink)",
                    margin: "1rem 0 0.5rem",
                    fontFamily: "var(--font-lexend)",
                    letterSpacing: "-0.03em",
                    textShadow: "0 0 35px rgba(244, 151, 142, 0.45)",
                  }}
                >
                  {totalCalculatedSavings} <span style={{ fontSize: "2.2rem" }}>GB</span>
                </div>

                <p style={{ color: "#e8ded2", fontSize: "1.05rem", marginBottom: "2.2rem", lineHeight: 1.6 }}>
                  Cleaned in seconds with safe non-destructive heuristics. Zero impact on active project checkouts.
                </p>

                <a href="#downloads" className="btn-primary" style={{ width: "100%", padding: "1.15rem", fontSize: "1.08rem" }}>
                  <Download size={20} />
                  <span>Download Free &amp; Clean {totalCalculatedSavings} GB</span>
                </a>

                <div style={{ marginTop: "1.2rem", fontSize: "0.85rem", color: "#b5a899", fontWeight: 600 }}>
                  Zero registration • MIT Open Source • Direct Download
                </div>
              </div>
            </div>
          </div>
        </div>
      </section>

      {/* ── COMPARISON TABLE ── */}
      <section
        id="comparison"
        style={{
          padding: "6rem 0",
          background: "var(--soil-void)",
          borderBottom: "1px solid rgba(255, 255, 255, 0.08)",
        }}
      >
        <div className="container">
          <div className="section-head reveal">
            <span className="worm-badge" style={{ marginBottom: "0.85rem" }}>
              Transparent Comparison
            </span>
            <h2
              style={{
                fontFamily: "var(--font-lexend)",
                fontSize: "clamp(2rem, 3.8vw, 3rem)",
                fontWeight: 700,
                letterSpacing: "-0.03em",
                color: "#ffffff",
                marginBottom: "1rem",
              }}
            >
              Worm vs. Commercial Cleaners
            </h2>
            <p style={{ color: "#ded3c5", fontSize: "1.1rem", lineHeight: 1.6 }}>
              Why pay an annual subscription for closed-source software with telemetry when you can run a native, open-source tool built for developers?
            </p>
          </div>

          <div style={{ overflowX: "auto" }}>
            <table
              style={{
                width: "100%",
                borderCollapse: "separate",
                borderSpacing: "0",
                background: "var(--soil-surface)",
                borderRadius: "20px",
                border: "1px solid rgba(255, 255, 255, 0.1)",
                overflow: "hidden",
                minWidth: "700px",
                boxShadow: "0 20px 50px rgba(0,0,0,0.5)",
              }}
            >
              <thead>
                <tr style={{ background: "rgba(0, 0, 0, 0.6)", borderBottom: "1px solid rgba(255, 255, 255, 0.1)" }}>
                  <th style={{ padding: "1.4rem 1.6rem", textAlign: "left", color: "#ffffff", fontSize: "1rem", fontWeight: 800 }}>
                    Feature / Quality
                  </th>
                  <th style={{ padding: "1.4rem 1.6rem", textAlign: "center", background: "rgba(224, 122, 95, 0.22)", color: "var(--worm-pink)", fontSize: "1.15rem", fontWeight: 800 }}>
                    Worm Cleaner
                  </th>
                  <th style={{ padding: "1.4rem 1.6rem", textAlign: "center", color: "var(--worm-amber-light)", fontSize: "1rem", fontWeight: 700 }}>
                    Mole (mo)
                  </th>
                  <th style={{ padding: "1.4rem 1.6rem", textAlign: "center", color: "#ded3c5", fontSize: "1rem", fontWeight: 700 }}>
                    CleanMyMac
                  </th>
                  <th style={{ padding: "1.4rem 1.6rem", textAlign: "center", color: "#ded3c5", fontSize: "1rem", fontWeight: 700 }}>
                    CCleaner
                  </th>
                  <th style={{ padding: "1.4rem 1.6rem", textAlign: "center", color: "#ded3c5", fontSize: "1rem", fontWeight: 700 }}>
                    BleachBit
                  </th>
                </tr>
              </thead>
              <tbody>
                {[
                  {
                    feature: "Pricing Model",
                    worm: "100% Free Forever",
                    mole: "Free CLI / Paid App ($15+)",
                    cmm: "$39.95 / year sub",
                    ccl: "Freemium ($29.95/yr)",
                    bb: "Free",
                    highlight: true
                  },
                  {
                    feature: "Telemetry & Privacy",
                    worm: "0 Telemetry (Zero)",
                    mole: "0 in CLI (License in App)",
                    cmm: "Analytics & Tracking",
                    ccl: "Heavy Telemetry / Ads",
                    bb: "Zero Telemetry",
                    highlight: true
                  },
                  {
                    feature: "Source Code",
                    worm: "MIT Open Source (GitHub)",
                    mole: "GPL CLI / Closed App",
                    cmm: "Closed Source",
                    ccl: "Closed Source",
                    bb: "GPL Open Source",
                    highlight: true
                  },
                  {
                    feature: "Cross-Platform Support",
                    worm: "macOS 14+ & Windows 10/11",
                    mole: "macOS only (Win experimental)",
                    cmm: "macOS only",
                    ccl: "macOS + Windows",
                    bb: "Linux + Windows",
                    highlight: true
                  },
                  {
                    feature: "Developer Cache Engine",
                    worm: "Full (Xcode, npm, Cargo, Docker)",
                    mole: "General 'mo purge'",
                    cmm: "Superficial",
                    ccl: "None",
                    bb: "Limited",
                    highlight: false
                  },
                  {
                    feature: "App Leftover Hunter",
                    worm: "Deep ~/Library & Registry purge",
                    mole: "CLI 'mo uninstall' / Paid App",
                    cmm: "Yes",
                    ccl: "Basic",
                    bb: "Basic",
                    highlight: false
                  },
                  {
                    feature: "Live Hardware Monitor",
                    worm: "Native Menu Bar & Tray",
                    mole: "CLI 'mo status' / Paid App",
                    cmm: "Separate heavy menu app",
                    ccl: "Background daemon",
                    bb: "None",
                    highlight: false
                  },
                  {
                    feature: "Memory Footprint",
                    worm: "< 15 MB RAM (Native Swift/AOT)",
                    mole: "45–90 MB RAM",
                    cmm: "120–200 MB RAM",
                    ccl: "80–150 MB RAM",
                    bb: "40–60 MB RAM",
                    highlight: true
                  },
                  {
                    feature: "Framework Architecture",
                    worm: "Swift 6 + .NET 9 Native AOT",
                    mole: "Go Binary + Shell scripts",
                    cmm: "Swift / Objective-C",
                    ccl: "C++ / Daemons",
                    bb: "Python",
                    highlight: false
                  }
                ].map((row, idx) => (
                  <tr
                    key={row.feature}
                    style={{
                      borderBottom: "1px solid rgba(255, 255, 255, 0.05)",
                      background: idx % 2 === 0 ? "transparent" : "rgba(255, 255, 255, 0.02)",
                    }}
                  >
                    <td style={{ padding: "1.15rem 1.6rem", fontWeight: 700, fontSize: "0.98rem", color: "#ffffff" }}>
                      {row.feature}
                    </td>
                    <td
                      style={{
                        padding: "1.15rem 1.6rem",
                        textAlign: "center",
                        background: "rgba(224, 122, 95, 0.12)",
                        color: "var(--worm-pink)",
                        fontWeight: 800,
                        fontSize: "0.98rem",
                      }}
                    >
                      <div style={{ display: "inline-flex", alignItems: "center", gap: "0.45rem" }}>
                        <Check size={18} />
                        <span>{row.worm}</span>
                      </div>
                    </td>
                    <td style={{ padding: "1.15rem 1.6rem", textAlign: "center", color: "#ded3c5", fontSize: "0.92rem", fontWeight: 600 }}>
                      {row.mole}
                    </td>
                    <td style={{ padding: "1.15rem 1.6rem", textAlign: "center", color: "#ded3c5", fontSize: "0.92rem" }}>
                      {row.cmm}
                    </td>
                    <td style={{ padding: "1.15rem 1.6rem", textAlign: "center", color: "#ded3c5", fontSize: "0.92rem" }}>
                      {row.ccl}
                    </td>
                    <td style={{ padding: "1.15rem 1.6rem", textAlign: "center", color: "#ded3c5", fontSize: "0.92rem" }}>
                      {row.bb}
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>

          {/* Worm vs Mole Spotlight Card */}
          <div
            className="soil-card-premium"
            style={{
              marginTop: "2.5rem",
              padding: "2rem 2.5rem",
              borderRadius: "18px",
              border: "1px solid rgba(224, 122, 95, 0.3)",
              background: "linear-gradient(145deg, rgba(28, 22, 18, 0.95) 0%, rgba(18, 14, 12, 0.98) 100%)",
            }}
          >
            <div style={{ display: "flex", alignItems: "center", gap: "0.85rem", marginBottom: "1.25rem" }}>
              <span className="worm-badge" style={{ fontSize: "0.82rem" }}>
                Worm vs. Mole (mo)
              </span>
              <h3 style={{ fontSize: "1.25rem", fontWeight: 800, color: "#ffffff" }}>
                Why Developers Choose Worm over Mole
              </h3>
            </div>

            <div className="reveal" style={{ display: "grid", gridTemplateColumns: "repeat(auto-fit, minmax(280px, 1fr))", gap: "1.75rem" }}>
              <div>
                <h4 style={{ fontSize: "1rem", fontWeight: 700, color: "var(--worm-pink)", marginBottom: "0.5rem" }}>
                  1. 100% Free GUI &amp; CLI (No Paid App)
                </h4>
                <p style={{ color: "#ded3c5", fontSize: "0.92rem", lineHeight: 1.6 }}>
                  Mole offers a free terminal CLI (`mo`), but charges $15–$20 for its native Mac app license. Worm is <strong>100% free and open-source (MIT)</strong> for both its native GUI app and its CLI with zero locked features.
                </p>
              </div>

              <div>
                <h4 style={{ fontSize: "1rem", fontWeight: 700, color: "var(--worm-pink)", marginBottom: "0.5rem" }}>
                  2. First-Class Windows Support
                </h4>
                <p style={{ color: "#ded3c5", fontSize: "0.92rem", lineHeight: 1.6 }}>
                  Mole is strictly tailored for macOS with an experimental Windows branch. Worm is designed from day one with <strong>full native Windows 10/11 support</strong> powered by compiled .NET 9 Native AOT.
                </p>
              </div>

              <div>
                <h4 style={{ fontSize: "1rem", fontWeight: 700, color: "var(--worm-pink)", marginBottom: "0.5rem" }}>
                  3. Dedicated Developer Cache Heuristics
                </h4>
                <p style={{ color: "#ded3c5", fontSize: "0.92rem", lineHeight: 1.6 }}>
                  While Mole performs general cleans and project purges, Worm specifically fingerprints Xcode DerivedData, SPM caches, Docker layers, npm/pnpm trees, and Cargo builds with fast, non-destructive safety checks.
                </p>
              </div>
            </div>
          </div>
        </div>
      </section>

      {/* ── FREQUENTLY ASKED QUESTIONS ── */}
      <section
        id="faq"
        style={{
          padding: "6rem 0",
          background: "var(--soil-base)",
          borderBottom: "1px solid rgba(255, 255, 255, 0.08)",
        }}
      >
        <div className="container" style={{ maxWidth: "880px" }}>
          <div style={{ textAlign: "center", marginBottom: "3.5rem" }}>
            <span className="moss-badge" style={{ marginBottom: "0.85rem" }}>
              Frequently Answered Questions
            </span>
            <h2
              style={{
                fontFamily: "var(--font-lexend)",
                fontSize: "clamp(2rem, 3.8vw, 3rem)",
                fontWeight: 700,
                letterSpacing: "-0.03em",
                color: "#ffffff",
                marginBottom: "1rem",
              }}
            >
              Everything You Need to Know
            </h2>
            <p style={{ color: "#ded3c5", fontSize: "1.1rem" }}>
              Transparent answers regarding safety, project protection, and architecture.
            </p>
          </div>

          <div style={{ display: "flex", flexDirection: "column", gap: "1.1rem" }}>
            {faqs.map((faq, index) => {
              const isOpen = activeFaq === index;
              return (
                <div
                  key={index}
                  className="soil-card-premium"
                  style={{
                    borderRadius: "16px",
                    overflow: "hidden",
                    border: isOpen ? "1px solid rgba(244, 151, 142, 0.4)" : "1px solid rgba(255, 255, 255, 0.08)",
                  }}
                >
                  <button
                    onClick={() => setActiveFaq(isOpen ? null : index)}
                    style={{
                      width: "100%",
                      padding: "1.5rem 1.75rem",
                      background: "transparent",
                      border: "none",
                      display: "flex",
                      alignItems: "center",
                      justifyContent: "space-between",
                      textAlign: "left",
                      color: "#ffffff",
                      fontSize: "1.15rem",
                      fontWeight: 700,
                      cursor: "pointer",
                      gap: "1rem",
                    }}
                  >
                    <span>{faq.q}</span>
                    <ChevronDown
                      size={22}
                      color="var(--worm-pink)"
                      style={{
                        transform: isOpen ? "rotate(180deg)" : "rotate(0deg)",
                        transition: "transform 0.25s ease",
                        flexShrink: 0,
                      }}
                    />
                  </button>

                  {isOpen && (
                    <div
                      style={{
                        padding: "0 1.75rem 1.6rem",
                        color: "#e8ded2",
                        lineHeight: 1.75,
                        fontSize: "1.05rem",
                        borderTop: "1px solid rgba(255, 255, 255, 0.06)",
                        paddingTop: "1.2rem",
                      }}
                    >
                      {faq.a}
                    </div>
                  )}
                </div>
              );
            })}
          </div>
        </div>
      </section>

      {/* ── FOOTER & CLEPSYDRA BRANDING ── */}
      <footer
        style={{
          background: "#060504",
          padding: "5.5rem 0 3.5rem",
          borderTop: "1px solid rgba(255, 255, 255, 0.08)",
        }}
      >
        <div className="container">
          <div
            style={{
              display: "grid",
              gridTemplateColumns: "repeat(auto-fit, minmax(240px, 1fr))",
              gap: "3.5rem",
              marginBottom: "4rem",
            }}
          >
            {/* Brand Col */}
            <div>
              <div style={{ display: "flex", alignItems: "center", gap: "0.85rem", marginBottom: "1.2rem" }}>
                <img
                  src="/images/NavMascot@2x.png"
                  alt="Worm Cleaner mascot"
                  width={36}
                  height={36}
                  style={{ width: "36px", height: "36px" }}
                />
                <span style={{ fontWeight: 800, fontSize: "1.3rem", letterSpacing: "-0.03em", color: "#ffffff" }}>
                  WORM CLEANER
                </span>
              </div>
              <p style={{ color: "var(--n-300)", fontSize: "0.95rem", lineHeight: 1.65, marginBottom: "1.75rem" }}>
                Worm (Worm Cleaner) is a free, open-source disk cleaner, app uninstaller
                and system monitor for Mac and Windows. Not malware.
              </p>
              <div style={{ display: "flex", gap: "0.75rem", flexWrap: "wrap", marginBottom: "1.25rem" }}>
                <a
                  href={REPO_URL}
                  target="_blank"
                  rel="noopener noreferrer"
                  className="btn-secondary"
                  style={{ padding: "0.6rem 1.05rem", fontSize: "0.88rem" }}
                >
                  <GithubIcon size={16} />
                  <span>Star on GitHub</span>
                </a>
              </div>

              {/* Author and company profiles. Mirrored in the Person and
                  Organization sameAs arrays in index.html — the two must agree. */}
              <div style={{ display: "flex", gap: "0.5rem", flexWrap: "wrap" }}>
                <a
                  className="social-link"
                  href={SOCIAL.author}
                  target="_blank"
                  rel="noopener noreferrer me"
                  title="Follow @namdevnaman on Instagram"
                >
                  <InstagramIcon size={15} />
                  <span>@namdevnaman</span>
                </a>
                <a
                  className="social-link"
                  href={SOCIAL.company}
                  target="_blank"
                  rel="noopener noreferrer"
                  title="Follow @clepsydra_technologies on Instagram"
                >
                  <InstagramIcon size={15} />
                  <span>@clepsydra_technologies</span>
                </a>
              </div>

              {/* Sits under the brand rather than as a fifth column: at a 240px
                  min the auto-fit grid only fits four, which orphaned this into
                  a half-empty second row. */}
              <h3 style={{ color: "var(--ink)", fontSize: "0.78rem", fontWeight: 800, margin: "2rem 0 1rem", letterSpacing: "0.14em", textTransform: "uppercase", fontFamily: "var(--font-mono)" }}>
                Safety
              </h3>
              <ul style={{ listStyle: "none", display: "flex", flexDirection: "column", gap: "0.7rem", fontSize: "0.88rem" }}>
                {[
                  "System Integrity Protection respected",
                  "Simulation mode previews every deletion",
                  "Recycle Bin fallback, never a hard unlink",
                  "Source repositories never touched"
                ].map((promise) => (
                  <li key={promise} style={{ display: "flex", alignItems: "flex-start", gap: "0.55rem", color: "var(--n-300)" }}>
                    <CheckCircle2 size={14} color="var(--moss-light)" style={{ flexShrink: 0, marginTop: "0.25rem" }} />
                    <span>{promise}</span>
                  </li>
                ))}
              </ul>
            </div>

            {/* In-page navigation. The header is the only other place these
                sections are reachable from, and a footer that cannot get you
                back up the page is a dead end on a long single-page site. */}
            <div>
              <h4 style={{ color: "var(--ink)", fontSize: "0.78rem", fontWeight: 800, marginBottom: "1.25rem", letterSpacing: "0.14em", textTransform: "uppercase", fontFamily: "var(--font-mono)" }}>
                Explore
              </h4>
              <ul style={{ listStyle: "none", display: "flex", flexDirection: "column", gap: "0.7rem", fontSize: "0.95rem" }}>
                {SECTIONS.map((section) => (
                  <li key={section.id}>
                    <a
                      href={`#${section.id}`}
                      style={{ color: "var(--n-200)", textDecoration: "none", transition: "color 140ms" }}
                      onMouseEnter={(e) => (e.currentTarget.style.color = "var(--worm-pink)")}
                      onMouseLeave={(e) => (e.currentTarget.style.color = "var(--n-200)")}
                    >
                      {section.label}
                    </a>
                  </li>
                ))}
              </ul>
            </div>

            {/* Quick Links */}
            <div>
              <h4 style={{ color: "var(--ink)", fontSize: "0.78rem", fontWeight: 800, marginBottom: "1.25rem", letterSpacing: "0.14em", textTransform: "uppercase", fontFamily: "var(--font-mono)" }}>
                Downloads
              </h4>
              <ul style={{ listStyle: "none", display: "flex", flexDirection: "column", gap: "0.85rem", fontSize: "0.95rem" }}>
                <li>
                  <a href="https://github.com/namdevnaman/worm/releases/latest/download/Worm-Installer.dmg" style={{ color: "#ded3c5", textDecoration: "none" }}>
                    macOS Universal (.dmg)
                  </a>
                </li>
                <li>
                  <a href="https://github.com/namdevnaman/worm/releases/latest/download/Worm-macOS.zip" style={{ color: "#ded3c5", textDecoration: "none" }}>
                    macOS Portable (.zip)
                  </a>
                </li>
                <li>
                  <a href="https://github.com/namdevnaman/worm/releases/latest/download/Worm-Windows-x64.zip" style={{ color: "#ded3c5", textDecoration: "none" }}>
                    Windows 10/11 x64 (.zip)
                  </a>
                </li>
                <li>
                  <a href="https://github.com/namdevnaman/worm/releases" target="_blank" rel="noopener noreferrer" style={{ color: "var(--worm-pink)", textDecoration: "none", fontWeight: 700 }}>
                    All Releases &amp; Checksums →
                  </a>
                </li>
              </ul>
            </div>

            {/* Project & Company */}
            <div>
              <h4 style={{ color: "var(--ink)", fontSize: "0.78rem", fontWeight: 800, marginBottom: "1.25rem", letterSpacing: "0.14em", textTransform: "uppercase", fontFamily: "var(--font-mono)" }}>
                Clepsydra Technologies
              </h4>
              <ul style={{ listStyle: "none", display: "flex", flexDirection: "column", gap: "0.85rem", fontSize: "0.95rem" }}>
                <li>
                  <a href="https://clepsydratechnologies.com" target="_blank" rel="noopener noreferrer" style={{ color: "#ded3c5", textDecoration: "none" }}>
                    clepsydratechnologies.com
                  </a>
                </li>
                <li>
                  <a href="https://worm.clepsydratechnologies.com" style={{ color: "#ded3c5", textDecoration: "none" }}>
                    worm.clepsydratechnologies.com
                  </a>
                </li>
                <li>
                  <a href="https://github.com/namdevnaman/worm/blob/main/LICENSE" target="_blank" rel="noopener noreferrer" style={{ color: "#ded3c5", textDecoration: "none" }}>
                    MIT License
                  </a>
                </li>
                <li>
                  <a href="https://github.com/namdevnaman/worm/blob/main/SETUP.md" target="_blank" rel="noopener noreferrer" style={{ color: "#ded3c5", textDecoration: "none" }}>
                    Setup &amp; Developer Guide
                  </a>
                </li>
              </ul>
            </div>

          </div>

          {/* Bottom rule & copyright */}
          <div
            style={{
              paddingTop: "2.25rem",
              borderTop: "1px solid rgba(255, 255, 255, 0.08)",
              display: "flex",
              alignItems: "center",
              justifyContent: "space-between",
              flexWrap: "wrap",
              gap: "1.25rem",
              fontSize: "0.9rem",
              color: "#8a7e70",
            }}
          >
            <div>
              © 2026 Clepsydra Technologies &amp; Naman Namdev. All rights reserved.
              &nbsp;·&nbsp; v{APP_VERSION} &nbsp;·&nbsp; Last updated {LAST_UPDATED}
            </div>
            <div style={{ display: "flex", gap: "1.75rem" }}>
              <span>Domain: worm.clepsydratechnologies.com</span>
              <span>Zero Telemetry Verified</span>
              <span>Vercel Deploy Ready</span>
            </div>
          </div>
        </div>
      </footer>
    </div>
  );
}

export default App;
