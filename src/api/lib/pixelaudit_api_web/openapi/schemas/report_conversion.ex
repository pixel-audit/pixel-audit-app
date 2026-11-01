defmodule PixelAudit.ApiWeb.OpenApi.Schemas.ReportConversion do
  @moduledoc false
  require OpenApiSpex
  alias OpenApiSpex.Schema

  OpenApiSpex.schema(%{
    title: "ReportConversion",
    description:
      "A data source's conversion from one step to the next: the next count over the " <>
        "previous one, null when either is unknown or the previous is zero.",
    type: :object,
    properties: %{
      data_source_id: %Schema{type: :string, format: :uuid},
      from_step_id: %Schema{type: :string, format: :uuid},
      to_step_id: %Schema{type: :string, format: :uuid},
      rate: %Schema{type: :number, nullable: true}
    },
    required: [:data_source_id, :from_step_id, :to_step_id, :rate]
  })
end
