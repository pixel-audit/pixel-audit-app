defmodule PixelAudit.Api.ReportingTest do
  use PixelAudit.Api.DataCase, async: true
  use Oban.Testing, repo: PixelAudit.Api.Repo

  import PixelAudit.Api.Fixtures

  alias PixelAudit.Api.{Connections, Funnels, Reporting}
  alias PixelAudit.Api.Reporting.{MetaPixelRefreshJob, RefreshJob, Schedule}

  describe "parse_range/2" do
    test "reads the dates and refuses bad ranges" do
      assert {:ok, ~D[2026-10-01], ~D[2026-10-31]} =
               Reporting.parse_range("2026-10-01", "2026-10-31")

      assert {:error, :missing_date} = Reporting.parse_range(nil, "2026-10-31")
      assert {:error, :invalid_date} = Reporting.parse_range("yesterday", "2026-10-31")
      assert {:error, :invalid_date_range} = Reporting.parse_range("2026-10-31", "2026-10-01")
      assert {:error, :range_too_large} = Reporting.parse_range("2025-01-01", "2026-12-31")
    end
  end

  describe "refresh_funnel/5" do
    test "enqueues one run per data source, a Meta pull first for a Meta source" do
      %{funnel: funnel} = measured_funnel_fixture()
      meta = connection_fixture(:meta)
      data_source_fixture(funnel, meta, :meta_pixel_api)
      funnel = Funnels.get_funnel!(funnel.id)

      {:ok, runs} = Reporting.refresh_funnel(funnel, ~D[2026-10-01], ~D[2026-10-03], :manual)

      assert Enum.map(runs, &{&1.kind, &1.status, &1.trigger}) == [
               {:data_source, :queued, :manual},
               {:meta_pixel, :queued, :manual},
               {:data_source, :queued, :manual}
             ]

      assert_enqueued(worker: RefreshJob, args: %{refresh_run_id: Enum.at(runs, 0).id})
      assert_enqueued(worker: MetaPixelRefreshJob, args: %{refresh_run_id: Enum.at(runs, 1).id})
      assert Enum.all?(runs, & &1.oban_job_id)

      assert {:error, :not_found} =
               Reporting.refresh_funnel(funnel, ~D[2026-10-01], ~D[2026-10-03], :manual,
                 data_source_id: Ecto.UUID.generate()
               )
    end
  end

  describe "RefreshJob" do
    test "computes every step and day through the connector and the report sums them" do
      %{funnel: funnel, steps: [visit, cart, purchase], data_source: data_source} =
        measured_funnel_fixture()

      {:ok, run} =
        Reporting.refresh_data_source(data_source, ~D[2026-10-01], ~D[2026-10-03], :manual)

      assert :ok = perform_job(RefreshJob, %{refresh_run_id: run.id})

      run = Reporting.get_refresh_run!(run.id)
      assert run.status == :done
      assert run.started_at
      assert run.finished_at

      report = Reporting.report(funnel, ~D[2026-10-01], ~D[2026-10-05])
      assert report.days == 5

      cell = fn step ->
        Enum.find(report.cells, &(&1.step_id == step.id and &1.data_source_id == data_source.id))
      end

      assert %{count: 300, days_ok: 3, days_error: 0, days_missing: 2} = cell.(visit)
      assert %{count: 120} = cell.(cart)
      assert %{count: 30} = cell.(purchase)

      assert [%{from_step_id: from, to_step_id: to, rate: rate}, %{rate: rate2}] =
               report.conversions

      assert {from, to} == {visit.id, cart.id}
      assert_in_delta rate, 0.4, 0.0001
      assert_in_delta rate2, 0.25, 0.0001
    end

    test "puts the day into the SQL as typed date literals" do
      alias PixelAudit.Api.Funnels.DataSourceType.PostgresQuery

      assert PostgresQuery.with_dates(
               "SELECT COUNT(*) FROM e WHERE at >= $1 AND at < $2 + 1 AND x = $10;",
               ~D[2026-10-20],
               ~D[2026-10-21]
             ) ==
               "SELECT COUNT(*) FROM e WHERE at >= DATE '2026-10-20' AND at < DATE '2026-10-21' + 1 AND x = $10"
    end

    test "stores a day's failure and marks the run failed" do
      %{funnel: funnel, steps: [visit | _], data_source: data_source} = measured_funnel_fixture()

      {:ok, _} =
        Funnels.put_step_parameters(data_source, visit, %{
          "parameters" => %{"sql" => "SELECT 1, 2"}
        })

      {:ok, run} =
        Reporting.refresh_data_source(data_source, ~D[2026-10-01], ~D[2026-10-01], :cron)

      assert :ok = perform_job(RefreshJob, %{refresh_run_id: run.id})

      run = Reporting.get_refresh_run!(run.id)
      assert run.status == :failed
      assert run.error =~ "1 of 3 day counts failed"

      days = Reporting.list_run_days(run)

      assert Enum.map(days, &{&1.step.code, &1.status}) == [
               {"visit", :error},
               {"cart", :ok},
               {"purchase", :ok}
             ]

      assert hd(days).error =~ "2 columns"

      report = Reporting.report(Funnels.get_funnel!(funnel.id), ~D[2026-10-01], ~D[2026-10-01])
      cell = Enum.find(report.cells, &(&1.step_id == visit.id))
      assert %{count: nil, days_ok: 0, days_error: 1, days_missing: 0} = cell
      assert cell.last_error =~ "2 columns"
    end

    test "a step without parameters is not measured" do
      %{funnel: funnel, steps: [visit | _], data_source: data_source} = measured_funnel_fixture()
      {:ok, :ok} = Funnels.delete_step_parameters(data_source, visit)

      report = Reporting.report(Funnels.get_funnel!(funnel.id), ~D[2026-10-01], ~D[2026-10-01])
      assert %{count: nil, days_missing: 0} = Enum.find(report.cells, &(&1.step_id == visit.id))
    end

    test "a Meta source waits for its connection's pull, then counts from the cache" do
      funnel = funnel_fixture()
      step = step_fixture(funnel)
      meta = connection_fixture(:meta)
      data_source = data_source_fixture(funnel, meta, :meta_pixel_api)

      {:ok, _} =
        Funnels.put_step_parameters(data_source, step, %{
          "parameters" => %{"event_name" => "Purchase"}
        })

      {:ok, meta_run} =
        Reporting.refresh_meta_connection(meta, ~D[2026-10-30], ~D[2026-10-30], :manual)

      {:ok, run} =
        Reporting.refresh_data_source(data_source, ~D[2026-10-30], ~D[2026-10-30], :manual)

      assert {:snooze, 60} = perform_job(RefreshJob, %{refresh_run_id: run.id})

      Req.Test.stub(PixelAudit.Api.Connections.Connector, fn conn ->
        Req.Test.json(
          conn,
          meta_stats_page([{"2026-10-30T10:00:00+0000", [{"Purchase", 5}, {"PageView", 50}]}])
        )
      end)

      assert :ok = perform_job(MetaPixelRefreshJob, %{refresh_run_id: meta_run.id})
      assert Reporting.get_refresh_run!(meta_run.id).status == :done

      assert :ok = perform_job(RefreshJob, %{refresh_run_id: run.id})
      report = Reporting.report(Funnels.get_funnel!(funnel.id), ~D[2026-10-30], ~D[2026-10-30])
      assert [%{count: 5, days_ok: 1}] = report.cells
    end
  end

  describe "MetaPixelRefreshJob" do
    test "marks the run failed and retries when Meta refuses" do
      meta = connection_fixture(:meta)
      {:ok, run} = Reporting.refresh_meta_connection(meta, ~D[2026-10-30], ~D[2026-10-30], :cron)

      Req.Test.stub(PixelAudit.Api.Connections.Connector, fn conn ->
        conn |> Plug.Conn.put_status(500) |> Req.Test.json(%{"error" => %{"message" => "boom"}})
      end)

      assert {:error, message} = perform_job(MetaPixelRefreshJob, %{refresh_run_id: run.id})
      assert message =~ "boom"
      assert %{status: :failed, error: error} = Reporting.get_refresh_run!(run.id)
      assert error =~ "boom"
    end
  end

  describe "Schedule" do
    test "the hourly scope pulls every Meta connection for two days" do
      meta = connection_fixture(:meta)
      connection_fixture(:postgres)

      assert :ok = perform_job(Schedule, %{scope: "meta_hourly"})

      %{runs: [run]} = Reporting.list_refresh_runs(%{kind: :meta_pixel})
      assert run.connection_id == meta.id
      assert run.trigger == :cron
      assert Date.diff(run.date_to, run.date_from) == 1
    end

    test "the nightly scope recomputes yesterday and the day before for every data source" do
      %{data_source: data_source} = measured_funnel_fixture()

      assert :ok = perform_job(Schedule, %{scope: "nightly"})

      %{runs: [run]} = Reporting.list_refresh_runs(%{kind: :data_source})
      assert run.data_source_id == data_source.id
      assert run.date_to == Date.add(Date.utc_today(), -1)
      assert run.date_from == Date.add(Date.utc_today(), -2)
    end
  end

  test "a new Meta connection and a parameter change enqueue refreshes" do
    meta = connection_fixture(:meta)
    {:ok, run} = Reporting.refresh_after_connection_created(meta)
    assert run.kind == :meta_pixel
    assert Date.diff(run.date_to, run.date_from) == 6
    assert :ok = Reporting.refresh_after_connection_created(connection_fixture(:postgres))

    %{data_source: data_source} = measured_funnel_fixture()
    {:ok, run} = Reporting.refresh_after_change(data_source)
    assert run.kind == :data_source
    assert run.trigger == :change
    assert Connections.list_connections() != []
  end
end
