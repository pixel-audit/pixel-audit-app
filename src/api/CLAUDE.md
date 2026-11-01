# src/api

The Phoenix API. `AGENTS.md` beside this file carries the framework and
language guidelines; the repository's `specs/` carry the domain. What is
here are the project's own rules of placement.

## Code lives with the functionality it serves

- **No `PixelAudit.Api.Workers` namespace.** An Oban worker is part of the
  context whose work it does, and lives in that context's directory under
  that context's namespace: the refresh jobs are
  `PixelAudit.Api.Reporting.RefreshJob`, `...MetaPixelRefreshJob` and the
  cron entry point `...Schedule`, all in `lib/pixelaudit_api/reporting/`.
  A worker is an entry point into a context, like a controller action, not a
  category of its own.
- **A connector is a module per connection type** under
  `PixelAudit.Api.Connections.Connector.*`, implementing the behaviour in
  `connections/connector.ex`; it declares its credentials as
  `PixelAudit.Api.FieldSpec`s, which drive the env sync, the validation and
  the panel's form at once. A new connection type is one module plus its
  entry in `Connector.all/0`.
- **A data source type is a module per type** under
  `PixelAudit.Api.Funnels.DataSourceType.*`: its connection type, settings,
  step parameters and the resolver that counts one step for one day. A new
  type is one module plus its entry in `DataSourceType.all/0`.
- **Counts are per day.** A resolver is always asked for one day
  (`date_from = date_to`); the report sums cached days. SQL resolvers bind
  the dates as parameters — never interpolate them.
- **Credentials never leave the API.** `connections.credentials` is a
  Cloak-encrypted map; JSON views render `credential_keys` and the
  non-secret `credentials_preview` only, and `Inspect` skips the field.

## The API

- One API, `/api/admin/v1`, `snake_case`, no authentication (specs/api.md).
- Every operation has an `operation_id` of the form `admin.verbNoun` and
  named schema modules under `PixelAudit.ApiWeb.OpenApi.Schemas` — orval
  derives the panel's types from them, so inline anonymous schemas in a
  response are a bug.
- `{:error, atom}` from a context is mapped to a status once, in
  `PixelAudit.ApiWeb.FallbackController`; a new reason is added there with
  a comment saying why it is a 409 or a 422.
- Validation errors of a field inside a declared map are keyed
  `credentials.<key>`, `settings.<key>`, `parameters.<key>`.
