defmodule PixelAudit.ApiWeb.OpenApi.Schemas.ConnectionCallResponse do
  @moduledoc false
  require OpenApiSpex
  alias PixelAudit.ApiWeb.OpenApi.Schemas

  OpenApiSpex.schema(%{
    title: "ConnectionCallResponse",
    type: :object,
    properties: %{data: Schemas.ConnectionCall},
    required: [:data]
  })
end
