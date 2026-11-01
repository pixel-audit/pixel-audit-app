defmodule PixelAudit.ApiWeb.OpenApi.Schemas.DataSourcesResponse do
  @moduledoc false
  require OpenApiSpex
  alias OpenApiSpex.Schema
  alias PixelAudit.ApiWeb.OpenApi.Schemas

  OpenApiSpex.schema(%{
    title: "DataSourcesResponse",
    type: :object,
    properties: %{data: %Schema{type: :array, items: Schemas.DataSource}},
    required: [:data]
  })
end
