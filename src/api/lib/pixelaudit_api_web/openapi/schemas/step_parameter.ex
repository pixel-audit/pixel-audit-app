defmodule PixelAudit.ApiWeb.OpenApi.Schemas.StepParameter do
  @moduledoc false
  require OpenApiSpex
  alias OpenApiSpex.Schema

  OpenApiSpex.schema(%{
    title: "StepParameter",
    description:
      "What a data source needs to count one step, keyed by the type's parameter keys " <>
        "(GET /funnels/data-source-types).",
    type: :object,
    properties: %{
      step_id: %Schema{type: :string, format: :uuid},
      parameters: %Schema{type: :object, additionalProperties: %Schema{type: :string}}
    },
    required: [:step_id, :parameters]
  })
end
