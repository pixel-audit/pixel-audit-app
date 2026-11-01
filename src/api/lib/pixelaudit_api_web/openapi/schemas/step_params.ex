defmodule PixelAudit.ApiWeb.OpenApi.Schemas.StepParams do
  @moduledoc false
  require OpenApiSpex
  alias OpenApiSpex.Schema

  OpenApiSpex.schema(%{
    title: "StepParams",
    type: :object,
    properties: %{
      code: %Schema{type: :string, pattern: "^[a-z0-9]+$"},
      name: %Schema{type: :string},
      description: %Schema{type: :string, nullable: true}
    }
  })
end
