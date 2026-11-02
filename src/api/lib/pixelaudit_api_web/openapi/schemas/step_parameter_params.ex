defmodule PixelAudit.ApiWeb.OpenApi.Schemas.StepParameterParams do
  @moduledoc false
  require OpenApiSpex
  alias OpenApiSpex.Schema

  OpenApiSpex.schema(%{
    title: "StepParameterParams",
    type: :object,
    properties: %{
      parameters: %Schema{type: :object, additionalProperties: %Schema{type: :string}},
      description: %Schema{type: :string, nullable: true, maxLength: 2000},
      primary: %Schema{
        type: :boolean,
        default: false,
        description: "At most one data source is primary for a step (422 on `primary`)."
      }
    },
    required: [:parameters]
  })
end
