defmodule PixelAudit.Api.Funnels.DataSourceType.ClickHouseQuery do
  @moduledoc """
  A step is a SQL query on a ClickHouse database, answering one row with
  one number. The day is bound as `{date_from:Date}` and `{date_to:Date}` —
  never interpolated into the text.
  """

  @behaviour PixelAudit.Api.Funnels.DataSourceType

  import PixelAudit.Api.FieldSpec, only: [field: 2]

  alias PixelAudit.Api.Settings.Connector.ClickHouse
  alias PixelAudit.Api.Funnels.DataSourceType

  @impl true
  def type, do: :clickhouse_query

  @impl true
  def label, do: "ClickHouse query"

  @impl true
  def description, do: "A SQL query on a ClickHouse database, one number per day."

  @impl true
  def connection_type, do: :clickhouse

  @impl true
  def settings_schema, do: []

  @impl true
  def parameter_schema do
    [
      field("sql",
        label: "SQL",
        kind: :sql,
        required: true,
        description:
          "Must answer one row with one number. {date_from:Date} is the day's start and {date_to:Date} its end " <>
            "(the same day: counts are cached per day), e.g. " <>
            "SELECT count() FROM events WHERE toDate(at) BETWEEN {date_from:Date} AND {date_to:Date} AND name = 'purchase'."
      )
    ]
  end

  @impl true
  def count(connection, _settings, %{"sql" => sql}, date_from, date_to) do
    params = %{"date_from" => date_from, "date_to" => date_to}

    with {:ok, rows} <- ClickHouse.query(connection.credentials, sql, params) do
      DataSourceType.scalar_count(rows)
    end
  end
end
