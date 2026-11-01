# PixelAudit

PixelAudit watches whether events reach the advertising networks. A **funnel**
is a user journey as ordered steps; one or more **data sources** count each
step — a Meta pixel's stats, a GA4 property's BigQuery export, a Google Ads
transfer, a Postgres or ClickHouse query — through **connections** that hold
the credentials. The counts are cached per day, refreshed hourly (Meta) and
nightly (everything), and shown as a sankey and a sources × steps table over
any date range, so the networks' figures can be laid side by side.

Two components in a monorepo:

| Component | Path | Stack |
|---|---|---|
| API | `src/api` | Elixir / Phoenix, Ecto, Oban, OpenAPI (`open_api_spex`) |
| Admin panel | `src/admin` | Vite, React, TypeScript, TanStack Router/Query, Tailwind, orval |

In production they are one image: the `Dockerfile` at the root builds the
panel and the API and has Phoenix serve the panel's build next to the API,
under one hostname. Deployment: that image and a Helm chart for an
on-premise Kubernetes (`deploy/`). Licence: GNU AGPL v3 (`LICENSE`).

## Prerequisites

You need three things installed: **asdf** (manages Erlang, Elixir and Node.js
versions), **foreman** (runs the app processes from the `Procfile`), and
**Docker** (runs PostgreSQL).

### 1. Install asdf

asdf reads the `.tool-versions` file in the repo root, so everyone gets the
exact same Erlang/Elixir/Node.js versions.

macOS:

```sh
brew install asdf
echo 'export PATH="${ASDF_DATA_DIR:-$HOME/.asdf}/shims:$PATH"' >> ~/.zshrc
exec zsh
```

Linux: download the latest release binary from
<https://github.com/asdf-vm/asdf/releases> onto your `PATH` and add the same
`shims` line to your shell's rc file.

Then, from the repo root:

```sh
asdf plugin add erlang
asdf plugin add elixir
asdf plugin add nodejs
asdf install
```

Building Erlang takes a while and needs a compiler toolchain
(`xcode-select --install` plus `brew install autoconf openssl` on macOS;
`build-essential autoconf m4 libncurses-dev libssl-dev` on Debian/Ubuntu).

### 2. Install foreman

```sh
gem install foreman
```

### 3. Install Docker

Docker Desktop on macOS, Docker Engine with the Compose plugin on Linux.

## Running the dev environment

First-time setup — starts PostgreSQL, fetches the API's dependencies, creates
and migrates the database, applies the `CONNECTION_*` environment (see
below) and runs `npm install` for the panel:

```sh
make setup
```

Then:

```sh
make up
```

This starts the Docker services, kills anything still holding the app ports,
and starts the API and the panel from the `Procfile` via foreman:

| App | Path | URL |
|---|---|---|
| Phoenix API | `src/api` | <http://localhost:16000> (OpenAPI: `/openapi/admin.json`) |
| Admin panel | `src/admin` | <http://localhost:16001> — its dev server proxies `/api`, `/openapi`, `/health` and `/config.js` to the API, so the panel calls its own origin here as in the image |

The Docker services:

| Service | Purpose | Port |
|---|---|---|
| `postgres` | PostgreSQL for the API | `localhost:15460` |
| `postgres-sample` (`make targets-up`) | a sample shop database with an `events` table, to point a Postgres query data source at | `localhost:15461` |
| `clickhouse-sample` (`make targets-up`) | the same events in ClickHouse, for a ClickHouse query data source | `localhost:18123` |

(The API's port is set in `.foreman`; the panel's in `src/admin/vite.config.ts`.)

Two unrelated sets of environment variables reach the API: its own, and
the connections. Foreman loads `.env` for both; copy `.env.example` to
start.

### The application's environment

These configure the API itself and are read when it starts:

- `DATABASE_URL` — the API's own PostgreSQL, where funnels, connections
  and cached counts live (the `postgres` service above). Not a
  connection: the databases a funnel measures are defined below.
- `PORT` — the API's port (`.foreman` sets it for development).
- `CREDENTIALS_ENCRYPTION_KEY` — the key the connection credentials are
  encrypted with (Cloak, AES-GCM); fixed in `config/dev.exs` for
  development, required in production.
- `WEB_SECRET_KEY_BASE` — Phoenix's own signing secret; unrelated to the
  key above, required in production.

### Connections from the environment

