defmodule PixelAudit.ApiWeb.OpenApi.Schemas.RefreshRunsCreatedResponse do
  @moduledoc false
  require OpenApiSpex
  alias OpenApiSpex.Schema
  alias PixelAudit.ApiWeb.OpenApi.Schemas

  OpenApiSpex.schema(%{
    title: "RefreshRunsCreatedResponse",
    description: "The runs a refresh request enqueued.",
    type: :object,
    properties: %{data: %Schema{type: :array, items: Schemas.RefreshRun}},
    required: [:data]
  })
end
