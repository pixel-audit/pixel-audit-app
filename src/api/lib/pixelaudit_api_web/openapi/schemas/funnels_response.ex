defmodule PixelAudit.ApiWeb.OpenApi.Schemas.FunnelsResponse do
  @moduledoc false
  require OpenApiSpex
  alias OpenApiSpex.Schema
  alias PixelAudit.ApiWeb.OpenApi.Schemas

  OpenApiSpex.schema(%{
    title: "FunnelsResponse",
    type: :object,
    properties: %{data: %Schema{type: :array, items: Schemas.Funnel}},
    required: [:data]
  })
end
