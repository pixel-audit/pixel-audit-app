# Connections

A connection holds the credentials for one external system under a name,
unique, which the environment addresses it by. It is part of the Settings context (`PixelAudit.Api.Settings`, table
`settings_connections`, API `/api/admin/v1/settings/connections`), beside
the variables (`specs/variables.md`). Four types, one connector module each
(`PixelAudit.Api.Settings.Connector.*`):

| Type | `CONNECTION_<name>_TYPE` | Credentials | Client |
|---|---|---|---|
| `meta` | `meta` | `access_token` (secret), `pixel_id`, `api_version` (default `v25.0`) | Req against `graph.facebook.com` |
| `bigquery` | `bigquery` | `credentials_json` (secret; the service account key, JSON or base64), `project_id`, `location` | Goth for the token, Req against the BigQuery REST API (`jobs.query`, named parameters) |
| `postgres` | `postgres` | `url` (`postgres://user:password@host:5432/database`; `?sslmode=` honoured) | Postgrex, one connection per query |
| `clickhouse` | `clickhouse` | `url` (`http(s)://user:password@host:8123/database`; user and database default to `default`) | `ch` over the HTTP interface, one connection per query |

Each connector declares its credentials as `PixelAudit.Api.FieldSpec`s.
One declaration drives three things: the validation of what the API
receives (unknown keys refused, defaults filled in, errors keyed
`credentials.<key>`), the environment sync below, and the panel's form
(`GET /api/admin/v1/connections/types`).

`check/1` tries the credentials: Meta asks for the pixel by id, the three
databases run `SELECT 1`. The outcome is stored on the connection
(`last_checked_at`, `last_check_status`, `last_check_error`).

## Credentials at rest

`connections.credentials` is one map, JSON-encoded and encrypted with Cloak
(`PixelAudit.Api.Vault`, AES-GCM-256, cipher tag `AES.GCM.V1`) under the
key `CREDENTIALS_ENCRYPTION_KEY` — 64 hex characters, fixed in dev and
test, required in production. (Phoenix's own `WEB_SECRET_KEY_BASE`
plays no part in this; it signs the framework's tokens and cookies.) The
map never leaves the API: responses carry
`credential_keys` and `credentials_preview` (the non-secret values, a
URL among them with its password hidden), the
schema's `Inspect` skips the field, and the request logger filters
`credentials`. Losing the key makes every stored credential unreadable, so
it is backed up with the database. Rotation: add a `V2` cipher as the
vault's default, re-encrypt the table, drop `V1`.

## The environment (`boot`)

`PixelAudit.Api.Settings.EnvSync` maps `CONNECTION_*` variables (its
`Connections` half) and `VARIABLE_*` variables (`Variables`, see
`specs/variables.md`) onto rows — what the `boot` role does after
migrating (`mix boot`, `bin/boot` in the release, the chart's boot Job):

- `CONNECTION_<name>_TYPE` names the type (the env names above); `<name>`
  is the connection's name, letters and digits here so it fits a variable
  name and is free of `_`, which keeps `CONNECTION_shop_URL` unambiguous.
- `CONNECTION_<name>_<PARAM>` is a credential, `<PARAM>` the key upper-cased.
- The whole set — connections and variables together — is validated
  first (an unknown type, an unknown parameter, a missing required one)
  and nothing is written when any of it is wrong; the role exits non-zero
  with the problems listed. What passes is written in one transaction.
- The connection of that name is updated: type and credentials replaced
  whole, description kept. A new name is created. Both are
  `managed_by_env`: the API refuses a change of their name, type or
  credentials (`409 managed_by_env`); the description stays editable.
- A connection that was managed and is no longer in the environment is
  left in place, no longer marked — deleting it would take its data
  sources' cached counts along for what may be a typo.

## The gateway — the one way out

**Rule:** nothing in the application talks to an external system directly.
Every query a data source type runs, every HTTP request a connector makes
and every check goes through `PixelAudit.Api.Settings.Gateway` with the
`%Connection{}` it goes through — `Gateway.query(connection, sql, params)`
for the three databases (BigQuery included: to the rest of the application
it is a database), `Gateway.request(connection, %Req.Request{})` for an
API. A connector's own `query/3` is the driver and is called by the
gateway alone; `Req` is called by the gateway alone. The data source types,
the refresh jobs and the caches (`caching.md`) never reach past it.

The gateway records every call as a `settings_connection_calls` row
(`PixelAudit.Api.Settings.ConnectionCall`), whatever the outcome:

| Field | A `query` | An `api_call` |
|---|---|---|
| `started_at`, `duration_ms`, `status` (`ok`/`error`), `error` | both | both |
| `purpose` (`count`, `meta_stats_pull`, `check`), `date`, `refresh_run_id`, `data_source_id`, `step_id` — why it was made, from the capture it ran in (`provenance.md`) | both | both |
| `sql`, `params` (as JSON), `result` (every row) | ✓ | |
| `method`, `url`, `request_content_type`, `request_body`, `response_status`, `response_content_type`, `response_body` | | ✓ |

Credentials are never recorded: they travel in what the connector builds
(Meta's token as a bearer header, a driver's connection options), not in
the URL, the SQL or the bodies. Bodies and results are kept whole: the
record is the evidence the values computed from it cite. An HTTP answer
of 400 or above, or no answer, is an `error`; what a 200 means is the
connector's reading and not recorded.

The id is a UUIDv7 generated by Postgres (`uuidv7()`, Postgres 18), so
ids sort by time. The panel lists a connection's calls
(`GET /settings/connections/:id/calls`, newest first, paged, optionally
between two UTC days, of one purpose, or those that served one data
source, step or day) under its Queries or Calls tab, each with its
provenance, and shows one whole (`GET /settings/connections/:id/calls/:call_id`).
Nothing deletes a call: a cited one cannot go, and the rest are the
history of what the system did.

## Deleting

A connection a data source reads through cannot be deleted
(`409 connection_in_use`). Deleting one takes its cached Meta pixel stats
and its recorded calls with it.

## Meta pixel stats

A Meta connection has a cache of its pixel's hourly fire counts per event,
`connection_meta_pixel_stats`, filled from `GET /{pixel_id}/stats?aggregation=event`
by `PixelAudit.Api.Reporting.MetaPixelRefreshJob` — see `caching.md`. The
`meta_pixel_api` data source type counts from this cache, never from Meta
directly.
