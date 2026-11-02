defmodule PixelAudit.ApiWeb.OpenApi.Schemas.StepReport do
  @moduledoc false
  require OpenApiSpex
  alias OpenApiSpex.Schema
  alias PixelAudit.ApiWeb.OpenApi.Schemas

  OpenApiSpex.schema(%{
    title: "StepReport",
    description:
      "One step of a funnel over a date range: the data sources, and for each a series " <>
        "with a point per day.",
    type: :object,
    properties: %{
      funnel_id: %Schema{type: :string, format: :uuid},
      step: Schemas.Step,
      date_from: %Schema{type: :string, format: :date},
      date_to: %Schema{type: :string, format: :date},
      days: %Schema{type: :integer},
      data_sources: %Schema{type: :array, items: Schemas.DataSource},
      series: %Schema{type: :array, items: Schemas.StepReportSeries}
    },
    required: [:funnel_id, :step, :date_from, :date_to, :days, :data_sources, :series]
  })
end
