defmodule PixelAudit.ApiWeb.Admin.Funnels.DataSourceJSON do
  alias PixelAudit.Api.Funnels.{DataSource, StepParameter}
  alias PixelAudit.ApiWeb.Admin.Settings.ConnectionJSON

  def show(%{data_source: data_source}) do
    %{data: data(data_source)}
  end

  def data(%DataSource{} = data_source) do
    %{
      id: data_source.id,
      name: data_source.name,
      description: data_source.description,
      type: data_source.type,
      connection_id: data_source.connection_id,
      connection: ConnectionJSON.ref(data_source.connection),
      settings: data_source.settings || %{},
      position: data_source.position,
      color: data_source.color,
      step_parameters: Enum.map(data_source.step_parameters, &step_parameter/1)
    }
  end

  def step_parameter(%StepParameter{} = step_parameter) do
    %{step_id: step_parameter.step_id, parameters: step_parameter.parameters || %{}}
  end
end
