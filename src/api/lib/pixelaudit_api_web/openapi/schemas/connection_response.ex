defmodule PixelAudit.ApiWeb.OpenApi.Schemas.ConnectionResponse do
  @moduledoc false
  require OpenApiSpex
  alias PixelAudit.ApiWeb.OpenApi.Schemas

  OpenApiSpex.schema(%{
    title: "ConnectionResponse",
    type: :object,
    properties: %{data: Schemas.Connection},
    required: [:data]
  })
end
