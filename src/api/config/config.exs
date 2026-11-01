# This file is responsible for configuring your application
# and its dependencies with the aid of the Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
import Config

config :pixelaudit_api,
  namespace: PixelAudit.Api,
  ecto_repos: [PixelAudit.Api.Repo],
  generators: [timestamp_type: :utc_datetime, binary_id: true],
  # Where the panel is served — the one browser origin allowed to call the
  # API out of the box. config/dev.exs and CORS_ORIGINS (config/runtime.exs)
  # extend the list.
  cors_origins: [],
  # The longest one connector call (Meta, BigQuery, a SQL query) may take.
  connector_timeout_ms: 60_000,
  # A manual or scheduled refresh covers at most this many days at once.
  max_refresh_days: 366,
  # How far back a freshly added Meta connection or data source is filled in.
  # Meta serves roughly the last seven days of pixel stats, so there is no
  # point asking for more.
  backfill_days: 7

# Every connection announces itself to Postgres (pg_stat_activity's
# application_name) as pixelaudit-api. config/runtime.exs sets the same for
# releases, where a DATABASE_URL may override it.
config :pixelaudit_api, PixelAudit.Api.Repo, parameters: [application_name: "pixelaudit-api"]

# Background jobs. Three queues because the work has different shapes:
#
#   * `meta` runs one job at a time: Meta's Graph API rate-limits per token,
#     and the hourly pull is small.
#   * `refresh` recomputes daily counts, one job per data source and range;
#     three at once keeps a slow BigQuery job from blocking a quick SQL one.
#   * `default` is for the cron entry points that only enqueue other jobs.
#
# Cron times are UTC.
config :pixelaudit_api, Oban,
  engine: Oban.Engines.Basic,
  repo: PixelAudit.Api.Repo,
  queues: [default: 5, refresh: 3, meta: 1],
  plugins: [
    {Oban.Plugins.Pruner, max_age: 7 * 24 * 60 * 60},
    # A node that dies mid-job leaves it `executing` forever without this.
    {Oban.Plugins.Lifeline, rescue_after: :timer.minutes(30)},
    {Oban.Plugins.Cron,
     crontab: [
       # Meta keeps about seven days of pixel stats; the last two days are
       # pulled every hour so a late-counted hour is picked up.
       {"15 * * * *", PixelAudit.Api.Reporting.Schedule, args: %{scope: "meta_hourly"}},
       # The nightly run: the full Meta window, then yesterday and the day
       # before for every data source (two days, so a late export or a
       # failed day heals itself).
       {"30 3 * * *", PixelAudit.Api.Reporting.Schedule, args: %{scope: "nightly"}}
     ]}
  ]

# Configure the endpoint
config :pixelaudit_api, PixelAudit.ApiWeb.Endpoint,
  url: [host: "localhost"],
  adapter: Bandit.PhoenixAdapter,
  render_errors: [
    formats: [json: PixelAudit.ApiWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: PixelAudit.Api.PubSub,
  live_view: [signing_salt: "0foStBY0"]

# Configure Elixir's Logger
config :logger, :default_formatter,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

# Credentials must never reach a request log: Phoenix's parameter logger
# replaces these keys with "[FILTERED]" wherever they appear.
config :phoenix, :filter_parameters, ["credentials", "password", "token", "access_token"]

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"
