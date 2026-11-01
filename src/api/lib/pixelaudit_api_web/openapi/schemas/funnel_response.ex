defmodule PixelAudit.ApiWeb.OpenApi.Schemas.FunnelResponse do
  @moduledoc false
  require OpenApiSpex
  alias PixelAudit.ApiWeb.OpenApi.Schemas

  OpenApiSpex.schema(%{
    title: "FunnelResponse",
    type: :object,
    properties: %{data: Schemas.Funnel},
    required: [:data]
  })
end
