defmodule PixelAudit.ApiWeb.OpenApi.Schemas.HealthResponse do
  @moduledoc false
  require OpenApiSpex
  alias OpenApiSpex.Schema

  OpenApiSpex.schema(%{
    title: "HealthResponse",
    type: :object,
    properties: %{status: %Schema{type: :string}},
    required: [:status]
  })
end
