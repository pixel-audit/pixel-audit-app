defmodule PixelAudit.ApiWeb.Admin.Funnels.StepJSON do
  alias PixelAudit.Api.Funnels.Step

  def index(%{steps: steps}) do
    %{data: for(step <- steps, do: data(step))}
  end

  def show(%{step: step}) do
    %{data: data(step)}
  end

  def data(%Step{} = step) do
    %{
      id: step.id,
      code: step.code,
      name: step.name,
      description: step.description,
      position: step.position
    }
  end
end
