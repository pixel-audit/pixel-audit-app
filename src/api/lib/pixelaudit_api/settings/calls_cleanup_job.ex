defmodule PixelAudit.Api.Settings.CallsCleanupJob do
  @moduledoc """
  Deletes the recorded connection calls older than the retention
  (`:connection_calls_retention_days`, 30 by default). Nightly, from the
  cron in config/config.exs; unique over an hour so a tick that fires
  twice runs once.
  """

  use Oban.Worker, queue: :default, max_attempts: 1, unique: [period: 3600]

  require Logger

  alias PixelAudit.Api.Settings

  @impl Oban.Worker
  def perform(_job) do
    days = Application.fetch_env!(:pixelaudit_api, :connection_calls_retention_days)
    before = DateTime.add(DateTime.utc_now(), -days, :day)
    deleted = Settings.delete_connection_calls_before(before)
    Logger.info("settings.calls_cleanup deleted=#{deleted} before=#{DateTime.to_iso8601(before)}")
    :ok
  end
end
