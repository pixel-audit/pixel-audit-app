defmodule PixelAudit.Api.ConnectionsTest do
  use PixelAudit.Api.DataCase, async: true

  import PixelAudit.Api.Fixtures

  alias PixelAudit.Api.Connections
  alias PixelAudit.Api.Connections.Connection

  describe "create_connection/1" do
    test "stores the credentials encrypted and reads them back" do
      connection = connection_fixture(:meta, %{code: "fb"})

      assert %Connection{code: "fb", type: :meta} = connection
      assert connection.credentials["access_token"] == "EAAtoken"

      # The column holds a Cloak ciphertext, not the JSON.
      %{rows: [[raw]]} =
        Repo.query!("SELECT credentials FROM connections WHERE id = $1", [
          Ecto.UUID.dump!(connection.id)
        ])

      refute raw =~ "EAAtoken"
      assert Connections.get_connection!(connection.id).credentials["pixel_id"] == "123456"
    end

    test "fills a credential's default in" do
      connection =
        connection_fixture(:meta, %{
          credentials: %{"access_token" => "t", "pixel_id" => "1"}
        })

      assert connection.credentials["api_version"] == "v25.0"
    end

    test "refuses a missing required credential, keyed by the field" do
      {:error, changeset} =
        Connections.create_connection(%{
          "code" => "fb",
          "name" => "FB",
          "type" => "meta",
          "credentials" => %{"pixel_id" => "1"}
        })

      assert %{"credentials.access_token": ["can't be blank"]} = errors_on(changeset)
    end

    test "refuses an unknown credential key" do
      {:error, changeset} =
        Connections.create_connection(%{
          "code" => "pg",
          "name" => "PG",
          "type" => "postgres",
          "credentials" => %{"url" => "postgres://x/y", "bogus" => "1"}
        })

      assert %{credentials: ["is not a known field"]} = errors_on(changeset)
    end

    test "refuses a code outside [a-z0-9]+ and a duplicate" do
      {:error, changeset} =
        Connections.create_connection(%{
          "code" => "Bad_Code",
          "name" => "x",
          "type" => "postgres",
          "credentials" => credentials_for(:postgres)
        })

      assert %{code: [_]} = errors_on(changeset)

      connection_fixture(:postgres, %{code: "dup"})

      {:error, changeset} =
        Connections.create_connection(%{
          "code" => "dup",
          "name" => "x",
          "type" => "postgres",
          "credentials" => credentials_for(:postgres)
        })

      assert %{code: ["has already been taken"]} = errors_on(changeset)
    end
  end

  describe "update_connection/2" do
    test "merges the credentials sent and clears a key with nil" do
      connection =
        connection_fixture(:bigquery, %{
          credentials: %{"credentials_json" => "{}", "project_id" => "p", "location" => "US"}
        })

      {:ok, updated} =
        Connections.update_connection(connection, %{
          "name" => "BQ",
          "credentials" => %{"location" => nil, "project_id" => "analytics"}
        })

      assert updated.name == "BQ"

      assert updated.credentials == %{
               "credentials_json" => "{}",
               "project_id" => "analytics"
             }
    end

    test "re-validates the credentials when the type changes" do
      connection = connection_fixture(:postgres)

      {:error, changeset} = Connections.update_connection(connection, %{"type" => "meta"})

      assert %{
               "credentials.access_token": ["can't be blank"],
               "credentials.pixel_id": ["can't be blank"]
             } =
               errors_on(changeset)
    end

    test "keeps the type and credentials of a connection managed by the environment" do
      {:ok, _} =
        PixelAudit.Api.Connections.EnvSync.run(%{
          "CONNECTION_shop_TYPE" => "postgres",
          "CONNECTION_shop_URL" => test_database_url()
        })

      connection = Connections.get_connection_by_code("shop")
      assert connection.managed_by_env

      assert {:error, :managed_by_env} =
               Connections.update_connection(connection, %{
                 "credentials" => %{"url" => "x"}
               })

      assert {:error, :managed_by_env} =
               Connections.update_connection(connection, %{"type" => "clickhouse"})

      assert {:ok, %{name: "Shop DB", description: "the shop"}} =
               Connections.update_connection(connection, %{
                 "name" => "Shop DB",
                 "description" => "the shop"
               })
    end
  end

  describe "delete_connection/1" do
    test "refuses while a data source reads through it" do
      %{connection: connection} = measured_funnel_fixture()
      assert {:error, :connection_in_use} = Connections.delete_connection(connection)
    end

    test "deletes an unused one with its cached pixel stats" do
      connection = connection_fixture(:meta)

      Connections.upsert_meta_pixel_stats(connection, [
        %{date: ~D[2026-10-30], hour: 1, event_name: "PageView", count: 3}
      ])

      assert {:ok, _} = Connections.delete_connection(connection)
      assert Repo.aggregate(PixelAudit.Api.Connections.MetaPixelStat, :count) == 0
    end
  end

  describe "check_connection/1" do
    test "records a working Postgres connection" do
      connection = connection_fixture(:postgres)
      {:ok, connection} = Connections.check_connection(connection)
      assert connection.last_check_status == :ok
      assert connection.last_check_error == nil
      assert connection.last_checked_at
    end

    test "records a refused one with the reason" do
      connection =
        connection_fixture(:postgres, %{
          credentials: %{"url" => "postgres://nobody:nothing@localhost:1/none"}
        })

      {{:error, message}, connection} = Connections.check_connection(connection)
      assert connection.last_check_status == :error
      assert connection.last_check_error == message
      assert message =~ "PostgreSQL"
    end

    test "asks Meta for the pixel" do
      Req.Test.stub(PixelAudit.Api.Connections.Connector, fn conn ->
        assert conn.request_path == "/v25.0/123456"
        assert conn.query_params["access_token"] == "EAAtoken"
        Req.Test.json(conn, %{"id" => "123456", "name" => "Shop pixel"})
      end)

      {:ok, connection} = Connections.check_connection(connection_fixture(:meta))
      assert connection.last_check_status == :ok
    end

    test "reports Meta's refusal" do
      Req.Test.stub(PixelAudit.Api.Connections.Connector, fn conn ->
        conn
        |> Plug.Conn.put_status(400)
        |> Req.Test.json(%{
          "error" => %{"message" => "Invalid OAuth access token.", "code" => 190}
        })
      end)

      {{:error, message}, _} = Connections.check_connection(connection_fixture(:meta))
      assert message == "Meta Graph API answered 400 (code 190): Invalid OAuth access token."
    end
  end

  describe "meta pixel stats" do
    test "upserts by hour and event, and sums a day" do
      connection = connection_fixture(:meta)

      rows = [
        %{date: ~D[2026-10-30], hour: 1, event_name: "PageView", count: 3},
        %{date: ~D[2026-10-30], hour: 2, event_name: "PageView", count: 4},
        %{date: ~D[2026-10-30], hour: 2, event_name: "Purchase", count: 1}
      ]

      assert Connections.upsert_meta_pixel_stats(connection, rows) == 3

      assert Connections.upsert_meta_pixel_stats(connection, [
               %{date: ~D[2026-10-30], hour: 2, event_name: "PageView", count: 10}
             ]) == 1

      assert Connections.meta_pixel_day_count(connection, "PageView", ~D[2026-10-30]) == {:ok, 13}
      assert Connections.meta_pixel_day_count(connection, "Lead", ~D[2026-10-30]) == {:ok, 0}
      assert Connections.meta_pixel_day_count(connection, "PageView", ~D[2026-10-29]) == :missing
      assert Connections.meta_pixel_event_names(connection) == ["PageView", "Purchase"]
    end
  end
end
