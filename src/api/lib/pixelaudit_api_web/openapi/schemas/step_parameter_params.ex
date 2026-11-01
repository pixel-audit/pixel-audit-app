defmodule PixelAudit.ApiWeb.OpenApi.Schemas.StepParameterParams do
  @moduledoc false
  require OpenApiSpex
  alias OpenApiSpex.Schema

  OpenApiSpex.schema(%{
    title: "StepParameterParams",
    type: :object,
    properties: %{
      parameters: %Schema{type: :object, additionalProperties: %Schema{type: :string}},
      description: %Schema{type: :string, nullable: true, maxLength: 2000}
    },
    required: [:parameters]
  })
end
