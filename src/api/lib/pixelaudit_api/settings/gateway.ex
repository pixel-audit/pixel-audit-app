defmodule PixelAudit.Api.Settings.Gateway do
  @moduledoc """
  The one way to an external system. Every query a data source type runs
  and every HTTP request a connector makes goes through here, with the
  connection it goes through — never through a connector or `Req`
  directly — so each is recorded as a `PixelAudit.Api.Settings.ConnectionCall`:
  when it started, how long it took, what was sent, what came back or
  what failed. `specs/connections.md` states the rule.

  Credentials travel in what the connector builds (a bearer header, the
  driver's options), never in what is recorded: a query's SQL and
  parameters, a request's method, URL, content types and bodies. What is
  recorded is kept whole and for good — it is the evidence a stored
  value cites (`specs/provenance.md`).

  A computation runs inside `capture/2`, which gives every call it makes
  its context — why it was made: the purpose, the refresh run, the data
  source, the step and the day — and collects the ids of those calls,
  plus whatever cached values the computation read cite (`cite/1`), so
  the value computed can cite them all.
  """

  require Logger

  alias PixelAudit.Api.Repo
  alias PixelAudit.Api.Settings.{Connection, ConnectionCall, Connector}

  @capture_key {__MODULE__, :capture}
  @last_call_key {__MODULE__, :last_call_id}

  @type context :: %{
          optional(:purpose) => ConnectionCall.purpose(),
          optional(:refresh_run_id) => Ecto.UUID.t(),
          optional(:data_source_id) => Ecto.UUID.t(),
          optional(:step_id) => Ecto.UUID.t(),
          optional(:date) => Date.t()
        }

  ## Context and citations

  @doc """
  Runs `fun` as one computation: every call recorded meanwhile carries
  `context`, and the answer comes with the ids of those calls and of
  whatever was cited (`cite/1`) — in the order they were made, without
  repeats. Captures nest: an inner capture's calls are the outer one's
  too.
  """
  @spec capture(context(), (-> result)) :: {result, [Ecto.UUID.t()]} when result: term()
  def capture(context, fun) when is_map(context) and is_function(fun, 0) do
    outer = Process.get(@capture_key)
    Process.put(@capture_key, %{context: Map.merge(context_of(outer), context), cited: []})

    try do
      result = fun.()
      {result, cited_calls()}
    after
      inner = Process.get(@capture_key)

      case outer do
        nil -> Process.delete(@capture_key)
        outer -> Process.put(@capture_key, %{outer | cited: outer.cited ++ inner.cited})
      end
    end
  end

  @doc "Adds calls the running computation rests on — those a cached value it read cites."
  @spec cite([Ecto.UUID.t()]) :: :ok
  def cite(call_ids) when is_list(call_ids) do
    case Process.get(@capture_key) do
      nil -> :ok
      capture -> Process.put(@capture_key, %{capture | cited: capture.cited ++ call_ids})
    end

    :ok
  end

  @doc "The calls the running capture has collected so far, oldest first, without repeats."
  @spec cited_calls() :: [Ecto.UUID.t()]
  def cited_calls do
    case Process.get(@capture_key) do
      nil -> []
      capture -> Enum.uniq(capture.cited)
    end
  end

  @doc "The id of the last call this process recorded, if any."
  @spec last_call_id() :: Ecto.UUID.t() | nil
  def last_call_id, do: Process.get(@last_call_key)

  defp context_of(nil), do: %{}
  defp context_of(%{context: context}), do: context

  @doc """
  Runs a SQL query through a database connection — Postgres, ClickHouse
  or BigQuery, whose connectors take the parameters in their own shape —
  and records it. Answers the rows, or the error.
  """
  @spec query(Connection.t(), String.t(), term()) :: {:ok, [[term()]]} | {:error, String.t()}
  def query(%Connection{} = connection, sql, params) do
    connector = Connector.for_type(connection.type)

    {result, started_at, duration_ms} =
      timed(fn -> connector.query(connection.credentials || %{}, sql, params) end)

    record(connection, %{
      kind: :query,
      started_at: started_at,
      duration_ms: duration_ms,
      sql: sql,
      params: normalise(params),
      status: status(result),
      result: rows_of(result),
      error: error_of(result)
    })

    result
  end

  @doc """
  Makes an HTTP request through an API connection and records it: the
  method and URL, the content types and bodies of both sides, or the
  transport failure. Answers `Req`'s own result; the connector reads the
  response.
  """
  @spec request(Connection.t(), Req.Request.t()) ::
          {:ok, Req.Response.t()} | {:error, Exception.t()}
  def request(%Connection{} = connection, %Req.Request{} = request) do
    {{request, outcome}, started_at, duration_ms} =
      timed(fn -> Req.Request.run_request(request) end)

    attrs = %{
      kind: :api_call,
      started_at: started_at,
      duration_ms: duration_ms,
      method: request.method |> to_string() |> String.upcase(),
      url: URI.to_string(request.url),
      request_content_type: header(request.headers, "content-type"),
      request_body: body_text(request.body)
    }

    attrs =
      case outcome do
        %Req.Response{} = response ->
          Map.merge(attrs, %{
            status: if(response.status < 400, do: :ok, else: :error),
            error: if(response.status >= 400, do: "HTTP #{response.status}"),
            response_status: response.status,
            response_content_type: header(response.headers, "content-type"),
            response_body: body_text(response.body)
          })

        exception ->
          Map.merge(attrs, %{status: :error, error: Connector.describe_error(exception)})
      end

    record(connection, attrs)

    case outcome do
      %Req.Response{} = response -> {:ok, response}
      exception -> {:error, exception}
    end
  end

  defp timed(fun) do
    started_at = DateTime.utc_now()
    t0 = System.monotonic_time(:millisecond)
    result = fun.()
    {result, started_at, System.monotonic_time(:millisecond) - t0}
  end

  defp status({:ok, _}), do: :ok
  defp status({:error, _}), do: :error

  defp rows_of({:ok, rows}), do: normalise(rows)
  defp rows_of({:error, _}), do: nil

  defp error_of({:ok, _}), do: nil
  defp error_of({:error, message}), do: message

  # A failure to record must not fail the call that was recorded — it is
  # logged and the caller gets its answer. A recorded call joins the
  # running capture, with the capture's context on it.
  defp record(%Connection{id: connection_id}, attrs) do
    capture = Process.get(@capture_key)

    attrs =
      attrs
      |> Map.put(:connection_id, connection_id)
      |> Map.merge(context_of(capture))

    %ConnectionCall{}
    |> ConnectionCall.changeset(attrs)
    |> Repo.insert()
    |> case do
      {:ok, call} ->
        Process.put(@last_call_key, call.id)
        cite([call.id])
        :ok

      {:error, changeset} ->
        Logger.error("settings.gateway could not record a call: #{inspect(changeset.errors)}")
        :ok
    end
  end

  defp header(headers, name) do
    case Map.get(headers, name) do
      [value | _] -> value
      _ -> nil
    end
  end

  defp body_text(nil), do: nil
  defp body_text(""), do: nil
  defp body_text(body) when is_binary(body), do: body
  defp body_text(body) when is_list(body), do: IO.iodata_to_binary(body)
  defp body_text(body), do: body |> normalise() |> Jason.encode!()

  @doc false
  # Whatever a connector sends or answers, as JSON can hold it.
  def normalise(%Date{} = date), do: Date.to_iso8601(date)
  def normalise(%DateTime{} = at), do: DateTime.to_iso8601(at)
  def normalise(%NaiveDateTime{} = at), do: NaiveDateTime.to_iso8601(at)
  def normalise(%Decimal{} = decimal), do: Decimal.to_string(decimal)
  def normalise(%_{} = struct), do: struct |> Map.from_struct() |> normalise()

  def normalise(map) when is_map(map),
    do: Map.new(map, fn {k, v} -> {to_string(k), normalise(v)} end)

  def normalise(list) when is_list(list), do: Enum.map(list, &normalise/1)
  def normalise(tuple) when is_tuple(tuple), do: tuple |> Tuple.to_list() |> normalise()

  def normalise(atom) when is_atom(atom) and atom not in [nil, true, false],
    do: Atom.to_string(atom)

  def normalise(value) when is_binary(value) or is_number(value) or is_atom(value), do: value
  def normalise(other), do: inspect(other)
end
