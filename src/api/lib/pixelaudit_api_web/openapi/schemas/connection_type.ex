defmodule PixelAudit.ApiWeb.OpenApi.Schemas.ConnectionType do
  @moduledoc false
  require OpenApiSpex
  alias OpenApiSpex.Schema
  alias PixelAudit.ApiWeb.OpenApi.Schemas

  OpenApiSpex.schema(%{
    title: "ConnectionType",
    description: "A connection type and the credentials it takes.",
    type: :object,
    properties: %{
      type: %Schema{type: :string, enum: ["meta", "bigquery", "postgres", "clickhouse"]},
      env_type: %Schema{type: :string, description: "The value of CONNECTION_<id>_TYPE."},
      label: %Schema{type: :string},
      credentials: %Schema{type: :array, items: Schemas.FieldSpec}
    },
    required: [:type, :env_type, :label, :credentials]
  })
end
