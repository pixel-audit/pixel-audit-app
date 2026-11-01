# PixelAudit — implementation plan

PixelAudit monitors whether events reach the advertising networks (Meta,
Google Analytics, Google Ads) by comparing, per funnel step and per day, the
counts each data source reports. It is one Phoenix API plus one React admin
panel in a monorepo, laid out and tooled like `memoria-app`, without auth.

Lines marked **Decision** are choices this plan makes where the brief left
room; lines marked **Assumption** are readings of the brief to confirm.

---

## 1. Repository layout

Mirrors `memoria-app` one-to-one, minus the parts PixelAudit has no use for
(Logto, mailpit, the device apps, the stores, Helm).

```
pixelaudit/
├── .tool-versions          erlang 29.0.5 / elixir 1.20.0-otp-29 / nodejs 24.19.0 (same as memoria)
├── .foreman                port: 16000
├── .gitignore
├── LICENSE                 GNU AGPL v3 (see §4a)
├── Makefile                setup / up / down / clean / openapi-generate / boot / check / helm-lint (see §4)
├── Procfile                api + admin
├── docker-compose.yml      postgres for the app + optional local connector targets (see §4)
├── README.md
├── .github/workflows/test-build.yml   test both components, build + push the two images, package + push the chart
├── deploy/                 Helm chart for third-party, on-premise Kubernetes installs (see §4b)
│   ├── Chart.yaml, values.yaml, values.schema.json, README.md
│   └── templates/          api, admin, boot job, ingress, secret, pvc-less; optional in-chart postgres
├── specs/                  the domain, written as it is implemented
│   ├── api.md              API rules (trimmed copy of memoria's: one API, snake_case, no auth)
│   ├── admin-panel.md
│   ├── connections.md      connectors, env sync, credential params
│   ├── funnels.md          funnel / step / data source / parameters
│   └── caching.md          daily cache, refresh runs, Meta retention
└── src/
    ├── api/                Phoenix (Elixir 1.20, Phoenix 1.8, Ecto, Oban, open_api_spex, Req, Bandit)
    └── admin/              Vite 8 / React 19 / TS / TanStack Router+Query / Tailwind 4 / shadcn-style ui / react-intl / orval
```

Ports stay out of memoria's range so both stacks can run side by side:

| Service | Port |
|---|---|
| Phoenix API | 16000 |
| Admin panel (vite dev) | 16001 (preview 36001) |
| Postgres (app DB) | 15460 |
| Postgres (sample connector target, optional) | 15461 |
| ClickHouse (sample connector target, optional) | 18123 (http) / 19000 (native) |

---

## 2. Backend (`src/api`)

### 2.1 Project skeleton

Generated with `mix phx.new pixelaudit_api --app pixelaudit_api --module PixelAudit.Api --no-html --no-assets --no-mailer --no-live --binary-id`, then shaped like memoria:

- `mix.exs` deps: `phoenix`, `phoenix_ecto`, `ecto_sql`, `postgrex`, `bandit`, `jason`, `corsica`, `open_api_spex`, `oban`, `req`, `telemetry_*`, `dns_cluster`, plus the connector deps in §2.5 (`goth`, `ch`) and `cloak` + `cloak_ecto` for credentials at rest (§2.4.1).
- `config/{config,dev,test,prod,runtime}.exs` copied in structure: CORS origins list in dev, `OpenApiSpex.Plug.NoneCache` in dev, `DATABASE_URL` parsing with `sslmode` in `runtime.exs`, `PORT` from env, `SECRET_KEY_BASE` required in prod. `SECRET_KEY` (64 hex chars) is the Cloak key — required in prod, fixed in dev/test.
- `AGENTS.md` / `CLAUDE.md`: memoria's, trimmed (Req over other HTTP clients, workers live in their context, syntax traps, `mix precommit`).
- `Dockerfile`, `docker/entrypoint.sh`, `rel/overlays/bin/*`, `rel/vm.args.eex` copied; roles become **`web`** (default) and **`boot`**.

### 2.2 Processes

| Role | Script | Runs |
|---|---|---|
| `boot` | `rel/overlays/bin/boot` → `PixelAudit.Api.Release.boot/0` | `create` (idempotent) → `migrate` → `PixelAudit.Api.Settings.EnvSync.run/0` (§2.6). Exits 0 on success, non-zero on a malformed `CONNECTION_*` set. Oban started with `queues: false, plugins: false` like memoria's `seed`. |
| `web` | `rel/overlays/bin/server` | `PHX_SERVER=true` + Oban queues and cron (§2.7). |

Dev equivalents: `mix boot` alias (`ecto.create`, `ecto.migrate`, `run priv/repo/boot.exs`) wired into `make setup` and `make boot`; `mix phx.server` is `web`. The web role does **not** run migrations or env sync — `boot` is the only writer of connection rows from the environment, so a deploy is `boot` (init container / one-off) then `web`.

