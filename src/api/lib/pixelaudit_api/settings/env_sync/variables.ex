defmodule PixelAudit.Api.Settings.EnvSync.Variables do
  @moduledoc """
  The `VARIABLE_*` half of `PixelAudit.Api.Settings.EnvSync`:

      VARIABLE_<key>_VALUE=...
      VARIABLE_<key>_DESCRIPTION=...

  `<key>` is the variable's key, `[a-zA-Z0-9]+` and case-sensitive, so it
  cannot hold `_` and `VARIABLE_apiBase_VALUE` reads one way only. The
  description is optional.

  A variable whose key exists has its value replaced, and its description
  when the environment gives one; a new one is created. Both are marked
  `managed_by_env`, which makes the value read-only in the API.
  """

  require Logger

  alias PixelAudit.Api.Repo
  alias PixelAudit.Api.Settings.Variable

  @type result :: %{key: String.t(), action: :created | :updated}

  @params ["VALUE", "DESCRIPTION"]

  @doc """
  Reads the definitions out of the environment without touching the
  database: `{:ok, [%{key, value, description}]}` or the problems.
  """
  def parse(env) do
    names =
      env
      |> Map.keys()
      |> Enum.flat_map(fn name ->
        case Regex.run(~r/^VARIABLE_([A-Za-z0-9]+)_([A-Z_]+)$/, name) do
          [_, key, param] -> [{key, param}]
          nil -> []
        end
      end)

    keys = names |> Enum.map(&elem(&1, 0)) |> Enum.uniq() |> Enum.sort()

    {definitions, problems} =
      Enum.reduce(keys, {[], []}, fn key, {definitions, problems} ->
        params = for {^key, param} <- names, do: param
        unknown = for param <- params, param not in @params, do: param

        cond do
          unknown != [] ->
            {definitions,
             problems ++
               for(
                 param <- unknown,
                 do:
                   "VARIABLE_#{key}_#{param} is not a parameter of a variable " <>
                     "(known: #{Enum.join(@params, ", ")})"
               )}

          "VALUE" not in params ->
            {definitions, problems ++ ["VARIABLE_#{key}_VALUE is missing"]}

          true ->
            definition = %{
              key: key,
              value: env["VARIABLE_#{key}_VALUE"],
              description: env["VARIABLE_#{key}_DESCRIPTION"]
            }

            {[definition | definitions], problems}
        end
      end)

    case problems do
      [] -> {:ok, Enum.reverse(definitions)}
      problems -> {:error, problems}
    end
  end

  @doc """
  Writes the parsed definitions — inside the caller's transaction, which
  it rolls back with the problem when one is refused — and releases the
  variables no longer defined. Answers the results.
  """
  @spec apply([map()]) :: [result()]
  def apply(definitions) do
    results =
      for definition <- definitions do
        case upsert(definition) do
          {:ok, result} -> result
          {:error, changeset} -> Repo.rollback(describe_changeset(definition.key, changeset))
        end
      end

    release_unmanaged(Enum.map(results, & &1.key))
    results
  end

  @doc "Logs what `apply/1` did, once it is committed."
  @spec log([result()]) :: :ok
  def log(results) do
    for result <- results do
      Logger.info("settings.env_sync variable #{result.action} key=#{result.key}")
    end

    :ok
  end

  defp upsert(%{key: key, value: value, description: description}) do
    attrs = %{"key" => key, "value" => value, "managed_by_env" => true}
    # The environment sets the description only when it says one; a
    # description typed in the panel survives a boot that says none.
    attrs = if description, do: Map.put(attrs, "description", description), else: attrs

    case Repo.get_by(Variable, key: key) do
      nil ->
        %Variable{} |> Variable.env_changeset(attrs) |> Repo.insert() |> annotate(:created)

      %Variable{} = existing ->
        existing |> Variable.env_changeset(attrs) |> Repo.update() |> annotate(:updated)
    end
  end

  defp annotate({:ok, variable}, action), do: {:ok, %{key: variable.key, action: action}}
  defp annotate(error, _action), do: error

  defp release_unmanaged(managed_keys) do
    import Ecto.Query

    {count, released} =
      Repo.update_all(
        from(v in Variable,
          where: v.managed_by_env == true and v.key not in ^managed_keys,
          select: v.key
        ),
        set: [managed_by_env: false]
      )

    if count > 0 do
      Logger.warning(
        "settings.env_sync variables no longer in the environment, kept unmanaged: " <>
          Enum.join(released, ", ")
      )
    end

    :ok
  end

  defp describe_changeset(key, changeset) do
    errors =
      Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
        Enum.reduce(opts, msg, fn {key, value}, acc ->
          String.replace(acc, "%{#{key}}", fn _ -> to_string(value) end)
        end)
      end)

    "variable #{key}: " <>
      Enum.map_join(errors, "; ", fn {field, messages} ->
        "#{field} #{Enum.join(messages, ", ")}"
      end)
  end
end
