import Config

# config/runtime.exs is executed for all environments, including
# during releases. It is executed after compilation and before the
# system starts, so it is typically used to load production configuration
# and secrets from environment variables or elsewhere. Do not define
# any compile-time configuration in here, as it won't be applied.

# ## Using releases
#
# If you use `mix release`, you need to explicitly enable the server
# by passing the PHX_SERVER=true when you start it:
#
#     PHX_SERVER=true bin/pixelaudit_api start
#
# rel/overlays/bin/server does exactly that (the image's `web` role).
if System.get_env("PHX_SERVER") do
  config :pixelaudit_api, PixelAudit.ApiWeb.Endpoint, server: true
end

config :pixelaudit_api, PixelAudit.ApiWeb.Endpoint,
  http: [port: String.to_integer(System.get_env("PORT", "4000"))]

# Browser origins allowed to call the API (CORS), comma-separated — e.g.
# CORS_ORIGINS=https://pixelaudit.example.com
# Optional: without it dev falls back to the list in config/dev.exs and
# other environments allow no cross-origin calls.
if cors_origins = System.get_env("CORS_ORIGINS") do
  origins =
    cors_origins
    |> String.split(",")
    |> Enum.map(&String.trim/1)
    |> Enum.reject(&(&1 == ""))

  config :pixelaudit_api, :cors_origins, origins
end

# The key the connection credentials are encrypted with
# (PixelAudit.Api.Vault): 256 bits as 64 hex characters. Read in every role —
# `boot` writes credentials from the environment, `web` reads them. Dev and
# test carry a fixed value in their config; production requires it (below).
# One set in the environment wins everywhere.
secret_key_hex = ~r/^[0-9a-fA-F]{64}$/

if secret_key = System.get_env("SECRET_KEY") do
  if not Regex.match?(secret_key_hex, secret_key) do
    raise """
    environment variable SECRET_KEY must be a 256-bit key as 64 hex characters.
    You can generate one by calling: openssl rand -hex 32
    """
  end

  config :pixelaudit_api, :secret_key, secret_key
end

if config_env() == :prod do
  database_url =
    System.get_env("DATABASE_URL") ||
      raise """
      environment variable DATABASE_URL is missing.
      For example: ecto://USER:PASS@HOST/DATABASE
      """

  maybe_ipv6 = if System.get_env("ECTO_IPV6") in ~w(true 1), do: [:inet6], else: []

  # libpq-style parameters in the URL's query, the form a managed database's
  # connection string comes in, mapped onto Postgrex options:
  #
  #   sslmode           disable | allow | prefer   no TLS (Postgrex cannot
  #                                                negotiate, so "prefer" —
  #                                                libpq's default — is plain)
  #                     require                    TLS, certificate not verified
  #                     verify-ca | verify-full    TLS, certificate verified
  #                                                against the system CA store
  #   application_name  the name the connections show in pg_stat_activity
  #
  # Both are taken out of the URL; whatever else is in the query is left to
  # Ecto's own URL parsing.
  database_uri = URI.parse(database_url)
  query = URI.decode_query(database_uri.query || "")
  {sslmode, query} = Map.pop(query, "sslmode", "prefer")
  {application_name, query} = Map.pop(query, "application_name")

  database_url =
    URI.to_string(%{
      database_uri
      | query: if(query == %{}, do: nil, else: URI.encode_query(query))
    })

  database_ssl =
    case sslmode do
      mode when mode in ~w(disable allow prefer) ->
        false

      "require" ->
        [verify: :verify_none]

      mode when mode in ~w(verify-ca verify-full) ->
        [
          verify: :verify_peer,
          cacerts: :public_key.cacerts_get(),
          server_name_indication: String.to_charlist(database_uri.host),
          customize_hostname_check: [
            match_fun: :public_key.pkix_verify_hostname_match_fun(:https)
          ]
        ]

      other ->
        raise "unsupported sslmode #{inspect(other)} in DATABASE_URL"
    end

  config :pixelaudit_api, PixelAudit.Api.Repo,
    ssl: database_ssl,
    url: database_url,
    parameters: [application_name: application_name || "pixelaudit-api"],
    pool_size: String.to_integer(System.get_env("DATABASE_POOL_SIZE") || "10"),
    socket_options: maybe_ipv6

  # The secret key base is used to sign/encrypt cookies and other secrets.
  # A default value is used in config/dev.exs and config/test.exs but you
  # want to use a different value for prod and you most likely don't want
  # to check this value into version control, so we use an environment
  # variable instead.
  secret_key_base =
    System.get_env("SECRET_KEY_BASE") ||
      raise """
      environment variable SECRET_KEY_BASE is missing.
      You can generate one by calling: mix phx.gen.secret
      """

  # Validated above; here it only has to exist.
  System.get_env("SECRET_KEY") ||
    raise """
    environment variable SECRET_KEY is missing.
    It is the 256-bit key the connection credentials are encrypted with, as 64 hex characters.
    You can generate one by calling: openssl rand -hex 32
    """

  # The public hostname the API is served under.
  host =
    System.get_env("HOSTNAME") ||
      raise """
      environment variable HOSTNAME is missing.
      It is the public hostname the API is served under, e.g. pixelaudit-api.example.com
      """

  config :pixelaudit_api, :dns_cluster_query, System.get_env("DNS_CLUSTER_QUERY")

  config :pixelaudit_api, PixelAudit.ApiWeb.Endpoint,
    url: [host: host, port: 443, scheme: "https"],
    http: [
      # Enable IPv6 and bind on all interfaces.
      ip: {0, 0, 0, 0, 0, 0, 0, 0}
    ],
    secret_key_base: secret_key_base
end
