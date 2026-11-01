defmodule PixelAudit.ApiWeb.OpenApi.Schemas.ConnectionCallsResponse do
  @moduledoc false
  require OpenApiSpex
  alias OpenApiSpex.Schema
  alias PixelAudit.ApiWeb.OpenApi.Schemas

  OpenApiSpex.schema(%{
    title: "ConnectionCallsResponse",
    type: :object,
    properties: %{
      data: %Schema{type: :array, items: Schemas.ConnectionCall},
      total: %Schema{type: :integer, description: "How many calls match, over all pages."}
    },
    required: [:data, :total]
  })
end
