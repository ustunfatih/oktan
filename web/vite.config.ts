import { defineConfig } from "vite";
import react from "@vitejs/plugin-react";

export default defineConfig({
  root: "app",
  plugins: [react()],
  build: { outDir: "../dist", emptyOutDir: true },
  server: {
    // `npm run dev:worker` serves the API on 8787; the SPA dev server forwards /api to it.
    proxy: { "/api": "http://localhost:8787" },
  },
});
