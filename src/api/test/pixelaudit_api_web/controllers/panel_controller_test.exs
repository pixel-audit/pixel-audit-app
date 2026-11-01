defmodule PixelAudit.ApiWeb.PanelControllerTest do
  use PixelAudit.ApiWeb.ConnCase, async: true

  test "renders the panel's runtime configuration as a script", %{conn: conn} do
    conn = get(conn, "/config.js")
    assert response_content_type(conn, :javascript)
    body = response(conn, 200)
    assert body =~ ~s(window.PIXELAUDIT_CONFIG = {)
    assert body =~ ~s("apiUrl":"")
    assert body =~ ~s("sourceUrl":"https://github.com/pixel-audit/pixel-audit-app")
  end

  test "says where the panel is when its build is not here", %{conn: conn} do
    # The test build has no priv/static/index.html: a panel address is a
    # plain 404 naming the dev server, never an API error.
    conn = get(conn, "/funnels/checkout")
    assert response(conn, 404) =~ "dev server"
    assert response_content_type(conn, :text)
  end

  test "an unknown API path is a JSON 404, not the panel", %{conn: conn} do
    assert %{"errors" => %{"detail" => "not_found"}} =
             conn |> get("/api/admin/v1/no-such-thing") |> json_response(404)
  end

  test "robots.txt forbids every crawler", %{conn: conn} do
    assert get(conn, "/robots.txt") |> response(200) =~ "Disallow: /"
  end
end
