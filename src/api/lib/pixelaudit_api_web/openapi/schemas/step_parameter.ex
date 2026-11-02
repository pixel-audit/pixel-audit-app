defmodule PixelAudit.ApiWeb.OpenApi.Schemas.StepParameter do
  @moduledoc false
  require OpenApiSpex
  alias OpenApiSpex.Schema

  OpenApiSpex.schema(%{
    title: "StepParameter",
    description:
      "What a data source needs to count one step, keyed by the type's parameter keys " <>
        "(GET /funnels/data-source-types), a note on how it counts it, and whether it is " <>
        "the step's primary source (at most one per step).",
    type: :object,
    properties: %{
      step_id: %Schema{type: :string, format: :uuid},
      parameters: %Schema{type: :object, additionalProperties: %Schema{type: :string}},
      description: %Schema{type: :string, nullable: true},
      primary: %Schema{type: :boolean}
    },
    required: [:step_id, :parameters, :description, :primary]
  })
end
