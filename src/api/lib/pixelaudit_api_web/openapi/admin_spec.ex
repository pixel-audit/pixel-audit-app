defmodule PixelAudit.ApiWeb.OpenApi.AdminSpec do
  @moduledoc "OpenAPI document for the admin panel's API."

  @behaviour OpenApiSpex.OpenApi

  @impl true
  def spec do
    PixelAudit.ApiWeb.OpenApi.Spec.build("PixelAudit Admin API", "/api/admin/")
  end
end
