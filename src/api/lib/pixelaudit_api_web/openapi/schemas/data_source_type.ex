defmodule PixelAudit.ApiWeb.OpenApi.Schemas.DataSourceType do
  @moduledoc false
  require OpenApiSpex
  alias OpenApiSpex.Schema
  alias PixelAudit.ApiWeb.OpenApi.Schemas

  OpenApiSpex.schema(%{
    title: "DataSourceType",
    description: "A data source type: its connection type, settings and per-step parameters.",
    type: :object,
    properties: %{
      type: %Schema{
        type: :string,
        enum: [
          "meta_pixel_api",
          "google_analytics_bigquery",
          "google_ads_bigquery",
          "postgres_query",
          "clickhouse_query"
        ]
      },
      label: %Schema{type: :string},
      description: %Schema{type: :string},
      connection_type: %Schema{
        type: :string,
        enum: ["meta", "bigquery", "postgres", "clickhouse"]
      },
      settings: %Schema{type: :array, items: Schemas.FieldSpec},
      parameters: %Schema{type: :array, items: Schemas.FieldSpec}
    },
    required: [:type, :label, :description, :connection_type, :settings, :parameters]
  })
end
