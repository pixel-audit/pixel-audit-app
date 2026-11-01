defmodule PixelAudit.ApiWeb.OpenApi.Schemas.StepParameterResponse do
  @moduledoc false
  require OpenApiSpex
  alias PixelAudit.ApiWeb.OpenApi.Schemas

  OpenApiSpex.schema(%{
    title: "StepParameterResponse",
    type: :object,
    properties: %{data: Schemas.StepParameter},
    required: [:data]
  })
end
