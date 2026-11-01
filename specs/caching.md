# Caching and refreshes

Everything the report shows comes from a cache of daily values, filled by
background jobs (Oban, Postgres-backed). Two layers:

1. **Meta pixel stats** (`connection_meta_pixel_stats`): one row per Meta
   connection, day, hour and event name, as `GET /{pixel_id}/stats?aggregation=event`
   reports them (UTC). Meta serves about the **last seven days** per
   request, so this copy is what lets a funnel go back further.
2. **Daily counts** (`reporting_daily_counts`): one row per data source,
   step and day — the count, or the resolver's error — computed by the data
   source type's resolver (`funnels.md`). The report sums the `ok` days of
   a range.

## Refresh runs

Every refresh is a row of `reporting_refresh_runs` (`kind`: `meta_pixel`
or `data_source`; the connection, funnel and data source it concerns; the
date range; `trigger`: `cron`, `manual` or `change`; `status`: `queued`,
`running`, `done`, `failed`; the timestamps and the error) and an Oban job
that carries the run's id. The panel lists the runs
(`GET /reporting/refresh-runs`, filtered by funnel, connection, data
source, status, kind) and polls while any is queued or running; a run's
days (`GET /reporting/refresh-runs/:id/days`) are the daily-count rows it
wrote, each with its step, count or error.

| Job | Queue | What it does |
|---|---|---|
| `Reporting.MetaPixelRefreshJob` | `meta` (1 at a time; Meta rate-limits per token) | pulls the connection's hourly stats for the range and upserts them; 3 attempts |
| `Reporting.RefreshJob` | `refresh` (3 at a time) | for every step the data source measures and every day of the range, asks the resolver and upserts the day; 1 attempt (each day's outcome is stored as it comes); marks the run `failed` when any day failed, naming how many and the first error |
| `Reporting.Schedule` | `default` | the cron entry point: enqueues the runs below |
| `Settings.CallsCleanupJob` | `default` | deletes the recorded connection calls (`connections.md`, the gateway) older than 30 days |

A `RefreshJob` for a `meta_pixel_api` data source **snoozes** while a pull
of its connection's stats is queued or running, so it reads the fresh copy.

## When

| Trigger | What |
|---|---|
| every hour at :15 (`meta_hourly`) | every Meta connection, the last two days — a late-counted hour is picked up |
| every night at 04:45 UTC | the recorded connection calls older than 30 days are deleted |
| every night at 03:30 UTC (`nightly`) | every Meta connection for the last seven days; then every data source of every funnel for yesterday and the day before (two days, so a late export or a day that failed heals) |
| a Meta connection is created | its last seven days |
| a data source's parameters change (or a data source with parameters is edited) | the data source's last seven days |
| `POST /funnels/:id/refresh` (optionally one data source) | every data source of the funnel over the given range, a Meta source's connection pulled first |
| `POST /connections/:id/refresh` (Meta only) | the connection's stats over the given range |

Ranges are at most 366 days. Days are UTC calendar days: Meta's stats are
hourly UTC, GA4's export days are the property's, a SQL query's are
whatever it does with the bound dates — so day-level comparison across
sources is approximate around midnight; nothing here tries to align them.

## Retention

The Meta stats and the daily counts are never pruned: they are small (one
row per event-hour, one per step-day) and are the history the product
exists to keep. The recorded connection calls are kept 30 days
(`connection_calls_retention_days`); Oban's own job rows seven days.

Every read of an external system a job makes — a query, a Meta page —
goes through the gateway (`connections.md`), never through a connector
directly, so each is recorded on its connection.