### 2.3 Contexts and modules

```
lib/pixelaudit_api/
├── application.ex, repo.ex, release.ex, vault.ex (Cloak)
├── connections/                       context PixelAudit.Api.Settings
│   ├── connection.ex                  schema `connections`
│   ├── connector.ex                   behaviour (§2.5)
│   ├── connector/meta_api.ex
│   ├── connector/big_query.ex
│   ├── connector/postgres.ex
│   ├── connector/click_house.ex
│   ├── env_sync.ex                    CONNECTION_* → rows (§2.6)
│   └── meta_pixel_stat.ex             schema `connection_meta_pixel_stats` (raw hourly cache)
├── funnels/                           context PixelAudit.Api.Funnels
│   ├── funnel.ex, step.ex, data_source.ex, step_parameter.ex
│   └── data_source_type.ex            the five types: their connection type, settings and step-parameter schemas, resolver
├── reporting/                         context PixelAudit.Api.Reporting
│   ├── daily_count.ex                 schema `reporting_daily_counts`
│   ├── refresh_run.ex                 schema `reporting_refresh_runs`
│   ├── refresh_job.ex                 Oban worker (per data source × date range)
│   ├── meta_pixel_refresh_job.ex      Oban worker (per Meta connection; fills the raw cache)
│   ├── nightly.ex                     Oban cron entry point: enqueues the two above for every connection / data source
│   └── report.ex                      builds the funnel report (table + sankey input) from the cache
lib/pixelaudit_api_web/
├── endpoint.ex, router.ex, telemetry.ex
├── controllers/{fallback_controller, changeset_json, error_json, health_controller}.ex
├── controllers/admin/connections/connection_controller.ex (+ _json)
├── controllers/admin/funnels/{funnel,step,data_source,step_parameter}_controller.ex (+ _json)
├── controllers/admin/reporting/{report,refresh_run}_controller.ex (+ _json)
└── openapi/{spec,admin_spec}.ex, openapi/schemas/*.ex
```

### 2.4 Data model

All ids are UUIDs (`binary_id`); the human-facing identifier is a separate `code` column (`[a-z0-9]+`, unique within its parent, case-sensitive). Timestamps `utc_datetime`. Dates are calendar dates; **Assumption:** a report day is a UTC day for API sources and the query's own day for SQL sources (see §2.7 on timezones).

| Table | Columns (besides id/timestamps) | Notes |
|---|---|---|
| `connections` | `code` (unique), `name`, `description`, `type` (`meta_api` \| `bigquery` \| `postgres` \| `clickhouse`), `credentials` (Cloak-encrypted JSON map), `managed_by_env` bool, `last_checked_at`, `last_check_status`, `last_check_error` | `credentials` keys per type in §2.5. Never returned by the API; responses carry `credential_keys` (which keys are set) and a masked preview. |
| `connection_meta_pixel_stats` | `connection_id`, `date`, `hour`, `event_name`, `count` | unique `(connection_id, date, hour, event_name)`. Raw cache of `GET /{pixel_id}/stats?aggregation=event`. |
| `funnels` | `code` (unique), `name`, `description` | |
| `funnel_steps` | `funnel_id`, `code` (unique per funnel), `name`, `description`, `position` int | ordered; reorder endpoint |
| `funnel_data_sources` | `funnel_id`, `code` (unique per funnel), `name`, `description`, `type` (`meta_pixel_api` \| `google_analytics_bigquery` \| `google_ads_bigquery` \| `postgres_query` \| `clickhouse_query`), `connection_id`, `settings` JSON, `position` int | `connection.type` must match the data source type's connection type (changeset check). `settings` = source-level values, e.g. GA4 dataset. |
| `funnel_step_parameters` | `data_source_id`, `step_id`, `parameters` JSON | unique `(data_source_id, step_id)`. Validated against the type's step-parameter schema. Missing row = step not measured by this source (shows as "—"). |
| `reporting_daily_counts` | `data_source_id`, `step_id`, `date`, `count` (nullable), `status` (`ok` \| `error`), `error`, `computed_at`, `refresh_run_id` | unique `(data_source_id, step_id, date)`. The daily funnel-step cache. |
| `reporting_refresh_runs` | `kind` (`meta_pixel` \| `data_source`), `connection_id` / `data_source_id`, `date_from`, `date_to`, `trigger` (`cron` \| `manual`), `status` (`queued` \| `running` \| `done` \| `failed`), `started_at`, `finished_at`, `error`, `oban_job_id` | what the panel lists under "Refreshes". |

Deletes cascade down (funnel → steps, data sources → parameters, counts). Deleting a connection is refused (409 `connection_in_use`) while a data source uses it.

#### 2.4.1 Credentials at rest (Cloak)

