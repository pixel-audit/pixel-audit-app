defmodule PixelAudit.ApiWeb.Admin.Funnels.ReportJSON do
  alias PixelAudit.ApiWeb.Admin.Funnels.{DataSourceJSON, StepJSON}

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
