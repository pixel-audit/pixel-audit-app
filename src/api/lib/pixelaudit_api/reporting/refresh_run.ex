defmodule PixelAudit.Api.Reporting.RefreshRun do
  @moduledoc """
  One refresh: either a pull of a Meta connection's pixel stats
  (`kind: :meta_pixel`) or a recomputation of a data source's daily counts
  (`kind: :data_source`), over a date range, with how it was triggered and
  how it went. The panel lists these; the Oban job behind one is an
  implementation detail (`oban_job_id`).
  """

  use Ecto.Schema

  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "reporting_refresh_runs" do
    field :kind, Ecto.Enum, values: [:meta_pixel, :data_source]
    belongs_to :connection, PixelAudit.Api.Settings.Connection
    belongs_to :funnel, PixelAudit.Api.Funnels.Funnel
    belongs_to :data_source, PixelAudit.Api.Funnels.DataSource
    field :date_from, :date
    field :date_to, :date
    field :trigger, Ecto.Enum, values: [:cron, :manual, :change]
    field :status, Ecto.Enum, values: [:queued, :running, :done, :failed], default: :queued
    field :started_at, :utc_datetime
    field :finished_at, :utc_datetime
    field :error, :string
    field :oban_job_id, :integer

    timestamps(type: :utc_datetime)
  end

  def changeset(run, attrs) do
    run
    |> cast(attrs, [
      :kind,
      :connection_id,
      :funnel_id,
      :data_source_id,
      :date_from,
      :date_to,
      :trigger,
      :status,
      :oban_job_id
    ])
    |> validate_required([:kind, :date_from, :date_to, :trigger])
  end

  def started(run), do: change(run, status: :running, started_at: DateTime.utc_now(:second))

  def finished(run, :ok),
    do: change(run, status: :done, finished_at: DateTime.utc_now(:second), error: nil)

  def finished(run, {:error, message}),
    do:
      change(run,
        status: :failed,
        finished_at: DateTime.utc_now(:second),
        error: String.slice(to_string(message), 0, 2000)
      )
end
