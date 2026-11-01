defmodule PixelAudit.ApiWeb.OpenApi.Schemas.VariableParams do
  @moduledoc false
  require OpenApiSpex
  alias OpenApiSpex.Schema

  OpenApiSpex.schema(%{
    title: "VariableParams",
    description:
      "A variable to create or update. The value is any string, the empty one included.",
    type: :object,
    properties: %{
      key: %Schema{type: :string, pattern: "^[a-zA-Z0-9]+$"},
      value: %Schema{type: :string},
      description: %Schema{type: :string, nullable: true}
    }
  })
end
