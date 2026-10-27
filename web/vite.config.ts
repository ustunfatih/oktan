import { defineConfig } from "vite";
import react from "@vitejs/plugin-react";

export default defineConfig({
  root: "app",
  plugins: [react()],
  build: {
    outDir: "../dist",
    emptyOutDir: true,
    // Keep every font a separate file: small ones would otherwise be inlined as data: URIs, which the
    // Content-Security-Policy (font-src 'self') blocks.
    assetsInlineLimit: 0,
  },
  server: {
    // `npm run dev:worker` serves the API on 8787; the SPA dev server forwards /api to it.
    proxy: { "/api": "http://localhost:8787" },
  },
});
