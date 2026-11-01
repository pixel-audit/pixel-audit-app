defmodule PixelAudit.Api.Reporting.Schedule do
  @moduledoc """
  The cron entry points (config/config.exs): each one only decides what to
  refresh and enqueues the runs.

    * `meta_hourly` — every Meta connection, the last two days.
    * `nightly` — every Meta connection for Meta's whole window, then every
      data source of every funnel for yesterday and the day before.

  Queue `default`; unique over five minutes so a cron tick that fires twice
  (two nodes) enqueues once.
  """

  use Oban.Worker, queue: :default, max_attempts: 1, unique: [period: 300, keys: [:scope]]

  require Logger

  alias PixelAudit.Api.{Funnels, Reporting, Settings}

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"scope" => "meta_hourly"}}) do
    today = Date.utc_today()
    refresh_meta(Date.add(today, -1), today)
    :ok
  end

  def perform(%Oban.Job{args: %{"scope" => "nightly"}}) do
    today = Date.utc_today()
    backfill = Application.fetch_env!(:pixelaudit_api, :backfill_days)
    refresh_meta(Date.add(today, -backfill), today)

    yesterday = Date.add(today, -1)
    date_from = Date.add(yesterday, -1)

    for funnel <- Funnels.list_funnels(), data_source <- funnel.data_sources do
      {:ok, _run} = Reporting.refresh_data_source(data_source, date_from, yesterday, :cron)
    end

    Logger.info("reporting.schedule nightly enqueued from=#{date_from} to=#{yesterday}")
    :ok
  end

  defp refresh_meta(date_from, date_to) do
    for connection <- Settings.list_meta_connections() do
      {:ok, _run} = Reporting.refresh_meta_connection(connection, date_from, date_to, :cron)
    end
  end
end
