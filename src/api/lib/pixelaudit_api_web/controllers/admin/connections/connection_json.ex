defmodule PixelAudit.ApiWeb.Admin.Connections.ConnectionJSON do
  alias PixelAudit.Api.Connections.{Connection, Connector}
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

  @doc "A connection as a data source names it."
  def ref(%Connection{} = connection) do
    %{id: connection.id, code: connection.code, name: connection.name, type: connection.type}
  end

  # The credentials never leave the API: which keys are set, and the
  # values of the ones the connector does not call secret.
  defp data(%Connection{} = connection) do
    credentials = connection.credentials || %{}

    secret_keys =
      Connector.for_type(connection.type).credential_params() |> FieldSpec.secret_keys()

    %{
      id: connection.id,
      code: connection.code,
      name: connection.name,
      description: connection.description,
      type: connection.type,
      managed_by_env: connection.managed_by_env,
      credential_keys: credentials |> Map.keys() |> Enum.sort(),
      credentials_preview: Map.drop(credentials, secret_keys),
      last_checked_at: connection.last_checked_at,
      last_check_status: connection.last_check_status,
      last_check_error: connection.last_check_error,
      inserted_at: connection.inserted_at,
      updated_at: connection.updated_at
    }
  end
end
