defmodule PixelAudit.Api.Settings.MetaPixelStat do
  @moduledoc """
  One hour of one event's fire count on a Meta pixel, as its Graph API
  reported it — PixelAudit's own copy, because Meta keeps about seven days
  and this needs to go back as far as the funnels do.

  Filled by `PixelAudit.Api.Reporting.MetaPixelRefreshJob`, read by the
  `meta_pixel_api` data source type.
  """

  use Ecto.Schema

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "settings_connection_meta_pixel_stats" do
    belongs_to :connection, PixelAudit.Api.Settings.Connection
    field :date, :date
    field :hour, :integer
    field :event_name, :string
    field :count, :integer

    has_many :citations, PixelAudit.Api.Reporting.Citation

    timestamps(type: :utc_datetime, updated_at: false)
  end
end
