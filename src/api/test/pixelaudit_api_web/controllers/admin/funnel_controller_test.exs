defmodule PixelAudit.ApiWeb.Admin.Funnels.FunnelControllerTest do
  use PixelAudit.ApiWeb.ConnCase, async: true
  use Oban.Testing, repo: PixelAudit.Api.Repo

  import PixelAudit.Api.Fixtures

  @base "/api/admin/v1/funnels"

  test "lists the data source types", %{conn: conn} do
    %{"data" => types} = conn |> get("#{@base}/data-source-types") |> json_response(200)
    assert length(types) == 5

    pg = Enum.find(types, &(&1["type"] == "postgres_query"))
    assert pg["connection_type"] == "postgres"
    assert pg["settings"] == []
    assert [%{"key" => "sql", "kind" => "sql", "required" => true}] = pg["parameters"]
  end

  test "reorders the data sources", %{conn: conn} do
    funnel = funnel_fixture()
    connection = connection_fixture(:postgres)
    shop = data_source_fixture(funnel, connection, :postgres_query, %{name: "Shop"})
    warehouse = data_source_fixture(funnel, connection, :postgres_query, %{name: "Warehouse"})
    order_path = "#{@base}/#{funnel.id}/data-sources/order"

    %{"data" => reordered} =
      conn
      |> put(order_path, %{"data_source_ids" => [warehouse.id, shop.id]})
      |> json_response(200)

    assert Enum.map(reordered, &{&1["name"], &1["position"]}) == [{"Warehouse", 0}, {"Shop", 1}]
    assert Enum.map(reordered, & &1["connection"]["id"]) == [connection.id, connection.id]

    %{"data" => shown} = conn |> get("#{@base}/#{funnel.id}") |> json_response(200)
    assert Enum.map(shown["data_sources"], & &1["name"]) == ["Warehouse", "Shop"]

    assert %{"errors" => %{"detail" => "invalid_order"}} =
             conn
             |> put(order_path, %{"data_source_ids" => [shop.id]})
             |> json_response(422)
  end

  test "builds a funnel: steps, data source, parameters, report, refresh", %{conn: conn} do
    %{"data" => funnel} =
      conn |> post(@base, %{"name" => "Checkout"}) |> json_response(201)

    assert funnel["steps"] == []
    assert funnel["data_sources"] == []
    funnel_path = "#{@base}/#{funnel["id"]}"

    %{"data" => visit} =
      conn
      |> post("#{funnel_path}/steps", %{"name" => "Visit"})
      |> json_response(201)

    %{"data" => cart} =
      conn
      |> post("#{funnel_path}/steps", %{"name" => "Cart"})
      |> json_response(201)

    assert [visit["position"], cart["position"]] == [0, 1]

    %{"data" => reordered} =
      conn
      |> put("#{funnel_path}/steps/order", %{"step_ids" => [cart["id"], visit["id"]]})
      |> json_response(200)

    assert Enum.map(reordered, & &1["name"]) == ["Cart", "Visit"]

    assert %{"errors" => %{"detail" => "invalid_order"}} =
             conn
             |> put("#{funnel_path}/steps/order", %{"step_ids" => [cart["id"]]})
             |> json_response(422)

    %{"data" => renamed} =
      conn
      |> put("#{funnel_path}/steps/#{visit["id"]}", %{"name" => "Visited"})
      |> json_response(200)

    assert renamed["name"] == "Visited"

    connection = connection_fixture(:postgres)

    %{"data" => data_source} =
      conn
      |> post("#{funnel_path}/data-sources", %{
        "name" => "Shop DB",
        "type" => "postgres_query",
        "connection_id" => connection.id
      })
      |> json_response(201)

    assert data_source["connection"]["id"] == connection.id
    assert data_source["step_parameters"] == []

    meta = connection_fixture(:meta)

    assert %{"errors" => %{"detail" => "connection_type_mismatch"}} =
             conn
             |> post("#{funnel_path}/data-sources", %{
               "name" => "FB",
               "type" => "postgres_query",
               "connection_id" => meta.id
             })
             |> json_response(422)

    parameters_path =
      "#{funnel_path}/data-sources/#{data_source["id"]}/steps/#{visit["id"]}/parameters"

    assert %{"errors" => %{"parameters.sql" => ["can't be blank"]}} =
             conn |> put(parameters_path, %{"parameters" => %{}}) |> json_response(422)

    %{"data" => parameter} =
      conn
      |> put(parameters_path, %{
        "parameters" => %{"sql" => "SELECT 7 WHERE $1 <= $2"},
        "description" => "Seven, always.",
        "primary" => true
      })
      |> json_response(200)

    assert parameter["step_id"] == visit["id"]
    assert parameter["description"] == "Seven, always."
    assert parameter["primary"] == true
    assert_enqueued(worker: PixelAudit.Api.Reporting.RefreshJob)

    %{"data" => shown} = conn |> get(funnel_path) |> json_response(200)
    assert conn |> get("#{@base}/nosuch") |> json_response(404)
    assert conn |> get("#{@base}/#{Ecto.UUID.generate()}") |> json_response(404)

    assert [%{"step_parameters" => [%{"step_id" => step_id, "description" => "Seven, always."}]}] =
             shown["data_sources"]

    assert step_id == visit["id"]

    # The report before any computation: the measured cell is missing every day.
    %{"data" => report} =
      conn
      |> get("#{funnel_path}/report?date_from=2026-10-01&date_to=2026-10-02")
      |> json_response(200)

    assert report["days"] == 2
    assert Enum.map(report["steps"], & &1["name"]) == ["Cart", "Visited"]

    visit_cell = Enum.find(report["cells"], &(&1["step_id"] == visit["id"]))
    assert %{"count" => nil, "days_missing" => 2, "days_ok" => 0} = visit_cell
    cart_cell = Enum.find(report["cells"], &(&1["step_id"] == cart["id"]))
    assert %{"count" => nil, "days_missing" => 0} = cart_cell

    assert %{"errors" => %{"detail" => "missing_date"}} =
             conn |> get("#{funnel_path}/report?date_from=2026-10-01") |> json_response(422)

    %{"data" => runs} =
      conn
      |> post("#{funnel_path}/refresh", %{"date_from" => "2026-10-01", "date_to" => "2026-10-02"})
      |> json_response(202)

    assert [
             %{
               "kind" => "data_source",
               "trigger" => "manual",
               "funnel" => %{"name" => "Checkout"}
             }
           ] = runs

    assert conn |> delete(parameters_path) |> response(204)
    assert conn |> delete("#{funnel_path}/data-sources/#{data_source["id"]}") |> response(204)
    assert conn |> delete("#{funnel_path}/steps/#{cart["id"]}") |> response(204)
    assert conn |> delete(funnel_path) |> response(204)
    assert conn |> get(funnel_path) |> json_response(404)
  end

  test "lists funnels with their steps and data sources", %{conn: conn} do
    %{funnel: funnel} = measured_funnel_fixture()

    %{"data" => [listed]} = conn |> get(@base) |> json_response(200)
    assert listed["id"] == funnel.id
    assert length(listed["steps"]) == 3

    assert [%{"type" => "postgres_query", "step_parameters" => parameters}] =
             listed["data_sources"]

    assert length(parameters) == 3
  end

  test "lists refresh runs with filters and pagination", %{conn: conn} do
    %{funnel: funnel, data_source: data_source} = measured_funnel_fixture()
    other = measured_funnel_fixture()

    for _ <- 1..3,
        do:
          {:ok, _} =
            PixelAudit.Api.Reporting.refresh_data_source(
              data_source,
              ~D[2026-10-01],
              ~D[2026-10-01],
              :cron
            )

    {:ok, _} =
      PixelAudit.Api.Reporting.refresh_data_source(
        other.data_source,
        ~D[2026-10-01],
        ~D[2026-10-01],
        :manual
      )

    %{"data" => runs, "total" => 4} =
      conn |> get("/api/admin/v1/reporting/refresh-runs") |> json_response(200)

    assert length(runs) == 4

    %{"data" => runs, "total" => 3} =
      conn
      |> get("/api/admin/v1/reporting/refresh-runs?funnel_id=#{funnel.id}&limit=2")
      |> json_response(200)

    assert length(runs) == 2

    %{"data" => [run]} =
      conn
      |> get("/api/admin/v1/reporting/refresh-runs?status=queued&limit=1")
      |> json_response(200)

    %{"data" => shown} =
      conn |> get("/api/admin/v1/reporting/refresh-runs/#{run["id"]}") |> json_response(200)

    assert shown["data_source"]["id"] in [data_source.id, other.data_source.id]

    %{"data" => days} =
      conn |> get("/api/admin/v1/reporting/refresh-runs/#{run["id"]}/days") |> json_response(200)

    assert days == []

    assert %{"errors" => %{"detail" => "invalid_status"}} =
             conn
             |> get("/api/admin/v1/reporting/refresh-runs?status=maybe")
             |> json_response(422)

    assert %{"errors" => %{"detail" => "invalid_pagination"}} =
             conn |> get("/api/admin/v1/reporting/refresh-runs?limit=0") |> json_response(422)
  end
end
