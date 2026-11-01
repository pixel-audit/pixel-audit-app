# API structure

Rules for the REST API served by the `src/api` Phoenix application.

## One API, for the panel

- Every endpoint lives under `/api/admin/v1/...`, in one router scope with
  one pipeline (`:admin_api`). Controllers are namespaced
  `PixelAudit.ApiWeb.Admin.*` under `lib/pixelaudit_api_web/controllers/admin/`.
- Keys are `snake_case` everywhere: bodies, query parameters, error bodies.
- Resources are grouped by domain area, and the module nesting mirrors the
  URL nesting: `/api/admin/v1/funnels/:funnel_id/data-sources` is
  `PixelAudit.ApiWeb.Admin.Funnels.DataSourceController`, the context is
  `PixelAudit.Api.Funnels` with `PixelAudit.Api.Funnels.DataSource`, the
  table `funnel_data_sources`. Likewise `/api/admin/v1/settings/connections`
  and `/settings/variables` are `PixelAudit.ApiWeb.Admin.Settings.*`, the
  context `PixelAudit.Api.Settings`, the tables `settings_connections` and
  `settings_variables`.
- Ids are UUIDs and every resource is addressed by its id. The one
  human-facing identifier is a connection's `name`, unique, which the
  `CONNECTION_<name>_*` environment addresses it by; a variable's `key`
  plays the same part for `VARIABLE_<key>_*`.

## No authentication, by design

The API has no authentication: it is meant to run behind a network boundary
(a private network, a VPN, an authenticating reverse proxy), and the Helm
chart's README says so. The only guard is on the data: connection
credentials are encrypted at rest and never returned — a connection answers
with `credential_keys` (which keys are set) and `credentials_preview` (the
non-secret values only).

The OpenAPI document (`GET /openapi/admin.json`, built by
`PixelAudit.ApiWeb.OpenApi.AdminSpec` from the router) declares no security
scheme. The panel's client is generated from it with orval; every operation
has an `operation_id` of the form `admin.verbNoun`, and every request and
response body is a named schema module under
`PixelAudit.ApiWeb.OpenApi.Schemas`, so the generated types are named.

## Errors

- A changeset failure is `422` with `{"errors": {"field": ["message"]}}`. A
  field inside a declared map is keyed with its prefix:
  `credentials.access_token`, `settings.dataset`, `parameters.sql`.
- A refusal is `{"errors": {"detail": "<reason>"}}`, the reason an atom's
  name, mapped to a status once in `PixelAudit.ApiWeb.FallbackController`:
  - `404 not_found` — also for an id that is not a UUID;
  - `409 connection_in_use`, `409 managed_by_env`;
  - `422 connection_type_mismatch`, `not_a_meta_connection`,
    `invalid_order`, `missing_date`, `invalid_date`, `invalid_date_range`,
    `range_too_large`, `invalid_pagination`, `invalid_status`, `invalid_kind`.
- Nothing about a connector's failure is a request error: a connector that
  refuses is recorded on the connection (`last_check_*`) or on the day
  (`reporting_daily_counts.error`) and shown there.

## Writes that trigger work

- Creating a Meta connection enqueues a pull of its pixel stats.
- Changing a data source's parameters, or a data source that already has
  parameters, enqueues a recomputation of its last seven days.
- `POST /funnels/:id/refresh` and `POST /settings/connections/:id/refresh` answer
  `202` with the refresh runs they enqueued; the work is done by Oban.

## External systems

- Nothing in the API talks to an external system but
  `PixelAudit.Api.Settings.Gateway` (`connections.md`): a controller, a
  context, a data source type or a job that needs a query run or a request
  made asks the gateway with the connection, and the call is recorded.
- `GET /settings/connections/:id/calls` lists those records, newest first,
  paged (`limit`, `offset`) and optionally between two UTC days
  (`date_from`, `date_to`; `422 invalid_date` otherwise).

## The panel, from the same origin

The API serves the panel too (`PixelAudit.ApiWeb.PanelController`): the
image copies the panel's build into `priv/static`, Plug.Static serves its
hashed assets, `favicon.ico` and `robots.txt` (which disallows every
crawler), `/config.js` is rendered from the environment (`apiUrl` empty —
the panel calls `/api/...` on its own origin — and `sourceUrl` from
`SOURCE_URL`), and every path no route claims answers `index.html` with an
`X-Robots-Tag: noindex` header, so the panel's router takes over from the
address. An unknown `/api/...` path stays a JSON 404. There is no CORS:
in development the panel's dev server proxies `/api`, `/openapi`,
`/health` and `/config.js` to the API. The panel sends its build's commit
as `x-pixelaudit-release-sha`.
