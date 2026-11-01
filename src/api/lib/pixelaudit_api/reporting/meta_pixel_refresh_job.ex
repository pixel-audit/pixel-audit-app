defmodule PixelAudit.Api.Reporting.MetaPixelRefreshJob do
  @moduledoc """
  Pulls a Meta connection's hourly pixel stats for a refresh run's date
  range into `settings_connection_meta_pixel_stats`. Queue `meta`, one at a time.

  Three attempts: Meta's API has bad minutes, and a failed hourly pull that
  is retried a little later is what keeps the cache gap-free. The run is
  marked failed on each failure and done on the attempt that succeeds.
  """

  use Oban.Worker, queue: :meta, max_attempts: 3

  require Logger

  alias PixelAudit.Api.Settings
  alias PixelAudit.Api.Settings.Connector.Meta
  alias PixelAudit.Api.Reporting

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"refresh_run_id" => run_id}}) do
    run = Reporting.get_refresh_run!(run_id)
    run = Reporting.start_run(run)
    connection = Settings.get_connection!(run.connection_id)

    start_time = DateTime.new!(run.date_from, ~T[00:00:00], "Etc/UTC")
    end_of_range = DateTime.new!(Date.add(run.date_to, 1), ~T[00:00:00], "Etc/UTC")
    end_time = Enum.min([end_of_range, DateTime.utc_now()], DateTime)

    result =
      try do
        with {:ok, rows} <- Meta.fetch_stats(connection.credentials, start_time, end_time) do
          stored = Settings.upsert_meta_pixel_stats(connection, rows)

          Logger.info(
            "reporting.meta_pixel refreshed connection=#{connection.id} from=#{run.date_from} to=#{run.date_to} rows=#{stored}"
          )

          :ok
        end
      rescue
        exception -> {:error, Exception.message(exception)}
      end

    Reporting.finish_run(run, result)

    case result do
      :ok ->
        :ok

      {:error, message} ->
        Logger.warning(
          "reporting.meta_pixel failed connection=#{connection.id} from=#{run.date_from} to=#{run.date_to} error=#{inspect(message)}"
        )

        {:error, message}
    end
  end
end
