defmodule PixelAudit.ApiWeb.OpenApi.Schemas.ConnectionsResponse do
  @moduledoc false
  require OpenApiSpex
  alias OpenApiSpex.Schema
  alias PixelAudit.ApiWeb.OpenApi.Schemas

  OpenApiSpex.schema(%{
    title: "ConnectionsResponse",
    type: :object,
    properties: %{data: %Schema{type: :array, items: Schemas.Connection}},
    required: [:data]
  })
end
