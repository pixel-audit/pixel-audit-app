defmodule PixelAudit.Api.Funnels.DataSourceType.GoogleAnalyticsBigQuery do
  @moduledoc """
  A step is a GA4 event, counted in the property's BigQuery export: the
  daily `events_YYYYMMDD` tables (and `events_intraday_YYYYMMDD` for a day
  whose daily table has not landed yet) of the `analytics_<property>`
  dataset.
  """

  @behaviour PixelAudit.Api.Funnels.DataSourceType

  import PixelAudit.Api.FieldSpec, only: [field: 2]

  alias PixelAudit.Api.Connections.Connector.BigQuery
  alias PixelAudit.Api.Funnels.DataSourceType

  @impl true
  def type, do: :google_analytics_bigquery

  @impl true
  def label, do: "Google Analytics 4 (BigQuery export)"

  @impl true
  def description, do: "Events of a GA4 property, counted in its BigQuery export dataset."

  @impl true
  def connection_type, do: :bigquery

  @impl true
  def settings_schema do
    [
      field("dataset",
        label: "Dataset",
        required: true,
        description: "The export dataset, e.g. analytics_123456789."
      )
    ]
  end

  @impl true
  def parameter_schema do
    [
      field("event_name",
        label: "Event name",
        required: true,
        description: "The GA4 event: page_view, add_to_cart, purchase, or a custom event."
      ),
      field("where",
        label: "Extra condition",
        kind: :sql,
        description:
          "Optional SQL appended with AND, e.g. (SELECT value.string_value FROM UNNEST(event_params) WHERE key = 'page_location') LIKE '%/checkout%'."
      )
    ]
  end

  @impl true
  def count(connection, %{"dataset" => dataset}, parameters, date_from, date_to) do
    project = connection.credentials["project_id"]
    table = "`#{project}.#{escape(dataset)}.events_*`"
    where = parameters["where"]

    sql =
      """
      SELECT COUNT(*)
      FROM #{table}
      WHERE (
        _TABLE_SUFFIX BETWEEN @suffix_from AND @suffix_to
        OR _TABLE_SUFFIX BETWEEN CONCAT('intraday_', @suffix_from) AND CONCAT('intraday_', @suffix_to)
      )
      AND event_name = @event_name
      """ <> if(where in [nil, ""], do: "", else: "AND (#{where})\n")

    params = [
      {"suffix_from", "STRING", suffix(date_from)},
      {"suffix_to", "STRING", suffix(date_to)},
      {"event_name", "STRING", parameters["event_name"]}
    ]

    with {:ok, rows} <- BigQuery.query(connection.credentials, sql, params) do
      DataSourceType.scalar_count(rows)
    end
  end

  defp suffix(%Date{} = date), do: Calendar.strftime(date, "%Y%m%d")

  # Dataset names are letters, digits and underscores; anything else cannot
  # be a dataset and must not reach the SQL.
  defp escape(name), do: String.replace(name, ~r/[^A-Za-z0-9_]/, "")
end
