defmodule PixelAudit.ApiWeb.Admin.Reporting.RefreshRunJSON do
  alias PixelAudit.Api.Reporting.RefreshRun

  def index(%{runs: runs, total: total}) do
    %{data: for(run <- runs, do: data(run)), total: total}
  end

  def created(%{runs: runs}) do
    %{data: for(run <- runs, do: data(run))}
  end

  def show(%{run: run}) do
    %{data: data(run)}
  end

  def days(%{days: days}) do
    %{
      data:
        for day <- days do
          %{
            date: day.date,
            step: PixelAudit.ApiWeb.Admin.Funnels.StepJSON.data(day.step),
            status: day.status,
            count: day.count,
            error: day.error,
            computed_at: day.computed_at
          }
        end
    }
  end

  @doc "A run as a daily count names the one that wrote it."
  def run_ref(nil), do: nil
  def run_ref(%Ecto.Association.NotLoaded{}), do: nil

  def run_ref(%RefreshRun{} = run) do
    %{
      id: run.id,
      trigger: run.trigger,
      status: run.status,
      started_at: run.started_at,
      finished_at: run.finished_at
    }
  end

  defp data(%RefreshRun{} = run) do
    %{
      id: run.id,
      kind: run.kind,
      connection: ref(run.connection),
      funnel: ref(run.funnel),
      data_source: ref(run.data_source),
      step: ref(run.step),
      date_from: run.date_from,
      date_to: run.date_to,
      trigger: run.trigger,
      status: run.status,
      started_at: run.started_at,
      finished_at: run.finished_at,
      error: run.error,
      inserted_at: run.inserted_at
    }
  end

  defp ref(nil), do: nil
  defp ref(%Ecto.Association.NotLoaded{}), do: nil
  defp ref(%{id: id, name: name}), do: %{id: id, name: name}
end
