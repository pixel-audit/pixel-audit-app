defmodule PixelAudit.Api.Settings do
  @moduledoc """
  The settings: the connections — credentials for the external systems the
  funnels' data sources read from, and the cached Meta pixel stats that
  hang off a Meta connection — and the variables, a key/value store.
  """

  import Ecto.Query, warn: false

  require Logger

  alias PixelAudit.Api.Settings.{Connection, Connector, MetaPixelStat, Variable}
  alias PixelAudit.Api.Repo

  ## Connections

  @doc "Every connection, by code."
  def list_connections do
    Repo.all(from c in Connection, order_by: c.code)
  end

  @doc "Connections of one type, by code."
  def list_connections(type: type) do
    Repo.all(from c in Connection, where: c.type == ^type, order_by: c.code)
  end

  def get_connection!(id), do: Repo.get!(Connection, id)

  def get_connection_by_code(code), do: Repo.get_by(Connection, code: code)

  @doc "Creates a connection from the panel's attributes (`credentials` included)."
  def create_connection(attrs) do
    %Connection{}
    |> Connection.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a connection. One the environment manages keeps its type and
  credentials: a request that touches them is refused with
  `{:error, :managed_by_env}`; its name and description stay editable.
  """
  def update_connection(%Connection{managed_by_env: true} = connection, attrs) do
    if touches_managed_fields?(attrs) do
      {:error, :managed_by_env}
    else
      connection
      |> Connection.changeset(Map.drop(attrs, ["type", :type, "credentials", :credentials]))
      |> Repo.update()
    end
  end

  def update_connection(%Connection{} = connection, attrs) do
    connection
    |> Connection.changeset(attrs)
    |> Repo.update()
  end

  defp touches_managed_fields?(attrs) do
    Enum.any?(["type", "credentials"], fn key ->
      Map.has_key?(attrs, key) or Map.has_key?(attrs, String.to_atom(key))
    end)
  end

  @doc """
  Deletes a connection, unless a data source still reads through it
  (`{:error, :connection_in_use}`): the data source would be left pointing
  nowhere, and its cached counts with it.
  """
  def delete_connection(%Connection{} = connection) do
    in_use =
      Repo.exists?(
        from d in PixelAudit.Api.Funnels.DataSource, where: d.connection_id == ^connection.id
      )

    if in_use, do: {:error, :connection_in_use}, else: Repo.delete(connection)
  end

  @doc """
  Asks the connector whether the credentials work, and records the answer
  on the connection (`last_check_*`).
  """
  def check_connection(%Connection{} = connection) do
    result =
      try do
        Connector.for_type(connection.type).check(connection.credentials || %{})
      rescue
        exception -> {:error, Connector.describe_error(exception)}
      end

    {:ok, connection} =
      connection
      |> Connection.check_changeset(result)
      |> Repo.update()

    case result do
      :ok ->
        Logger.info("connections.check ok code=#{connection.code}")

      {:error, message} ->
        Logger.warning(
          "connections.check failed code=#{connection.code} error=#{inspect(message)}"
        )
    end

    {result, connection}
  end

  @doc "Every connection whose credentials fill in a Meta-type data source."
  def list_meta_connections, do: list_connections(type: :meta)

  ## Meta pixel stats

  @doc """
  Stores the hourly rows `PixelAudit.Api.Settings.Connector.Meta.fetch_stats/3`
  answered, replacing what was stored for the same hour and event.
  """
  def upsert_meta_pixel_stats(%Connection{id: connection_id}, rows) do
    now = DateTime.utc_now(:second)

    entries =
      for row <- rows do
        %{
          id: Ecto.UUID.generate(),
          connection_id: connection_id,
          date: row.date,
          hour: row.hour,
          event_name: row.event_name,
          count: row.count,
          inserted_at: now
        }
      end

    entries
    |> Enum.chunk_every(1000)
    |> Enum.reduce(0, fn chunk, total ->
      {count, _} =
        Repo.insert_all(MetaPixelStat, chunk,
          on_conflict: {:replace, [:count, :inserted_at]},
          conflict_target: [:connection_id, :date, :hour, :event_name]
        )

      total + count
    end)
  end

  @doc """
  The pixel's fires of one event on one day, summed over the cached hours;
  `:missing` when nothing at all is cached for the connection on that day
  (not fetched yet, or outside Meta's window when first asked).
  """
  def meta_pixel_day_count(%Connection{id: connection_id}, event_name, %Date{} = date) do
    cached_day? =
      Repo.exists?(
        from s in MetaPixelStat, where: s.connection_id == ^connection_id and s.date == ^date
      )

    if cached_day? do
      sum =
        Repo.one(
          from s in MetaPixelStat,
            where:
              s.connection_id == ^connection_id and s.date == ^date and
                s.event_name == ^event_name,
            select: type(sum(s.count), :integer)
        )

      {:ok, sum || 0}
    else
      :missing
    end
  end

  @doc "The event names seen on a Meta connection, for the parameter form's suggestions."
  def meta_pixel_event_names(%Connection{id: connection_id}) do
    Repo.all(
      from s in MetaPixelStat,
        where: s.connection_id == ^connection_id,
        distinct: true,
        order_by: s.event_name,
        select: s.event_name
    )
  end

  ## Variables

  @doc "Every variable, by key."
  def list_variables do
    Repo.all(from v in Variable, order_by: v.key)
  end

  def get_variable!(id), do: Repo.get!(Variable, id)

  def get_variable_by_key(key), do: Repo.get_by(Variable, key: key)

  @doc "Creates a variable from the panel's attributes."
  def create_variable(attrs) do
    %Variable{}
    |> Variable.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a variable. One the environment manages keeps its key and value:
  a request that touches them is refused with `{:error, :managed_by_env}`;
  its description stays editable.
  """
  def update_variable(%Variable{managed_by_env: true} = variable, attrs) do
    if Enum.any?(
         ["key", "value"],
         &(Map.has_key?(attrs, &1) or Map.has_key?(attrs, String.to_atom(&1)))
       ) do
      {:error, :managed_by_env}
    else
      variable
      |> Variable.changeset(Map.take(attrs, ["description", :description]))
      |> Repo.update()
    end
  end

  def update_variable(%Variable{} = variable, attrs) do
    variable
    |> Variable.changeset(attrs)
    |> Repo.update()
  end

  def delete_variable(%Variable{} = variable), do: Repo.delete(variable)
end
