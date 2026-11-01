defmodule PixelAudit.ApiWeb.OpenApi.Schemas.ValidationErrors do
  @moduledoc false
  require OpenApiSpex
  alias OpenApiSpex.Schema

  OpenApiSpex.schema(%{
    title: "ValidationErrors",
    description:
      "Field errors, keyed by the field as the request named it; a key may be dotted " <>
        "(`credentials.access_token`, `settings.dataset`, `parameters.sql`).",
    type: :object,
    properties: %{
      errors: %Schema{
        type: :object,
        additionalProperties: %Schema{type: :array, items: %Schema{type: :string}}
      }
    },
    required: [:errors]
  })
end
