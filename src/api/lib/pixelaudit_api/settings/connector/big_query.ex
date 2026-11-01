defmodule PixelAudit.Api.Settings.Connector.BigQuery do
  @moduledoc """
  Google BigQuery through its REST API (`jobs.query`), authenticated with a
  service account.

  `query/3` runs one Standard SQL statement with named parameters and
  answers the rows as lists of strings, the way BigQuery's JSON serialises
  them; the caller casts what it expects.
  """

  @behaviour PixelAudit.Api.Settings.Connector

  import PixelAudit.Api.FieldSpec, only: [field: 2]

  alias PixelAudit.Api.Settings.Connector

  @scope "https://www.googleapis.com/auth/bigquery.readonly"

  @impl true
  def type, do: :bigquery

  @impl true
  def env_type, do: "bigquery"

  @impl true
  def label, do: "Google BigQuery"

  @impl true
  def credential_params do
    [
      field("credentials_json",
        label: "Service account JSON",
        kind: :secret,
        required: true,
        description:
          "The service account's key file, as JSON or base64-encoded JSON. " <>
            "It needs BigQuery Job User on the project and Data Viewer on the datasets."
      ),
      field("project_id",
        label: "Project ID",
        required: true,
        description: "The project the query jobs run in (and are billed to)."
      ),
      field("location",
        label: "Location",
        description: "The datasets' location, e.g. EU or US. Optional."
      )
    ]
  end

  @impl true
  def check(connection) do
    case PixelAudit.Api.Settings.Gateway.query(connection, "SELECT 1", []) do
      {:ok, _rows} -> :ok
      {:error, message} -> {:error, message}
    end
  end

  @typedoc "A named query parameter: `{name, type, value}` with a BigQuery scalar type."
  @type param :: {String.t(), String.t(), String.t()}

  @doc "Runs a query; `params` are named (`@name` in the SQL)."
  @spec query(map(), String.t(), [param()]) :: {:ok, [[String.t() | nil]]} | {:error, String.t()}
  def query(credentials, sql, params) do
    timeout = Application.fetch_env!(:pixelaudit_api, :connector_timeout_ms)

    body =
      %{
        query: sql,
        useLegacySql: false,
        parameterMode: "NAMED",
        queryParameters:
          for {name, type, value} <- params do
            %{name: name, parameterType: %{type: type}, parameterValue: %{value: value}}
          end,
        timeoutMs: timeout,
        maxResults: 1000
      }
      |> put_location(credentials)

    with {:ok, token} <- token(credentials),
         {:ok, service_account} <- service_account(credentials),
         project = credentials["project_id"] || service_account["project_id"],
         {:ok, response} <- post(project, token, body),
         {:ok, response} <- await(project, token, response, timeout) do
      {:ok, rows(response)}
    end
  end

  defp put_location(body, %{"location" => location}) when is_binary(location) and location != "",
    do: Map.put(body, :location, location)

  defp put_location(body, _credentials), do: body

  defp post(project, token, body) do
    url = "https://bigquery.googleapis.com/bigquery/v2/projects/#{project}/queries"
    handle(Req.post(url, [json: body, auth: {:bearer, token}] ++ Connector.req_options()))
  end

  # A query that did not finish within timeoutMs answers jobComplete: false;
  # getQueryResults waits for it.
  defp await(_project, _token, %{"jobComplete" => true} = response, _timeout), do: {:ok, response}

  defp await(project, token, %{"jobReference" => %{"jobId" => job_id} = ref}, timeout) do
    url = "https://bigquery.googleapis.com/bigquery/v2/projects/#{project}/queries/#{job_id}"

    params =
      [timeoutMs: timeout, maxResults: 1000] ++
        if(ref["location"], do: [location: ref["location"]], else: [])

    case handle(Req.get(url, [params: params, auth: {:bearer, token}] ++ Connector.req_options())) do
      {:ok, %{"jobComplete" => true} = response} -> {:ok, response}
      {:ok, _still_running} -> {:error, "BigQuery job #{job_id} did not finish in time"}
      {:error, message} -> {:error, message}
    end
  end

  defp await(_project, _token, response, _timeout),
    do: {:error, "unexpected BigQuery answer: #{inspect(response)}"}

  defp rows(%{"rows" => rows}) when is_list(rows) do
    for %{"f" => fields} <- rows, do: for(%{"v" => value} <- fields, do: value)
  end

  defp rows(_), do: []

  defp handle({:ok, %Req.Response{status: 200, body: body}}) when is_map(body), do: {:ok, body}

  defp handle({:ok, %Req.Response{status: status, body: %{"error" => %{"message" => message}}}}),
    do: {:error, "BigQuery answered #{status}: #{message}"}

  defp handle({:ok, %Req.Response{status: status, body: body}}),
    do: {:error, "BigQuery answered #{status}: #{inspect(body)}"}

  defp handle({:error, exception}),
    do: {:error, "BigQuery unreachable: " <> Connector.describe_error(exception)}

  # The service account's key file: JSON, or base64 of it (the form a
  # single-line environment variable is happiest with).
  defp service_account(%{"credentials_json" => json}) when is_binary(json) do
    decoded =
      case Jason.decode(json) do
        {:ok, map} when is_map(map) ->
          {:ok, map}

        _ ->
          with {:ok, raw} <- Base.decode64(String.trim(json), ignore: :whitespace),
               {:ok, map} when is_map(map) <- Jason.decode(raw) do
            {:ok, map}
          else
            _ -> :error
          end
      end

    case decoded do
      {:ok, %{"client_email" => _, "private_key" => _} = map} -> {:ok, map}
      {:ok, _} -> {:error, "the service account JSON lacks client_email or private_key"}
      :error -> {:error, "the service account credentials are not JSON (or base64 of JSON)"}
    end
  end

  defp service_account(_), do: {:error, "the service account credentials are missing"}

  # A bearer token for the service account, through Goth; in tests a fixed
  # one from config (`:bigquery_token`) so nothing talks to Google.
  defp token(credentials) do
    case Application.get_env(:pixelaudit_api, :bigquery_token) do
      token when is_binary(token) ->
        {:ok, token}

      nil ->
        with {:ok, service_account} <- service_account(credentials) do
          source = {:service_account, service_account, scopes: [@scope]}

          case Goth.Token.fetch(source: source) do
            {:ok, %Goth.Token{token: token}} ->
              {:ok, token}

            {:error, reason} ->
              {:error, "Google token refused: " <> Connector.describe_error(reason)}
          end
        end
    end
  end
end
