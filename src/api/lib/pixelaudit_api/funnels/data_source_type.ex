defmodule PixelAudit.Api.Funnels.DataSourceType do
  @moduledoc """
  What a data source type is: the connection type it reads through, the
  settings a data source of it carries, the parameters each funnel step
  takes, and how it counts one step on one day.

  Counting is always asked per day (`date_from = date_to = the day`): the
  report caches days and sums them over the range it shows
  (`PixelAudit.Api.Reporting`). The two dynamic values every resolver gets
  are therefore `date_from` and `date_to`, as the brief asks, and a SQL
  query sees them as bound parameters.
  """

  alias PixelAudit.Api.Settings.Connection
  alias PixelAudit.Api.FieldSpec

  @callback type() :: atom()
  @callback label() :: String.t()
  @callback description() :: String.t()
  @callback connection_type() :: Connection.type()
  @callback settings_schema() :: [FieldSpec.t()]
  @callback parameter_schema() :: [FieldSpec.t()]
  @callback count(
              connection :: Connection.t(),
              settings :: map(),
              parameters :: map(),
              date_from :: Date.t(),
              date_to :: Date.t()
            ) :: {:ok, non_neg_integer()} | {:error, String.t()}

  @types [
    PixelAudit.Api.Funnels.DataSourceType.MetaPixelApi,
    PixelAudit.Api.Funnels.DataSourceType.GoogleAnalyticsBigQuery,
    PixelAudit.Api.Funnels.DataSourceType.GoogleAdsBigQuery,
    PixelAudit.Api.Funnels.DataSourceType.PostgresQuery,
    PixelAudit.Api.Funnels.DataSourceType.ClickHouseQuery
  ]

  @doc "Every type, in the order the panel lists them."
  def all, do: @types

  @doc "The module of a data source type."
  def for_type(type) do
    Enum.find(@types, &(&1.type() == type)) ||
      raise ArgumentError, "unknown data source type #{inspect(type)}"
  end

  @doc """
  A query result as a count: exactly one row with one numeric column,
  which is what a step's SQL has to answer. BigQuery sends numbers as
  strings; a decimal or float is rounded.
  """
  @spec scalar_count([[term()]]) :: {:ok, non_neg_integer()} | {:error, String.t()}
  def scalar_count([[value]]), do: to_count(value)
  def scalar_count([]), do: {:error, "the query answered no row; it must answer exactly one"}

  def scalar_count([_ | _] = rows) when length(rows) > 1,
    do: {:error, "the query answered #{length(rows)} rows; it must answer exactly one"}

  def scalar_count([row]) when is_list(row),
    do: {:error, "the query answered #{length(row)} columns; it must answer exactly one"}

  defp to_count(nil), do: {:ok, 0}
  defp to_count(value) when is_integer(value) and value >= 0, do: {:ok, value}
  defp to_count(value) when is_integer(value), do: {:error, "the query answered a negative count"}
  defp to_count(value) when is_float(value), do: to_count(round(value))

  defp to_count(%Decimal{} = value),
    do: to_count(value |> Decimal.round() |> Decimal.to_integer())

  defp to_count(value) when is_binary(value) do
    case Integer.parse(value) do
      {int, ""} ->
        to_count(int)

      _ ->
        case Float.parse(value) do
          {float, ""} -> to_count(float)
          _ -> {:error, "the query answered #{inspect(value)}, not a number"}
        end
    end
  end

  defp to_count(value), do: {:error, "the query answered #{inspect(value)}, not a number"}
end
