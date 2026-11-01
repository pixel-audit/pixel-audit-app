defmodule PixelAudit.Api.Connections.Connector.BigQueryTest do
  use ExUnit.Case, async: true

  import PixelAudit.Api.Fixtures

  alias PixelAudit.Api.Connections.Connector.BigQuery

  test "posts a named-parameter query and reads the rows" do
    Req.Test.stub(PixelAudit.Api.Connections.Connector, fn conn ->
      assert conn.method == "POST"
      assert conn.request_path == "/bigquery/v2/projects/pa-project/queries"
      assert Plug.Conn.get_req_header(conn, "authorization") == ["Bearer test-token"]

      {:ok, body, conn} = Plug.Conn.read_body(conn)
      body = Jason.decode!(body)
      assert body["useLegacySql"] == false
      assert body["parameterMode"] == "NAMED"

      assert [
               %{
                 "name" => "event_name",
                 "parameterType" => %{"type" => "STRING"},
                 "parameterValue" => %{"value" => "purchase"}
               }
             ] =
               body["queryParameters"]

      Req.Test.json(conn, %{"jobComplete" => true, "rows" => [%{"f" => [%{"v" => "17"}]}]})
    end)

    assert {:ok, [["17"]]} =
             BigQuery.query(
               credentials_for(:bigquery),
               "SELECT COUNT(*) FROM t WHERE e = @event_name",
               [
                 {"event_name", "STRING", "purchase"}
               ]
             )
  end

  test "waits for a job that did not finish within the first call" do
    Req.Test.stub(PixelAudit.Api.Connections.Connector, fn conn ->
      case conn.method do
        "POST" ->
          Req.Test.json(conn, %{
            "jobComplete" => false,
            "jobReference" => %{"jobId" => "j1", "location" => "EU"}
          })

        "GET" ->
          assert conn.request_path == "/bigquery/v2/projects/pa-project/queries/j1"
          assert conn.query_params["location"] == "EU"
          Req.Test.json(conn, %{"jobComplete" => true, "rows" => [%{"f" => [%{"v" => "3"}]}]})
      end
    end)

    assert {:ok, [["3"]]} = BigQuery.query(credentials_for(:bigquery), "SELECT 3", [])
  end

  test "reports BigQuery's error" do
    Req.Test.stub(PixelAudit.Api.Connections.Connector, fn conn ->
      conn
      |> Plug.Conn.put_status(403)
      |> Req.Test.json(%{"error" => %{"message" => "Access Denied: Project pa-project"}})
    end)

    assert {:error, "BigQuery answered 403: Access Denied: Project pa-project"} =
             BigQuery.query(credentials_for(:bigquery), "SELECT 1", [])
  end

  test "accepts the service account as base64 and refuses something else" do
    credentials = %{
      "credentials_json" => Base.encode64(credentials_for(:bigquery)["credentials_json"]),
      "project_id" => "pa-project"
    }

    Req.Test.stub(PixelAudit.Api.Connections.Connector, fn conn ->
      Req.Test.json(conn, %{"jobComplete" => true, "rows" => []})
    end)

    assert {:ok, []} = BigQuery.query(credentials, "SELECT 1", [])

    assert {:error, message} =
             BigQuery.query(
               %{"credentials_json" => "not json", "project_id" => "p"},
               "SELECT 1",
               []
             )

    assert message =~ "not JSON"
  end
end
