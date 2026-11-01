defmodule PixelAudit.ApiWeb.OpenApi.Schemas.RefreshRunResponse do
  @moduledoc false
  require OpenApiSpex
  alias PixelAudit.ApiWeb.OpenApi.Schemas

  OpenApiSpex.schema(%{
    title: "RefreshRunResponse",
    type: :object,
    properties: %{data: Schemas.RefreshRun},
    required: [:data]
  })
end
