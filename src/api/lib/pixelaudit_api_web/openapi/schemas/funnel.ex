defmodule PixelAudit.ApiWeb.OpenApi.Schemas.Funnel do
  @moduledoc false
  require OpenApiSpex
  alias OpenApiSpex.Schema
  alias PixelAudit.ApiWeb.OpenApi.Schemas

  OpenApiSpex.schema(%{
    title: "Funnel",
    description: "A funnel with its ordered steps and its data sources.",
    type: :object,
    properties: %{
      id: %Schema{type: :string, format: :uuid},
      code: %Schema{type: :string, pattern: "^[a-z0-9]+$"},
      name: %Schema{type: :string},
      description: %Schema{type: :string, nullable: true},
      steps: %Schema{type: :array, items: Schemas.Step},
      data_sources: %Schema{type: :array, items: Schemas.DataSource},
      inserted_at: %Schema{type: :string, format: :"date-time"},
      updated_at: %Schema{type: :string, format: :"date-time"}
    },
    required: [:id, :code, :name, :description, :steps, :data_sources, :inserted_at, :updated_at]
  })
end
