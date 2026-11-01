defmodule PixelAudit.ApiWeb.OpenApi.Schemas.FieldSpec do
  @moduledoc false
  require OpenApiSpex
  alias OpenApiSpex.Schema

  OpenApiSpex.schema(%{
    title: "FieldSpec",
    description:
      "A declared string field: a connection type's credential, a data source type's " <>
        "setting, or a step parameter. The panel renders its form from these.",
    type: :object,
    properties: %{
      key: %Schema{type: :string},
      label: %Schema{type: :string},
      kind: %Schema{type: :string, enum: ["string", "text", "secret", "select", "sql"]},
      required: %Schema{type: :boolean},
      default: %Schema{type: :string, nullable: true},
      options: %Schema{type: :array, items: %Schema{type: :string}, nullable: true},
      description: %Schema{type: :string, nullable: true}
    },
    required: [:key, :label, :kind, :required, :default, :options, :description]
  })
end
