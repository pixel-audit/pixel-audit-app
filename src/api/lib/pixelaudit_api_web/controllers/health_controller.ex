defmodule PixelAudit.ApiWeb.HealthController do
  @moduledoc """
  Liveness and readiness of the running node, for the container platform
  (the Helm chart's probes). Deliberately touches nothing — no database —
  so that a dependency hiccup does not make the orchestrator restart
  healthy nodes; it only says the endpoint is serving.
  """
  use PixelAudit.ApiWeb, :controller

  def show(conn, _params) do
    json(conn, %{status: "ok"})
  end
end
