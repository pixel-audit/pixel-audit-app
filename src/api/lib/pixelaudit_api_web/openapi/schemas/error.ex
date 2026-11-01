defmodule PixelAudit.ApiWeb.OpenApi.Schemas.Error do
  @moduledoc false
  require OpenApiSpex
  alias OpenApiSpex.Schema

  OpenApiSpex.schema(%{
    title: "Error",
    description: "A refusal: `errors.detail` names the reason, machine-readably.",
    type: :object,
    properties: %{
      errors: %Schema{
        type: :object,
        properties: %{detail: %Schema{type: :string}},
        required: [:detail]
      }
    },
    required: [:errors]
  })
end
