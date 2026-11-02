defmodule PixelAudit.ApiWeb.Admin.Funnels.ReportJSON do
  alias PixelAudit.ApiWeb.Admin.Funnels.{DataSourceJSON, StepJSON}
  alias PixelAudit.ApiWeb.Admin.Reporting.RefreshRunJSON
  alias PixelAudit.ApiWeb.Admin.Settings.ConnectionJSON

  def show(%{funnel: funnel, report: report}) do
    %{
      data: %{
        funnel_id: funnel.id,
        date_from: report.date_from,
        date_to: report.date_to,
        days: report.days,
        steps: Enum.map(funnel.steps, &StepJSON.data/1),
        data_sources: Enum.map(funnel.data_sources, &DataSourceJSON.data/1),
        cells: report.cells,
        conversions: report.conversions
      }
    }
  end

  def days(%{
        funnel: funnel,
        data_source: data_source,
        step: step,
        date_from: date_from,
        date_to: date_to,
        days: days
      }) do
    %{
      data: %{
        funnel_id: funnel.id,
        data_source: DataSourceJSON.data(data_source),
        step: StepJSON.data(step),
        date_from: date_from,
        date_to: date_to,
        days:
          for day <- days do
            %{
              date: day.date,
              count: day.daily_count && day.daily_count.count,
              status: if(day.daily_count, do: day.daily_count.status, else: :missing),
              error: day.daily_count && day.daily_count.error,
              computed_at: day.daily_count && day.daily_count.computed_at,
              refresh_run: day.daily_count && RefreshRunJSON.run_ref(day.daily_count.refresh_run),
              calls: Enum.map(day.calls, &ConnectionJSON.call_data/1)
            }
          end
      }
    }
  end

  def step(%{funnel: funnel, step: step, series: series}) do
    %{
      data: %{
        funnel_id: funnel.id,
        step: StepJSON.data(step),
        date_from: series.date_from,
        date_to: series.date_to,
        days: series.days,
        data_sources: Enum.map(funnel.data_sources, &DataSourceJSON.data/1),
        series: series.series
      }
    }
  end
end
