defmodule PixelAudit.ApiWeb.OpenApi.Schemas.StepDays do
  @moduledoc false
  require OpenApiSpex
  alias OpenApiSpex.Schema
  alias PixelAudit.ApiWeb.OpenApi.Schemas

  OpenApiSpex.schema(%{
    title: "StepDays",
    description: "The trail of one cell of the report: a data source, a step, a day per row.",
    type: :object,
    properties: %{
      funnel_id: %Schema{type: :string, format: :uuid},
      data_source: Schemas.DataSource,
      step: Schemas.Step,
      date_from: %Schema{type: :string, format: :date},
      date_to: %Schema{type: :string, format: :date},
      days: %Schema{type: :array, items: Schemas.StepDay}
    },
    required: [:funnel_id, :data_source, :step, :date_from, :date_to, :days]
  })
end
