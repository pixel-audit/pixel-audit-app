defmodule PixelAudit.Api.Settings.Connector.MetaTest do
  use PixelAudit.Api.DataCase, async: true

  import PixelAudit.Api.Fixtures

  alias PixelAudit.Api.Settings
  alias PixelAudit.Api.Settings.Connector.Meta

  setup do
    connection =
      connection_fixture(:meta, %{
        credentials: %{"access_token" => "tok", "pixel_id" => "999", "api_version" => "v25.0"}
      })

    %{connection: connection}
  end

  test "reads hourly rows out of /stats and follows the paging", %{connection: connection} do
    Req.Test.stub(PixelAudit.Api.Settings.Connector, fn conn ->
      assert conn.request_path == "/v25.0/999/stats"
      assert conn.query_params["aggregation"] == "event"
      assert conn.query_params["start_time"] == "1793318400"
      assert Plug.Conn.get_req_header(conn, "authorization") == ["Bearer tok"]
      refute Map.has_key?(conn.query_params, "access_token")

      case conn.query_params["after"] do
        nil ->
          Req.Test.json(
            conn,
            meta_stats_page(
              [
                {"2026-10-30T00:00:00+0000", [{"PageView", 10}, {"Purchase", 1}]},
                {"2026-10-30T01:00:00+0000", [{"PageView", 7}]}
              ],
              %{"cursors" => %{"after" => "c2"}, "next" => "https://graph.facebook.com/next"}
            )
          )

        "c2" ->
          Req.Test.json(conn, meta_stats_page([{"2026-10-30T23:00:00+0000", [{"PageView", 1}]}]))
      end
    end)

    assert {:ok, rows} =
             Meta.fetch_stats(connection, ~U[2026-10-30 00:00:00Z], ~U[2026-10-31 00:00:00Z])

    assert Enum.map(rows, &Map.delete(&1, :call_id)) == [
             %{date: ~D[2026-10-30], hour: 0, event_name: "PageView", count: 10},
             %{date: ~D[2026-10-30], hour: 0, event_name: "Purchase", count: 1},
             %{date: ~D[2026-10-30], hour: 1, event_name: "PageView", count: 7},
             %{date: ~D[2026-10-30], hour: 23, event_name: "PageView", count: 1}
           ]

    # Both pages were recorded through the gateway, the token in neither;
    # each hour names the page that delivered it.
    %{calls: [second, first], total: 2} = Settings.list_connection_calls(connection)
    assert Enum.map(rows, & &1.call_id) == [first.id, first.id, first.id, second.id]
    assert first.kind == :api_call
    assert first.status == :ok
    assert first.method == "GET"
    assert first.url =~ "/v25.0/999/stats?"
    assert first.url =~ "aggregation=event"
    refute first.url =~ "tok"
    assert first.response_status == 200
    assert first.response_content_type =~ "application/json"
    assert first.response_body =~ "PageView"
    assert second.url =~ "after=c2"
  end

  test "walks every page by cursor and stops at the empty one past the last",
       %{connection: connection} do
    Req.Test.stub(PixelAudit.Api.Settings.Connector, fn conn ->
      # Every page carries a `next` link (with the token in it, as Meta
      # writes it) and an `after` cursor, the page past the last too.
      paging = fn after_cursor ->
        %{
          "cursors" => %{"before" => "b", "after" => after_cursor},
          "next" =>
            "https://graph.facebook.com/v26.0/999/stats?access_token=SECRET&after=" <>
              after_cursor
        }
      end

      refute conn.query_params["access_token"]

      case conn.query_params["after"] do
        nil ->
          Req.Test.json(
            conn,
            meta_stats_page([{"2026-11-01T16:00:00+0000", [{"PageView", 783}]}], paging.("c2"))
          )

        "c2" ->
          Req.Test.json(
            conn,
            meta_stats_page([{"2026-11-01T17:00:00+0000", [{"PageView", 715}]}], paging.("c3"))
          )

        "c3" ->
          Req.Test.json(conn, meta_stats_page([], paging.("c3")))
      end
    end)

    assert {:ok, rows} =
             Meta.fetch_stats(connection, ~U[2026-11-01 00:00:00Z], ~U[2026-11-03 00:00:00Z])

    assert Enum.map(rows, &{&1.hour, &1.count}) == [{16, 783}, {17, 715}]

    # Three calls, none with the token in its URL.
    %{calls: calls, total: 3} = Settings.list_connection_calls(connection)
    refute Enum.any?(calls, &(&1.url =~ "SECRET"))
    assert Enum.map(calls, &(&1.url =~ "after=")) == [true, true, false]
  end

  test "reads an answer the Graph API labels text/javascript", %{connection: connection} do
    Req.Test.stub(PixelAudit.Api.Settings.Connector, fn conn ->
      conn
      |> Plug.Conn.put_resp_content_type("text/javascript")
      |> Plug.Conn.send_resp(200, ~s({"id":"999","name":"Pixel"}))
    end)

    assert :ok = Meta.check(connection)

    Req.Test.stub(PixelAudit.Api.Settings.Connector, fn conn ->
      conn
      |> Plug.Conn.put_resp_content_type("text/javascript")
      |> Plug.Conn.send_resp(400, ~s({"error":{"message":"Invalid token","code":190}}))
    end)

    assert {:error, "Meta Graph API answered 400 (code 190): Invalid token"} =
             Meta.check(connection)
  end

  test "converts an hour given in another offset to UTC", %{connection: connection} do
    Req.Test.stub(PixelAudit.Api.Settings.Connector, fn conn ->
      Req.Test.json(conn, meta_stats_page([{"2026-10-30T01:00:00+0200", [{"Lead", 2}]}]))
    end)

    assert {:ok, [%{date: ~D[2026-10-29], hour: 23, event_name: "Lead", count: 2, call_id: _}]} =
             Meta.fetch_stats(connection, ~U[2026-10-29 00:00:00Z], ~U[2026-10-31 00:00:00Z])
  end

  test "reports an unreachable API, and records it", %{connection: connection} do
    Req.Test.stub(PixelAudit.Api.Settings.Connector, fn conn ->
      Req.Test.transport_error(conn, :econnrefused)
    end)

    assert {:error, "Meta Graph API unreachable: " <> _} =
             Meta.fetch_stats(connection, ~U[2026-10-29 00:00:00Z], ~U[2026-10-31 00:00:00Z])

    assert %{calls: [%{status: :error, error: error, response_status: nil}]} =
             Settings.list_connection_calls(connection)

    assert error =~ "refused"
  end
end
