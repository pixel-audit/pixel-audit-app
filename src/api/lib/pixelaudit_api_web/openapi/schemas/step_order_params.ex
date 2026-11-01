defmodule PixelAudit.ApiWeb.OpenApi.Schemas.StepOrderParams do
  @moduledoc false
  require OpenApiSpex
  alias OpenApiSpex.Schema

  OpenApiSpex.schema(%{
    title: "StepOrderParams",
    description: "Every step of the funnel, by id, in the wanted order.",
    type: :object,
    properties: %{
      step_ids: %Schema{type: :array, items: %Schema{type: :string, format: :uuid}}
    },
    required: [:step_ids]
  })
end
