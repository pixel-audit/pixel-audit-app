defmodule PixelAudit.ApiWeb.Admin.Connections.ConnectionController do
  use PixelAudit.ApiWeb, :controller
  use OpenApiSpex.ControllerSpecs

  import PixelAudit.ApiWeb.ControllerHelpers

  require Logger

  alias PixelAudit.Api.{Connections, Reporting}
  alias PixelAudit.ApiWeb.OpenApi.Schemas

  action_fallback PixelAudit.ApiWeb.FallbackController

  @id_parameter [
    in: :path,
    type: %OpenApiSpex.Schema{type: :string, format: :uuid},
    required: true,
    description: "Connection id"
  ]

  tags(["connections"])

  operation(:types,
    operation_id: "admin.listConnectionTypes",
    summary: "List the connection types and their credential fields",
    responses: [ok: {"Connection types", "application/json", Schemas.ConnectionTypesResponse}]
  )

  def types(conn, _params) do
    render(conn, :types, connectors: PixelAudit.Api.Connections.Connector.all())
  end

  operation(:index,
    operation_id: "admin.listConnections",
    summary: "List connections",
    responses: [ok: {"Connections", "application/json", Schemas.ConnectionsResponse}]
  )

  def index(conn, _params) do
    render(conn, :index, connections: Connections.list_connections())
  end

  operation(:show,
    operation_id: "admin.getConnection",
    summary: "Get a connection",
    parameters: [id: @id_parameter],
    responses: [
      ok: {"Connection", "application/json", Schemas.ConnectionResponse},
      not_found: {"Not found", "application/json", Schemas.Error}
    ]
  )

  def show(conn, %{"id" => id}) do
    with {:ok, connection} <- fetch_resource(fn -> Connections.get_connection!(id) end) do
      render(conn, :show, connection: connection)
    end
  end

  operation(:create,
    operation_id: "admin.createConnection",
    summary: "Create a connection",
    description: "A Meta connection's pixel stats are pulled right away for the last days.",
    request_body: {"Connection", "application/json", Schemas.ConnectionParams},
    responses: [
      created: {"Created connection", "application/json", Schemas.ConnectionResponse},
      unprocessable_entity: {"Validation errors", "application/json", Schemas.ValidationErrors}
    ]
  )

  def create(conn, _params) do
    with {:ok, connection} <- Connections.create_connection(conn.body_params) do
      Logger.info("admin.connection created code=#{connection.code} type=#{connection.type}")
      Reporting.refresh_after_connection_created(connection)

      conn
      |> put_status(:created)
      |> render(:show, connection: connection)
    end
  end

  operation(:update,
    operation_id: "admin.updateConnection",
    summary: "Update a connection",
    description:
      "Only the credential keys sent change; `null` clears one. A connection managed by the " <>
        "environment refuses a change of type or credentials (409 managed_by_env).",
    parameters: [id: @id_parameter],
    request_body: {"Connection", "application/json", Schemas.ConnectionParams},
    responses: [
      ok: {"Updated connection", "application/json", Schemas.ConnectionResponse},
      unprocessable_entity: {"Validation errors", "application/json", Schemas.ValidationErrors},
      conflict: {"Managed by the environment", "application/json", Schemas.Error},
      not_found: {"Not found", "application/json", Schemas.Error}
    ]
  )

  def update(conn, %{"id" => id}) do
    with {:ok, connection} <- fetch_resource(fn -> Connections.get_connection!(id) end),
         {:ok, connection} <- Connections.update_connection(connection, conn.body_params) do
      Logger.info("admin.connection updated code=#{connection.code}")
      render(conn, :show, connection: connection)
    end
  end

  operation(:delete,
    operation_id: "admin.deleteConnection",
    summary: "Delete a connection",
    description: "Refused (409 connection_in_use) while a data source reads through it.",
    parameters: [id: @id_parameter],
    responses: [
      no_content: "Deleted",
      conflict: {"In use", "application/json", Schemas.Error},
      not_found: {"Not found", "application/json", Schemas.Error}
    ]
  )

  def delete(conn, %{"id" => id}) do
    with {:ok, connection} <- fetch_resource(fn -> Connections.get_connection!(id) end),
         {:ok, _connection} <- Connections.delete_connection(connection) do
      Logger.info("admin.connection deleted code=#{connection.code}")
      send_resp(conn, :no_content, "")
    end
  end

  operation(:check,
    operation_id: "admin.checkConnection",
    summary: "Check a connection",
    description:
      "Calls the external system with the credentials and records the outcome on the connection.",
    parameters: [id: @id_parameter],
    responses: [
      ok: {"Connection with the check's outcome", "application/json", Schemas.ConnectionResponse},
      not_found: {"Not found", "application/json", Schemas.Error}
    ]
  )

  def check(conn, %{"id" => id}) do
    with {:ok, connection} <- fetch_resource(fn -> Connections.get_connection!(id) end) do
      {_result, connection} = Connections.check_connection(connection)
      render(conn, :show, connection: connection)
    end
  end

  operation(:refresh,
    operation_id: "admin.refreshConnection",
    summary: "Pull a Meta connection's pixel stats",
    description:
      "Enqueues a pull of the pixel's hourly stats for the range. Meta serves about the " <>
        "last seven days; older days come back empty.",
    parameters: [id: @id_parameter],
    request_body: {"Range", "application/json", Schemas.RefreshRangeParams},
    responses: [
      accepted: {"The enqueued run", "application/json", Schemas.RefreshRunResponse},
      unprocessable_entity:
        {"Not a Meta connection, or a bad range", "application/json", Schemas.Error},
      not_found: {"Not found", "application/json", Schemas.Error}
    ]
  )

  def refresh(conn, %{"id" => id}) do
    params = conn.body_params

    with {:ok, connection} <- fetch_resource(fn -> Connections.get_connection!(id) end),
         {:ok, date_from, date_to} <-
           Reporting.parse_range(params["date_from"], params["date_to"]),
         {:ok, run} <- Reporting.refresh_meta_connection(connection, date_from, date_to, :manual) do
      Logger.info(
        "admin.connection refresh code=#{connection.code} from=#{date_from} to=#{date_to}"
      )

      conn
      |> put_status(:accepted)
      |> put_view(json: PixelAudit.ApiWeb.Admin.Reporting.RefreshRunJSON)
      |> render(:show, run: Reporting.get_refresh_run_with_assocs!(run.id))
    end
  end
end
