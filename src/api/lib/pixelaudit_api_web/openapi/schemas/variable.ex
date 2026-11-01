defmodule PixelAudit.ApiWeb.OpenApi.Schemas.Variable do
  @moduledoc false
  require OpenApiSpex
  alias OpenApiSpex.Schema

  OpenApiSpex.schema(%{
    title: "Variable",
    description: "A variable: one string value under a key.",
    type: :object,
    properties: %{
      id: %Schema{type: :string, format: :uuid},
      key: %Schema{type: :string, pattern: "^[a-zA-Z0-9]+$"},
      value: %Schema{type: :string},
      description: %Schema{type: :string, nullable: true},
      managed_by_env: %Schema{
        type: :boolean,
        description:
          "Set by the boot role from VARIABLE_* variables; key and value are read-only."
      },
      inserted_at: %Schema{type: :string, format: :"date-time"},
      updated_at: %Schema{type: :string, format: :"date-time"}
    },
    required: [:id, :key, :value, :description, :managed_by_env, :inserted_at, :updated_at]
  })
end
