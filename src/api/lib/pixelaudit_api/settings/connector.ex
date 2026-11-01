defmodule PixelAudit.Api.Settings.Connector do
  @moduledoc """
  What a connection type is: its name in the environment
  (`CONNECTION_<id>_TYPE`), the credentials it takes, and how to check that
  they work. One module per type, beside this one.

  A connector's own `query/3` (the SQL ones) is the driver: only
  `PixelAudit.Api.Settings.Gateway` calls it, with the credentials, and
  records the call. Everything else — the data source types, the refresh
  jobs, `check/1` — goes through the gateway with the connection, never
  through a connector or `Req` directly.
  """

  alias PixelAudit.Api.Settings.Connection
  alias PixelAudit.Api.FieldSpec

  @callback type() :: Connection.type()
  @callback env_type() :: String.t()
  @callback label() :: String.t()
  @callback credential_params() :: [FieldSpec.t()]
  @callback check(Connection.t()) :: :ok | {:error, String.t()}

  @connectors [
    PixelAudit.Api.Settings.Connector.Meta,
    PixelAudit.Api.Settings.Connector.BigQuery,
    PixelAudit.Api.Settings.Connector.Postgres,
    PixelAudit.Api.Settings.Connector.ClickHouse
  ]

  @doc "Every connector, in the order the panel lists them."
  @spec all() :: [module()]
  def all, do: @connectors

  @doc "The connector of a connection type."
  @spec for_type(Connection.type()) :: module()
  def for_type(type) do
    Enum.find(@connectors, &(&1.type() == type)) ||
      raise ArgumentError, "unknown connection type #{inspect(type)}"
  end

  @doc "The connector named by `CONNECTION_<id>_TYPE`, or `nil`."
  @spec for_env_type(String.t()) :: module() | nil
  def for_env_type(env_type), do: Enum.find(@connectors, &(&1.env_type() == env_type))

  @doc """
  Options every Req request of a connector carries: the timeout, and in
  tests the stub (`:req_options` in config/test.exs).
  """
  @spec req_options() :: keyword()
  def req_options do
    timeout = Application.fetch_env!(:pixelaudit_api, :connector_timeout_ms)

    Keyword.merge(
      [receive_timeout: timeout, retry: false],
      Application.get_env(:pixelaudit_api, :req_options, [])
    )
  end

  @doc """
  Runs a connector call in its own process, unlinked from the caller, and
  answers its result — or `{:error, message}` when the call crashed or
  outlived the connector timeout. The SQL drivers link their connection
  process to whoever starts it and exit it when the database refuses them;
  isolated here, that exit becomes an error message instead of taking a
  job or a request down.
  """
  @spec isolate((-> result)) :: result | {:error, String.t()} when result: term()
  def isolate(fun) when is_function(fun, 0) do
    timeout = Application.fetch_env!(:pixelaudit_api, :connector_timeout_ms)
    task = Task.Supervisor.async_nolink(__MODULE__.TaskSupervisor, fun)

    case Task.yield(task, timeout + 1_000) || Task.shutdown(task, :brutal_kill) do
      {:ok, result} -> result
      {:exit, reason} -> {:error, "the connector crashed: " <> describe_error(reason)}
      nil -> {:error, "the connector did not answer within #{timeout} ms"}
    end
  end

  @doc "A connector or driver failure as the one-line message stored and shown."
  @spec describe_error(term()) :: String.t()
  def describe_error(%{__exception__: true} = exception), do: Exception.message(exception)

  def describe_error({%{__exception__: true} = exception, _stacktrace}),
    do: Exception.message(exception)

  def describe_error({:shutdown, reason}), do: describe_error(reason)
  def describe_error(message) when is_binary(message), do: message
  def describe_error(other), do: inspect(other)
end
