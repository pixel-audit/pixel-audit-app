defmodule PixelAudit.ApiWeb.OpenApi.Schemas.DataSourceOrderParams do
  @moduledoc false
  require OpenApiSpex
  alias OpenApiSpex.Schema

  OpenApiSpex.schema(%{
    title: "DataSourceOrderParams",
    description: "Every data source of the funnel, by id, in the wanted order.",
    type: :object,
    properties: %{
      data_source_ids: %Schema{type: :array, items: %Schema{type: :string, format: :uuid}}
    },
    required: [:data_source_ids]
  })
end
