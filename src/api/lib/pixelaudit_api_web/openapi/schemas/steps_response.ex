defmodule PixelAudit.ApiWeb.OpenApi.Schemas.StepsResponse do
  @moduledoc false
  require OpenApiSpex
  alias OpenApiSpex.Schema
  alias PixelAudit.ApiWeb.OpenApi.Schemas

  OpenApiSpex.schema(%{
    title: "StepsResponse",
    type: :object,
    properties: %{data: %Schema{type: :array, items: Schemas.Step}},
    required: [:data]
  })
end
