defmodule PixelAudit.Api.Settings.GatewayTest do
  use PixelAudit.Api.DataCase, async: true
  use Oban.Testing, repo: PixelAudit.Api.Repo

  import PixelAudit.Api.Fixtures

  alias PixelAudit.Api.Settings
  alias PixelAudit.Api.Reporting.Citation
  alias PixelAudit.Api.Settings.{ConnectionCall, Gateway}

  describe "query/3" do
    test "runs the query through the connection's connector and records it" do
      connection = connection_fixture(:postgres)

      assert {:ok, [[42]]} =
               Gateway.query(connection, "SELECT 42 WHERE $1::date <= $2::date", [
                 ~D[2026-10-01],
                 ~D[2026-10-02]
               ])

      assert %{calls: [call], total: 1} = Settings.list_connection_calls(connection)
      assert call.kind == :query
      assert call.status == :ok
      assert call.sql == "SELECT 42 WHERE $1::date <= $2::date"
      assert call.params == ["2026-10-01", "2026-10-02"]
      assert call.result == [[42]]
      assert call.error == nil
      assert is_integer(call.duration_ms) and call.duration_ms >= 0
      assert %DateTime{} = call.started_at

      # A UUIDv7 from the database: time-ordered, version nibble 7.
      assert <<_::binary-size(14), "7", _::binary>> = call.id
    end

    test "records a failed query with its error" do
      connection = connection_fixture(:postgres)
      assert {:error, message} = Gateway.query(connection, "SELECT * FROM no_such_table", [])
      assert message =~ "no_such_table"

      assert %{calls: [%{status: :error, error: ^message, result: nil}]} =
               Settings.list_connection_calls(connection)
    end

    test "normalises what BigQuery's parameters and ClickHouse's look like" do
      assert Gateway.normalise([{"suffix_from", "STRING", "20261001"}]) == [
               ["suffix_from", "STRING", "20261001"]
             ]

      assert Gateway.normalise(%{"date_from" => ~D[2026-10-01], at: ~U[2026-10-01 10:00:00Z]}) ==
               %{"date_from" => "2026-10-01", "at" => "2026-10-01T10:00:00Z"}

      assert Gateway.normalise([[Decimal.new("1.5"), nil, true, :atom]]) == [
               ["1.5", nil, true, "atom"]
             ]
    end
  end

  describe "list_connection_calls/3" do
    test "pages newest first and filters by day" do
      connection = connection_fixture(:postgres)
      other = connection_fixture(:postgres)
      insert_call(other, ~U[2026-10-02 10:00:00Z])

      for day <- 1..5,
          do:
            insert_call(
              connection,
              DateTime.new!(Date.new!(2026, 10, day), ~T[12:00:00], "Etc/UTC")
            )

      assert %{calls: calls, total: 5} = Settings.list_connection_calls(connection)
      assert Enum.map(calls, & &1.started_at.day) == [5, 4, 3, 2, 1]

      assert %{calls: [%{started_at: %{day: 3}}], total: 5} =
               Settings.list_connection_calls(connection, %{}, limit: 1, offset: 2)

      assert %{calls: calls, total: 2} =
               Settings.list_connection_calls(connection, %{
                 date_from: ~D[2026-10-02],
                 date_to: ~D[2026-10-03]
               })

      assert Enum.map(calls, & &1.started_at.day) == [3, 2]
    end
  end

  describe "capture/2" do
    test "gives every call its context and collects them, with what was cited" do
      connection = connection_fixture(:postgres)
      run_id = Ecto.UUID.generate()
      cited_elsewhere = insert_call(connection, DateTime.utc_now())

      {result, calls} =
        Gateway.capture(%{purpose: :check}, fn ->
          {:ok, _} = Gateway.query(connection, "SELECT 1", [])

          {inner, inner_calls} =
            Gateway.capture(%{purpose: :count, date: ~D[2026-10-01]}, fn ->
              Gateway.cite([cited_elsewhere.id])
              Gateway.query(connection, "SELECT 2", [])
            end)

          assert {:ok, [[2]]} = inner
          assert length(inner_calls) == 2
          :done
        end)

      assert result == :done

      assert %{calls: [two, one, _elsewhere], total: 3} =
               Settings.list_connection_calls(connection)

      assert calls == [one.id, cited_elsewhere.id, two.id]
      assert one.purpose == :check
      assert one.date == nil
      # The inner capture keeps the outer context it does not override.
      assert two.purpose == :count
      assert two.date == ~D[2026-10-01]
      assert Gateway.cited_calls() == []
      assert Gateway.last_call_id() == two.id
      refute Enum.any?([one, two], &(&1.refresh_run_id == run_id))
    end

    test "keeps the capture whole when the computation raises" do
      connection = connection_fixture(:postgres)

      assert_raise RuntimeError, fn ->
        Gateway.capture(%{purpose: :count}, fn ->
          Gateway.query(connection, "SELECT 1", [])
          raise "boom"
        end)
      end

      assert Gateway.cited_calls() == []
      assert %{total: 1} = Settings.list_connection_calls(connection)
    end
  end

  describe "a cited call" do
    test "cannot be deleted, and its bodies are kept whole" do
      connection = connection_fixture(:postgres)
      long = String.duplicate("x", 100_000)
      {:ok, _} = Gateway.query(connection, "SELECT '#{long}'", [])
      %{calls: [call]} = Settings.list_connection_calls(connection)
      assert [[^long]] = call.result

      %{funnel: funnel, steps: [step | _], data_source: data_source} = measured_funnel_fixture()

      {:ok, run} =
        PixelAudit.Api.Reporting.refresh_data_source(
          data_source,
          ~D[2026-10-01],
          ~D[2026-10-01],
          :manual
        )

      :ok =
        PixelAudit.Api.Reporting.put_daily_count(
          run,
          data_source,
          step,
          ~D[2026-10-01],
          {:ok, 1},
          [call.id]
        )

      assert [%Citation{call_id: call_id}] = Repo.all(Citation)
      assert call_id == call.id
      assert_raise Ecto.ConstraintError, fn -> Repo.delete!(call) end

      # The value goes, and takes its citation: the call is free.
      {:ok, _} =
        PixelAudit.Api.Funnels.delete_data_source(
          PixelAudit.Api.Funnels.get_data_source!(funnel, data_source.id)
        )

      assert Repo.all(Citation) == []
      assert {:ok, _} = Repo.delete(call)
    end
  end

  defp insert_call(connection, started_at) do
    Repo.insert!(
      ConnectionCall.changeset(%ConnectionCall{}, %{
        connection_id: connection.id,
        kind: :query,
        status: :ok,
        started_at: started_at,
        duration_ms: 1,
        sql: "SELECT 1"
      })
    )
  end
end
