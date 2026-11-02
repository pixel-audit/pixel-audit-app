defmodule PixelAudit.ApiWeb.OpenApiTest do
  use PixelAudit.ApiWeb.ConnCase, async: true

  test "serves a document with unique operation ids and resolved schemas", %{conn: conn} do
    spec = conn |> get("/openapi/admin.json") |> json_response(200)

    assert spec["info"]["title"] == "PixelAudit Admin API"
    assert Map.has_key?(spec["paths"], "/api/admin/v1/funnels/{funnel_id}/report")

    operation_ids =
      for {_path, item} <- spec["paths"], {_method, op} <- item, is_map(op), do: op["operationId"]

    assert length(operation_ids) == length(Enum.uniq(operation_ids))
    assert length(operation_ids) == 36
    assert Enum.all?(operation_ids, &String.starts_with?(&1, "admin."))

    assert Map.has_key?(spec["components"]["schemas"], "Report")
    assert Map.has_key?(spec["components"]["schemas"], "FieldSpec")
    assert spec["security"] in [nil, []]
  end

  test "the health endpoint answers without touching anything", %{conn: conn} do
    assert %{"status" => "ok"} = conn |> get("/health") |> json_response(200)
  end
end
