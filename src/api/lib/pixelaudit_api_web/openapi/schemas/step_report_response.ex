defmodule PixelAudit.ApiWeb.OpenApi.Schemas.StepReportResponse do
  @moduledoc false
  require OpenApiSpex
  alias PixelAudit.ApiWeb.OpenApi.Schemas

  OpenApiSpex.schema(%{
    title: "StepReportResponse",
    type: :object,
    properties: %{data: Schemas.StepReport},
    required: [:data]
  })
end
