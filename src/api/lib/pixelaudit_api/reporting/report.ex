defmodule PixelAudit.Api.Reporting.Report do
  @moduledoc """
  A funnel's report over a date range, from the cached daily counts: one
  cell per data source and step with the sum of the days that counted, how
  many days counted, failed or were never computed, and each data source's
  step-to-step conversion. The sankey and the table in the panel are both
  drawn from this.
  """

  import Ecto.Query

  alias PixelAudit.Api.Funnels.Funnel
  alias PixelAudit.Api.Repo
  alias PixelAudit.Api.Reporting.DailyCount

  @type cell :: %{
          data_source_id: Ecto.UUID.t(),
          step_id: Ecto.UUID.t(),
          count: non_neg_integer() | nil,
          days_ok: non_neg_integer(),
          days_error: non_neg_integer(),
          days_missing: non_neg_integer(),
          last_error: String.t() | nil
        }

  @doc "Builds the report of a funnel loaded with its steps, data sources and parameters."
  def build(%Funnel{} = funnel, %Date{} = date_from, %Date{} = date_to) do
    days = Date.diff(date_to, date_from) + 1
    data_source_ids = Enum.map(funnel.data_sources, & &1.id)

    aggregates =
      Repo.all(
        from c in DailyCount,
          where:
            c.data_source_id in ^data_source_ids and c.date >= ^date_from and c.date <= ^date_to,
          group_by: [c.data_source_id, c.step_id],
          select: %{
            data_source_id: c.data_source_id,
            step_id: c.step_id,
            count:
              type(
                sum(fragment("CASE WHEN ? = 'ok' THEN ? ELSE 0 END", c.status, c.count)),
                :integer
              ),
            days_ok: count(fragment("CASE WHEN ? = 'ok' THEN 1 END", c.status)),
            days_error: count(fragment("CASE WHEN ? = 'error' THEN 1 END", c.status))
          }
      )
      |> Map.new(&{{&1.data_source_id, &1.step_id}, &1})

    last_errors =
      Repo.all(
        from c in DailyCount,
          where:
            c.data_source_id in ^data_source_ids and c.date >= ^date_from and c.date <= ^date_to and
              c.status == :error,
          distinct: [c.data_source_id, c.step_id],
          order_by: [c.data_source_id, c.step_id, desc: c.date],
          select: {c.data_source_id, c.step_id, c.error}
      )
      |> Map.new(fn {ds, step, error} -> {{ds, step}, error} end)

    cells =
      for data_source <- funnel.data_sources, step <- funnel.steps do
        measured? = Enum.any?(data_source.step_parameters, &(&1.step_id == step.id))
        key = {data_source.id, step.id}

        case {measured?, aggregates[key]} do
          {false, _} ->
            cell(data_source.id, step.id, nil, 0, 0, 0, nil)

          {true, nil} ->
            cell(data_source.id, step.id, nil, 0, 0, days, nil)

          {true, aggregate} ->
            count = if aggregate.days_ok > 0, do: aggregate.count, else: nil

            cell(
              data_source.id,
              step.id,
              count,
              aggregate.days_ok,
              aggregate.days_error,
              days - aggregate.days_ok - aggregate.days_error,
              last_errors[key]
            )
        end
      end

    %{
      date_from: date_from,
      date_to: date_to,
      days: days,
      cells: cells,
      conversions: conversions(funnel, cells)
    }
  end

  defp cell(data_source_id, step_id, count, ok, error, missing, last_error) do
    %{
      data_source_id: data_source_id,
      step_id: step_id,
      count: count,
      days_ok: ok,
      days_error: error,
      days_missing: missing,
      last_error: last_error
    }
  end

  # From each step to the next, per data source: the next count over the
  # previous one. `nil` when either is unknown or the previous is zero.
  defp conversions(funnel, cells) do
    by_key = Map.new(cells, &{{&1.data_source_id, &1.step_id}, &1})

    for data_source <- funnel.data_sources,
        [from, to] <- Enum.chunk_every(funnel.steps, 2, 1, :discard) do
      previous = by_key[{data_source.id, from.id}].count
      next = by_key[{data_source.id, to.id}].count

      rate =
        case {previous, next} do
          {p, n} when is_integer(p) and p > 0 and is_integer(n) -> n / p
          _ -> nil
        end

      %{data_source_id: data_source.id, from_step_id: from.id, to_step_id: to.id, rate: rate}
    end
  end
end
