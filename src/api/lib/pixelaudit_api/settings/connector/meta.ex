defmodule PixelAudit.Api.Settings.Connector.Meta do
  @moduledoc """
  Meta's Graph API for one pixel: the access token, the pixel id and the
  API version.

  `fetch_stats/3` reads `GET /{pixel_id}/stats?aggregation=event`, which
  answers the pixel's fire counts per event per hour — for about the last
  seven days only, which is why `PixelAudit.Api.Reporting` keeps its own
  copy (`PixelAudit.Api.Settings.MetaPixelStat`).
  """

  @behaviour PixelAudit.Api.Settings.Connector

  import PixelAudit.Api.FieldSpec, only: [field: 2]

  alias PixelAudit.Api.Settings.{Connection, Connector, Gateway}

  @default_version "v25.0"

  @impl true
  def type, do: :meta

  @impl true
  def env_type, do: "meta"

  @impl true
  def label, do: "Meta Pixel (Graph API)"

  @impl true
  def credential_params do
    [
      field("access_token",
        label: "Access token",
        kind: :secret,
        required: true,
        description: "A system user or user token with ads_read on the pixel's ad account."
      ),
      field("pixel_id", label: "Pixel ID", required: true),
      field("api_version",
        label: "API version",
        default: @default_version,
        description: "Graph API version, e.g. #{@default_version}."
      )
    ]
  end

  @impl true
  def check(connection) do
    pixel_id = connection.credentials["pixel_id"]

    case request(connection, "/#{pixel_id}", fields: "id,name") do
      {:ok, %{"id" => _}} -> :ok
      {:ok, body} -> {:error, "unexpected answer: #{inspect(body)}"}
      {:error, message} -> {:error, message}
    end
  end

  @doc """
  The pixel's hourly event counts between two instants.

  Answers rows of `%{date: Date.t(), hour: 0..23, event_name: String.t(),
  count: non_neg_integer(), call_id: Ecto.UUID.t()}` in UTC — `call_id`
  the recorded call of the page that delivered the hour, which the cached
  hour cites. Meta pages the answer; every page is followed.
  """
  @spec fetch_stats(Connection.t(), DateTime.t(), DateTime.t()) ::
          {:ok, [map()]} | {:error, String.t()}
  def fetch_stats(%Connection{} = connection, %DateTime{} = start_time, %DateTime{} = end_time) do
    params = [
      aggregation: "event",
      start_time: DateTime.to_unix(start_time),
      end_time: DateTime.to_unix(end_time),
      limit: 500
    ]

    pixel_id = connection.credentials["pixel_id"]

    with {:ok, pages} <- paginate(connection, "/#{pixel_id}/stats", params) do
      {:ok, Enum.flat_map(pages, &rows_of_page/1)}
    end
  end

  # One page of /stats: `data` is a list of `{start_time, count, data: [{value, count}]}`
  # per hour, where `value` is the event name.
  defp rows_of_page({%{"data" => data}, call_id}) when is_list(data) do
    Enum.flat_map(data, fn hour ->
      with {:ok, at} <- parse_time(hour["start_time"]) do
        events = hour["data"] || []

        for %{"value" => event_name, "count" => count} <- events do
          %{
            date: DateTime.to_date(at),
            hour: at.hour,
            event_name: event_name,
            count: count,
            call_id: call_id
          }
        end
      else
        _ -> []
      end
    end)
  end

  defp rows_of_page(_), do: []

  # Meta writes its times as "2026-01-01T10:00:00+0000" — an offset without
  # the colon, which DateTime.from_iso8601 reads fine.
  defp parse_time(value) when is_binary(value) do
    case DateTime.from_iso8601(value) do
      {:ok, at, _offset} -> {:ok, DateTime.shift_zone!(at, "Etc/UTC")}
      error -> error
    end
  end

  defp parse_time(_), do: :error

  # Every page with the id of the call that fetched it.
  defp paginate(connection, path, params, acc \\ []) do
    case request(connection, path, params) do
      {:ok, %{"paging" => %{"cursors" => %{"after" => cursor}, "next" => next}} = page}
      when is_binary(next) and is_binary(cursor) ->
        acc = [{page, Gateway.last_call_id()} | acc]
        paginate(connection, path, Keyword.put(params, :after, cursor), acc)

      {:ok, page} ->
        {:ok, Enum.reverse([{page, Gateway.last_call_id()} | acc])}

      {:error, message} ->
        {:error, message}
    end
  end

  # The access token travels as a bearer header, which the gateway does not
  # record; the URL and its parameters, which it does, hold no secret.
  defp request(%Connection{credentials: credentials} = connection, path, params) do
    version = credentials["api_version"] || @default_version
    url = "https://graph.facebook.com/#{version}#{path}"

    request =
      Req.new(
        [method: :get, url: url, params: params, auth: {:bearer, credentials["access_token"]}] ++
          Connector.req_options()
      )

    case Gateway.request(connection, request) do
      {:ok, %Req.Response{status: 200, body: body}} ->
        case decoded(body) do
          %{} = body -> {:ok, body}
          other -> {:error, "Meta Graph API answered 200 with #{inspect(other)}, not an object"}
        end

      {:ok, %Req.Response{status: status, body: body}} ->
        {:error, graph_error(status, decoded(body))}

      {:error, exception} ->
        {:error, "Meta Graph API unreachable: " <> Connector.describe_error(exception)}
    end
  end

  # Req decodes JSON when the answer says `application/json`; the Graph API
  # also answers `text/javascript`, which leaves the JSON as text.
  defp decoded(body) when is_binary(body) do
    case Jason.decode(body) do
      {:ok, decoded} -> decoded
      {:error, _} -> body
    end
  end

  defp decoded(body), do: body

  defp graph_error(status, %{"error" => %{"message" => message} = error}) do
    code = error["code"]
    "Meta Graph API answered #{status}#{if code, do: " (code #{code})", else: ""}: #{message}"
  end

  defp graph_error(status, body), do: "Meta Graph API answered #{status}: #{inspect(body)}"
end
