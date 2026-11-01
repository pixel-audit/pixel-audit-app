defmodule PixelAudit.ApiWeb.Admin.Connections.ConnectionControllerTest do
  use PixelAudit.ApiWeb.ConnCase, async: true

  import PixelAudit.Api.Fixtures

  @base "/api/admin/v1/connections"

  test "lists the connection types with their credential fields", %{conn: conn} do
    %{"data" => types} = conn |> get("#{@base}/types") |> json_response(200)
    assert Enum.map(types, & &1["type"]) == ["meta", "bigquery", "postgres", "clickhouse"]

    meta = Enum.find(types, &(&1["type"] == "meta"))
    assert meta["env_type"] == "meta"

    assert [%{"key" => "access_token", "kind" => "secret", "required" => true} | _] =
             meta["credentials"]
  end

  test "creates, shows, updates and deletes a connection without ever returning a secret", %{
    conn: conn
  } do
    params = %{
      "code" => "fb",
      "name" => "Facebook",
      "type" => "meta",
      "credentials" => %{"access_token" => "EAAsecret", "pixel_id" => "42"}
    }

    %{"data" => created} = conn |> post(@base, params) |> json_response(201)
    assert created["code"] == "fb"
    assert created["credential_keys"] == ["access_token", "api_version", "pixel_id"]
    assert created["credentials_preview"] == %{"api_version" => "v25.0", "pixel_id" => "42"}
    refute inspect(created) =~ "EAAsecret"
    refute created["managed_by_env"]

    # A Meta connection's creation pulls its stats.
    %{"data" => [run]} = conn |> get("/api/admin/v1/reporting/refresh-runs") |> json_response(200)
    assert run["kind"] == "meta_pixel"
    assert run["connection"]["code"] == "fb"

    %{"data" => shown} = conn |> get("#{@base}/#{created["id"]}") |> json_response(200)
    assert shown == created

    %{"data" => updated} =
      conn
      |> put("#{@base}/#{created["id"]}", %{
        "name" => "FB",
        "credentials" => %{"pixel_id" => "43"}
      })
      |> json_response(200)

    assert updated["name"] == "FB"
    assert updated["credentials_preview"]["pixel_id"] == "43"

    assert conn |> delete("#{@base}/#{created["id"]}") |> response(204)
    assert conn |> get("#{@base}/#{created["id"]}") |> json_response(404)
    assert conn |> get("#{@base}/not-a-uuid") |> json_response(404)
  end

  test "shows a database URL with its password hidden", %{conn: conn} do
    params = %{
      "code" => "shop",
      "name" => "Shop",
      "type" => "postgres",
      "credentials" => %{"url" => "postgres://sample:s3cret@db.example.com:5432/shop"}
    }

    %{"data" => created} = conn |> post(@base, params) |> json_response(201)
    assert created["credential_keys"] == ["url"]

    assert created["credentials_preview"] == %{
             "url" => "postgres://sample:***@db.example.com:5432/shop"
           }

    refute inspect(created) =~ "s3cret"
  end

  test "answers 422 with the field errors", %{conn: conn} do
    %{"errors" => errors} =
      conn
      |> post(@base, %{"code" => "X", "type" => "postgres", "credentials" => %{}})
      |> json_response(422)

    assert errors["name"] == ["can't be blank"]
    assert errors["code"] == ["must be lowercase letters and digits only"]
    assert errors["credentials.url"] == ["can't be blank"]
  end

  test "refuses to delete a connection in use", %{conn: conn} do
    %{connection: connection} = measured_funnel_fixture()

    assert %{"errors" => %{"detail" => "connection_in_use"}} =
             conn |> delete("#{@base}/#{connection.id}") |> json_response(409)
  end

  test "refuses type and credential changes on an env-managed connection", %{conn: conn} do
    {:ok, _} =
      PixelAudit.Api.Connections.EnvSync.run(%{
        "CONNECTION_shop_TYPE" => "postgres",
        "CONNECTION_shop_URL" => test_database_url()
      })

    connection = PixelAudit.Api.Connections.get_connection_by_code("shop")

    assert %{"errors" => %{"detail" => "managed_by_env"}} =
             conn
             |> put("#{@base}/#{connection.id}", %{"type" => "clickhouse"})
             |> json_response(409)

    assert %{"data" => %{"name" => "Shop", "managed_by_env" => true}} =
             conn |> put("#{@base}/#{connection.id}", %{"name" => "Shop"}) |> json_response(200)
  end

  test "checks a connection and records the outcome", %{conn: conn} do
    connection = connection_fixture(:postgres)

    %{"data" => checked} = conn |> post("#{@base}/#{connection.id}/check") |> json_response(200)
    assert checked["last_check_status"] == "ok"
    assert checked["last_checked_at"]
  end

  test "refreshes a Meta connection's stats, and only a Meta one", %{conn: conn} do
    meta = connection_fixture(:meta)
    postgres = connection_fixture(:postgres)
    range = %{"date_from" => "2026-10-01", "date_to" => "2026-10-03"}

    %{"data" => run} = conn |> post("#{@base}/#{meta.id}/refresh", range) |> json_response(202)
    assert run["kind"] == "meta_pixel"
    assert run["status"] == "queued"
    assert run["trigger"] == "manual"
    assert run["date_from"] == "2026-10-01"

    assert %{"errors" => %{"detail" => "not_a_meta_connection"}} =
             conn |> post("#{@base}/#{postgres.id}/refresh", range) |> json_response(422)

    assert %{"errors" => %{"detail" => "invalid_date_range"}} =
             conn
             |> post("#{@base}/#{meta.id}/refresh", %{
               "date_from" => "2026-10-03",
               "date_to" => "2026-10-01"
             })
             |> json_response(422)
  end
end
