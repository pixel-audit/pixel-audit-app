defmodule PixelAudit.ApiWeb.Admin.Funnels.DataSourceController do
  use PixelAudit.ApiWeb, :controller
  use OpenApiSpex.ControllerSpecs

  import PixelAudit.ApiWeb.ControllerHelpers

  require Logger

  alias PixelAudit.Api.{Funnels, Reporting}
  alias PixelAudit.ApiWeb.OpenApi.Schemas

  action_fallback PixelAudit.ApiWeb.FallbackController

  @funnel_parameter [
    in: :path,
    type: %OpenApiSpex.Schema{type: :string},
    required: true,
    description: "Funnel id"
  ]
  @id_parameter [
    in: :path,
    type: %OpenApiSpex.Schema{type: :string, format: :uuid},
    required: true,
    description: "Data source id"
  ]

  tags(["funnel-data-sources"])

  operation(:types,
    operation_id: "admin.listDataSourceTypes",
    summary: "List the data source types with their settings and step parameters",
    responses: [ok: {"Data source types", "application/json", Schemas.DataSourceTypesResponse}]
  )

  def types(conn, _params) do
    json(conn, %{data: Funnels.data_source_types()})
  end

  operation(:create,
    operation_id: "admin.createFunnelDataSource",
    summary: "Add a data source to the funnel",
    description:
      "The connection must be of the type's connection type (422 connection_type_mismatch).",
    parameters: [funnel_id: @funnel_parameter],
    request_body: {"Data source", "application/json", Schemas.DataSourceParams},
    responses: [
      created: {"Created data source", "application/json", Schemas.DataSourceResponse},
      unprocessable_entity: {"Validation errors", "application/json", Schemas.ValidationErrors},
      not_found: {"Not found", "application/json", Schemas.Error}
    ]
  )

  def create(conn, %{"funnel_id" => funnel_id}) do
    with {:ok, funnel} <- fetch_resource(fn -> Funnels.get_funnel!(funnel_id) end),
         {:ok, data_source} <- Funnels.create_data_source(funnel, conn.body_params) do
      Logger.info(
        "admin.funnel.data_source created funnel=#{funnel.id} id=#{data_source.id} type=#{data_source.type}"
      )

      conn
      |> put_status(:created)
      |> render(:show, data_source: data_source)
    end
  end

  operation(:update,
    operation_id: "admin.updateFunnelDataSource",
    summary: "Update a data source",
    description: "A change enqueues a recomputation of the data source's recent days.",
    parameters: [funnel_id: @funnel_parameter, id: @id_parameter],
    request_body: {"Data source", "application/json", Schemas.DataSourceParams},
    responses: [
      ok: {"Updated data source", "application/json", Schemas.DataSourceResponse},
      unprocessable_entity: {"Validation errors", "application/json", Schemas.ValidationErrors},
      not_found: {"Not found", "application/json", Schemas.Error}
    ]
  )

  def update(conn, %{"funnel_id" => funnel_id, "id" => id}) do
    with {:ok, funnel} <- fetch_resource(fn -> Funnels.get_funnel!(funnel_id) end),
         {:ok, data_source} <- fetch_resource(fn -> Funnels.get_data_source!(funnel, id) end),
         {:ok, data_source} <- Funnels.update_data_source(data_source, conn.body_params) do
      Logger.info("admin.funnel.data_source updated funnel=#{funnel.id} id=#{data_source.id}")

      if data_source.step_parameters != [], do: Reporting.refresh_after_change(data_source)
      render(conn, :show, data_source: data_source)
    end
  end

  operation(:delete,
    operation_id: "admin.deleteFunnelDataSource",
    summary: "Delete a data source and its cached counts",
    parameters: [funnel_id: @funnel_parameter, id: @id_parameter],
    responses: [
      no_content: "Deleted",
      not_found: {"Not found", "application/json", Schemas.Error}
    ]
  )

  def delete(conn, %{"funnel_id" => funnel_id, "id" => id}) do
    with {:ok, funnel} <- fetch_resource(fn -> Funnels.get_funnel!(funnel_id) end),
         {:ok, data_source} <- fetch_resource(fn -> Funnels.get_data_source!(funnel, id) end),
         {:ok, _data_source} <- Funnels.delete_data_source(data_source) do
      Logger.info("admin.funnel.data_source deleted funnel=#{funnel.id} id=#{data_source.id}")

      send_resp(conn, :no_content, "")
    end
  end
end
