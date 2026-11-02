defmodule PixelAudit.ApiWeb.Admin.Funnels.ReportController do
  use PixelAudit.ApiWeb, :controller
  use OpenApiSpex.ControllerSpecs

  import PixelAudit.ApiWeb.ControllerHelpers

  alias PixelAudit.Api.{Funnels, Reporting}
  alias PixelAudit.ApiWeb.OpenApi.Schemas

  action_fallback PixelAudit.ApiWeb.FallbackController

  tags(["funnel-report"])

  operation(:show,
    operation_id: "admin.getFunnelReport",
    summary: "The funnel's counts over a date range, per data source and step",
    description:
      "Read from the daily cache: a cell sums the days that counted, and says how many " <>
        "days counted, failed or were never computed.",
    parameters: [
      funnel_id: [
        in: :path,
        type: %OpenApiSpex.Schema{type: :string},
        required: true,
        description: "Funnel id"
      ],
      date_from: [
        in: :query,
        type: %OpenApiSpex.Schema{type: :string, format: :date},
        required: true
      ],
      date_to: [
        in: :query,
        type: %OpenApiSpex.Schema{type: :string, format: :date},
        required: true
      ]
    ],
    responses: [
      ok: {"Report", "application/json", Schemas.ReportResponse},
      unprocessable_entity: {"Bad range", "application/json", Schemas.Error},
      not_found: {"Not found", "application/json", Schemas.Error}
    ]
  )

  operation(:step,
    operation_id: "admin.getStepReport",
    summary: "One step's counts day by day over a date range, per data source",
    description:
      "Read from the daily cache: for every data source of the funnel a point per day of " <>
        "the range — the day's count, or why there is none (failed, or never computed).",
    parameters: [
      funnel_id: [
        in: :path,
        type: %OpenApiSpex.Schema{type: :string},
        required: true,
        description: "Funnel id"
      ],
      step_id: [
        in: :path,
        type: %OpenApiSpex.Schema{type: :string},
        required: true,
        description: "Step id"
      ],
      date_from: [
        in: :query,
        type: %OpenApiSpex.Schema{type: :string, format: :date},
        required: true
      ],
      date_to: [
        in: :query,
        type: %OpenApiSpex.Schema{type: :string, format: :date},
        required: true
      ]
    ],
    responses: [
      ok: {"Step report", "application/json", Schemas.StepReportResponse},
      unprocessable_entity: {"Bad range", "application/json", Schemas.Error},
      not_found: {"Not found", "application/json", Schemas.Error}
    ]
  )

  def step(conn, %{"funnel_id" => funnel_id, "step_id" => step_id} = params) do
    with {:ok, funnel} <- fetch_resource(fn -> Funnels.get_funnel!(funnel_id) end),
         {:ok, step} <- find_step(funnel, step_id),
         {:ok, date_from, date_to} <-
           Reporting.parse_range(params["date_from"], params["date_to"]) do
      render(conn, :step,
        funnel: funnel,
        step: step,
        series: Reporting.step_series(funnel, step, date_from, date_to)
      )
    end
  end

  defp find_step(funnel, step_id) do
    case Enum.find(funnel.steps, &(&1.id == step_id)) do
      nil -> {:error, :not_found}
      step -> {:ok, step}
    end
  end

  def show(conn, %{"funnel_id" => funnel_id} = params) do
    with {:ok, funnel} <- fetch_resource(fn -> Funnels.get_funnel!(funnel_id) end),
         {:ok, date_from, date_to} <-
           Reporting.parse_range(params["date_from"], params["date_to"]) do
      render(conn, :show, funnel: funnel, report: Reporting.report(funnel, date_from, date_to))
    end
  end
end
