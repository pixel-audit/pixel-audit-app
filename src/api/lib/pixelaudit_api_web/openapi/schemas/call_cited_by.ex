defmodule PixelAudit.ApiWeb.OpenApi.Schemas.CallCitedBy do
  @moduledoc false
  require OpenApiSpex
  alias OpenApiSpex.Schema
  alias PixelAudit.ApiWeb.OpenApi.Schemas

  OpenApiSpex.schema(%{
    title: "CallCitedBy",
    description:
      "The stored values that rest on a call: the daily counts it was computed for, and " <>
        "how many cached Meta hours it delivered. Both empty for a call nothing rests on.",
    type: :object,
    properties: %{
      daily_counts: %Schema{type: :array, items: Schemas.CitedDailyCount},
      meta_pixel_hours: %Schema{type: :integer}
    },
    required: [:daily_counts, :meta_pixel_hours]
  })
end
