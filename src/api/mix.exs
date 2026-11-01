defmodule PixelAudit.Api.MixProject do
  use Mix.Project

  def project do
    [
      app: :pixelaudit_api,
      version: "0.1.0",
      package: [licenses: ["AGPL-3.0-only"]],
      elixir: "~> 1.17",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      aliases: aliases(),
      deps: deps(),
      listeners: [Phoenix.CodeReloader]
    ]
  end

  # Configuration for the OTP application.
  #
  # Type `mix help compile.app` for more information.
  def application do
    [
      mod: {PixelAudit.Api.Application, []},
      extra_applications: [:logger, :runtime_tools]
    ]
  end

  def cli do
    [
      preferred_envs: [precommit: :test]
    ]
  end

  # Specifies which paths to compile per environment.
  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  # Specifies your project dependencies.
  #
  # Type `mix help deps` for examples and options.
  defp deps do
    [
      {:phoenix, "~> 1.8.12"},
      {:phoenix_ecto, "~> 4.5"},
      {:ecto_sql, "~> 3.13"},
      {:postgrex, ">= 0.0.0"},
      {:telemetry_metrics, "~> 1.0"},
      {:telemetry_poller, "~> 1.0"},
      {:jason, "~> 1.2"},
      {:dns_cluster, "~> 0.2.0"},
      {:bandit, "~> 1.5"},
      # Browser origins of the admin panel's dev server and deployments.
      {:corsica, "~> 2.1"},
      # The OpenAPI document the admin panel's client is generated from.
      {:open_api_spex, "~> 3.21"},
      # Background jobs: the hourly Meta pixel pull, the nightly recomputation
      # of the daily counts, and the manual refreshes. Postgres-backed, so
      # jobs share the Repo and need no extra infrastructure.
      {:oban, "~> 2.24"},
      # The one HTTP client (Meta Graph API, BigQuery REST API); avoid any other.
      {:req, "~> 0.5"},
      # Google service-account tokens for BigQuery.
      {:goth, "~> 1.4"},
      # ClickHouse client (Plausible's), with typed query parameters.
      {:ch, "~> 0.3"},
      # Connection credentials encrypted at rest (PixelAudit.Api.Vault).
      {:cloak, "~> 1.1"},
      {:cloak_ecto, "~> 1.3"}
    ]
  end

  # Aliases are shortcuts or tasks specific to the current project.
  # For example, to install project dependencies and perform other setup tasks, run:
  #
  #     $ mix setup
  #
  # See the documentation for `Mix` for more info on aliases.
  defp aliases do
    [
      setup: ["deps.get", "ecto.setup"],
      "ecto.setup": ["ecto.create", "ecto.migrate"],
      # The `boot` role (docker/entrypoint.sh) in development: create, migrate,
      # then map the CONNECTION_* environment onto connection rows.
      boot: ["ecto.create", "ecto.migrate", "run priv/repo/boot.exs"],
      "ecto.reset": ["ecto.drop", "ecto.setup"],
      test: ["ecto.create --quiet", "ecto.migrate --quiet", "test"],
      precommit: ["compile --warnings-as-errors", "deps.unlock --unused", "format", "test"]
    ]
  end
end
