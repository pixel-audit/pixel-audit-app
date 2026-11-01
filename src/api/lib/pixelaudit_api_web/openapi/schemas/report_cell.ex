defmodule PixelAudit.ApiWeb.OpenApi.Schemas.ReportCell do
  @moduledoc false
  require OpenApiSpex
  alias OpenApiSpex.Schema

  OpenApiSpex.schema(%{
    title: "ReportCell",
    description:
      "One data source's count of one step over the range: the sum of the days that " <>
        "counted. `count` is null when the data source does not measure the step or no " <>
        "day counted yet; `days_*` say how complete the sum is.",
    type: :object,
    properties: %{
      data_source_id: %Schema{type: :string, format: :uuid},
      step_id: %Schema{type: :string, format: :uuid},
      count: %Schema{type: :integer, nullable: true},
      days_ok: %Schema{type: :integer},
      days_error: %Schema{type: :integer},
      days_missing: %Schema{type: :integer},
      last_error: %Schema{type: :string, nullable: true}
    },
    required: [
      :data_source_id,
      :step_id,
      :count,
      :days_ok,
      :days_error,
      :days_missing,
      :last_error
    ]
  })
end
