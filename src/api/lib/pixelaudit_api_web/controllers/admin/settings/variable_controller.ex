defmodule PixelAudit.ApiWeb.Admin.Settings.VariableController do
  use PixelAudit.ApiWeb, :controller
  use OpenApiSpex.ControllerSpecs

  import PixelAudit.ApiWeb.ControllerHelpers

  require Logger

  alias PixelAudit.Api.Settings
  alias PixelAudit.ApiWeb.OpenApi.Schemas

  action_fallback PixelAudit.ApiWeb.FallbackController

  @id_parameter [
    in: :path,
    type: %OpenApiSpex.Schema{type: :string, format: :uuid},
    required: true,
    description: "Variable id"
  ]

  tags(["variables"])

  operation(:index,
    operation_id: "admin.listVariables",
    summary: "List variables",
    responses: [ok: {"Variables", "application/json", Schemas.VariablesResponse}]
  )

  def index(conn, _params) do
    render(conn, :index, variables: Settings.list_variables())
  end

  operation(:show,
    operation_id: "admin.getVariable",
    summary: "Get a variable",
    parameters: [id: @id_parameter],
    responses: [
      ok: {"Variable", "application/json", Schemas.VariableResponse},
      not_found: {"Not found", "application/json", Schemas.Error}
    ]
  )

  def show(conn, %{"id" => id}) do
    with {:ok, variable} <- fetch_resource(fn -> Settings.get_variable!(id) end) do
      render(conn, :show, variable: variable)
    end
  end

  operation(:create,
    operation_id: "admin.createVariable",
    summary: "Create a variable",
    request_body: {"Variable", "application/json", Schemas.VariableParams},
    responses: [
      created: {"Created variable", "application/json", Schemas.VariableResponse},
      unprocessable_entity: {"Validation errors", "application/json", Schemas.ValidationErrors}
    ]
  )

  def create(conn, _params) do
    with {:ok, variable} <- Settings.create_variable(conn.body_params) do
      Logger.info("admin.variable created key=#{variable.key}")

      conn
      |> put_status(:created)
      |> render(:show, variable: variable)
    end
  end

  operation(:update,
    operation_id: "admin.updateVariable",
    summary: "Update a variable",
    description:
      "A variable managed by the environment refuses a change of key or value " <>
        "(409 managed_by_env); its description stays editable.",
    parameters: [id: @id_parameter],
    request_body: {"Variable", "application/json", Schemas.VariableParams},
    responses: [
      ok: {"Updated variable", "application/json", Schemas.VariableResponse},
      unprocessable_entity: {"Validation errors", "application/json", Schemas.ValidationErrors},
      conflict: {"Managed by the environment", "application/json", Schemas.Error},
      not_found: {"Not found", "application/json", Schemas.Error}
    ]
  )

  def update(conn, %{"id" => id}) do
    with {:ok, variable} <- fetch_resource(fn -> Settings.get_variable!(id) end),
         {:ok, variable} <- Settings.update_variable(variable, conn.body_params) do
      Logger.info("admin.variable updated key=#{variable.key}")
      render(conn, :show, variable: variable)
    end
  end

  operation(:delete,
    operation_id: "admin.deleteVariable",
    summary: "Delete a variable",
    parameters: [id: @id_parameter],
    responses: [
      no_content: "Deleted",
      not_found: {"Not found", "application/json", Schemas.Error}
    ]
  )

  def delete(conn, %{"id" => id}) do
    with {:ok, variable} <- fetch_resource(fn -> Settings.get_variable!(id) end),
         {:ok, _variable} <- Settings.delete_variable(variable) do
      Logger.info("admin.variable deleted key=#{variable.key}")
      send_resp(conn, :no_content, "")
    end
  end
end
