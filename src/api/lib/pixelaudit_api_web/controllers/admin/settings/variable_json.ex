defmodule PixelAudit.ApiWeb.Admin.Settings.VariableJSON do
  alias PixelAudit.Api.Settings.Variable

  def index(%{variables: variables}) do
    %{data: for(variable <- variables, do: data(variable))}
  end

  def show(%{variable: variable}) do
    %{data: data(variable)}
  end

  defp data(%Variable{} = variable) do
    %{
      id: variable.id,
      key: variable.key,
      value: variable.value,
      description: variable.description,
      managed_by_env: variable.managed_by_env,
      inserted_at: variable.inserted_at,
      updated_at: variable.updated_at
    }
  end
end
