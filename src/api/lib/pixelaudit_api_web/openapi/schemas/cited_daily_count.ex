defmodule PixelAudit.ApiWeb.OpenApi.Schemas.CitedDailyCount do
  @moduledoc false
  require OpenApiSpex
  alias OpenApiSpex.Schema
  alias PixelAudit.ApiWeb.OpenApi.Schemas

  OpenApiSpex.schema(%{
    title: "CitedDailyCount",
    description: "A daily count that cites a call: whose, of which step, on which day.",
    type: :object,
    properties: %{
      id: %Schema{type: :string, format: :uuid},
      data_source: %Schema{allOf: [Schemas.EntityRef], nullable: true},
      step: %Schema{allOf: [Schemas.EntityRef], nullable: true},
      date: %Schema{type: :string, format: :date},
      count: %Schema{type: :integer, nullable: true},
      status: %Schema{type: :string, enum: ["ok", "error"]}
    },
    required: [:id, :data_source, :step, :date, :count, :status]
  })
end
