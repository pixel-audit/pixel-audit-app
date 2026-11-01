defmodule PixelAudit.Api.Reporting.DailyCount do
  @moduledoc """
  One data source's count of one funnel step on one day — the cache the
  report is drawn from. `status: :error` keeps the resolver's message in
  `error` and no count, so the report can say a day is missing rather than
  show a zero.
  """

  use Ecto.Schema

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "reporting_daily_counts" do
    belongs_to :data_source, PixelAudit.Api.Funnels.DataSource
    belongs_to :step, PixelAudit.Api.Funnels.Step
    belongs_to :refresh_run, PixelAudit.Api.Reporting.RefreshRun
    field :date, :date
    field :count, :integer
    field :status, Ecto.Enum, values: [:ok, :error]
    field :error, :string
    field :computed_at, :utc_datetime
  end
end
