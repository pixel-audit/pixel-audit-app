defmodule PixelAudit.ApiWeb.OpenApi.Schemas.RefreshRangeParams do
  @moduledoc false
  require OpenApiSpex
  alias OpenApiSpex.Schema

  OpenApiSpex.schema(%{
    title: "RefreshRangeParams",
    description: "The days to refresh, inclusive; at most 366.",
    type: :object,
    properties: %{
      date_from: %Schema{type: :string, format: :date},
      date_to: %Schema{type: :string, format: :date},
      data_source_id: %Schema{
        type: :string,
        format: :uuid,
        nullable: true,
        description: "For a funnel refresh: only this data source. Every data source when absent."
      }
    },
    required: [:date_from, :date_to]
  })
end
