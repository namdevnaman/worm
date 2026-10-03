import { defineConfig, type Plugin } from "vite";
import { existsSync } from "node:fs";
import path from "path";
import react from "@vitejs/plugin-react";

/**
 * Serve the generated SEO pages at their clean URLs in dev and preview.
 *
 * The landing pages ship as flat `<slug>.html` files in public/ and reach their
 * clean URLs on Vercel through "cleanUrls", which the host resolves at the
 * filesystem layer. Vite has no equivalent setting, so without this middleware
 * `appType: "spa"` answers every unknown path with the React app — which means
 * /mac-storage-cleaner silently renders the homepage with a 200. That is the
 * worst kind of bug locally: it looks like it works.
 *
 * So: if the request has no extension, no file matches it directly, and a
 * matching `<slug>.html` exists in public/, rewrite to that file. Anything
 * unmatched falls through to the SPA as before.
 */
function seoPages(): Plugin {
  const publicDir = path.resolve(__dirname, "public");

  const middleware = (server: { middlewares: { use: (fn: Function) => void } }) => {
    server.middlewares.use((req: any, _res: any, next: () => void) => {
      const url: string = (req.url || "").split("?")[0];

      if (req.method !== "GET" && req.method !== "HEAD") return next();
      if (path.extname(url)) return next();

      const candidate = path.join(publicDir, decodeURIComponent(url) + ".html");
      // Guard against traversal before touching the filesystem.
      if (!candidate.startsWith(publicDir + path.sep)) return next();
      if (!existsSync(candidate)) return next();

      req.url = url + ".html";
      next();
    });
  };

  return {
    name: "worm-seo-pages",
    configureServer: middleware,
    configurePreviewServer: middleware,
  } as Plugin;
}

export default defineConfig({
  plugins: [react(), seoPages()],
  resolve: {
    alias: {
      "@": path.resolve(__dirname, "./src"),
    },
  },
  build: {
    outDir: "build",
    emptyOutDir: true,
  },
  server: {
    port: 3000,
    open: false,
  },
});