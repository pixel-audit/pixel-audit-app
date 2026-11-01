defmodule PixelAudit.Api.Connections.Connector.Postgres do
  @moduledoc """
  A PostgreSQL database by URL. Every query opens one Postgrex connection
  for its duration and closes it: there is an arbitrary number of
  connections and most are asked once a day, so a pool per connection
  would mostly sit idle.
  """

  @behaviour PixelAudit.Api.Connections.Connector

  import PixelAudit.Api.FieldSpec, only: [field: 2]

  alias PixelAudit.Api.Connections.Connector

  @impl true
  def type, do: :postgres

  @impl true
  def env_type, do: "postgres"

  @impl true
  def label, do: "PostgreSQL"

  @impl true
  def credential_params do
    [
      field("database_url",
        label: "Database URL",
        kind: :secret,
        required: true,
        description: "postgres://user:password@host:5432/database — add ?sslmode=require for TLS."
      )
    ]
  end

  @impl true
  def check(credentials) do
    case query(credentials, "SELECT 1", []) do
      {:ok, _rows} -> :ok
      {:error, message} -> {:error, message}
    end
  end

  @doc "Runs a query with positional parameters (`$1`, `$2`); answers the rows."
  @spec query(map(), String.t(), [term()]) :: {:ok, [[term()]]} | {:error, String.t()}
  def query(credentials, sql, params) do
    Connector.isolate(fn -> run(credentials, sql, params) end)
  end

  # Inside the isolated task (Connector.isolate/1): the driver's connection
  # process is linked here and exits when the database refuses it; trapping
  # the exit turns that into the error the query call then answers with.
  defp run(credentials, sql, params) do
    Process.flag(:trap_exit, true)
    timeout = Application.fetch_env!(:pixelaudit_api, :connector_timeout_ms)

    with {:ok, opts} <- connection_options(credentials["database_url"]) do
      opts =
        Keyword.merge(opts,
          pool_size: 1,
          # A refused connection stops the process instead of retrying
          # forever in the background; the query then errors out.
          backoff_type: :stop,
          show_sensitive_data_on_connection_error: false,
          queue_target: timeout,
          queue_interval: timeout,
          timeout: timeout,
          connect_timeout: timeout
        )

      case Postgrex.start_link(opts) do
        {:ok, pid} ->
          try do
            case Postgrex.query(pid, sql, params, timeout: timeout) do
              {:ok, %Postgrex.Result{rows: rows}} ->
                {:ok, rows}

              {:error, exception} ->
                {:error, "PostgreSQL: " <> Connector.describe_error(exception)}
            end
          catch
            :exit, reason -> {:error, "PostgreSQL: " <> Connector.describe_error(reason)}
          after
            stop(pid)
          end

        {:error, reason} ->
          {:error, "PostgreSQL: " <> Connector.describe_error(reason)}
      end
    end
  end

  defp stop(pid) do
    GenServer.stop(pid, :normal, 5_000)
  catch
    :exit, _ -> :ok
  end

  @doc false
  def connection_options(url) when is_binary(url) do
    uri = URI.parse(url)

    cond do
      uri.scheme not in ["postgres", "postgresql"] ->
        {:error, "the database URL must start with postgres:// or postgresql://"}

      is_nil(uri.host) or uri.host == "" ->
        {:error, "the database URL names no host"}

      true ->
        {username, password} = userinfo(uri.userinfo)
        query = URI.decode_query(uri.query || "")

        {:ok,
         [
           hostname: uri.host,
           port: uri.port || 5432,
           username: username,
           password: password,
           database: String.trim_leading(uri.path || "", "/"),
           ssl: ssl(query["sslmode"], uri.host)
         ]}
    end
  end

  def connection_options(_), do: {:error, "the database URL is missing"}

  defp userinfo(nil), do: {nil, nil}

  defp userinfo(info) do
    case String.split(info, ":", parts: 2) do
      [user] -> {URI.decode(user), nil}
      [user, password] -> {URI.decode(user), URI.decode(password)}
    end
  end

  defp ssl(mode, _host) when mode in [nil, "disable", "allow", "prefer"], do: false
  defp ssl("require", _host), do: [verify: :verify_none]

  defp ssl(mode, host) when mode in ["verify-ca", "verify-full"] do
    [
      verify: :verify_peer,
      cacerts: :public_key.cacerts_get(),
      server_name_indication: String.to_charlist(host),
      customize_hostname_check: [match_fun: :public_key.pkix_verify_hostname_match_fun(:https)]
    ]
  end

  defp ssl(_other, _host), do: false
end
