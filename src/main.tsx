import React from "react";
import ReactDOM from "react-dom/client";
import { Analytics } from "@vercel/analytics/react";
import App from "./App";
import "./index.css";

/*
 * ─────────────────────────────────────────────────────────────────────────
 * WEB ANALYTICS
 *
 * Mounted here rather than in App.tsx so the component tree, layout and styles
 * stay untouched. <Analytics /> renders no visible DOM.
 *
 * Scope, kept deliberately narrow because Worm's positioning depends on it:
 * this measures the marketing site, not the app. The Worm Cleaner binary ships
 * no telemetry and makes no network calls — that is a property of the shipped
 * app and is verified in the README, SECURITY.md and the published FAQ.
 *
 * Vercel Web Analytics sets no cookies, collects no personal data and needs no
 * consent banner, which is why the site's "no tracking pixels" phrasing was
 * narrowed to describe the app rather than this site.
 * ─────────────────────────────────────────────────────────────────────────
 */

const rootElement = document.getElementById("root");
if (rootElement) {
  ReactDOM.createRoot(rootElement).render(
    <React.StrictMode>
      <App />
      <Analytics />
    </React.StrictMode>
  );
}