defmodule PixelAudit.Api.Funnels.DataSourceType.MetaPixelApi do
  @moduledoc """
  A step is a Meta pixel event, counted from PixelAudit's own copy of the
  pixel's hourly stats (`PixelAudit.Api.Connections.MetaPixelStat`) — never
  from Meta directly, which only keeps about a week.
  """

  @behaviour PixelAudit.Api.Funnels.DataSourceType

  import PixelAudit.Api.FieldSpec, only: [field: 2]

  alias PixelAudit.Api.Connections

  @impl true
  def type, do: :meta_pixel_api

  @impl true
  def label, do: "Meta Pixel (stats API)"

  @impl true
  def description,
    do: "The pixel's fire count of an event, from the hourly stats the API reports."

  @impl true
  def connection_type, do: :meta_api

  @impl true
  def settings_schema, do: []

  @impl true
  def parameter_schema do
    [
      field("event_name",
        label: "Event name",
        required: true,
        description:
          "The pixel event as Meta names it: PageView, ViewContent, Purchase, or a custom event."
      )
    ]
  end

  @impl true
  def count(connection, _settings, %{"event_name" => event_name}, date_from, date_to) do
    Date.range(date_from, date_to)
    |> Enum.reduce_while({:ok, 0}, fn date, {:ok, total} ->
      case Connections.meta_pixel_day_count(connection, event_name, date) do
        {:ok, count} ->
          {:cont, {:ok, total + count}}

        :missing ->
          {:halt,
           {:error,
            "no pixel stats are cached for #{date}; Meta serves about the last seven days, " <>
              "refresh the connection or wait for the hourly pull"}}
      end
    end)
  end
end
