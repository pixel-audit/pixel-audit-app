defmodule PixelAudit.ApiWeb.OpenApi.Schemas.StepDaysResponse do
  @moduledoc false
  require OpenApiSpex
  alias PixelAudit.ApiWeb.OpenApi.Schemas

  OpenApiSpex.schema(%{
    title: "StepDaysResponse",
    type: :object,
    properties: %{data: Schemas.StepDays},
    required: [:data]
  })
end
