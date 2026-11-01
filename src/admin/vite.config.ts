import babel from "@rolldown/plugin-babel";
import { tanstackRouter } from "@tanstack/router-plugin/vite";
import tailwindcss from "@tailwindcss/vite";
import react, { reactCompilerPreset } from "@vitejs/plugin-react";
// vitest/config re-exports Vite's defineConfig along with the `test` field.
import { defineConfig } from "vitest/config";

export default defineConfig({
  plugins: [
    // Must come before react() — it generates src/routeTree.gen.ts from the files
    // in src/routes and rewrites routes for code splitting. After react() it would
    // no longer see the JSX sources.
    tanstackRouter({ target: "react", autoCodeSplitting: true }),
    // React Compiler. plugin-react 6 transforms JSX via oxc, so the (Babel-based)
    // compiler goes separately and before it — it must still see the untransformed
    // source. The preset itself is limited to the client environment and adds
    // react/compiler-runtime to optimizeDeps.
    babel({ presets: [reactCompilerPreset()] }),
    react(),
    tailwindcss(),
  ],
  resolve: {
    // The "@/*" alias comes from paths in tsconfig.json — Vite 8 reads them
    // natively, without the vite-tsconfig-paths plugin.
    tsconfigPaths: true,
    // One copy of React and the router; two copies yield "Invalid hook call" or
    // two independent router contexts.
    dedupe: ["react", "react-dom", "@tanstack/react-router"],
  },
  // Dev on 16001 — right above the API (16000); the API is on 16000.
  // Monorepo apps stick to the 14000+ range. Preview (the built dist/) is
  // deliberately on 36001 so it does not collide with the dev servers from `make up`.
  // The API is the panel's own origin: every call goes to /api/... on the
  // page's host. In development the panel's dev server forwards those
  // paths — and the runtime configuration the API renders — to the
  // Phoenix server on 16000, so the same code runs here and in the image.
  server: {
    host: true,
    port: 16001,
    proxy: Object.fromEntries(
      ["/api", "/openapi", "/health", "/config.js"].map((path) => [
        path,
        { target: "http://localhost:16000", changeOrigin: false },
      ]),
    ),
  },
  preview: { host: true, port: 36001 },
  build: { outDir: "dist", sourcemap: true },
  test: {
    // What is tested is pure logic (schedule, slot-plan) — no DOM.
    environment: "node",
    include: ["src/**/*.test.ts"],
  },
});
