defmodule PixelAudit.ApiWeb.Admin.Funnels.RefreshController do
  use PixelAudit.ApiWeb, :controller
  use OpenApiSpex.ControllerSpecs

  import PixelAudit.ApiWeb.ControllerHelpers

  require Logger

  alias PixelAudit.Api.{Funnels, Reporting}
  alias PixelAudit.ApiWeb.OpenApi.Schemas

  action_fallback PixelAudit.ApiWeb.FallbackController

  tags(["funnel-report"])

  operation(:create,
    operation_id: "admin.refreshFunnel",
    summary: "Recompute the funnel's daily counts over a date range",
    description:
      "Enqueues one run per data source (or the one named by `data_source_id`); a Meta " <>
        "data source's connection is pulled first. Answers with the runs.",
    parameters: [
      funnel_id: [
        in: :path,
        type: %OpenApiSpex.Schema{type: :string},
        required: true,
        description: "Funnel id"
      ]
    ],
    request_body: {"Range", "application/json", Schemas.RefreshRangeParams},
    responses: [
      accepted: {"The enqueued runs", "application/json", Schemas.RefreshRunsCreatedResponse},
      unprocessable_entity: {"Bad range", "application/json", Schemas.Error},
      not_found: {"Not found", "application/json", Schemas.Error}
    ]
  )

  def create(conn, %{"funnel_id" => funnel_id}) do
    params = conn.body_params

    with {:ok, funnel} <- fetch_resource(fn -> Funnels.get_funnel!(funnel_id) end),
         {:ok, date_from, date_to} <-
           Reporting.parse_range(params["date_from"], params["date_to"]),
         {:ok, runs} <-
           Reporting.refresh_funnel(funnel, date_from, date_to, :manual,
             data_source_id: params["data_source_id"]
           ) do
      Logger.info(
        "admin.funnel refresh id=#{funnel.id} from=#{date_from} to=#{date_to} runs=#{length(runs)}"
      )

      runs = Enum.map(runs, &Reporting.get_refresh_run_with_assocs!(&1.id))

      conn
      |> put_status(:accepted)
      |> put_view(json: PixelAudit.ApiWeb.Admin.Reporting.RefreshRunJSON)
      |> render(:created, runs: runs)
    end
  end
end
