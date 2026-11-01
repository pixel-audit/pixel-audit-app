# Connections

A connection holds the credentials for one external system under a short
code. Four types, one connector module each
(`PixelAudit.Api.Connections.Connector.*`):

| Type | `CONNECTION_<id>_TYPE` | Credentials | Client |
|---|---|---|---|
| `meta_api` | `meta-api` | `access_token` (secret), `pixel_id`, `api_version` (default `v25.0`) | Req against `graph.facebook.com` |
| `bigquery` | `bigquery` | `credentials_json` (secret; the service account key, JSON or base64), `project_id`, `location` | Goth for the token, Req against the BigQuery REST API (`jobs.query`, named parameters) |
| `postgres` | `postgres` | `database_url` (secret; `?sslmode=` honoured) | Postgrex, one connection per query |
| `clickhouse` | `clickhouse` | `url`, `database`, `username`, `password` (secret) | `ch` over the HTTP interface, one connection per query |

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
key `SECRET_KEY` — 64 hex characters, fixed in dev and test, required in
production. The map never leaves the API: responses carry
`credential_keys` and `credentials_preview` (the non-secret values), the
schema's `Inspect` skips the field, and the request logger filters
`credentials`. Losing the key makes every stored credential unreadable, so
it is backed up with the database. Rotation: add a `V2` cipher as the
vault's default, re-encrypt the table, drop `V1`.

## The environment (`boot`)

`PixelAudit.Api.Connections.EnvSync` maps `CONNECTION_*` variables onto
rows — what the `boot` role does after migrating (`mix boot`,
`bin/boot` in the release, the chart's boot Job):

- `CONNECTION_<id>_TYPE` names the type (the env names above); `<id>` is
  the code, lowercase so it fits a variable name and free of `_`, which
  keeps `CONNECTION_shop_DATABASE_URL` unambiguous.
- `CONNECTION_<id>_<PARAM>` is a credential, `<PARAM>` the key upper-cased.
- The whole set is validated first — an unknown type, an unknown
  parameter, a missing required one — and nothing is written when any of
  it is wrong; the role exits non-zero with the problems listed.
- An existing code is updated: type and credentials replaced whole, name
  and description kept. A new code is created, named after itself. Both
  are `managed_by_env`: the API refuses a change of their type or
  credentials (`409 managed_by_env`); name and description stay editable.
- A connection that was managed and is no longer in the environment is
  left in place, no longer marked — deleting it would take its data
  sources' cached counts along for what may be a typo.

## Deleting

A connection a data source reads through cannot be deleted
(`409 connection_in_use`). Deleting one takes its cached Meta pixel stats
with it.

## Meta pixel stats

A Meta connection has a cache of its pixel's hourly fire counts per event,
`connection_meta_pixel_stats`, filled from `GET /{pixel_id}/stats?aggregation=event`
by `PixelAudit.Api.Reporting.MetaPixelRefreshJob` — see `caching.md`. The
`meta_pixel_api` data source type counts from this cache, never from Meta
directly.
