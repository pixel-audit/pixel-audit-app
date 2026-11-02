defmodule PixelAudit.Api.Settings do
  @moduledoc """
  The settings: the connections — credentials for the external systems the
  funnels' data sources read from, and the cached Meta pixel stats that
  hang off a Meta connection — and the variables, a key/value store.
  """

  import Ecto.Query, warn: false

  require Logger

  alias PixelAudit.Api.Reporting.Citation
  alias PixelAudit.Api.Repo

  alias PixelAudit.Api.Settings.{
    Connection,
    ConnectionCall,
    Connector,
    Gateway,
    MetaPixelStat,
    Variable
  }

  ## Connections

  @doc "Every connection, by name."
  def list_connections do
    Repo.all(from c in Connection, order_by: c.name)
  end

  @doc "Connections of one type, by name."
  def list_connections(type: type) do
    Repo.all(from c in Connection, where: c.type == ^type, order_by: c.name)
  end

  def get_connection!(id), do: Repo.get!(Connection, id)

  def get_connection_by_name(name), do: Repo.get_by(Connection, name: name)

  @doc "Creates a connection from the panel's attributes (`credentials` included)."
  def create_connection(attrs) do
    %Connection{}
    |> Connection.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a connection. One the environment manages keeps its name (the
  environment addresses it by it), type and credentials: a request that
  touches them is refused with `{:error, :managed_by_env}`; its description
  stays editable.
  """
  def update_connection(%Connection{managed_by_env: true} = connection, attrs) do
    if touches_managed_fields?(attrs) do
      {:error, :managed_by_env}
    else
      connection
      |> Connection.changeset(Map.take(attrs, ["description", :description]))
      |> Repo.update()
    end
  end

  def update_connection(%Connection{} = connection, attrs) do
    connection
    |> Connection.changeset(attrs)
    |> Repo.update()
  end

  defp touches_managed_fields?(attrs) do
    Enum.any?(["name", "type", "credentials"], fn key ->
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
    {result, _calls} =
      Gateway.capture(%{purpose: :check}, fn ->
        try do
          Connector.for_type(connection.type).check(connection)
        rescue
          exception -> {:error, Connector.describe_error(exception)}
        end
      end)

    {:ok, connection} =
      connection
      |> Connection.check_changeset(result)
      |> Repo.update()

    case result do
      :ok ->
        Logger.info("connections.check ok name=#{connection.name}")

      {:error, message} ->
        Logger.warning(
          "connections.check failed name=#{connection.name} error=#{inspect(message)}"
        )
    end

    {result, connection}
  end

  @doc "Every connection whose credentials fill in a Meta-type data source."
  def list_meta_connections, do: list_connections(type: :meta)

  ## Meta pixel stats

  @doc """
  Stores the hourly rows `PixelAudit.Api.Settings.Connector.Meta.fetch_stats/3`
  answered, replacing what was stored for the same hour and event, and
  makes each hour cite the call that delivered it (`row.call_id`, when
  there is one) in place of what it cited before.
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

    call_of = Map.new(rows, &{{&1.date, &1.hour, &1.event_name}, Map.get(&1, :call_id)})

    Repo.transaction(fn ->
      entries
      |> Enum.chunk_every(1000)
      |> Enum.reduce(0, fn chunk, total ->
        {count, stored} =
          Repo.insert_all(MetaPixelStat, chunk,
            on_conflict: {:replace, [:count, :inserted_at]},
            conflict_target: [:connection_id, :date, :hour, :event_name],
            returning: [:id, :date, :hour, :event_name]
          )

        cite_meta_pixel_stats(stored, call_of, now)
        total + count
      end)
    end)
    |> then(fn {:ok, total} -> total end)
  end

  defp cite_meta_pixel_stats(stored, call_of, now) do
    ids = Enum.map(stored, & &1.id)
    Repo.delete_all(from c in Citation, where: c.meta_pixel_stat_id in ^ids)

    citations =
      for stat <- stored,
          call_id = call_of[{stat.date, stat.hour, stat.event_name}],
          call_id != nil,
          do: %{meta_pixel_stat_id: stat.id, call_id: call_id, inserted_at: now}

    if citations != [], do: Repo.insert_all(Citation, citations)
    :ok
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
      hours =
        from s in MetaPixelStat,
          where:
            s.connection_id == ^connection_id and s.date == ^date and
              s.event_name == ^event_name

      sum = Repo.one(from s in hours, select: type(sum(s.count), :integer))

      # The day rests on the pages that delivered its hours.
      Gateway.cite(
        Repo.all(
          from c in Citation,
            join: s in subquery(hours),
            on: c.meta_pixel_stat_id == s.id,
            order_by: c.call_id,
            distinct: true,
            select: c.call_id
        )
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

  ## Connection calls

  @doc """
  The calls made through a connection, newest first, with their total:
  `filters` may hold `date_from` and `date_to` (UTC days the call was
  made on, inclusive), `purpose`, `data_source_id`, `step_id` and `date`
  (the day the call counted); `opts` `limit` and `offset`.
  """
  def list_connection_calls(%Connection{id: connection_id}, filters \\ %{}, opts \\ []) do
    limit = Keyword.get(opts, :limit, 50)
    offset = Keyword.get(opts, :offset, 0)

    query =
      Enum.reduce(filters, from(c in ConnectionCall, where: c.connection_id == ^connection_id), fn
        {:date_from, %Date{} = date}, q ->
          where(q, [c], c.started_at >= ^DateTime.new!(date, ~T[00:00:00], "Etc/UTC"))

        {:date_to, %Date{} = date}, q ->
          where(q, [c], c.started_at < ^DateTime.new!(Date.add(date, 1), ~T[00:00:00], "Etc/UTC"))

        {:purpose, purpose}, q when not is_nil(purpose) ->
          where(q, [c], c.purpose == ^purpose)

        {:data_source_id, id}, q when is_binary(id) ->
          where(q, [c], c.data_source_id == ^id)

        {:step_id, id}, q when is_binary(id) ->
          where(q, [c], c.step_id == ^id)

        {:date, %Date{} = date}, q ->
          where(q, [c], c.date == ^date)

        _other, q ->
          q
      end)

    total = Repo.aggregate(query, :count)

    calls =
      query
      |> order_by([c], desc: c.started_at, desc: c.id)
      |> limit(^limit)
      |> offset(^offset)
      |> preload(^call_preloads())
      |> Repo.all()

    %{calls: calls, total: total}
  end

  @doc "One call made through the connection, with its context and what cites it."
  def get_connection_call!(%Connection{id: connection_id}, id) do
    Repo.one!(
      from c in ConnectionCall,
        where: c.connection_id == ^connection_id and c.id == ^id,
        preload: ^call_preloads()
    )
  end

  @doc "What a call carries for the panel: its context, and the values that cite it."
  def call_preloads,
    do: [
      :connection,
      :refresh_run,
      :data_source,
      :step,
      citations: [daily_count: [:step, :data_source], meta_pixel_stat: []]
    ]

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
