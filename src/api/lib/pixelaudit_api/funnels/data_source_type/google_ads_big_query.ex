defmodule PixelAudit.Api.Funnels.DataSourceType.GoogleAdsBigQuery do
  @moduledoc """
  A step is a Google Ads conversion action, counted in the account's
  BigQuery Data Transfer dataset: `ads_ConversionStats_<customer id>` for
  the daily figures, joined to `ads_ConversionAction_<customer id>` for the
  action's name.

  The transfer's table layout is Google's and has changed before; the SQL
  is kept in this one module so a change is one edit.
  """

  @behaviour PixelAudit.Api.Funnels.DataSourceType

  import PixelAudit.Api.FieldSpec, only: [field: 2]

  alias PixelAudit.Api.Connections.Connector.BigQuery
  alias PixelAudit.Api.Funnels.DataSourceType

  @impl true
  def type, do: :google_ads_bigquery

  @impl true
  def label, do: "Google Ads (BigQuery transfer)"

  @impl true
  def description,
    do: "Conversions of a Google Ads account, counted in its BigQuery Data Transfer dataset."

  @impl true
  def connection_type, do: :bigquery

  @impl true
  def settings_schema do
    [
      field("dataset",
        label: "Dataset",
        required: true,
        description: "The Google Ads transfer dataset."
      ),
      field("customer_id",
        label: "Customer ID",
        required: true,
        description:
          "The Google Ads customer id without dashes, as in the table names (ads_ConversionStats_<id>)."
      )
    ]
  end

  @impl true
  def parameter_schema do
    [
      field("conversion_action_name",
        label: "Conversion action",
        required: true,
        description: "The conversion action's name as shown in Google Ads."
      ),
      field("metric",
        label: "Metric",
        kind: :select,
        options: ["conversions", "all_conversions"],
        default: "conversions",
        description:
          "Conversions counts the actions included in \"Conversions\"; all conversions counts every action."
      )
    ]
  end

  @impl true
  def count(connection, settings, parameters, date_from, date_to) do
    project = connection.credentials["project_id"]
    dataset = escape(settings["dataset"])
    customer_id = escape(settings["customer_id"])

    metric =
      if parameters["metric"] == "all_conversions",
        do: "metrics_all_conversions",
        else: "metrics_conversions"

    sql = """
    SELECT SUM(s.#{metric})
    FROM `#{project}.#{dataset}.ads_ConversionStats_#{customer_id}` s
    JOIN `#{project}.#{dataset}.ads_ConversionAction_#{customer_id}` a
      ON a.conversion_action_resource_name = s.segments_conversion_action
     AND a._DATA_DATE = a._LATEST_DATE
    WHERE s.segments_date BETWEEN @date_from AND @date_to
      AND a.conversion_action_name = @conversion_action_name
    """

    params = [
      {"date_from", "DATE", Date.to_iso8601(date_from)},
      {"date_to", "DATE", Date.to_iso8601(date_to)},
      {"conversion_action_name", "STRING", parameters["conversion_action_name"]}
    ]

    with {:ok, rows} <- BigQuery.query(connection.credentials, sql, params) do
      DataSourceType.scalar_count(rows)
    end
  end

  defp escape(name), do: String.replace(name || "", ~r/[^A-Za-z0-9_]/, "")
end
