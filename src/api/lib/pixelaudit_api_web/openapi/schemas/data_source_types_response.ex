defmodule PixelAudit.ApiWeb.OpenApi.Schemas.DataSourceTypesResponse do
  @moduledoc false
  require OpenApiSpex
  alias OpenApiSpex.Schema
  alias PixelAudit.ApiWeb.OpenApi.Schemas

  OpenApiSpex.schema(%{
    title: "DataSourceTypesResponse",
    type: :object,
    properties: %{data: %Schema{type: :array, items: Schemas.DataSourceType}},
    required: [:data]
  })
end
