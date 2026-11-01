defmodule PixelAudit.ApiWeb.OpenApi.Schemas.VariablesResponse do
  @moduledoc false
  require OpenApiSpex
  alias OpenApiSpex.Schema
  alias PixelAudit.ApiWeb.OpenApi.Schemas

  OpenApiSpex.schema(%{
    title: "VariablesResponse",
    type: :object,
    properties: %{data: %Schema{type: :array, items: Schemas.Variable}},
    required: [:data]
  })
end
