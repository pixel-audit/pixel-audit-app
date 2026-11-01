# Funnels

A funnel (`funnels`: name, description) is a user journey as ordered
**steps** (`funnel_steps`: name,
description, `position`), measured by one or more **data sources**
(`funnel_data_sources`, each with a `color` — `#rrggbb`, dealt from a
palette of twelve when not given, the first not yet used in the funnel at
random — the panel draws it in), each of which carries, per step, the
**parameters** its type needs to count that step
(`funnel_step_parameters`, unique per data source and step, with an
optional `description` of how it counts it — the panel shows it as a
tooltip on the count in the report). A step with
no parameters for a data source is not measured by it and shows blank in
the report.

Steps and data sources are both ordered by `position`, from 0. Each is
appended at the end and reordered by sending every id in the wanted order
(`PUT /funnels/:id/steps/order` with `step_ids`,
`PUT /funnels/:id/data-sources/order` with `data_source_ids`; a list that
is not every one exactly once is `422 invalid_order`). Deleting one
compacts the positions. The report's table lists the data sources in that
order.

## Data source types

One module each under `PixelAudit.Api.Funnels.DataSourceType.*`,
declaring the connection type it reads through, its settings (per data
source) and its parameters (per step) as `FieldSpec`s — the panel renders
its forms from `GET /api/admin/v1/funnels/data-source-types` — and a
resolver `count(connection, settings, parameters, date_from, date_to)`.

| Type | Connection | Settings | Step parameters | Counts |
|---|---|---|---|---|
| `meta_pixel_api` | `meta` | — | `event_name` | the event's fires on the day, summed over the cached hours; a day with nothing cached is an error, not a zero |
| `google_analytics_bigquery` | `bigquery` | `dataset` (e.g. `analytics_123456789`) | `event_name`, `where` (extra SQL, optional) | `COUNT(*)` over `events_*` (and `events_intraday_*`) of the day's `_TABLE_SUFFIX` |
| `google_ads_bigquery` | `bigquery` | `dataset`, `customer_id` | `conversion_action_name`, `metric` (`conversions` / `all_conversions`) | `SUM` of the metric in `ads_ConversionStats_<customer_id>` joined to `ads_ConversionAction_<customer_id>` by resource name on the day's `segments_date` |
| `postgres_query` | `postgres` | — | `sql` | the query's one row, one number; `$1`/`$2` stand for the day and are replaced by typed `DATE '…'` literals before the query runs |
| `clickhouse_query` | `clickhouse` | — | `sql` | the query's one row, one number; `{date_from:Date}`/`{date_to:Date}` are the day |

Rules shared by every type:

- A data source's connection must be of the type's connection type
  (`422 connection_type_mismatch`); its settings are validated against the
  type's declaration (`settings.<key>`), its step parameters against the
  type's parameter declaration (`parameters.<key>`).
- **Counting is per day.** A resolver is always asked for one day
  (`date_from = date_to`); the report sums cached days over the range it
  shows. This is right for event counts and over-counts a query that
  counts distinct users over several days — the parameter form's hint
  says so.
- Dates reach BigQuery and ClickHouse as **bound parameters**. Postgres
  gets them as typed `DATE '…'` literals in place of `$1`/`$2`, because a
  bound parameter's type is inferred from its use and
  `created_at < $2 + 1` comes out as "timestamptz < integer"; the values
  are PixelAudit's own calendar days, formatted by it, so the literal is
  safe. Nothing a person typed is ever interpolated.
- A query must answer exactly one row with one number (an integer, a
  decimal or float rounded, or BigQuery's string of one); anything else is
  that day's error, stored and shown.
- A change to a data source's parameters (or to a data source that has
  parameters) enqueues a recomputation of its last seven days.

The Google Ads table layout is Google's BigQuery Data Transfer schema as
of writing; it is kept in that one module so a change there is one edit.

## The report

`GET /funnels/:id/report?date_from&date_to` (at most 366 days) answers
the steps, the data sources, and a cell per data source and step: the
`count` summed over the days that counted (`null` when the step is not
measured by the source, or no day counted yet), `days_ok`, `days_error`,
`days_missing` (never computed) and the last error; plus each data
source's step-to-step conversion rate. The panel draws the sankey and the
table from this — see `admin-panel.md`.
