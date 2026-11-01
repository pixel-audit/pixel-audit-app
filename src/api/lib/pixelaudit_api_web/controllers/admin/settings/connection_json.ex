defmodule PixelAudit.ApiWeb.Admin.Settings.ConnectionJSON do
  alias PixelAudit.Api.Settings.{Connection, Connector}
  alias PixelAudit.Api.FieldSpec

  def index(%{connections: connections}) do
    %{data: for(connection <- connections, do: data(connection))}
  end

  def show(%{connection: connection}) do
    %{data: data(connection)}
  end

  def types(%{connectors: connectors}) do
    %{
      data:
        for connector <- connectors do
          %{
            type: connector.type(),
            env_type: connector.env_type(),
            label: connector.label(),
            credentials: Enum.map(connector.credential_params(), &FieldSpec.to_api/1)
          }
        end
    }
  end

  def calls(%{calls: calls, total: total}) do
    %{data: for(call <- calls, do: call_data(call)), total: total}
  end

  defp call_data(call) do
    %{
      id: call.id,
      connection_id: call.connection_id,
      kind: call.kind,
      status: call.status,
      started_at: call.started_at,
      duration_ms: call.duration_ms,
      error: call.error,
      sql: call.sql,
      params: call.params,
      result: call.result,
      method: call.method,
      url: call.url,
      request_content_type: call.request_content_type,
      request_body: call.request_body,
      response_status: call.response_status,
      response_content_type: call.response_content_type,
      response_body: call.response_body
    }
  end

  @doc "A connection as a data source names it."
  def ref(%Connection{} = connection) do
    %{id: connection.id, name: connection.name, type: connection.type}
  end

  # The credentials never leave the API whole: which keys are set, and the
  # values as `FieldSpec.preview/2` shows them — no secret, a URL without
  # its password.
  defp data(%Connection{} = connection) do
    credentials = connection.credentials || %{}
    specs = Connector.for_type(connection.type).credential_params()

    %{
      id: connection.id,
      name: connection.name,
      description: connection.description,
      type: connection.type,
      managed_by_env: connection.managed_by_env,
      credential_keys: credentials |> Map.keys() |> Enum.sort(),
      credentials_preview: FieldSpec.preview(specs, credentials),
      last_checked_at: connection.last_checked_at,
      last_check_status: connection.last_check_status,
      last_check_error: connection.last_check_error,
      inserted_at: connection.inserted_at,
      updated_at: connection.updated_at
    }
  end
end
