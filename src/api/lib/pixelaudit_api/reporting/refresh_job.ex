defmodule PixelAudit.Api.Reporting.RefreshJob do
  @moduledoc """
  Recomputes one data source's daily counts over a refresh run's date
  range: for every step the data source has parameters for (or the one
  the run names) and every day, asks the type's resolver and stores the
  answer — the count, or the error — in `reporting_daily_counts`, citing
  the calls the resolver made or read cached values of
  (`PixelAudit.Api.Settings.Gateway.capture/2`). Queue `refresh`.

  One attempt: each day's outcome is stored as it comes, so a retry of the
  whole job would only repeat work; the nightly run recomputes the recent
  days anyway, and a person can ask again from the panel.

  A Meta-type data source waits (snoozes) while a pull of its connection's
  pixel stats is queued or running, so it reads the fresh copy.
  """

  use Oban.Worker, queue: :refresh, max_attempts: 1

  require Logger

  alias PixelAudit.Api.Funnels
  alias PixelAudit.Api.Funnels.DataSourceType
  alias PixelAudit.Api.Reporting
  alias PixelAudit.Api.Settings.Gateway

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"refresh_run_id" => run_id}}) do
    run = Reporting.get_refresh_run!(run_id)
    data_source = Funnels.get_data_source_for_refresh!(run.data_source_id)

    if data_source.type == :meta_pixel_api and
         Reporting.meta_run_active?(data_source.connection_id) do
      {:snooze, 60}
    else
      compute(Reporting.start_run(run), data_source)
    end
  end

  defp compute(run, data_source) do
    module = DataSourceType.for_type(data_source.type)
    parameters = Map.new(data_source.step_parameters, &{&1.step_id, &1.parameters})

    steps =
      Enum.filter(
        data_source.funnel.steps,
        &(Map.has_key?(parameters, &1.id) and (run.step_id == nil or &1.id == run.step_id))
      )

    dates = Date.range(run.date_from, run.date_to)

    outcomes =
      for step <- steps, date <- dates do
        context = %{
          purpose: :count,
          refresh_run_id: run.id,
          data_source_id: data_source.id,
          step_id: step.id,
          date: date
        }

        {outcome, cited} =
          Gateway.capture(context, fn ->
            count(module, data_source, parameters[step.id], date)
          end)

        Reporting.put_daily_count(run, data_source, step, date, outcome, cited)
        outcome
      end

    failed = Enum.filter(outcomes, &match?({:error, _}, &1))

    result =
      case failed do
        [] ->
          :ok

        [{:error, first} | _] ->
          {:error, "#{length(failed)} of #{length(outcomes)} day counts failed; first: #{first}"}
      end

    Reporting.finish_run(run, result)

    Logger.info(
      "reporting.refresh data_source=#{data_source.id} from=#{run.date_from} to=#{run.date_to} " <>
        "cells=#{length(outcomes)} failed=#{length(failed)}"
    )

    :ok
  end

  defp count(module, data_source, step_parameters, date) do
    case module.count(data_source.connection, data_source.settings, step_parameters, date, date) do
      {:ok, count} when is_integer(count) -> {:ok, count}
      {:error, message} -> {:error, to_string(message)}
      other -> {:error, "the resolver answered #{inspect(other)}"}
    end
  rescue
    exception -> {:error, Exception.message(exception)}
  catch
    :exit, reason -> {:error, "the resolver exited: #{inspect(reason)}"}
  end
end
