defmodule PixelAudit.Api.Settings.EnvSyncTest do
  use PixelAudit.Api.DataCase, async: true

  import PixelAudit.Api.Fixtures

  alias PixelAudit.Api.Settings
  alias PixelAudit.Api.Settings.EnvSync

  test "creates connections of every type, named by the variable" do
    env = %{
      "CONNECTION_fb_TYPE" => "meta",
      "CONNECTION_fb_ACCESS_TOKEN" => "tok",
      "CONNECTION_fb_PIXEL_ID" => "42",
      "CONNECTION_bq_TYPE" => "bigquery",
      "CONNECTION_bq_CREDENTIALS_JSON" => "{}",
      "CONNECTION_bq_PROJECT_ID" => "proj",
      "CONNECTION_shop_TYPE" => "postgres",
      "CONNECTION_shop_URL" => "postgres://u:p@h/db",
      "CONNECTION_ch_TYPE" => "clickhouse",
      "CONNECTION_ch_URL" => "http://default:secret@ch:8123",
      "UNRELATED" => "x"
    }

    assert {:ok, %{connections: results, variables: []}} = EnvSync.run(env)

    assert Enum.map(results, &{&1.name, &1.type, &1.action}) == [
             {"bq", :bigquery, :created},
             {"ch", :clickhouse, :created},
             {"fb", :meta, :created},
             {"shop", :postgres, :created}
           ]

    fb = Settings.get_connection_by_name("fb")
    assert fb.name == "fb"
    assert fb.managed_by_env

    assert fb.credentials == %{
             "access_token" => "tok",
             "pixel_id" => "42",
             "api_version" => "v25.0"
           }

    ch = Settings.get_connection_by_name("ch")

    assert ch.credentials == %{"url" => "http://default:secret@ch:8123"}
  end

  test "updates the connection of that name: type and credentials, keeping its description" do
    connection = connection_fixture(:postgres, %{name: "shop", description: "d"})

    env = %{
      "CONNECTION_shop_TYPE" => "clickhouse",
      "CONNECTION_shop_URL" => "http://ch:8123"
    }

    assert {:ok, %{connections: [%{name: "shop", action: :updated}]}} = EnvSync.run(env)

    updated = Settings.get_connection!(connection.id)
    assert updated.type == :clickhouse
    assert updated.name == "shop"
    assert updated.description == "d"
    assert updated.managed_by_env
    assert updated.credentials == %{"url" => "http://ch:8123"}
  end

  test "releases a managed connection that left the environment, without deleting it" do
    {:ok, _} =
      EnvSync.run(%{
        "CONNECTION_a_TYPE" => "postgres",
        "CONNECTION_a_URL" => "postgres://h/d"
      })

    assert Settings.get_connection_by_name("a").managed_by_env

    {:ok, %{connections: []}} = EnvSync.run(%{})
    assert %{managed_by_env: false} = Settings.get_connection_by_name("a")
  end

  test "refuses the whole set on one bad definition and writes nothing" do
    env = %{
      "CONNECTION_ok_TYPE" => "postgres",
      "CONNECTION_ok_URL" => "postgres://h/d",
      "CONNECTION_bad_TYPE" => "mysql",
      "CONNECTION_fb_TYPE" => "meta",
      "CONNECTION_fb_PIXEL_ID" => "1",
      "CONNECTION_fb_COLOUR" => "blue"
    }

    assert {:error, problems} = EnvSync.run(env)
    assert Enum.any?(problems, &(&1 =~ "CONNECTION_bad_TYPE is \"mysql\""))
    assert Enum.any?(problems, &(&1 =~ "CONNECTION_fb_COLOUR is not a parameter"))
    assert Enum.any?(problems, &(&1 =~ "CONNECTION_fb_ACCESS_TOKEN can't be blank"))
    assert Settings.list_connections() == []
  end

  test "ignores variables whose id is not lowercase alphanumeric" do
    assert {:ok, %{connections: []}} = EnvSync.run(%{"CONNECTION_my_shop_TYPE" => "postgres"})
  end

  describe "variables" do
    test "creates and updates variables, with an optional description" do
      env = %{
        "VARIABLE_apiBase_VALUE" => "https://api.example.com",
        "VARIABLE_apiBase_DESCRIPTION" => "Where the API lives",
        "VARIABLE_empty_VALUE" => "",
        "VARIABLE_rate_VALUE" => "0.5"
      }

      assert {:ok, %{variables: results}} = EnvSync.run(env)

      assert Enum.map(results, &{&1.key, &1.action}) == [
               {"apiBase", :created},
               {"empty", :created},
               {"rate", :created}
             ]

      api_base = Settings.get_variable_by_key("apiBase")
      assert api_base.value == "https://api.example.com"
      assert api_base.description == "Where the API lives"
      assert api_base.managed_by_env
      assert Settings.get_variable_by_key("empty").value == ""

      # A new value replaces the old one; a description typed in the panel
      # survives a boot that says none.
      {:ok, _} = Settings.update_variable(api_base, %{"description" => "Edited"})

      assert {:ok, %{variables: [%{key: "apiBase", action: :updated}]}} =
               EnvSync.run(%{"VARIABLE_apiBase_VALUE" => "https://api2.example.com"})

      api_base = Settings.get_variable_by_key("apiBase")
      assert api_base.value == "https://api2.example.com"
      assert api_base.description == "Edited"
      refute Settings.get_variable_by_key("rate").managed_by_env
    end

    test "takes over a variable created in the panel" do
      variable = variable_fixture(%{key: "rate", value: "1"})

      assert {:ok, %{variables: [%{key: "rate", action: :updated}]}} =
               EnvSync.run(%{"VARIABLE_rate_VALUE" => "2"})

      assert %{value: "2", managed_by_env: true} = Settings.get_variable!(variable.id)
    end

    test "refuses the whole set on a bad variable, beside the connections' problems" do
      env = %{
        "VARIABLE_ok_VALUE" => "1",
        "VARIABLE_lonely_DESCRIPTION" => "no value",
        "VARIABLE_odd_VALUE" => "1",
        "VARIABLE_odd_COLOUR" => "blue",
        "CONNECTION_bad_TYPE" => "mysql"
      }

      assert {:error, problems} = EnvSync.run(env)
      assert Enum.any?(problems, &(&1 =~ "CONNECTION_bad_TYPE is \"mysql\""))
      assert Enum.any?(problems, &(&1 == "VARIABLE_lonely_VALUE is missing"))
      assert Enum.any?(problems, &(&1 =~ "VARIABLE_odd_COLOUR is not a parameter"))
      assert Settings.list_variables() == []
    end

    test "ignores variables whose key is not alphanumeric" do
      assert {:ok, %{variables: []}} = EnvSync.run(%{"VARIABLE_my_key_VALUE" => "1"})
    end
  end
end
