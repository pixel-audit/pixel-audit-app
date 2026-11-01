defmodule PixelAudit.ApiWeb.OpenApi.Schemas.DataSource do
  @moduledoc false
  require OpenApiSpex
  alias OpenApiSpex.Schema
  alias PixelAudit.ApiWeb.OpenApi.Schemas

  OpenApiSpex.schema(%{
    title: "DataSource",
    description: "Where a funnel's step counts are read from, with its per-step parameters.",
    type: :object,
    properties: %{
      id: %Schema{type: :string, format: :uuid},
      code: %Schema{type: :string, pattern: "^[a-z0-9]+$"},
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
      connection: Schemas.ConnectionRef,
      settings: %Schema{type: :object, additionalProperties: %Schema{type: :string}},
      position: %Schema{type: :integer},
      step_parameters: %Schema{type: :array, items: Schemas.StepParameter}
    },
    required: [
      :id,
      :code,
      :name,
      :description,
      :type,
      :connection_id,
      :connection,
      :settings,
      :position,
      :color,
      :step_parameters
    ]
  })
end
