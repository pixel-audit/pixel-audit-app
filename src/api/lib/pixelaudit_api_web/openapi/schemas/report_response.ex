defmodule PixelAudit.ApiWeb.OpenApi.Schemas.ReportResponse do
  @moduledoc false
  require OpenApiSpex
  alias PixelAudit.ApiWeb.OpenApi.Schemas

  OpenApiSpex.schema(%{
    title: "ReportResponse",
    type: :object,
    properties: %{data: Schemas.Report},
    required: [:data]
  })
end
