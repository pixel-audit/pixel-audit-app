defmodule PixelAudit.ApiWeb.OpenApi.Schemas.VariableResponse do
  @moduledoc false
  require OpenApiSpex
  alias PixelAudit.ApiWeb.OpenApi.Schemas

  OpenApiSpex.schema(%{
    title: "VariableResponse",
    type: :object,
    properties: %{data: Schemas.Variable},
    required: [:data]
  })
end
