defmodule PixelAudit.Api.Settings.Connector.MetaTest do
  use ExUnit.Case, async: true

  import PixelAudit.Api.Fixtures

  alias PixelAudit.Api.Settings.Connector.Meta

  @credentials %{"access_token" => "tok", "pixel_id" => "999", "api_version" => "v25.0"}

  test "reads hourly rows out of /stats and follows the paging" do
    Req.Test.stub(PixelAudit.Api.Settings.Connector, fn conn ->
      assert conn.request_path == "/v25.0/999/stats"
      assert conn.query_params["aggregation"] == "event"
      assert conn.query_params["start_time"] == "1793318400"

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
             Meta.fetch_stats(@credentials, ~U[2026-10-30 00:00:00Z], ~U[2026-10-31 00:00:00Z])

    assert rows == [
             %{date: ~D[2026-10-30], hour: 0, event_name: "PageView", count: 10},
             %{date: ~D[2026-10-30], hour: 0, event_name: "Purchase", count: 1},
             %{date: ~D[2026-10-30], hour: 1, event_name: "PageView", count: 7},
             %{date: ~D[2026-10-30], hour: 23, event_name: "PageView", count: 1}
           ]
  end

  test "converts an hour given in another offset to UTC" do
    Req.Test.stub(PixelAudit.Api.Settings.Connector, fn conn ->
      Req.Test.json(conn, meta_stats_page([{"2026-10-30T01:00:00+0200", [{"Lead", 2}]}]))
    end)

    assert {:ok, [%{date: ~D[2026-10-29], hour: 23, event_name: "Lead", count: 2}]} =
             Meta.fetch_stats(@credentials, ~U[2026-10-29 00:00:00Z], ~U[2026-10-31 00:00:00Z])
  end

  test "reports an unreachable API" do
    Req.Test.stub(PixelAudit.Api.Settings.Connector, fn conn ->
      Req.Test.transport_error(conn, :econnrefused)
    end)

    assert {:error, "Meta Graph API unreachable: " <> _} =
             Meta.fetch_stats(@credentials, ~U[2026-10-29 00:00:00Z], ~U[2026-10-31 00:00:00Z])
  end
end
