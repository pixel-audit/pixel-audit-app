defmodule PixelAudit.ApiWeb.OpenApi.Schemas.StepDay do
  @moduledoc false
  require OpenApiSpex
  alias OpenApiSpex.Schema
  alias PixelAudit.ApiWeb.OpenApi.Schemas

  OpenApiSpex.schema(%{
    title: "StepDay",
    description:
      "One day of a data source's count of a step: the count as stored, or why there is " <>
        "none (`error`, or `missing` when never computed), when and by which run it was " <>
        "computed, and the calls it cites — whole, oldest first. A day computed before " <>
        "calls were cited has an empty `calls`.",
    type: :object,
    properties: %{
      date: %Schema{type: :string, format: :date},
      count: %Schema{type: :integer, nullable: true},
      status: %Schema{type: :string, enum: ["ok", "error", "missing"]},
      error: %Schema{type: :string, nullable: true},
      computed_at: %Schema{type: :string, format: :"date-time", nullable: true},
      refresh_run: %Schema{allOf: [Schemas.RefreshRunRef], nullable: true},
      calls: %Schema{type: :array, items: Schemas.ConnectionCall}
    },
    required: [:date, :count, :status, :error, :computed_at, :refresh_run, :calls]
  })
end
