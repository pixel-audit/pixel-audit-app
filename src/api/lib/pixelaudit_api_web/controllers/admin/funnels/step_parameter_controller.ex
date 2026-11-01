defmodule PixelAudit.ApiWeb.Admin.Funnels.StepParameterController do
  use PixelAudit.ApiWeb, :controller
  use OpenApiSpex.ControllerSpecs

  import PixelAudit.ApiWeb.ControllerHelpers

  require Logger

  alias PixelAudit.Api.{Funnels, Reporting}
  alias PixelAudit.ApiWeb.OpenApi.Schemas

  action_fallback PixelAudit.ApiWeb.FallbackController

  @uuid %OpenApiSpex.Schema{type: :string, format: :uuid}
  @parameters [
    funnel_id: [
      in: :path,
      type: %OpenApiSpex.Schema{type: :string},
      required: true,
      description: "Funnel id or code"
    ],
    data_source_id: [in: :path, type: @uuid, required: true, description: "Data source id"],
    step_id: [in: :path, type: @uuid, required: true, description: "Step id"]
  ]

  tags(["funnel-data-sources"])

  operation(:update,
    operation_id: "admin.putFunnelStepParameters",
    summary: "Set what the data source needs to count the step",
    description:
      "Replaces the step's parameters for the data source, keyed by the type's parameter " <>
        "keys, and enqueues a recomputation of the data source's recent days.",
    parameters: @parameters,
    request_body: {"Parameters", "application/json", Schemas.StepParameterParams},
    responses: [
      ok: {"The step's parameters", "application/json", Schemas.StepParameterResponse},
      unprocessable_entity: {"Validation errors", "application/json", Schemas.ValidationErrors},
      not_found: {"Not found", "application/json", Schemas.Error}
    ]
  )

  def update(conn, %{
        "funnel_id" => funnel_id,
        "data_source_id" => data_source_id,
        "step_id" => step_id
      }) do
    with {:ok, funnel} <- fetch_resource(fn -> Funnels.get_funnel!(funnel_id) end),
         {:ok, data_source} <-
           fetch_resource(fn -> Funnels.get_data_source!(funnel, data_source_id) end),
         {:ok, step} <- fetch_resource(fn -> Funnels.get_step!(funnel, step_id) end),
         {:ok, step_parameter} <- Funnels.put_step_parameters(data_source, step, conn.body_params) do
      Logger.info(
        "admin.funnel.step_parameters set funnel=#{funnel.code} data_source=#{data_source.code} step=#{step.code}"
      )

      Reporting.refresh_after_change(data_source)

      conn
      |> put_view(json: PixelAudit.ApiWeb.Admin.Funnels.DataSourceJSON)
      |> json(%{
        data: PixelAudit.ApiWeb.Admin.Funnels.DataSourceJSON.step_parameter(step_parameter)
      })
    end
  end

  operation(:delete,
    operation_id: "admin.deleteFunnelStepParameters",
    summary: "Stop the data source measuring the step",
    description: "Its cached counts for the step go too.",
    parameters: @parameters,
    responses: [
      no_content: "Deleted",
      not_found: {"Not found", "application/json", Schemas.Error}
    ]
  )

  def delete(conn, %{
        "funnel_id" => funnel_id,
        "data_source_id" => data_source_id,
        "step_id" => step_id
      }) do
    with {:ok, funnel} <- fetch_resource(fn -> Funnels.get_funnel!(funnel_id) end),
         {:ok, data_source} <-
           fetch_resource(fn -> Funnels.get_data_source!(funnel, data_source_id) end),
         {:ok, step} <- fetch_resource(fn -> Funnels.get_step!(funnel, step_id) end),
         {:ok, _} <- Funnels.delete_step_parameters(data_source, step) do
      Logger.info(
        "admin.funnel.step_parameters cleared funnel=#{funnel.code} data_source=#{data_source.code} step=#{step.code}"
      )

      send_resp(conn, :no_content, "")
    end
  end
end
