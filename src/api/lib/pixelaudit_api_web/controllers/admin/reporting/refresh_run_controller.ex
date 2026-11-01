defmodule PixelAudit.ApiWeb.Admin.Reporting.RefreshRunController do
  use PixelAudit.ApiWeb, :controller
  use OpenApiSpex.ControllerSpecs

  import PixelAudit.ApiWeb.ControllerHelpers

  alias PixelAudit.Api.Reporting
  alias PixelAudit.ApiWeb.OpenApi.Schemas

  action_fallback PixelAudit.ApiWeb.FallbackController

  @uuid %OpenApiSpex.Schema{type: :string, format: :uuid}

  tags(["reporting"])

  operation(:index,
    operation_id: "admin.listRefreshRuns",
    summary: "List refresh runs, newest first",
    parameters: [
      funnel_id: [in: :query, type: @uuid, required: false],
      connection_id: [in: :query, type: @uuid, required: false],
      data_source_id: [in: :query, type: @uuid, required: false],
      status: [
        in: :query,
        type: %OpenApiSpex.Schema{type: :string, enum: ["queued", "running", "done", "failed"]},
        required: false
      ],
      kind: [
        in: :query,
        type: %OpenApiSpex.Schema{type: :string, enum: ["meta_pixel", "data_source"]},
        required: false
      ],
      limit: [
        in: :query,
        type: %OpenApiSpex.Schema{type: :integer, minimum: 1, maximum: 200},
        required: false
      ],
      offset: [in: :query, type: %OpenApiSpex.Schema{type: :integer, minimum: 0}, required: false]
    ],
    responses: [
      ok: {"Refresh runs", "application/json", Schemas.RefreshRunsResponse},
      unprocessable_entity: {"Bad filter or pagination", "application/json", Schemas.Error}
    ]
  )

  def index(conn, params) do
    with {:ok, pagination} <- pagination(params),
         {:ok, status} <-
           enum_param(params["status"], [:queued, :running, :done, :failed], :invalid_status),
         {:ok, kind} <- enum_param(params["kind"], [:meta_pixel, :data_source], :invalid_kind),
         {:ok, filters} <- id_filters(params, status, kind) do
      %{runs: runs, total: total} = Reporting.list_refresh_runs(filters, pagination)
      render(conn, :index, runs: runs, total: total)
    end
  end

  defp id_filters(params, status, kind) do
    ids =
      for key <- ["funnel_id", "connection_id", "data_source_id"],
          value = params[key],
          is_binary(value) and value != "",
          do: {String.to_existing_atom(key), value}

    if Enum.all?(ids, fn {_, value} -> match?({:ok, _}, Ecto.UUID.cast(value)) end) do
      filters =
        ids
        |> Map.new()
        |> Map.merge(if(status, do: %{status: status}, else: %{}))
        |> Map.merge(if(kind, do: %{kind: kind}, else: %{}))

      {:ok, filters}
    else
      {:error, :not_found}
    end
  end

  operation(:show,
    operation_id: "admin.getRefreshRun",
    summary: "Get a refresh run",
    parameters: [id: [in: :path, type: @uuid, required: true, description: "Run id"]],
    responses: [
      ok: {"Refresh run", "application/json", Schemas.RefreshRunResponse},
      not_found: {"Not found", "application/json", Schemas.Error}
    ]
  )

  def show(conn, %{"id" => id}) do
    with {:ok, run} <- fetch_resource(fn -> Reporting.get_refresh_run_with_assocs!(id) end) do
      render(conn, :show, run: run)
    end
  end

  operation(:days,
    operation_id: "admin.listRefreshRunDays",
    summary: "The days a run computed, each with its outcome",
    description:
      "For a daily-counts run: every step and day it computed, with the count or the " <>
        "error. A later run of the same days takes them over, so an old run may list fewer. " <>
        "A pixel pull has no days.",
    parameters: [id: [in: :path, type: @uuid, required: true, description: "Run id"]],
    responses: [
      ok: {"Days", "application/json", Schemas.RefreshRunDaysResponse},
      not_found: {"Not found", "application/json", Schemas.Error}
    ]
  )

  def days(conn, %{"id" => id}) do
    with {:ok, run} <- fetch_resource(fn -> Reporting.get_refresh_run!(id) end) do
      render(conn, :days, days: Reporting.list_run_days(run))
    end
  end
end
