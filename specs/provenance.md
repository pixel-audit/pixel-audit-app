# Provenance — where every value comes from

The requirement below is binding; what follows it is how the system
meets it.

## The requirement

**Every value the panel shows can be traced, from the panel, to the
external call or calls that produced it** — the exact query or request as
it was sent (parameters included), what came back whole, when it was
made, how long it took, through which connection, and by which refresh
run — and **a call a stored value cites is never deleted.** A value is a
daily count (`reporting_daily_counts`), a cached Meta hour
(`connection_meta_pixel_stats`), and everything derived from them: a cell
of the report, a point on a step's chart, a conversion rate. A value that
is derived from other stored values (a Meta day from its cached hours)
cites those values' calls, so the trail reaches the external system
whatever the depth. Nothing in the system is a number whose origin has to
be guessed.

What this rules out: a cache row written without the id of the call that
filled it; a resolver that reaches an external system other than through
the gateway (`connections.md` already forbids it); a log truncated so the
cited answer is incomplete; a retention rule that removes a cited call.

## The data model

### Citations — a value's calls

A link table rather than a column, because a value may rest on several
calls (a Meta day on the pages that delivered its hours; a resolver that
runs two queries) and a call may serve several values (one page of Meta
stats carries many hours):

```
reporting_citations  (PixelAudit.Api.Reporting.Citation)
  id                  uuid (uuidv7)
  daily_count_id      uuid  → reporting_daily_counts                ON DELETE CASCADE   one of
  meta_pixel_stat_id  uuid  → settings_connection_meta_pixel_stats  ON DELETE CASCADE   the two
  call_id             uuid  → settings_connection_calls             ON DELETE NO ACTION
  inserted_at
  check num_nonnulls(daily_count_id, meta_pixel_stat_id) = 1
  unique (daily_count_id, call_id); unique (meta_pixel_stat_id, call_id); index (call_id)
```

The foreign key to the call is the requirement in the schema: Postgres
refuses to delete a cited call, whoever asks. `NO ACTION` rather than
`RESTRICT` because the check runs at the end of the statement: a
connection's deletion takes its Meta hours, their citations and its calls
in one statement, and goes through. A value's citations are replaced
whole each time the value is recomputed (the old call stays in the log,
no longer cited). Deleting a value (its data source, step or connection
goes) deletes its citations with it, and the calls it cited then become
deletable — the trail of a value that no longer exists is not kept.

### The call carries its context

`settings_connection_calls` gains **why** it was made, so the connection's
Calls tab can say it and a call can be found from either end:

```
  refresh_run_id   uuid  → reporting_refresh_runs  ON DELETE SET NULL   nullable
  data_source_id   uuid  → funnel_data_sources     ON DELETE SET NULL   nullable
  step_id          uuid  → funnel_steps            ON DELETE SET NULL   nullable
  date             date                                                  nullable: the day being counted
  purpose          text   'count' | 'meta_stats_pull' | 'check'
```

The gateway does not learn these from its callers' signatures. It reads a
**call context** held in the process: `Gateway.capture(%{purpose: :count,
refresh_run_id: …, data_source_id: …, step_id: …, date: …}, fn -> … end)`,
which `RefreshJob` sets around each resolver call, `MetaPixelRefreshJob`
around the pull (`purpose: :meta_stats_pull`) and the check around the
check (`purpose: :check`). Captures nest, the inner keeping what the
outer set. A resolver's code does not know; a connector's does not
either.

### Capturing what a computation cited

The same capture **collects** what the computation rested on, and
answers it with the result — `{result, call_ids}`, oldest first, without
repeats:

- every call the gateway records inside the capture;
- what a read of cached rows cites: `Settings.meta_pixel_day_count/3`
  cites the calls behind the hours it summed (`Gateway.cite(call_ids)`), so
  a Meta day's daily count cites the pages that delivered its hours — the
  derived value inherits the trail.

`Reporting.put_daily_count/6` takes the cited call ids and writes the
citations in the same transaction as the count. `Settings.upsert_meta_pixel_stats/2`
takes, per row, the call that delivered it (the Meta connector's
`fetch_stats` returns each parsed hour with the id of its page's call,
read from `Gateway.last_call_id/0` after each page) and writes the
citation per upserted hour, in place of what the hour cited before.

