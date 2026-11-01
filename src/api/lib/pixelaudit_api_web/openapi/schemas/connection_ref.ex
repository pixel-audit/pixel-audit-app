defmodule PixelAudit.ApiWeb.OpenApi.Schemas.ConnectionRef do
  @moduledoc false
  require OpenApiSpex
  alias OpenApiSpex.Schema

  OpenApiSpex.schema(%{
    title: "ConnectionRef",
    description: "The connection a data source reads through.",
    type: :object,
    properties: %{
      id: %Schema{type: :string, format: :uuid},
      code: %Schema{type: :string},
      name: %Schema{type: :string},
      type: %Schema{type: :string, enum: ["meta", "bigquery", "postgres", "clickhouse"]}
    },
    required: [:id, :code, :name, :type]
  })
end
