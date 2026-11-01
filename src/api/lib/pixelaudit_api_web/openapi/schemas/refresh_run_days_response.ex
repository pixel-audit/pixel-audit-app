defmodule PixelAudit.ApiWeb.OpenApi.Schemas.RefreshRunDaysResponse do
  @moduledoc false
  require OpenApiSpex
  alias OpenApiSpex.Schema
  alias PixelAudit.ApiWeb.OpenApi.Schemas

  OpenApiSpex.schema(%{
    title: "RefreshRunDaysResponse",
    type: :object,
    properties: %{data: %Schema{type: :array, items: Schemas.RefreshRunDay}},
    required: [:data]
  })
end
