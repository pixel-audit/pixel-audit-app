defmodule PixelAudit.ApiWeb.OpenApi.Schemas.Step do
  @moduledoc false
  require OpenApiSpex
  alias OpenApiSpex.Schema

  OpenApiSpex.schema(%{
    title: "Step",
    description: "One step of the funnel's user journey; `position` orders them from 0.",
    type: :object,
    properties: %{
      id: %Schema{type: :string, format: :uuid},
      name: %Schema{type: :string},
      description: %Schema{type: :string, nullable: true},
      position: %Schema{type: :integer}
    },
    required: [:id, :name, :description, :position]
  })
end
