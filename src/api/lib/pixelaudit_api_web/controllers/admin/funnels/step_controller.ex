defmodule PixelAudit.ApiWeb.Admin.Funnels.StepController do
  use PixelAudit.ApiWeb, :controller
  use OpenApiSpex.ControllerSpecs

  import PixelAudit.ApiWeb.ControllerHelpers

  require Logger

  alias PixelAudit.Api.Funnels
  alias PixelAudit.ApiWeb.OpenApi.Schemas

  action_fallback PixelAudit.ApiWeb.FallbackController

  @funnel_parameter [
    in: :path,
    type: %OpenApiSpex.Schema{type: :string},
    required: true,
    description: "Funnel id or code"
  ]
  @id_parameter [
    in: :path,
    type: %OpenApiSpex.Schema{type: :string, format: :uuid},
    required: true,
    description: "Step id"
  ]

  tags(["funnel-steps"])

  operation(:create,
    operation_id: "admin.createFunnelStep",
    summary: "Add a step at the end of the funnel",
    parameters: [funnel_id: @funnel_parameter],
    request_body: {"Step", "application/json", Schemas.StepParams},
    responses: [
      created: {"Created step", "application/json", Schemas.StepResponse},
      unprocessable_entity: {"Validation errors", "application/json", Schemas.ValidationErrors},
      not_found: {"Not found", "application/json", Schemas.Error}
    ]
  )

  def create(conn, %{"funnel_id" => funnel_id}) do
    with {:ok, funnel} <- fetch_resource(fn -> Funnels.get_funnel!(funnel_id) end),
         {:ok, step} <- Funnels.create_step(funnel, conn.body_params) do
      Logger.info("admin.funnel.step created funnel=#{funnel.code} code=#{step.code}")

      conn
      |> put_status(:created)
      |> render(:show, step: step)
    end
  end

  operation(:update,
    operation_id: "admin.updateFunnelStep",
    summary: "Update a step",
    parameters: [funnel_id: @funnel_parameter, id: @id_parameter],
    request_body: {"Step", "application/json", Schemas.StepParams},
    responses: [
      ok: {"Updated step", "application/json", Schemas.StepResponse},
      unprocessable_entity: {"Validation errors", "application/json", Schemas.ValidationErrors},
      not_found: {"Not found", "application/json", Schemas.Error}
    ]
  )

  def update(conn, %{"funnel_id" => funnel_id, "id" => id}) do
    with {:ok, funnel} <- fetch_resource(fn -> Funnels.get_funnel!(funnel_id) end),
         {:ok, step} <- fetch_resource(fn -> Funnels.get_step!(funnel, id) end),
         {:ok, step} <- Funnels.update_step(step, conn.body_params) do
      Logger.info("admin.funnel.step updated funnel=#{funnel.code} code=#{step.code}")
      render(conn, :show, step: step)
    end
  end

  operation(:delete,
    operation_id: "admin.deleteFunnelStep",
    summary: "Delete a step and its cached counts",
    parameters: [funnel_id: @funnel_parameter, id: @id_parameter],
    responses: [
      no_content: "Deleted",
      not_found: {"Not found", "application/json", Schemas.Error}
    ]
  )

  def delete(conn, %{"funnel_id" => funnel_id, "id" => id}) do
    with {:ok, funnel} <- fetch_resource(fn -> Funnels.get_funnel!(funnel_id) end),
         {:ok, step} <- fetch_resource(fn -> Funnels.get_step!(funnel, id) end),
         {:ok, _step} <- Funnels.delete_step(step) do
      Logger.info("admin.funnel.step deleted funnel=#{funnel.code} code=#{step.code}")
      send_resp(conn, :no_content, "")
    end
  end

  operation(:reorder,
    operation_id: "admin.reorderFunnelSteps",
    summary: "Put the steps in the given order",
    description:
      "`step_ids` must name every step of the funnel exactly once (422 invalid_order).",
    parameters: [funnel_id: @funnel_parameter],
    request_body: {"Order", "application/json", Schemas.StepOrderParams},
    responses: [
      ok: {"The steps in their new order", "application/json", Schemas.StepsResponse},
      unprocessable_entity: {"Invalid order", "application/json", Schemas.Error},
      not_found: {"Not found", "application/json", Schemas.Error}
    ]
  )

  def reorder(conn, %{"funnel_id" => funnel_id}) do
    with {:ok, funnel} <- fetch_resource(fn -> Funnels.get_funnel!(funnel_id) end),
         {:ok, steps} <- Funnels.reorder_steps(funnel, conn.body_params["step_ids"]) do
      Logger.info("admin.funnel.steps reordered funnel=#{funnel.code}")
      render(conn, :index, steps: steps)
    end
  end
end