`connections.credentials` is stored encrypted with the `cloak` / `cloak_ecto` hex packages:

- `PixelAudit.Api.Vault` (`use Cloak.Vault, otp_app: :pixelaudit_api`), started in the supervision tree before the Repo, with one AES-GCM-256 cipher tagged `"AES.GCM.V1"`; the key is `SECRET_KEY` decoded from its 64 hex characters (`Base.decode16!`) in the vault's `init/1`, so the same variable memoria uses for its secret is the one the chart and `.env.example` ask for.
- `PixelAudit.Api.Encrypted.Map` (`use Cloak.Ecto.Map, vault: PixelAudit.Api.Vault`) is the column type: the credentials map is JSON-encoded and encrypted as one blob (`:binary` column), so individual keys are never visible in the database and a dump of the table carries nothing usable without the key.
- Key rotation follows Cloak's documented path: add a `"AES.GCM.V2"` cipher, make it the default, run `mix pixelaudit.rotate_credentials` (a Mix task calling `Cloak.Ecto` re-encryption over the `connections` table), then retire V1. Documented in `specs/connections.md` and the chart README.
- Credentials never leave the API: responses carry `credential_keys` (set / not set per param); logs never print the map (`Inspect` derived with `except: [:credentials]` on the schema).
- Tests run the vault with a fixed test key from `config/test.exs`.

### 2.5 Connectors

`PixelAudit.Api.Settings.Connector` behaviour, one module per connection type:

```elixir
@callback type() :: atom()
@callback credential_params() :: [{key :: String.t(), required?, secret?}]   # also drives EnvSync and the UI form
@callback changeset(credentials :: map()) :: Ecto.Changeset.t()
@callback check(credentials) :: :ok | {:error, term()}                         # "Test connection"
```

Query execution is per data-source type (§2.5.2), on top of the connection's client.

#### 2.5.1 Connection types and their credential params