A connection — the external system a funnel's data sources read from —
can be created in the panel, or defined by `CONNECTION_*` variables and
applied by the API's **boot** role
(`make boot`, or `mix boot` in `src/api`; in a deployment, the image's
`boot` command). Run `make boot` again after editing `.env`.

```sh
CONNECTION_<id>_TYPE=meta | bigquery | postgres | clickhouse
CONNECTION_<id>_<PARAM>=...
```

`<id>` is the connection's code (lowercase letters and digits,
case-sensitive) and `<PARAM>` one of the type's credentials, in upper case:

- `meta` — a Meta pixel: `ACCESS_TOKEN`, `PIXEL_ID`, `API_VERSION`
  (optional, `v25.0`).
- `bigquery` — a BigQuery project: `CREDENTIALS_JSON` (the service
  account's key file, as JSON or base64 of it), `PROJECT_ID`, `LOCATION`
  (optional).
- `postgres` — a PostgreSQL database to query:
  `URL=postgres://user:password@host:5432/database`
  (`?sslmode=require` for TLS).
- `clickhouse` — a ClickHouse database to query, over its HTTP interface:
  `URL=http://user:password@host:8123/database` (user and database
  default to `default`).

`GET /api/admin/v1/settings/connections/types` lists the same. An existing
connection with the same code is updated (its name and description kept),
a new one is created named after its code; both are marked as managed by
the environment, which makes their type and credentials read-only in the
panel. The panel shows a URL with its password hidden.

### Variables from the environment

A variable is one string value under a key — a key/value store kept under
**Settings → Variables** in the panel. The same boot role seeds them:

```sh
VARIABLE_<key>_VALUE=...
VARIABLE_<key>_DESCRIPTION=...   # optional
```

`<key>` is letters and digits, case-sensitive. An existing variable with
the same key gets the value (and the description, when given); a new one
is created. Both are marked as managed by the environment, which makes
their value read-only in the panel.

## A first funnel

1. `make targets-up` starts the sample databases; `.env.example` has the
   `CONNECTION_shop_*` and `CONNECTION_events_*` lines for them.
2. In the panel, add a funnel under **Funnels** and open its **Setup** tab:
   add steps (say `visit`, `cart`, `purchase`), add a data source of type
   *PostgreSQL query* on the `shop` connection, and in the parameters grid
   give each step its query, e.g.
   `SELECT COUNT(*) FROM events WHERE name = 'purchase' AND created_at >= $1 AND created_at < $2 + 1`.
   Saving the parameters recomputes the last seven days.
3. The **View** tab draws the funnel over a date range; **Refresh** recomputes
   any range on demand, and **Refreshes** lists every run and its outcome.

A Meta data source needs a Meta connection (access token and pixel id). Its
pixel stats are pulled hourly and kept, because Meta serves only about the
last seven days; the funnel's step is the event name.

## Quality gate

```sh
make check      # mix precommit (API), npm run check (panel), helm lint (chart)
```

The panel's API client is generated from the API's OpenAPI document — after
changing an endpoint, `make openapi-generate` regenerates it (starting the
API on demand) and type-checks the panel.

## Deployment

CI (`.github/workflows/test-build.yml`) tests both components and publishes
the image (`ghcr.io/pixel-audit/pixel-audit-app`) to the GitHub Container
Registry: `latest` on every push to `main`, `X.Y.Z` on a `vX.Y.Z` tag,
which also publishes the Helm chart. `make image` builds the same image
locally. The chart in `deploy/` installs it with its boot Job on any
Kubernetes, with your managed Postgres or its own PostgreSQL 18 on a
volume, exposed under one hostname through an Ingress or the Gateway API
(both optional), every secret read from a Secret you create; its README
covers the values and the two ways to pick an image version (a release,
or tracking `latest`).

The panel is not for search engines: the image serves a `robots.txt` that
disallows everything, the panel's page carries a `noindex` meta tag and
the server adds the matching header.

## Licence

PixelAudit is free software under the GNU Affero General Public License,
version 3 (`LICENSE`). The panel's sidebar links to the source, as §13 of
the licence asks of a program used over a network; a deployment points that
link at its own repository with `SOURCE_URL`, which the API renders into
the panel's `/config.js`.

## Layout

```
Dockerfile       the one image: the panel built, the API compiled, the panel served by it
src/api          the Phoenix API — CLAUDE.md there says where code goes
src/admin        the panel — CLAUDE.md there has the conventions
deploy           the Helm chart and its README
specs            the API rules and the domain (connections, funnels, caching)
docker           seeds of the sample databases
```
