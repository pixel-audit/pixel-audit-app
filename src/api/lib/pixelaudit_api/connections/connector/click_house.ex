defmodule PixelAudit.Api.Connections.Connector.ClickHouse do
  @moduledoc """
  A ClickHouse database over its HTTP interface, through the `ch` client.
  One connection per query, like `Postgres`.
  """

  @behaviour PixelAudit.Api.Connections.Connector

  import PixelAudit.Api.FieldSpec, only: [field: 2]

  alias PixelAudit.Api.Connections.Connector

  @impl true
  def type, do: :clickhouse

  @impl true
  def env_type, do: "clickhouse"

  @impl true
  def label, do: "ClickHouse"

  @impl true
  def credential_params do
    [
      field("url",
        label: "URL",
        kind: :url,
        required: true,
        description:
          "The HTTP interface: http://user:password@clickhouse:8123/database, " <>
            "or https://host:8443 — user and database default to \"default\"."
      )
    ]
  end

  @impl true
  def check(credentials) do
    case query(credentials, "SELECT 1", %{}) do
      {:ok, _rows} -> :ok
      {:error, message} -> {:error, message}
    end
  end

  @doc """
  Runs a query with named parameters (`{name:Type}` in the SQL, the map's
  keys are the names); answers the rows.
  """
  @spec query(map(), String.t(), map()) :: {:ok, [[term()]]} | {:error, String.t()}
  def query(credentials, sql, params) do
    Connector.isolate(fn -> run(credentials, sql, params) end)
  end

  # Inside the isolated task (Connector.isolate/1): the driver's connection
  # process is linked here and exits when the database refuses it; trapping
  # the exit turns that into the error the query call then answers with.
  defp run(credentials, sql, params) do
    Process.flag(:trap_exit, true)
    timeout = Application.fetch_env!(:pixelaudit_api, :connector_timeout_ms)

    with {:ok, opts} <- connection_options(credentials) do
      opts = Keyword.merge(opts, pool_size: 1, timeout: timeout)

      case Ch.start_link(opts) do
        {:ok, pid} ->
          try do
            case Ch.query(pid, sql, params, timeout: timeout) do
              {:ok, %Ch.Result{rows: rows}} ->
                {:ok, rows}

              {:error, exception} ->
                {:error, "ClickHouse: " <> Connector.describe_error(exception)}
            end
          catch
            :exit, reason -> {:error, "ClickHouse: " <> Connector.describe_error(reason)}
          after
            stop(pid)
          end

        {:error, reason} ->
          {:error, "ClickHouse: " <> Connector.describe_error(reason)}
      end
    end
  end

  defp stop(pid) do
    GenServer.stop(pid, :normal, 5_000)
  catch
    :exit, _ -> :ok
  end

  @doc false
  def connection_options(%{"url" => url}) when is_binary(url) do
    uri = URI.parse(url)

    cond do
      uri.scheme not in ["http", "https"] ->
        {:error, "the ClickHouse URL must start with http:// or https://"}

      is_nil(uri.host) or uri.host == "" ->
        {:error, "the ClickHouse URL names no host"}

      true ->
        {username, password} = userinfo(uri.userinfo)

        {:ok,
         [
           scheme: uri.scheme,
           hostname: uri.host,
           port: port(uri, url),
           database: database(uri.path),
           username: username,
           password: password
         ]}
    end
  end

  def connection_options(_), do: {:error, "the ClickHouse URL is missing"}

  # `URI.parse/1` fills in the scheme's own port (80, 443) when the URL
  # names none; ClickHouse's are 8123 and 8443.
  defp port(%URI{scheme: scheme, port: port}, url) do
    cond do
      Regex.match?(~r{^[a-z]+://[^/?#]*:\d+(?=[/?#]|$)}i, url) -> port
      scheme == "https" -> 8443
      true -> 8123
    end
  end

  defp userinfo(nil), do: {"default", ""}

  defp userinfo(info) do
    case String.split(info, ":", parts: 2) do
      [user] -> {URI.decode(user), ""}
      [user, password] -> {URI.decode(user), URI.decode(password)}
    end
  end

  defp database(path) do
    case String.trim(path || "", "/") do
      "" -> "default"
      name -> URI.decode(name)
    end
  end
end
