defmodule PixelAudit.ApiWeb.OpenApi.Spec do
  @moduledoc """
  Builder of the OpenAPI document served under `/openapi/admin.json`, from
  the router's operations under the API's path prefix. No security scheme:
  the API has no authentication (see specs/api.md).
  """

  alias OpenApiSpex.{Info, OpenApi, Paths, Server}

  @spec build(String.t(), String.t()) :: OpenApi.t()
  def build(title, path_prefix) do
    OpenApiSpex.resolve_schema_modules(%OpenApi{
      info: %Info{
        title: title,
        version: "1.0.0",
        description:
          "PixelAudit's admin API. No authentication: deploy it behind a network boundary."
      },
      servers: [Server.from_endpoint(PixelAudit.ApiWeb.Endpoint)],
      paths:
        PixelAudit.ApiWeb.Router
        |> Paths.from_router()
        |> Map.filter(fn {path, _item} -> String.starts_with?(path, path_prefix) end)
    })
  end
end
