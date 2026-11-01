defmodule PixelAudit.ApiWeb.Admin.Funnels.FunnelController do
  use PixelAudit.ApiWeb, :controller
  use OpenApiSpex.ControllerSpecs

  import PixelAudit.ApiWeb.ControllerHelpers

  require Logger

  alias PixelAudit.Api.Funnels
  alias PixelAudit.ApiWeb.OpenApi.Schemas

  action_fallback PixelAudit.ApiWeb.FallbackController

  @id_parameter [
    in: :path,
    type: %OpenApiSpex.Schema{type: :string},
    required: true,
    description: "Funnel id or code"
  ]

  tags(["funnels"])

  operation(:index,
    operation_id: "admin.listFunnels",
    summary: "List funnels, each with its steps and data sources",
    responses: [ok: {"Funnels", "application/json", Schemas.FunnelsResponse}]
  )

  def index(conn, _params) do
    render(conn, :index, funnels: Funnels.list_funnels())
  end

  operation(:show,
    operation_id: "admin.getFunnel",
    summary: "Get a funnel with its steps, data sources and parameters",
    parameters: [id: @id_parameter],
    responses: [
      ok: {"Funnel", "application/json", Schemas.FunnelResponse},
      not_found: {"Not found", "application/json", Schemas.Error}
    ]
  )

  def show(conn, %{"id" => id}) do
    with {:ok, funnel} <- fetch_resource(fn -> Funnels.get_funnel!(id) end) do
      render(conn, :show, funnel: funnel)
    end
  end

  operation(:create,
    operation_id: "admin.createFunnel",
    summary: "Create a funnel",
    request_body: {"Funnel", "application/json", Schemas.FunnelParams},
    responses: [
      created: {"Created funnel", "application/json", Schemas.FunnelResponse},
      unprocessable_entity: {"Validation errors", "application/json", Schemas.ValidationErrors}
    ]
  )

  def create(conn, _params) do
    with {:ok, funnel} <- Funnels.create_funnel(conn.body_params) do
      Logger.info("admin.funnel created code=#{funnel.code}")

      conn
      |> put_status(:created)
      |> render(:show, funnel: Funnels.get_funnel!(funnel.id))
    end
  end

  operation(:update,
    operation_id: "admin.updateFunnel",
    summary: "Update a funnel",
    parameters: [id: @id_parameter],
    request_body: {"Funnel", "application/json", Schemas.FunnelParams},
    responses: [
      ok: {"Updated funnel", "application/json", Schemas.FunnelResponse},
      unprocessable_entity: {"Validation errors", "application/json", Schemas.ValidationErrors},
      not_found: {"Not found", "application/json", Schemas.Error}
    ]
  )

  def update(conn, %{"id" => id}) do
    with {:ok, funnel} <- fetch_resource(fn -> Funnels.get_funnel!(id) end),
         {:ok, funnel} <- Funnels.update_funnel(funnel, conn.body_params) do
      Logger.info("admin.funnel updated code=#{funnel.code}")
      render(conn, :show, funnel: funnel)
    end
  end

  operation(:delete,
    operation_id: "admin.deleteFunnel",
    summary: "Delete a funnel, its steps, data sources and cached counts",
    parameters: [id: @id_parameter],
    responses: [
      no_content: "Deleted",
      not_found: {"Not found", "application/json", Schemas.Error}
    ]
  )

  def delete(conn, %{"id" => id}) do
    with {:ok, funnel} <- fetch_resource(fn -> Funnels.get_funnel!(id) end),
         {:ok, _funnel} <- Funnels.delete_funnel(funnel) do
      Logger.info("admin.funnel deleted code=#{funnel.code}")
      send_resp(conn, :no_content, "")
    end
  end
end
