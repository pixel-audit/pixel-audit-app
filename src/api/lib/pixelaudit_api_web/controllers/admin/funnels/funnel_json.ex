defmodule PixelAudit.ApiWeb.Admin.Funnels.FunnelJSON do
  alias PixelAudit.Api.Funnels.Funnel
  alias PixelAudit.ApiWeb.Admin.Funnels.{DataSourceJSON, StepJSON}

  def index(%{funnels: funnels}) do
    %{data: for(funnel <- funnels, do: data(funnel))}
  end

  def show(%{funnel: funnel}) do
    %{data: data(funnel)}
  end

  def data(%Funnel{} = funnel) do
    %{
      id: funnel.id,
      code: funnel.code,
      name: funnel.name,
      description: funnel.description,
      steps: Enum.map(funnel.steps, &StepJSON.data/1),
      data_sources: Enum.map(funnel.data_sources, &DataSourceJSON.data/1),
      inserted_at: funnel.inserted_at,
      updated_at: funnel.updated_at
    }
  end
end
