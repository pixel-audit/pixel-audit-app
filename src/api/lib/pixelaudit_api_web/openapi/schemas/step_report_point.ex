defmodule PixelAudit.ApiWeb.OpenApi.Schemas.StepReportPoint do
  @moduledoc false
  require OpenApiSpex
  alias OpenApiSpex.Schema

  OpenApiSpex.schema(%{
    title: "StepReportPoint",
    description:
      "One day of a data source's series: the day's count when it counted (`ok`), " <>
        "otherwise null with why — `error` (the resolver's message in `error`) or " <>
        "`missing` (never computed).",
    type: :object,
    properties: %{
      date: %Schema{type: :string, format: :date},
      count: %Schema{type: :integer, nullable: true},
      status: %Schema{type: :string, enum: ["ok", "error", "missing"]},
      error: %Schema{type: :string, nullable: true}
    },
    required: [:date, :count, :status, :error]
  })
end
