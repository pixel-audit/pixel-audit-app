defmodule PixelAudit.ApiWeb.Admin.Settings.VariableControllerTest do
  use PixelAudit.ApiWeb.ConnCase, async: true

  import PixelAudit.Api.Fixtures

  @base "/api/admin/v1/settings/variables"

  test "creates, lists, shows, updates and deletes a variable", %{conn: conn} do
    params = %{"key" => "apiBase", "value" => "https://x", "description" => "d"}

    %{"data" => created} = conn |> post(@base, params) |> json_response(201)
    assert created["key"] == "apiBase"
    assert created["value"] == "https://x"
    assert created["description"] == "d"
    refute created["managed_by_env"]

    %{"data" => [listed]} = conn |> get(@base) |> json_response(200)
    assert listed == created

    %{"data" => shown} = conn |> get("#{@base}/#{created["id"]}") |> json_response(200)
    assert shown == created

    %{"data" => updated} =
      conn |> put("#{@base}/#{created["id"]}", %{"value" => ""}) |> json_response(200)

    assert updated["value"] == ""

    assert conn |> delete("#{@base}/#{created["id"]}") |> response(204)
    assert conn |> get("#{@base}/#{created["id"]}") |> json_response(404)
    assert conn |> get("#{@base}/not-a-uuid") |> json_response(404)
  end

  test "answers 422 with the field errors", %{conn: conn} do
    %{"errors" => errors} = conn |> post(@base, %{"key" => "my key"}) |> json_response(422)
    assert errors["key"] == ["must be letters and digits only"]
    assert errors["value"] == ["can't be blank"]
  end

  test "refuses key and value changes on an env-managed variable", %{conn: conn} do
    {:ok, _} = PixelAudit.Api.Settings.EnvSync.run(%{"VARIABLE_rate_VALUE" => "1"})
    variable = PixelAudit.Api.Settings.get_variable_by_key("rate")

    assert %{"errors" => %{"detail" => "managed_by_env"}} =
             conn |> put("#{@base}/#{variable.id}", %{"value" => "2"}) |> json_response(409)

    assert %{"data" => %{"description" => "d", "managed_by_env" => true}} =
             conn |> put("#{@base}/#{variable.id}", %{"description" => "d"}) |> json_response(200)

    _ = variable_fixture()
  end
end
