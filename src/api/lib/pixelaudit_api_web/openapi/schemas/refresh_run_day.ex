defmodule PixelAudit.ApiWeb.OpenApi.Schemas.RefreshRunDay do
  @moduledoc false
  require OpenApiSpex
  alias OpenApiSpex.Schema
  alias PixelAudit.ApiWeb.OpenApi.Schemas

  OpenApiSpex.schema(%{
    title: "RefreshRunDay",
    description: "One step on one day as a run computed it: the count, or the error.",
    type: :object,
    properties: %{
      date: %Schema{type: :string, format: :date},
      step: Schemas.Step,
      status: %Schema{type: :string, enum: ["ok", "error"]},
      count: %Schema{type: :integer, nullable: true},
      error: %Schema{type: :string, nullable: true},
      computed_at: %Schema{type: :string, format: :"date-time"}
    },
    required: [:date, :step, :status, :count, :error, :computed_at]
  })
end
