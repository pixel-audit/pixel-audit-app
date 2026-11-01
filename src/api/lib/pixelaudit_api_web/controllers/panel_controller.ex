defmodule PixelAudit.ApiWeb.PanelController do
  @moduledoc """
  Serves the admin panel from the same origin as the API.

  The panel's build (src/admin, `vite build`) is copied into priv/static
  by the image's Dockerfile; Plug.Static serves its hashed assets, and this
  controller serves the two files that are not static: `/config.js`, the
  panel's runtime configuration rendered from the environment, and
  `index.html` for every other path, so the panel's own router takes over
  from the address (`/funnels/checkout`, a reload included).

  In development the panel runs on its own dev server, which proxies
  `/api`, `/openapi`, `/health` and `/config.js` here; `index.html` is not
  in priv/static then, and `index/2` says where the panel is.
  """

  use PixelAudit.ApiWeb, :controller

  @dev_server "http://localhost:16001"

  @doc """
  `window.PIXELAUDIT_CONFIG`: what the panel reads at page load. The API is
  the panel's own origin, so `apiUrl` is empty; `sourceUrl` is where this
  program's source is offered (AGPL §13), `SOURCE_URL` in a deployment.
  """
  def config(conn, _params) do
    config = %{apiUrl: "", sourceUrl: Application.fetch_env!(:pixelaudit_api, :source_url)}

    conn
    |> put_resp_content_type("application/javascript")
    |> put_resp_header("cache-control", "no-cache")
    |> send_resp(200, "window.PIXELAUDIT_CONFIG = #{Jason.encode!(config)};\n")
  end

  @doc "The panel's index.html for any address the API does not claim."
  def index(conn, %{"path" => ["api" | _]}) do
    conn |> put_status(:not_found) |> json(%{errors: %{detail: "not_found"}})
  end

  def index(conn, _params) do
    case File.read(index_html_path()) do
      {:ok, html} ->
        conn
        |> put_resp_content_type("text/html")
        |> put_resp_header("cache-control", "no-cache")
        # The panel is not for search engines, whatever robots.txt they read.
        |> put_resp_header("x-robots-tag", "noindex, nofollow")
        |> send_resp(200, html)

      {:error, _} ->
        conn
        |> put_resp_content_type("text/plain")
        |> send_resp(
          404,
          "The admin panel is not built into this server. " <>
            "In development it runs on its own dev server (#{@dev_server}); " <>
            "a release image carries it in priv/static.\n"
        )
    end
  end

  defp index_html_path, do: Application.app_dir(:pixelaudit_api, "priv/static/index.html")
end