### The record is the evidence, whole

The gateway stores the request and the response **whole**: nothing is
cut. A count query answers one row; a Meta stats page is a few hundred
KiB at most. Postgres's TOAST compresses `text` and `jsonb` out of line,
so the table's size is the compressed bodies.
`settings_connection_calls.result` keeps the rows as JSON.

### Retention

Nothing deletes calls on age: there is no cleanup job and no retention
setting. The schema would stop one deleting a cited call anyway; an
uncited call (a check, a failed query recomputed since, a Meta page
superseded by the next hourly pull) stays too — it is the history of
what the system did.

Growth, so this is a decision and not a surprise: a count query is one
call per data source, step and day computed (nightly, two days per
source-step: ~2 calls a day per measured cell, ~1 KiB each: a hundred
measured cells make ~70 k calls, ~100 MB, a year); a Meta connection's
hourly pull is 24 pages a day of ~100 KiB, ~1 GB a year per connection,
of which only the latest pull of each hour is cited. If that ever matters,
the rule to add is **"delete uncited calls older than N days"** — the
requirement allows it, the age-only rule it never did. It is not added:
everything stays in the database.

### What a refresh can target

A refresh run has an optional `step_id`: `POST /funnels/:id/refresh`
takes `step_id` beside `data_source_id` (a step the funnel has not is
`404`), and `RefreshJob` computes that one step when it is set. A single
day is a range of one day. The dialog below refreshes one day or the
whole range of one source and step through this; a Meta source's
connection is pulled first.

## The API

`GET /funnels/:id/data-sources/:data_source_id/steps/:step_id/days?date_from&date_to`
— the trail of one cell of the report, a row per day of the range:

| Field | |
|---|---|
| `date`, `count`, `status` (`ok`/`error`/`missing`), `error`, `computed_at` | the daily count as stored; a missing day has nulls |
| `refresh_run` | `{id, trigger, status, started_at, finished_at}` — the run that wrote it |
| `calls` | the cited calls, oldest first: `{id, kind, purpose, connection: {id, name, type}, started_at, duration_ms, status, error, sql, params, result, method, url, request_content_type, request_body, response_status, response_content_type, response_body}` — the whole record, nothing cut |

Every call the API answers — in the trail, in `GET /settings/connections/:id/calls`
and in `GET /settings/connections/:id/calls/:call_id` (one call, whole)
— carries its provenance: `purpose`, `date`, `refresh_run_id`,
`data_source` and `step` (why it was made), its `connection`, and
`cited_by`: the daily counts that rest on it (each with its data source,
step, day, count and status) and how many cached Meta hours. The calls
list takes `purpose`, `data_source_id`, `step_id` and `date` (the day
counted) as filters beside the days the calls were made on, so the trail
is walked from the connection's end too.

## The panel

**A count is a button.** In the counts table (`FunnelCountsTable`) and in
the step page's totals, a count — the number itself, dash and ellipsis
included — opens the **trail dialog** for that data source and step over
the shown range:

- the title names the source and the step; the range under it;
  **Refresh all** on the right queues a run of this source and step over
  the range (`POST …/refresh` with both ids);
- a row per day: the date, the count or the error, **computed at**
  (relative, the exact time on hover), the refresh run (a link to its
  page), **Refresh** for the one day, and a chevron;
- the row opens to its calls, each a block: the connection (a link to its
  Calls tab, narrowed to the calls that served this source, step and
  day), when and how long; then the query **as it ran** (the SQL with the
  day's literals in place, monospace) with its parameters, or the
  request's method, URL and body; then the result rows or the response
  body — each block with a **Copy** button that copies the text whole. A
  Meta day shows the pages behind its hours;
- while a refresh of the source is queued or running the dialog polls
  the runs and, when the run ends, reads the days, the report and the
  step's series again.

The connection's Calls tab shows each call's provenance under it — its
purpose, the data source and step it served, the day, a link to its
refresh run, and what cites it — with a purpose filter beside the days,
and the same Copy buttons on the exchange.

**No backfill.** A value computed before calls were cited has no
citations; the dialog says so for it ("computed before calls were
kept") and a refresh of the day records its call. The nightly recompute
replaces the recent days.
