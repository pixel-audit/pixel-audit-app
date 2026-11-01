import Config

# Configure your database — the postgres service of docker-compose.yml at the
# repository root (port 15460). POSTGRES_PORT points elsewhere, e.g. at a
# local Postgres.app.
postgres_port = System.get_env("POSTGRES_PORT", "15460") |> String.to_integer()

config :pixelaudit_api, PixelAudit.Api.Repo,
  username: System.get_env("POSTGRES_USER", "postgres"),
  password: System.get_env("POSTGRES_PASSWORD", "postgres"),
  hostname: "localhost",
  port: postgres_port,
  database: "pixelaudit_api_dev",
  stacktrace: true,
  show_sensitive_data_on_connection_error: true,
  pool_size: 10

# For development, we disable any cache and enable
# debugging and code reloading.
config :pixelaudit_api, PixelAudit.ApiWeb.Endpoint,
  # Binding on all interfaces, so the panel can be opened from another
  # machine on the network during development.
  http: [ip: {0, 0, 0, 0}],
  check_origin: false,
  code_reloader: true,
  debug_errors: true,
  secret_key_base: "syPwU+OUWyzbvdsZRHyp/M3l9npMThw0xetdYGwQi8evL4KSP7pMxoYKah+4GJUi",
  watchers: []

# The key the connection credentials are encrypted with
# (PixelAudit.Api.Vault). A fixed value here, so a dev database keeps
# working across restarts; production reads SECRET_KEY in config/runtime.exs.
config :pixelaudit_api,
       :secret_key,
       "0f1e2d3c4b5a69788796a5b4c3d2e1f00112233445566778899aabbccddeeff0"

# The panel's dev server — allowed to call the API from the browser (CORS).
# The port matches src/admin/vite.config.ts.
config :pixelaudit_api, :cors_origins, ["http://localhost:16001"]

# Rebuild the OpenAPI document on every request. The default cache keeps
# the first built spec for the VM's lifetime — surviving code reloading, so
# `make openapi-generate` against a running dev server would see a stale
# document after any spec change.
config :open_api_spex, cache_adapter: OpenApiSpex.Plug.NoneCache

# Enable dev routes
config :pixelaudit_api, dev_routes: true

# Do not include metadata nor timestamps in development logs
config :logger, :default_formatter, format: "[$level] $message\n"

# Set a higher stacktrace during development. Avoid configuring such
# in production as building large stacktraces may be expensive.
config :phoenix, :stacktrace_depth, 20

# Initialize plugs at runtime for faster development compilation
config :phoenix, :plug_init_mode, :runtime
