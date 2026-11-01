defmodule PixelAudit.Api.Funnels.DataSourceType.PostgresQuery do
  @moduledoc """
  A step is a SQL query on a PostgreSQL database, answering one row with
  one number. The day stands in the query as `$1` (date from) and `$2`
  (date to), which are replaced by typed date literals (`DATE '2026-10-20'`)
  before the query runs.

  Literals rather than bound parameters, deliberately: Postgres infers a
  bound parameter's type from where it is used, and `created_at < $2 + 1`
  comes out as "timestamptz < integer" while `$2::date + 1` in another
  place of the same query contradicts it — a query that reads naturally
  fails for a reason its author cannot see. The values are PixelAudit's
  own calendar days, formatted here (`Date.to_iso8601/1`), never anything
  a person typed, so the literal is safe and the query's own `$1`/`$2`
  behave like the dates they are.
  """

  @behaviour PixelAudit.Api.Funnels.DataSourceType

  import PixelAudit.Api.FieldSpec, only: [field: 2]

  alias PixelAudit.Api.Settings.Connector.Postgres
  alias PixelAudit.Api.Funnels.DataSourceType

  @impl true
  def type, do: :postgres_query

  @impl true
  def label, do: "PostgreSQL query"

  @impl true
  def description, do: "A SQL query on a PostgreSQL database, one number per day."

  @impl true
  def connection_type, do: :postgres

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
          "Must answer one row with one number. $1 is the day's start and $2 its end, both DATE " <>
            "literals (the same day: counts are cached per day), e.g. " <>
            "SELECT COUNT(*) FROM orders WHERE created_at >= $1 AND created_at < $2 + 1."
      )
    ]
  end

  @impl true
  def count(connection, _settings, %{"sql" => sql}, date_from, date_to) do
    sql = with_dates(sql, date_from, date_to)

    with {:ok, rows} <- Postgres.query(connection.credentials, sql, []) do
      DataSourceType.scalar_count(rows)
    end
  end

  @doc false
  def with_dates(sql, %Date{} = date_from, %Date{} = date_to) do
    sql
    |> String.trim()
    |> String.trim_trailing(";")
    |> String.replace(~r/\$1(?!\d)/, "DATE '#{Date.to_iso8601(date_from)}'")
    |> String.replace(~r/\$2(?!\d)/, "DATE '#{Date.to_iso8601(date_to)}'")
  end
end