| `type` | env `CONNECTION_<id>_TYPE` | Params (`CONNECTION_<id>_<PARAM>`) | Client |
|---|---|---|---|
| `meta_api` | `meta-api` | `ACCESS_TOKEN` (secret, req.), `PIXEL_ID` (req.), `API_VERSION` (default `v25.0`) | `Req` against `https://graph.facebook.com/{version}` |
| `bigquery` | `bigquery` | `CREDENTIALS_JSON` (secret, req.; service-account JSON, raw or base64), `PROJECT_ID` (req.), `LOCATION` (opt.) | `Goth` for the token, `Req` against `bigquery.googleapis.com/bigquery/v2/projects/{p}/queries` (`jobs.query` with named parameters, `useLegacySql: false`, poll `getQueryResults` when not complete) |
| `postgres` | `postgres` | `URL` (req., `postgres://user:password@host:5432/database`) | `Postgrex` started per query (`Postgrex.start_link` from the parsed URL, `Postgrex.query/4`, then stop) — no Ecto repo, so an arbitrary number of connections needs no supervision tree changes |
| `clickhouse` | `clickhouse` | `URL` (req., `http(s)://user:password@host:8123/database`) | `ch` (Plausible's ClickHouse client) started per query, or plain `Req` on the HTTP interface — **Decision:** `ch`, for typed parameters |

`check/1`: Meta → `GET /{pixel_id}?fields=id,name`; BigQuery → `SELECT 1`; Postgres → `SELECT 1`; ClickHouse → `SELECT 1`.

#### 2.5.2 Data source types: settings, step parameters, resolution

Each type is a module behind `PixelAudit.Api.Funnels.DataSourceType` declaring its connection type, a settings schema, a step-parameter schema (both plain maps validated with `Ecto.Changeset` on schemaless types, exposed to the panel via OpenAPI so the form renders from the schema) and a resolver `count(connection, settings, step_parameters, date) :: {:ok, integer} | {:error, reason}`.

Dynamic values available to every resolver: `date_from`, `date_to` (required by the brief). Daily caching means a resolver is always called with `date_from = date_to = the day` (see §2.7); a range in the UI is the sum of its days. **Decision / flag:** this is what the brief asks for ("daily funnel step calculations"), and it is right for event counts; it would over-count a query that counts *distinct users* over a range. The query author is told so in the parameter form's hint.

| Data source type | Connection | `settings` | Step `parameters` | Resolver |
|---|---|---|---|---|
| `meta_pixel_api` | `meta_api` | — | `event_name` (req.) | Reads the raw cache `connection_meta_pixel_stats` summed over the day's 24 hours; never calls Meta synchronously. |
| `google_analytics_bigquery` | `bigquery` | `dataset` (req., e.g. `analytics_123456789`), `timezone` (opt., default `UTC`) | `event_name` (req.), `where` (opt. extra SQL condition) | `SELECT COUNT(*) FROM \`{project}.{dataset}.events_*\` WHERE _TABLE_SUFFIX BETWEEN @date_from_suffix AND @date_to_suffix AND event_name = @event_name [AND (where)]` — GA4 daily export tables; `events_intraday_*` included for today. |
| `google_ads_bigquery` | `bigquery` | `dataset` (req., the Google Ads Data Transfer dataset), `customer_id` (req.) | `conversion_action_name` (req.), `metric` (`conversions` \| `all_conversions`, default `conversions`) | Query over the transfer's `ads_ConversionStats_{customer_id}` / `ads_ConversionAction_{customer_id}` joined on conversion action id, `segments_date BETWEEN @date_from AND @date_to`. **Assumption:** the account uses the BigQuery Data Transfer for Google Ads; the exact table set is verified against a real dataset in phase 3 and the SQL kept in one module. |
| `postgres_query` | `postgres` | — | `sql` (req.) | Runs the SQL with `$1 = date_from`, `$2 = date_to` bound as `date`; expects exactly one row and one numeric column. |
| `clickhouse_query` | `clickhouse` | — | `sql` (req.) | Runs with `{date_from:Date}`, `{date_to:Date}` bound; same one-row/one-column expectation. |

Dates are **bound as parameters, never interpolated** into SQL, in all three SQL connectors. Results that are not one row × one number fail the day with a readable `error`.

### 2.6 Env sync (`boot`)

`PixelAudit.Api.Settings.EnvSync.run/0`:

1. Scan `System.get_env/0` for `^CONNECTION_([a-z0-9]+)_TYPE$` (the id is lowercase so a shell/compose file can set it; `_` is not allowed in an id, so the split is unambiguous).
2. For each id: map `TYPE` (`meta-api` → `meta_api`, …), collect `CONNECTION_<id>_<PARAM>` for the type's `credential_params()`, unknown params are logged as warnings; a missing required param or unknown type aborts boot with a non-zero exit naming the variable.
3. Upsert by `code` (case-sensitive): existing → `type` and `credentials` replaced, `name`/`description` kept, `managed_by_env = true`; new → `name = code`, `managed_by_env = true`.
4. A connection previously managed by env that is no longer in the environment is **left in place** (its data sources keep working) with `managed_by_env` cleared and a log line. **Decision** — deleting on absence would drop cached data for a typo.
5. Log one line per connection (`connections.env_sync upserted code=… type=… action=created|updated`).

The panel shows env-managed connections with a badge; their credentials and type are read-only in the UI (409 `managed_by_env` on write, like memoria's settings), name/description stay editable.

### 2.7 Caching and refresh

Two layers, both daily:

1. **Raw Meta cache** — `MetaPixelRefreshJob` per `meta_api` connection: calls `GET /{pixel_id}/stats?aggregation=event&start_time=…&end_time=…` and upserts hourly rows. Meta serves at most about the last 7 days per request ([Ads Pixel Stats reference](https://developers.facebook.com/documentation/ads-commerce/marketing-api/reference/ads-pixel/stats)), so this job runs **every hour** for the last 2 days (cheap, covers late-arriving counts) and the nightly run re-pulls the full 7-day window as a safety net. Rows are upserted (max of old/new per hour is *not* used — the latest value wins, since Meta's numbers are stable once the hour closed).
2. **Daily step counts** — `RefreshJob` per `(data_source, date_from, date_to)`: for each step with parameters and each day in the range, calls the type's resolver and upserts `reporting_daily_counts` (status `ok` with the count, or `error` with the message). Meta-type sources resolve from layer 1, so they are enqueued after the Meta jobs in the nightly run.

Scheduling (Oban, cron in UTC, config in `config.exs` like memoria):

| When | What |
|---|---|
| `15 * * * *` | `MetaPixelRefreshJob` for every `meta_api` connection, last 2 days |
| `30 3 * * *` | `Reporting.Nightly`: Meta jobs for 7 days, then `RefreshJob` for every data source for **yesterday and the day before** (two days, so a late export or a job that failed yesterday heals) |
| on data source create / parameters change | `RefreshJob` for the last 7 days (so a new source shows data at once) — queued, not inline |
| on connection create (Meta) | `MetaPixelRefreshJob` for 7 days |
| manual | `POST .../refresh` with `date_from`/`date_to` (max 366 days) enqueues the same jobs and answers with the refresh run |

Queues: `refresh: 3` (connector calls, parallel across sources), `meta: 1` (Meta rate limits). Lifeline and Pruner plugins as memoria. A `RefreshRun` row is written when enqueued and updated from the job, so the panel can show progress and errors without reading `oban_jobs`.

**Timezones (flag):** Meta stats are hourly UTC; GA4 export days are in the property's timezone; SQL sources are whatever the query does with the bound dates. Day-level comparison across sources is therefore approximate around midnight. The plan does not try to align them beyond the GA `timezone` setting; `specs/caching.md` states it.

### 2.8 Admin API

One API, `/api/admin/v1/...`, `snake_case`, no authentication (the router has a single `:admin_api` pipeline with `accepts` + `PutApiSpec`; `specs/api.md` records that "no auth" is deliberate and global). CORS via Corsica for the dev panel origin and `CORS_ORIGINS` in prod. OpenAPI document at `GET /openapi/admin.json` (`PixelAudit.ApiWeb.OpenApi.AdminSpec`, `open_api_spex` with `operation_id`s `admin.listConnections` etc. and named schema modules, so orval emits named types).

| Method & path | Purpose |
|---|---|
| `GET /health` | liveness |
| `GET/POST /connections`, `GET/PUT/DELETE /connections/:id` | CRUD; `PUT` with `credentials` replaces only the keys sent, `null` clears one; response never includes values |
| `GET /connections/types` | the connection types with their credential params (drives the form) |
| `POST /connections/:id/check` | runs `check/1`, stores and returns the result |
| `POST /connections/:id/refresh` | Meta only: enqueue raw-cache refresh (`date_from`, `date_to`) → 202 + refresh run |
| `GET/POST /funnels`, `GET/PUT/DELETE /funnels/:id` | CRUD; `GET /funnels/:id` embeds steps, data sources and parameters |
| `POST /funnels/:id/steps`, `PUT/DELETE /funnels/:id/steps/:step_id`, `PUT /funnels/:id/steps/order` (`step_ids` list) | steps |
| `GET /funnels/data-source-types` | the five types with connection type, settings and step-parameter schemas |
| `POST /funnels/:id/data-sources`, `PUT/DELETE .../data-sources/:ds_id` | data sources |
| `PUT /funnels/:id/data-sources/:ds_id/steps/:step_id/parameters` (`DELETE` clears) | step × source parameters |
| `POST /funnels/:id/refresh` (`date_from`, `date_to`, optional `data_source_id`) | enqueue daily recomputation → 202 + refresh runs |
| `GET /funnels/:id/report?date_from&date_to` | the report (§2.9) |
| `GET /reporting/refresh-runs?funnel_id&connection_id&status&limit&offset` | runs list; `GET .../:id` |

Errors through a `FallbackController` modelled on memoria's with this project's vocabulary: `not_found`, `connection_in_use`, `managed_by_env`, `connection_type_mismatch`, `invalid_date_range`, `range_too_large`, `invalid_parameters`, `connector_failed` (502 with the connector's message).

### 2.9 The report

`Reporting.Report.build(funnel, date_from, date_to)` reads `reporting_daily_counts` for the range and answers:

```json
{
  "funnel": {...}, "date_from": "…", "date_to": "…",
  "steps": [{"id","code","name"}...],
  "data_sources": [{"id","code","name","type"}...],
  "cells": [{"data_source_id","step_id","count": 1234|null,"days_ok": 30,"days_error": 1,"days_missing": 0}],
  "conversion": [{"data_source_id","from_step_id","to_step_id","rate": 0.42|null}]
}
```

`count` is the sum of `ok` days; `null` when the source has no parameters for the step. `days_*` let the panel mark a cell as partial. The sankey is drawn client-side from `cells` + `steps` (§3.4), so the API stays a counts API.

---

## 3. Admin panel (`src/admin`)

### 3.1 Skeleton

Copied from memoria's `src/admin` and stripped of auth: `package.json` (minus `@logto/react`, `grapesjs*`), `vite.config.ts` (port 16001), `tsconfig*.json`, `eslint.config.js`, `prettier`, `orval.config.ts` (input `http://localhost:16000/openapi/admin.json`, output `src/api/generated`, `customFetch` mutator), `scripts/i18n.mjs`, `Dockerfile` + `docker/` (nginx, runtime `config.js` with `apiUrl` only), `CLAUDE.md` (reuse table trimmed to what is copied), `public/config.js`, `index.html`, `src/styles.css`.

Copied components, unchanged where possible: `components/ui/*` (shadcn-style on Radix + Tailwind 4), `components/crud/*` (`CrudCard`, `ListRow`, `FormDialog`, `ConfirmDeleteDialog`, `ApiList`, `ApiItem`, `PageHeader`, `DetailsCard`, `useApiSave`, `useApiDelete`, `okData`, `refusal`), `components/form/*` (`FormField`, `useFormState`, `EntityCombobox`), `app-sidebar`, `app-header`, `app-breadcrumbs`, `page.tsx`, `lib/navigation.ts`, `lib/i18n/*`, `lib/config.ts`, `lib/date-range.ts`, `lib/utils.ts`, `api/http.ts` (token provider removed). `main.tsx` keeps `I18nProvider` → `ApiProvider` (QueryClient) → `RouterProvider`; `RequireAuth`/`RequireApiAccess` go.

New dependency: `d3-sankey` + `d3-shape` (typed, small; drawn into our own SVG so it follows the panel's theme) — **Decision** over `@nivo/sankey`/`recharts` to keep the chart styleable and dependency-light.

### 3.2 Locales

`react-intl` as in memoria: every string is a `defineMessages` entry with a dotted id and English `defaultMessage`; `npm run i18n:extract` builds `messages/en.json` and `compiled/en.json`; `locale.ts` resolves to `en` (only catalogue). `i18n:check` runs without a translation requirement until a second language is added (the memoria check that fails on a missing Polish file is parameterised by the list of translated locales, initially empty). Dates and numbers via `intl.formatDate`/`formatNumber`.

### 3.3 Navigation and screens

| Route | Screen |
|---|---|
| `/` | Dashboard: funnels as cards with yesterday's first/last step counts per source, and the last refresh runs' status. Can start as a redirect to `/funnels`. |
| `/funnels` | List (`CrudCard` + `ListRow`): code, name, steps count, sources count; add dialog (code, name, description). |
| `/funnels/$id` | Funnel page with tabs **View** (default) / **Setup**. |
| `/funnels/$id` (View tab) | Date-range picker (presets: last 7/30 days, this month, previous month; URL `validateSearch` keeps `date_from`/`date_to`), source selector for the sankey, the **sankey**, then the **counts table** (rows = data sources, columns = steps aligned with the sankey nodes, each cell the count, conversion % from the previous step in small text, a warning marker when `days_error > 0` or `days_missing > 0` with a tooltip). "Refresh" button → `POST /funnels/:id/refresh` for the shown range, toast, run visible in Refreshes. |
| `/funnels/$id` (Setup tab) | Three cards: **Steps** (ordered list, drag or up/down buttons, add/edit/delete), **Data sources** (list with type badge and connection, add/edit dialog: type → connection filtered by that type → settings fields from `GET /funnels/data-source-types`), **Parameters** (a grid steps × sources; each cell opens a dialog with the type's step-parameter fields — `event_name`, or a SQL textarea with the hint about `date_from`/`date_to` binding and the "one row, one number" contract — and shows a check/dash state). |
| `/connections` | List with type badge, env-managed badge, last check status; add dialog (type → credential fields from `GET /connections/types`, secrets as password inputs). |
| `/connections/$id` | Details (`DetailsCard`): type, which credential keys are set (masked), env-managed notice, check status; actions Edit, Check connection, Refresh Meta cache (Meta only, with a date range), Delete (blocked when in use, `ConfirmDeleteDialog`'s blocked case). |
| `/refreshes` | Refresh runs table with filters (status, funnel/connection), auto-refetch every 10 s while any run is queued/running. |

Sidebar sections: Funnels, Connections, Refreshes (from `lib/navigation.ts`, icons from lucide).

### 3.4 Sankey

`components/funnels/funnel-sankey.tsx`, pure from report data:

- Nodes: one per step, left to right, height ∝ count for the selected data source.
- Links: step *i* → step *i+1* with value `count[i+1]`; a second link from step *i* to a "dropped" sink with `count[i] - count[i+1]` (clamped at 0 — a later step larger than an earlier one is possible across sources and is drawn as 0 drop with a warning badge on the node).
- Hover tooltip: step name, count, conversion from previous and from first step.
- A step without parameters for the chosen source is drawn hollow and the flow passes it by.
- Colours from the panel's theme tokens; layout via `d3-sankey`, responsive width via a `ResizeObserver`.

**Decision:** one source per sankey (selector above it, default = first data source); the comparison between sources is the table's job. A later option is "overlay" mode drawing one ribbon per source.

---

## 4. Docker, Makefile, Procfile

- `docker-compose.yml`: `postgres` (18, port 15460, volume, healthcheck) for the app. Under the `targets` profile, so `make setup` does not pull them unless asked: `postgres-sample` (15461, seeded with an `events` table by `docker/sample-postgres/init.sql`) and `clickhouse` (`clickhouse/clickhouse-server`, 18123/19000, seeded likewise) — local connector targets so a developer can configure a `postgres_query` and a `clickhouse_query` source without external credentials. **Decision:** no BigQuery emulator; BigQuery and Meta are tested against real sandboxes and stubbed in unit tests.
- `src/api/Dockerfile`: memoria's, roles `web`/`boot`. `src/admin/Dockerfile`: memoria's, `config.js` with `apiUrl`.
- `Procfile`: `api: cd ./src/api && mix phx.server`, `admin: cd ./src/admin && npm run dev`. `.foreman`: `port: 16000`.
- `Makefile` targets (names as memoria): `setup` (docker-up, postgres-wait, api-setup = `mix deps.get && mix boot`, admin-setup), `boot` (`cd src/api && mix boot` — re-runs env sync after editing `.env`), `up` (docker-up, orphans-kill on 16000/16001, deps-check, `foreman start`), `down`, `clean`, `openapi-generate` (starts the API on demand like memoria's, then `npm run api:generate` + `npm run typecheck`), `check` (`mix precommit` + `npm run check` + `helm-lint`), `helm-lint` (§4b), `targets-up`/`targets-down` for the sample databases, `e2e*` left for phase 5.
- `.env.example` with one connection of each type (`CONNECTION_shop_TYPE=postgres`, `CONNECTION_shop_URL=…`, `CONNECTION_fb_TYPE=meta-api`, …); foreman loads `.env` so `make boot` and `make up` see it.
- CI: `test-build.yml` — `mix test` with a Postgres service, `npm run check`, `helm lint` + `helm template` of `deploy/`, then the two images to GHCR tagged by commit and by `code-<tree sha>` as memoria does, plus a semver tag (`v1.2.3`) on a git tag, and the chart packaged and pushed as an OCI artifact (`oci://ghcr.io/<owner>/charts/pixelaudit`) on the same tag. **No deploy job**: the project is installed by whoever runs it (§4b).

---

## 4a. License

The repository is released under the **GNU Affero General Public License v3.0** (`LICENSE` at the root, the verbatim text from gnu.org). Each component states it where its ecosystem expects: `"license": "AGPL-3.0-only"` in `src/admin/package.json`, `licenses: ["AGPL-3.0-only"]` in `src/api/mix.exs` `package/0`, `annotations: {"artifacthub.io/license": "AGPL-3.0-only"}` in `deploy/Chart.yaml`, a one-line SPDX header is **not** added to every source file (the root LICENSE and the manifests are enough; keeps the diff noise down). The README carries a short "License" section and the panel's About/footer shows the version and the license name, since AGPL §13 asks a network service to offer its source: the footer links to the repository (`SOURCE_URL`, part of the runtime `config.js`, defaulting to the GitHub repo).

Dependency check in phase 1: all planned deps (Phoenix/Ecto/Oban/Cloak/Req/Goth/ch, React/TanStack/Radix/d3) are MIT or Apache-2.0, compatible with AGPL; Oban Pro is not used.

## 4b. Helm chart for on-premise installs (`deploy/`)

Memoria's chart is tied to its own cluster (secrets created by an infra module, namespaces per environment, CI setting `release`). PixelAudit's chart is written for a **third party installing it on their own Kubernetes**, so it is self-contained, values-driven and documented like a public chart:

- `Chart.yaml`: `name: pixelaudit`, `version` (chart semver) and `appVersion` (image tag) bumped together on release; `type: application`; optional dependency `postgresql` (Bitnami, `condition: postgresql.enabled`) for an in-cluster database, off by default in favour of the operator's own Postgres.
- `values.yaml` (every key commented, the README's table is generated from it with `helm-docs`) and `values.schema.json` so a wrong value fails at `helm install`, not at pod start:

  ```yaml
  image:
    registry: ghcr.io
    repository: <owner>/pixelaudit         # images are <repository>-api and <repository>-admin
    tag: ""                                 # defaults to .Chart.AppVersion
    pullPolicy: IfNotPresent
    pullSecrets: []
  api:
    replicaCount: 1
    hostname: pixelaudit-api.example.com   # public hostname (ingress + HOSTNAME)
    resources: {...}
    extraEnv: []                           # arbitrary env, e.g. CONNECTION_* for env-managed connections
    extraEnvFrom: []                       # secretRef/configMapRef holding CONNECTION_* vars
    corsOrigins: []                        # on top of the admin hostname
  admin:
    replicaCount: 1
    hostname: pixelaudit.example.com
    resources: {...}
  database:
    url: ""                                # DATABASE_URL, or:
    existingSecret: ""                     # secret name
    existingSecretKey: DATABASE_URL
    poolSize: 10
  secrets:
    secretKeyBase: ""                      # or existingSecret with keys SECRET_KEY_BASE / SECRET_KEY
    secretKey: ""                          # 64 hex chars: the Cloak key (§2.4.1)
    existingSecret: ""
  ingress:
    enabled: true
    className: ""
    annotations: {}                        # e.g. cert-manager.io/cluster-issuer
    tls: true
  postgresql:                              # Bitnami subchart, optional
    enabled: false
  serviceAccount: {create: true, annotations: {}}
  podSecurityContext / securityContext      # non-root, read-only root fs, drop ALL
  ```

- Templates: `api-deployment.yaml` (+ Service; liveness/readiness on `GET /health`), `admin-deployment.yaml` (+ Service; nginx on 8080, `API_URL` = `https://<api.hostname>`), **`boot-job.yaml`** — the API image's `boot` role as a `pre-install,pre-upgrade` hook (`before-hook-creation,hook-succeeded`, `backoffLimit: 0`), with the same env as the API pods so the `CONNECTION_*` variables it maps to rows are the ones the web pods carry; `ingress.yaml` (two hosts, TLS per `ingress.tls`), `secret.yaml` (rendered only when the inline values are set; an `existingSecret` is used as-is), `_helpers.tpl` (names, labels, image reference, env block shared by the boot job and the API), `NOTES.txt` (URLs, how to add a connection through env, how to run `boot` again after changing them: `helm upgrade` re-runs the hook).
- `README.md` in `deploy/`: prerequisites (Kubernetes ≥ 1.28, an ingress controller, cert-manager optional, a Postgres 15+ or `postgresql.enabled`), `helm install pixelaudit oci://ghcr.io/<owner>/charts/pixelaudit --version x.y.z -f my-values.yaml`, the values table, generating `SECRET_KEY_BASE`/`SECRET_KEY`, defining connections through a Secret of `CONNECTION_*` variables referenced by `api.extraEnvFrom`, upgrading (migrations run in the boot hook; `--atomic` rolls back on failure), backup notes (the database is the only state; the Cloak key must be backed up with it or the credentials are unreadable), uninstall.
- `make helm-lint` runs `helm lint deploy` and `helm template deploy --values deploy/ci/values-test.yaml | kubeconform`; CI runs the same. An `examples/` folder in `deploy/` ships two values files: minimal (external Postgres, one Meta connection via env) and all-in-one (`postgresql.enabled: true`, no ingress TLS) for a kind/minikube try-out.

---

## 5. Testing

- API: `DataCase`/`ConnCase` from memoria's `test/support`. Connector modules tested with `Req.Test` stubs (Meta, BigQuery) and against the sample Postgres/ClickHouse from compose when `TARGETS=1` (skipped otherwise, `@tag :targets`). EnvSync tested with `System.put_env` in a `setup` + `on_exit`. Report builder and refresh jobs tested with Oban's `:manual` testing mode (`assert_enqueued`, `perform_job`).
- Admin: vitest for pure logic (`lib/date-range.ts`, sankey layout input builder, parameter-schema → form field mapping), `tsc`, eslint. Playwright e2e (phase 5) reusing memoria's `e2e/` harness against the two images + compose targets.

---

## 6. Assumptions and open points

1. **Daily granularity everywhere.** Counts are cached per day and ranges are sums of days (§2.5.2). Right for event counts, wrong for distinct-user queries over a range.
2. **Google Ads table shape.** Assumes the BigQuery Data Transfer for Google Ads; confirmed against a real dataset before the resolver is finalised (phase 3).
3. **Meta window.** Meta serves roughly 7 days per `stats` request, so data older than that is only what PixelAudit cached; a connection added today starts its history today. Hourly polling in §2.7 is sized for that.
4. **No auth, by request.** The API is open to anyone who reaches it; credentials are encrypted at rest and never returned, which is the only guard. Deploy behind a network boundary.
5. **Env var ids are lowercase** (`CONNECTION_shop_TYPE`), matching `[a-z0-9]+` and case-sensitive against `code`.
6. **Sankey per source** with the table doing the comparison (§3.4).

---

## 7. Phases

Each phase ends with `make check` green and the OpenAPI client regenerated.

1. **Skeleton (repo, API, panel shells)** — `LICENSE` (AGPL-3.0) and license fields, layout from §1, Phoenix app with Repo/Oban/OpenAPI/health, `boot`/`web` roles, Dockerfiles, compose, Makefile, Procfile, panel copied and stripped of auth, sidebar with the three sections, empty screens, orval wired, CI (tests + images), Helm chart skeleton that installs the two deployments and the boot job (`helm lint` in CI).
2. **Connections** — schema with the Cloak vault and encrypted column (§2.4.1), the four connector modules with `check/1`, EnvSync in `boot`, connections API + types endpoint, Connections screens, `.env.example`, compose `targets` with seeded sample DBs, chart values for `CONNECTION_*` via `extraEnvFrom`.
3. **Funnels** — funnels/steps/data sources/parameters schemas and API, data-source type modules with settings and parameter schemas and resolvers (SQL ones first against the sample targets, then GA4, Google Ads, Meta), Setup tab screens.
4. **Caching and reporting** — Meta raw cache + hourly job, daily counts + refresh jobs + nightly cron + refresh runs, manual refresh endpoints, report endpoint, View tab with date range, counts table and sankey, Refreshes screen, dashboard.
5. **Hardening and release** — e2e suite, README (prerequisites and run-through as memoria's, license section), `specs/*.md` finalised, rate-limit/backoff on Meta and BigQuery, pruning of old `connection_meta_pixel_stats` rows (configurable retention, default keep all), chart finished (`values.schema.json`, helm-docs README, examples, optional Bitnami Postgres subchart, kubeconform in CI), chart and images published on a `v*` git tag, a kind-based install smoke test in CI.
