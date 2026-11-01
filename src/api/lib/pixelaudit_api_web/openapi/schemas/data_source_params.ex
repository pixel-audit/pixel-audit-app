defmodule PixelAudit.ApiWeb.OpenApi.Schemas.DataSourceParams do
  @moduledoc false
  require OpenApiSpex
  alias OpenApiSpex.Schema

  OpenApiSpex.schema(%{
    title: "DataSourceParams",
    description:
      "A data source to create or update. The connection must be of the type's connection " <>
        "type; `settings` is keyed by the type's setting keys (GET /funnels/data-source-types).",
    type: :object,
    properties: %{
      name: %Schema{type: :string},
      description: %Schema{type: :string, nullable: true},
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
      connection_id: %Schema{type: :string, format: :uuid},
      color: %Schema{
        type: :string,
        pattern: "^#[0-9a-f]{6}$",
        description:
          "The data source's colour in the report, #rrggbb. Dealt from a palette when absent on create."
      },
      settings: %Schema{
        type: :object,
        additionalProperties: %Schema{type: :string, nullable: true}
      }
    }
  })
end
