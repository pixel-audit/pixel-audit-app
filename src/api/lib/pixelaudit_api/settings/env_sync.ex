defmodule PixelAudit.Api.Settings.EnvSync do
  @moduledoc """
  Maps the `CONNECTION_*` and `VARIABLE_*` environment onto settings rows —
  what the `boot` role does after migrating (`PixelAudit.Api.Release.boot/0`,
  `mix boot`).

      CONNECTION_<id>_TYPE=meta | bigquery | postgres | clickhouse
      CONNECTION_<id>_<PARAM>=...
      VARIABLE_<key>_VALUE=...
      VARIABLE_<key>_DESCRIPTION=...

  The halves are `EnvSync.Connections` and `EnvSync.Variables`. The whole
  set is validated before anything is written, and written in one
  transaction: a deploy with one bad variable changes nothing. A row that
  was managed and is no longer in the environment is left as it is, no
  longer marked as managed.
  """

  require Logger

  alias PixelAudit.Api.Repo
  alias PixelAudit.Api.Settings.EnvSync.{Connections, Variables}

  @type results :: %{connections: [Connections.result()], variables: [Variables.result()]}

  @doc "Applies the given environment (`System.get_env/0` by default)."
  @spec run(%{String.t() => String.t()}) :: {:ok, results()} | {:error, [String.t()]}
  def run(env \\ System.get_env()) do
    case {Connections.parse(env), Variables.parse(env)} do
      {{:ok, connections}, {:ok, variables}} ->
        if connections == [] and variables == [] do
          Logger.info("settings.env_sync no CONNECTION_* or VARIABLE_* variables set")
        end

        apply_definitions(connections, variables)

      {connections, variables} ->
        {:error, problems(connections) ++ problems(variables)}
    end
  end

  defp problems({:ok, _definitions}), do: []
  defp problems({:error, problems}), do: problems

  defp apply_definitions(connections, variables) do
    Repo.transaction(fn ->
      %{connections: Connections.apply(connections), variables: Variables.apply(variables)}
    end)
    |> case do
      {:ok, results} ->
        Connections.log(results.connections)
        Variables.log(results.variables)
        {:ok, results}

      {:error, problem} ->
        {:error, [problem]}
    end
  end
end
