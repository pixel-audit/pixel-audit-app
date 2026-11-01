import Config

# Configure your database
#
# The MIX_TEST_PARTITION environment variable can be used
# to provide built-in test partitioning in CI environment.
# Run `mix help test` for more information.
postgres_port = System.get_env("POSTGRES_PORT", "15460") |> String.to_integer()

config :pixelaudit_api, PixelAudit.Api.Repo,
  username: System.get_env("POSTGRES_USER", "postgres"),
  password: System.get_env("POSTGRES_PASSWORD", "postgres"),
  hostname: "localhost",
  port: postgres_port,
  database: "pixelaudit_api_test#{System.get_env("MIX_TEST_PARTITION")}",
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: System.schedulers_online() * 2

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :pixelaudit_api, PixelAudit.ApiWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "Xiyvjzys9dI9aPm9lsppfjQtKF9lz+SW4KMK+RxFnsac5as1fJ1b3uXCdZvqXcCj",
  server: false

# A fixed Cloak key for the test database.
config :pixelaudit_api,
       :credentials_encryption_key,
       "ffeeddccbbaa99887766554433221100ffeeddccbbaa99887766554433221100"

# Jobs are inserted, never run, unless a test performs them by hand
# (Oban.Testing).
config :pixelaudit_api, Oban, testing: :manual

# The Meta and BigQuery clients go through Req.Test stubs, by the name of
# the connector; a test that does not stub them gets a 500 from the stub.
config :pixelaudit_api, :req_options, plug: {Req.Test, PixelAudit.Api.Connections.Connector}

# BigQuery's bearer token comes from here instead of Google, so no
# service-account exchange happens in tests.
config :pixelaudit_api, :bigquery_token, "test-token"

# Print only warnings and errors during test
config :logger, level: :warning

# Initialize plugs at runtime for faster test compilation
config :phoenix, :plug_init_mode, :runtime

# Sort query params output of verified routes for robust url comparisons
config :phoenix,
  sort_verified_routes_query_params: true
