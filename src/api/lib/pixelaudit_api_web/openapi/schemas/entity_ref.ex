defmodule PixelAudit.ApiWeb.OpenApi.Schemas.EntityRef do
  @moduledoc false
  require OpenApiSpex
  alias OpenApiSpex.Schema

  OpenApiSpex.schema(%{
    title: "EntityRef",
    description: "A connection, funnel or data source named by id, code and name.",
    type: :object,
    properties: %{
      id: %Schema{type: :string, format: :uuid},
      code: %Schema{type: :string},
      name: %Schema{type: :string}
    },
    required: [:id, :code, :name]
  })
end
