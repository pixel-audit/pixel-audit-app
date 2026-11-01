defmodule PixelAudit.ApiWeb.OpenApi.Schemas.Report do
  @moduledoc false
  require OpenApiSpex
  alias OpenApiSpex.Schema
  alias PixelAudit.ApiWeb.OpenApi.Schemas

  OpenApiSpex.schema(%{
    title: "Report",
    description: "A funnel over a date range: the steps, the data sources, and a cell per pair.",
    type: :object,
    properties: %{
      funnel_id: %Schema{type: :string, format: :uuid},
      date_from: %Schema{type: :string, format: :date},
      date_to: %Schema{type: :string, format: :date},
      days: %Schema{type: :integer},
      steps: %Schema{type: :array, items: Schemas.Step},
      data_sources: %Schema{type: :array, items: Schemas.DataSource},
      cells: %Schema{type: :array, items: Schemas.ReportCell},
      conversions: %Schema{type: :array, items: Schemas.ReportConversion}
    },
    required: [
      :funnel_id,
      :date_from,
      :date_to,
      :days,
      :steps,
      :data_sources,
      :cells,
      :conversions
    ]
  })
end
