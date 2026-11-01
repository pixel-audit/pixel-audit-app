defmodule PixelAudit.ApiWeb.OpenApi.Schemas.DataSourceResponse do
  @moduledoc false
  require OpenApiSpex
  alias PixelAudit.ApiWeb.OpenApi.Schemas

  OpenApiSpex.schema(%{
    title: "DataSourceResponse",
    type: :object,
    properties: %{data: Schemas.DataSource},
    required: [:data]
  })
end
