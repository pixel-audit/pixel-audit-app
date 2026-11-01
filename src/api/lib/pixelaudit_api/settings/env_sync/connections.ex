defmodule PixelAudit.Api.Settings.EnvSync.Connections do
  @moduledoc """
  The `CONNECTION_*` half of `PixelAudit.Api.Settings.EnvSync`:

      CONNECTION_<id>_TYPE=meta | bigquery | postgres | clickhouse
      CONNECTION_<id>_<PARAM>=...

  `<id>` is the connection's code, `[a-z0-9]+` and case-sensitive, so it
  is written in lowercase in the variable's name and cannot hold `_` — which
  makes `CONNECTION_shop_URL` unambiguous. `<PARAM>` is one of the
  type's credential keys, uppercased (`ACCESS_TOKEN` for `access_token`).

  A connection whose code exists is updated: type and credentials replaced,
  name and description kept. A new one is created with its name set to its
  code. Both are marked `managed_by_env`, which makes type and credentials
  read-only in the API. One that was managed and is no longer in the
  environment is left as it is, no longer marked — deleting it would take
  its data sources' cached counts along for what may be a typo.
  """

  require Logger

  alias PixelAudit.Api.Settings.{Connection, Connector}
  alias PixelAudit.Api.Repo

  @type result :: %{code: String.t(), type: Connection.type(), action: :created | :updated}

  @doc """
  Reads the definitions out of the environment without touching the
  database: `{:ok, [%{code, connector, credentials}]}` or the problems.
  """
  def parse(env) do
    codes =
      env
      |> Map.keys()
      |> Enum.flat_map(fn name ->
        case Regex.run(~r/^CONNECTION_([a-z0-9]+)_TYPE$/, name) do
          [_, code] -> [code]
          nil -> []
        end
      end)
      |> Enum.sort()

    {definitions, problems} =
      Enum.reduce(codes, {[], []}, fn code, {definitions, problems} ->
        case parse_one(env, code) do
          {:ok, definition} -> {[definition | definitions], problems}
          {:error, more} -> {definitions, problems ++ more}
        end
      end)

    case problems do
      [] -> {:ok, Enum.reverse(definitions)}
      problems -> {:error, problems}
    end
  end

  defp parse_one(env, code) do
    prefix = "CONNECTION_#{code}_"
    env_type = env["#{prefix}TYPE"]

    case Connector.for_env_type(env_type) do
      nil ->
        known = Enum.map_join(Connector.all(), ", ", & &1.env_type())
        {:error, ["#{prefix}TYPE is #{inspect(env_type)}; it must be one of: #{known}"]}

      connector ->
        params = connector.credential_params()
        keys = Map.new(params, &{String.upcase(&1.key), &1.key})

        provided =
          env
          |> Enum.filter(fn {name, _} ->
            String.starts_with?(name, prefix) and name != "#{prefix}TYPE"
          end)
          |> Map.new(fn {name, value} -> {String.replace_prefix(name, prefix, ""), value} end)

        unknown =
          for {param, _} <- provided, not Map.has_key?(keys, param) do
            "#{prefix}#{param} is not a parameter of #{connector.env_type()} connections " <>
              "(known: #{Enum.map_join(params, ", ", &String.upcase(&1.key))})"
          end

        credentials =
          for {param, value} <- provided, key = keys[param], into: %{}, do: {key, value}

        case {unknown, PixelAudit.Api.FieldSpec.validate(params, credentials)} do
          {[], {:ok, normalised}} ->
            {:ok, %{code: code, connector: connector, credentials: normalised}}

          {unknown, {:ok, _}} ->
            {:error, unknown}

          {unknown, {:error, errors}} ->
            {:error,
             unknown ++
               for({key, message} <- errors, do: "#{prefix}#{String.upcase(key)} #{message}")}
        end
    end
  end

  @doc """
  Writes the parsed definitions — inside the caller's transaction, which
  it rolls back with the problem when one is refused — and releases the
  connections no longer defined. Answers the results.
  """
  @spec apply([map()]) :: [result()]
  def apply(definitions) do
    results =
      for definition <- definitions do
        case upsert(definition) do
          {:ok, result} -> result
          {:error, changeset} -> Repo.rollback(describe_changeset(definition.code, changeset))
        end
      end

    release_unmanaged(Enum.map(results, & &1.code))
    results
  end

  @doc "Logs what `apply/1` did, once it is committed."
  @spec log([result()]) :: :ok
  def log(results) do
    for result <- results do
      Logger.info(
        "settings.env_sync connection #{result.action} code=#{result.code} type=#{result.type}"
      )
    end

    :ok
  end

  defp upsert(%{code: code, connector: connector, credentials: credentials}) do
    attrs = %{
      "code" => code,
      "type" => connector.type(),
      "credentials" => credentials,
      "managed_by_env" => true
    }

    case Repo.get_by(Connection, code: code) do
      nil ->
        %Connection{}
        |> Connection.env_changeset(Map.put(attrs, "name", code))
        |> Repo.insert()
        |> annotate(:created)

      %Connection{} = existing ->
        # The stored credentials are replaced whole, not merged: the
        # environment is the source of truth for a managed connection.
        %{existing | credentials: nil}
        |> Connection.env_changeset(attrs)
        |> Repo.update()
        |> annotate(:updated)
    end
  end

  defp annotate({:ok, connection}, action),
    do: {:ok, %{code: connection.code, type: connection.type, action: action}}

  defp annotate(error, _action), do: error

  defp release_unmanaged(managed_codes) do
    import Ecto.Query

    {count, released} =
      Repo.update_all(
        from(c in Connection,
          where: c.managed_by_env == true and c.code not in ^managed_codes,
          select: c.code
        ),
        set: [managed_by_env: false]
      )

    if count > 0 do
      Logger.warning(
        "settings.env_sync connections no longer in the environment, kept unmanaged: " <>
          Enum.join(released, ", ")
      )
    end

    :ok
  end

  defp describe_changeset(code, changeset) do
    errors =
      Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
        Enum.reduce(opts, msg, fn {key, value}, acc ->
          String.replace(acc, "%{#{key}}", fn _ -> to_string(value) end)
        end)
      end)

    "connection #{code}: " <>
      Enum.map_join(errors, "; ", fn {field, messages} ->
        "#{field} #{Enum.join(messages, ", ")}"
      end)
  end
end
