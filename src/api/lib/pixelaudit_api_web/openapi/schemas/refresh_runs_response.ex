defmodule PixelAudit.ApiWeb.OpenApi.Schemas.RefreshRunsResponse do
  @moduledoc false
  require OpenApiSpex
  alias OpenApiSpex.Schema
  alias PixelAudit.ApiWeb.OpenApi.Schemas

  OpenApiSpex.schema(%{
    title: "RefreshRunsResponse",
    type: :object,
    properties: %{
      data: %Schema{type: :array, items: Schemas.RefreshRun},
      total: %Schema{type: :integer, description: "How many runs match, over all pages."}
    },
    required: [:data, :total]
  })
end
