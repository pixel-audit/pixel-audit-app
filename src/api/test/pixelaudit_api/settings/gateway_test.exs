defmodule PixelAudit.Api.Settings.GatewayTest do
  use PixelAudit.Api.DataCase, async: true
  use Oban.Testing, repo: PixelAudit.Api.Repo

  import PixelAudit.Api.Fixtures

  alias PixelAudit.Api.Settings
  alias PixelAudit.Api.Settings.{CallsCleanupJob, ConnectionCall, Gateway}

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

  describe "CallsCleanupJob" do
    test "deletes the calls older than the retention" do
      connection = connection_fixture(:postgres)
      old = insert_call(connection, DateTime.add(DateTime.utc_now(), -31, :day))
      recent = insert_call(connection, DateTime.add(DateTime.utc_now(), -29, :day))

      assert :ok = perform_job(CallsCleanupJob, %{})

      assert Enum.map(Settings.list_connection_calls(connection).calls, & &1.id) == [recent.id]
      refute Repo.get(ConnectionCall, old.id)
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
