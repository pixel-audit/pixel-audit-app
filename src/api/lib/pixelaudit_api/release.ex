defmodule PixelAudit.Api.Release do
  @moduledoc """
  Database tasks for a running release, where Mix is not available.

  Each function is what one of the release's `bin/*` scripts
  (`rel/overlays/bin`) runs through `bin/pixelaudit_api eval`; the Docker
  image exposes them as the roles `migrate` and `boot` (see the Dockerfile
  and `docker/entrypoint.sh`). `boot` mirrors the `mix boot` alias:
  create + migrate + map the `CONNECTION_*` environment onto connections.
  """

  @app :pixelaudit_api

  @doc "Runs all pending migrations on every repo (`mix ecto.migrate`)."
  def migrate do
    load_app()

    for repo <- repos() do
      {:ok, _, _} = Ecto.Migrator.with_repo(repo, &Ecto.Migrator.run(&1, :up, all: true))
    end
  end

  @doc "Rolls a repo back to the given migration version."
  def rollback(repo, version) do
    load_app()
    {:ok, _, _} = Ecto.Migrator.with_repo(repo, &Ecto.Migrator.run(&1, :down, to: version))
  end

  @doc """
  Creates the database when it does not exist yet (`mix ecto.create`).

  A database that is already there is not an error: `boot` is meant to be
  safe to run on every deploy.
  """
  def create do
    load_app()

    for repo <- repos() do
      case repo.__adapter__().storage_up(repo.config()) do
        :ok ->
          :ok

        {:error, :already_up} ->
          :ok

        {:error, reason} ->
          raise "could not create the database for #{inspect(repo)}: #{inspect(reason)}"
      end
    end
  end

  @doc """
  The `boot` role: create + migrate + `PixelAudit.Api.Connections.EnvSync`.

  The env sync runs under the started application — the vault encrypts the
  credentials it writes — with Oban's queues and plugins off: nothing is to
  run in a one-off container that exits as soon as the sync is through.
  A malformed `CONNECTION_*` set stops the container with a non-zero exit
  and the problems on stderr, so a deploy fails loudly instead of with a
  connection silently missing.
  """
  def boot do
    create()
    migrate()

    oban = Application.fetch_env!(@app, Oban) |> Keyword.merge(queues: false, plugins: false)
    Application.put_env(@app, Oban, oban)
    {:ok, _started} = Application.ensure_all_started(@app)

    case PixelAudit.Api.Connections.EnvSync.run() do
      {:ok, _results} ->
        :ok

      {:error, problems} ->
        IO.puts(
          :stderr,
          "The CONNECTION_* environment is invalid:\n" <> Enum.join(problems, "\n")
        )

        System.halt(1)
    end
  end

  defp repos do
    Application.fetch_env!(@app, :ecto_repos)
  end

  defp load_app do
    # Many platforms require SSL when connecting to the database
    Application.ensure_all_started(:ssl)
    Application.ensure_loaded(@app)
  end
end
