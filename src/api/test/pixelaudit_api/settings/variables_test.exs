defmodule PixelAudit.Api.Settings.VariablesTest do
  use PixelAudit.Api.DataCase, async: true

  import PixelAudit.Api.Fixtures

  alias PixelAudit.Api.Settings
  alias PixelAudit.Api.Settings.Variable

  describe "create_variable/1" do
    test "stores a key, a value and an optional description" do
      variable = variable_fixture(%{key: "apiBase", value: "https://x", description: "d"})
      assert %Variable{key: "apiBase", value: "https://x", description: "d"} = variable
      refute variable.managed_by_env
    end

    test "keeps the value as it is, the empty string included" do
      assert %Variable{value: ""} = variable_fixture(%{value: ""})
      assert %Variable{value: "  spaced  "} = variable_fixture(%{value: "  spaced  "})
    end

    test "refuses a missing value, a key outside [a-zA-Z0-9]+ and a duplicate" do
      {:error, changeset} = Settings.create_variable(%{"key" => "k"})
      assert %{value: ["can't be blank"]} = errors_on(changeset)

      {:error, changeset} = Settings.create_variable(%{"key" => "my_key", "value" => "1"})
      assert %{key: ["must be letters and digits only"]} = errors_on(changeset)

      variable_fixture(%{key: "Taken"})
      {:error, changeset} = Settings.create_variable(%{"key" => "Taken", "value" => "1"})
      assert %{key: ["has already been taken"]} = errors_on(changeset)
    end
  end

  describe "update_variable/2" do
    test "changes the value and the description" do
      variable = variable_fixture()

      {:ok, updated} =
        Settings.update_variable(variable, %{"value" => "new", "description" => "why"})

      assert %{value: "new", description: "why"} = updated
    end

    test "keeps a managed variable's key and value" do
      {:ok, _} = Settings.EnvSync.run(%{"VARIABLE_rate_VALUE" => "1"})
      variable = Settings.get_variable_by_key("rate")

      assert {:error, :managed_by_env} = Settings.update_variable(variable, %{"value" => "2"})
      assert {:error, :managed_by_env} = Settings.update_variable(variable, %{"key" => "r"})

      assert {:ok, %{description: "d"}} =
               Settings.update_variable(variable, %{"description" => "d"})
    end
  end

  test "list_variables/0 orders by key; delete_variable/1 removes one" do
    b = variable_fixture(%{key: "b"})
    a = variable_fixture(%{key: "a"})
    assert Enum.map(Settings.list_variables(), & &1.id) == [a.id, b.id]

    {:ok, _} = Settings.delete_variable(a)
    assert Enum.map(Settings.list_variables(), & &1.id) == [b.id]
  end
end
