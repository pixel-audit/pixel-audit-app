defmodule PixelAudit.ApiWeb.OpenApi.Schemas.StepResponse do
  @moduledoc false
  require OpenApiSpex
  alias PixelAudit.ApiWeb.OpenApi.Schemas

  OpenApiSpex.schema(%{
    title: "StepResponse",
    type: :object,
    properties: %{data: Schemas.Step},
    required: [:data]
  })
end
