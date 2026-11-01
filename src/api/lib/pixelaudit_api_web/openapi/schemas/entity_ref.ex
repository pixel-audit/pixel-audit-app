defmodule PixelAudit.ApiWeb.OpenApi.Schemas.EntityRef do
  @moduledoc false
  require OpenApiSpex
  alias OpenApiSpex.Schema

  OpenApiSpex.schema(%{
    title: "EntityRef",
    description: "A connection, funnel or data source named by id and name.",
    type: :object,
    properties: %{
      id: %Schema{type: :string, format: :uuid},
      name: %Schema{type: :string}
    },
    required: [:id, :name]
  })
end
