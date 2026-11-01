# PixelAudit (admin panel)

The panel of PixelAudit: funnels and their steps, data sources and
parameters; the funnel's report as a sankey and a counts table; the
connections; the refresh runs.

The app is a single-page application (SPA) that talks to the PixelAudit API
(`src/api` at the repo root; see `specs/api.md`) through an orval-generated
client in `src/api/generated`. There is no sign-in: the API has no
authentication and is deployed behind a network boundary.

## Requirements

Node 24 (the repo root's `.tool-versions` pins the exact version).

## Running

```sh
npm install
npm run dev          # http://localhost:16001
```

In the monorepo the app is normally started together with the API via
`make up` in the repo root (see the root README). The API address is
runtime configuration (`public/config.js`, read by `src/lib/config.ts`);
the development default points at the local stack.

## Scripts

| Command                | What it does                                        |
| ---------------------- | --------------------------------------------------- |
| `npm run dev`          | Dev server with HMR on port 16001                   |
| `npm run build`        | Production build into `dist/`                       |
| `npm run preview`      | Serves the built `dist/` on port 36001              |
| `npm run check`        | **Quality gate: catalogue + types + lint + tests**  |
| `npm run typecheck`    | `tsc --noEmit` (`vite build` doesn't check types)   |
| `npm run lint`         | ESLint (type-aware)                                 |
| `npm run lint:fix`     | ESLint with autofixes                               |
| `npm run api:generate` | Regenerate the typed API client (orval)             |
| `npm run i18n:extract` | Regenerate the message catalogue                    |
| `npm run test`         | Unit tests (Vitest)                                 |
| `npm run test:watch`   | Tests in watch mode                                 |
| `npm run format`       | Prettier — writes changes                           |
| `npm run format:check` | Prettier — check only                               |

## Stack

- **Vite** (SPA, no SSR)
- **TanStack Router** — file-based routing from `src/routes`;
  `routeTree.gen.ts` is generated automatically and is never edited by hand
- **React 19** + TypeScript
- **Tailwind CSS 4** (CSS-first, theme configured in `src/styles.css`)
- **shadcn/ui** — components in `src/components/ui`
- **TanStack Query** and the **orval**-generated API client
- **d3-sankey** for the funnel's layout, drawn in the panel's own SVG
- **react-intl** — every string is a message (`src/lib/i18n/README.md`)

## Structure

```
src/
  routes/          routes (file-based routing)
  components/      domain components: connections/, funnels/, reporting/
  components/crud/ the shared list / dialog / mutation building blocks
  components/form/ fields, incl. the form rendered from the API's field specs
  components/ui/   shadcn/ui, generated — usually don't edit
  api/             generated/ (orval client, never hand-edited) and http.ts (fetch wrapper)
  lib/
    api.ts            useApi() and the client context; api-provider.tsx hands the client down
    config.ts         runtime configuration (public/config.js)
    navigation.ts     navigation tree: top bar, sidebar and breadcrumbs
    date-range.ts     the report's ranges and presets
    sankey.ts         the report → sankey nodes and flows (pure, tested)
    refusals.ts       the API's refusals in plain words
  main.tsx         client entry point
```

Conventions (shared CRUD components, one page per item, the generated client)
are in [CLAUDE.md](CLAUDE.md).

## Deploy

`npm run build` produces a static `dist/`. The hosting **must** rewrite
unknown paths to `index.html` — without that, entering `/funnels` directly
returns a 404 (in nginx: `try_files $uri /index.html;`).

The Docker image (nginx) serves `dist/` and writes `/config.js` on every
start from `API_URL` and `SOURCE_URL`, so one build serves any environment.
