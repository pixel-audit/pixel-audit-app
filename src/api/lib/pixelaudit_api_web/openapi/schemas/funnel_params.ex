defmodule PixelAudit.ApiWeb.OpenApi.Schemas.FunnelParams do
  @moduledoc false
  require OpenApiSpex
  alias OpenApiSpex.Schema

  OpenApiSpex.schema(%{
    title: "FunnelParams",
    type: :object,
    properties: %{
      name: %Schema{type: :string},
      description: %Schema{type: :string, nullable: true}
    }
  })
end
