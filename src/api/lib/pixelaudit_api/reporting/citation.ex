defmodule PixelAudit.Api.Reporting.Citation do
  @moduledoc """
  A stored value's trail to the outside: one row per call a value rests
  on — a daily count's query, or the Meta page that delivered a cached
  hour. The call cannot be deleted while cited (`specs/provenance.md`);
  the citations go with their value.
  """

  use Ecto.Schema

  @primary_key {:id, :binary_id, autogenerate: false, read_after_writes: true}
  @foreign_key_type :binary_id
  schema "reporting_citations" do
    belongs_to :daily_count, PixelAudit.Api.Reporting.DailyCount
    belongs_to :meta_pixel_stat, PixelAudit.Api.Settings.MetaPixelStat
    belongs_to :call, PixelAudit.Api.Settings.ConnectionCall
    field :inserted_at, :utc_datetime
  end
end
