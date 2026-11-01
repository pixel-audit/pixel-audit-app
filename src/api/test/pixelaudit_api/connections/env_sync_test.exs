defmodule PixelAudit.Api.Connections.EnvSyncTest do
  use PixelAudit.Api.DataCase, async: true

  import PixelAudit.Api.Fixtures

  alias PixelAudit.Api.Connections
  alias PixelAudit.Api.Connections.EnvSync

  test "creates connections named after their code, of every type" do
    env = %{
      "CONNECTION_fb_TYPE" => "meta-api",
      "CONNECTION_fb_ACCESS_TOKEN" => "tok",
      "CONNECTION_fb_PIXEL_ID" => "42",
      "CONNECTION_bq_TYPE" => "bigquery",
      "CONNECTION_bq_CREDENTIALS_JSON" => "{}",
      "CONNECTION_bq_PROJECT_ID" => "proj",
      "CONNECTION_shop_TYPE" => "postgres",
      "CONNECTION_shop_DATABASE_URL" => "postgres://u:p@h/db",
      "CONNECTION_ch_TYPE" => "clickhouse",
      "CONNECTION_ch_URL" => "http://ch:8123",
      "CONNECTION_ch_PASSWORD" => "secret",
      "UNRELATED" => "x"
    }

    assert {:ok, results} = EnvSync.run(env)

    assert Enum.map(results, &{&1.code, &1.type, &1.action}) == [
             {"bq", :bigquery, :created},
             {"ch", :clickhouse, :created},
             {"fb", :meta_api, :created},
             {"shop", :postgres, :created}
           ]

    fb = Connections.get_connection_by_code("fb")
    assert fb.name == "fb"
    assert fb.managed_by_env

    assert fb.credentials == %{
             "access_token" => "tok",
             "pixel_id" => "42",
             "api_version" => "v25.0"
           }

    ch = Connections.get_connection_by_code("ch")

    assert ch.credentials == %{
             "url" => "http://ch:8123",
             "password" => "secret",
             "database" => "default",
             "username" => "default"
           }
  end

  test "updates an existing connection's type and credentials, keeping its name" do
    connection =
      connection_fixture(:postgres, %{code: "shop", name: "The shop", description: "d"})

    env = %{
      "CONNECTION_shop_TYPE" => "clickhouse",
      "CONNECTION_shop_URL" => "http://ch:8123"
    }

    assert {:ok, [%{code: "shop", action: :updated}]} = EnvSync.run(env)

    updated = Connections.get_connection!(connection.id)
    assert updated.type == :clickhouse
    assert updated.name == "The shop"
    assert updated.description == "d"
    assert updated.managed_by_env
    refute Map.has_key?(updated.credentials, "database_url")
  end

  test "releases a managed connection that left the environment, without deleting it" do
    {:ok, _} =
      EnvSync.run(%{
        "CONNECTION_a_TYPE" => "postgres",
        "CONNECTION_a_DATABASE_URL" => "postgres://h/d"
      })

    assert Connections.get_connection_by_code("a").managed_by_env

    {:ok, []} = EnvSync.run(%{})
    assert %{managed_by_env: false} = Connections.get_connection_by_code("a")
  end

  test "refuses the whole set on one bad definition and writes nothing" do
    env = %{
      "CONNECTION_ok_TYPE" => "postgres",
      "CONNECTION_ok_DATABASE_URL" => "postgres://h/d",
      "CONNECTION_bad_TYPE" => "mysql",
      "CONNECTION_fb_TYPE" => "meta-api",
      "CONNECTION_fb_PIXEL_ID" => "1",
      "CONNECTION_fb_COLOUR" => "blue"
    }

    assert {:error, problems} = EnvSync.run(env)
    assert Enum.any?(problems, &(&1 =~ "CONNECTION_bad_TYPE is \"mysql\""))
    assert Enum.any?(problems, &(&1 =~ "CONNECTION_fb_COLOUR is not a parameter"))
    assert Enum.any?(problems, &(&1 =~ "CONNECTION_fb_ACCESS_TOKEN can't be blank"))
    assert Connections.list_connections() == []
  end

  test "ignores variables whose id is not lowercase alphanumeric" do
    assert {:ok, []} = EnvSync.run(%{"CONNECTION_My_Shop_TYPE" => "postgres"})
  end
end
