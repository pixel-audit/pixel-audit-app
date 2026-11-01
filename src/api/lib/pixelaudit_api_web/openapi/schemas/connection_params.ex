defmodule PixelAudit.ApiWeb.OpenApi.Schemas.ConnectionParams do
  @moduledoc false
  require OpenApiSpex
  alias OpenApiSpex.Schema

  OpenApiSpex.schema(%{
    title: "ConnectionParams",
    description:
      "A connection to create or update. `credentials` is keyed by the type's credential " <>
        "keys (GET /connections/types); on update only the keys sent change, and `null` clears one.",
    type: :object,
    properties: %{
      name: %Schema{type: :string},
      description: %Schema{type: :string, nullable: true},
      type: %Schema{type: :string, enum: ["meta", "bigquery", "postgres", "clickhouse"]},
      credentials: %Schema{
        type: :object,
        additionalProperties: %Schema{type: :string, nullable: true}
      }
    }
  })
end
