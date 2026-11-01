defmodule PixelAudit.ApiWeb.OpenApi.Schemas.ConnectionTypesResponse do
  @moduledoc false
  require OpenApiSpex
  alias OpenApiSpex.Schema
  alias PixelAudit.ApiWeb.OpenApi.Schemas

  OpenApiSpex.schema(%{
    title: "ConnectionTypesResponse",
    type: :object,
    properties: %{data: %Schema{type: :array, items: Schemas.ConnectionType}},
    required: [:data]
  })
end
