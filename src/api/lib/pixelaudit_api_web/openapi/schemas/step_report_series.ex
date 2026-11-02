defmodule PixelAudit.ApiWeb.OpenApi.Schemas.StepReportSeries do
  @moduledoc false
  require OpenApiSpex
  alias OpenApiSpex.Schema
  alias PixelAudit.ApiWeb.OpenApi.Schemas

  OpenApiSpex.schema(%{
    title: "StepReportSeries",
    description:
      "One data source's counts of the step, a point per day of the range in date order. " <>
        "`measured` is false when the source has no parameters for the step: every point " <>
        "is then missing.",
    type: :object,
    properties: %{
      data_source_id: %Schema{type: :string, format: :uuid},
      measured: %Schema{type: :boolean},
      points: %Schema{type: :array, items: Schemas.StepReportPoint}
    },
    required: [:data_source_id, :measured, :points]
  })
end
