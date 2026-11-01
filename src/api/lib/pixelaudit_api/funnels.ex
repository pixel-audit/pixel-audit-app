defmodule PixelAudit.Api.Funnels do
  @moduledoc """
  The funnels: their ordered steps, the data sources that measure them,
  and the parameters each data source takes per step.

  Changing what a data source measures enqueues a recomputation of its
  recent days (`PixelAudit.Api.Reporting.refresh_data_source/4`), so the
  report shows the new definition without waiting for the night.
  """

  import Ecto.Query, warn: false

  alias PixelAudit.Api.Settings.Connection
  alias PixelAudit.Api.Funnels.{DataSource, DataSourceType, Funnel, Step, StepParameter}
  alias PixelAudit.Api.Repo

  ## Funnels

  @doc "Every funnel, by name, with its steps and data sources."
  def list_funnels do
    Repo.all(
      from f in Funnel,
        order_by: f.name,
        preload: [:steps, data_sources: [:connection, :step_parameters]]
    )
  end

  @doc """
  A funnel by id, with its steps, data sources (and their connections) and
  parameters.
  """
  def get_funnel!(id) do
    Funnel
    |> Repo.get!(id)
    |> Repo.preload(
      steps: [],
      data_sources: [:connection, :step_parameters]
    )
  end

  def create_funnel(attrs) do
    %Funnel{}
    |> Funnel.changeset(attrs)
    |> Repo.insert()
  end

  def update_funnel(%Funnel{} = funnel, attrs) do
    funnel
    |> Funnel.changeset(attrs)
    |> Repo.update()
  end

  def delete_funnel(%Funnel{} = funnel), do: Repo.delete(funnel)

  ## Steps

  def get_step!(%Funnel{id: funnel_id}, id) do
    Repo.one!(from s in Step, where: s.funnel_id == ^funnel_id and s.id == ^id)
  end

  @doc "Adds a step at the end of the funnel."
  def create_step(%Funnel{id: funnel_id}, attrs) do
    position =
      Repo.one(from s in Step, where: s.funnel_id == ^funnel_id, select: max(s.position)) || -1

    %Step{funnel_id: funnel_id, position: position + 1}
    |> Step.changeset(attrs)
    |> Repo.insert()
  end

  def update_step(%Step{} = step, attrs) do
    step
    |> Step.changeset(attrs)
    |> Repo.update()
  end

  def delete_step(%Step{} = step) do
    Repo.transaction(fn ->
      {:ok, step} = Repo.delete(step)
      compact_positions(step.funnel_id)
      step
    end)
  end

  @doc """
  Puts the steps in the given order. `step_ids` must name every step of the
  funnel exactly once, otherwise `{:error, :invalid_order}`.
  """
  def reorder_steps(%Funnel{id: funnel_id}, step_ids) when is_list(step_ids) do
    current = Repo.all(from s in Step, where: s.funnel_id == ^funnel_id, select: s.id)

    if Enum.sort(current) == Enum.sort(step_ids) and
         length(step_ids) == length(Enum.uniq(step_ids)) do
      Repo.transaction(fn ->
        step_ids
        |> Enum.with_index()
        |> Enum.each(fn {id, position} ->
          Repo.update_all(from(s in Step, where: s.id == ^id), set: [position: position])
        end)

        Repo.all(from s in Step, where: s.funnel_id == ^funnel_id, order_by: s.position)
      end)
    else
      {:error, :invalid_order}
    end
  end

  def reorder_steps(_funnel, _other), do: {:error, :invalid_order}

  defp compact_positions(funnel_id) do
    Repo.all(from s in Step, where: s.funnel_id == ^funnel_id, order_by: s.position, select: s.id)
    |> Enum.with_index()
    |> Enum.each(fn {id, position} ->
      Repo.update_all(from(s in Step, where: s.id == ^id), set: [position: position])
    end)
  end

  ## Data sources

  def get_data_source!(%Funnel{id: funnel_id}, id) do
    Repo.one!(
      from d in DataSource,
        where: d.funnel_id == ^funnel_id and d.id == ^id,
        preload: [:connection, :step_parameters]
    )
  end

  @doc "A data source with everything a refresh needs: connection, funnel steps, parameters."
  def get_data_source_for_refresh!(id) do
    DataSource
    |> Repo.get!(id)
    |> Repo.preload([:connection, :step_parameters, funnel: [:steps]])
  end

  @doc """
  Adds a data source. The connection must be of the type's connection type
  (`{:error, :connection_type_mismatch}`).
  """
  def create_data_source(%Funnel{id: funnel_id}, attrs) do
    position =
      Repo.one(from d in DataSource, where: d.funnel_id == ^funnel_id, select: max(d.position)) ||
        -1

    # Dealt a colour of its own unless one was sent.
    used = Repo.all(from d in DataSource, where: d.funnel_id == ^funnel_id, select: d.color)
    color = DataSource.random_color(used)

    changeset =
      DataSource.changeset(
        %DataSource{funnel_id: funnel_id, position: position + 1, color: color},
        attrs
      )

    with :ok <- check_connection_type(changeset),
         {:ok, data_source} <- Repo.insert(changeset) do
      {:ok, Repo.preload(data_source, [:connection, :step_parameters])}
    end
  end

  def update_data_source(%DataSource{} = data_source, attrs) do
    changeset = DataSource.changeset(data_source, attrs)

    with :ok <- check_connection_type(changeset),
         {:ok, data_source} <- Repo.update(changeset) do
      {:ok, Repo.preload(data_source, [:connection, :step_parameters], force: true)}
    end
  end

  def delete_data_source(%DataSource{} = data_source), do: Repo.delete(data_source)

  defp check_connection_type(changeset) do
    type = Ecto.Changeset.get_field(changeset, :type)
    connection_id = Ecto.Changeset.get_field(changeset, :connection_id)

    cond do
      not changeset.valid? ->
        {:error, changeset}

      is_nil(type) or is_nil(connection_id) ->
        :ok

      true ->
        case Repo.get(Connection, connection_id) do
          nil ->
            {:error, Ecto.Changeset.add_error(changeset, :connection_id, "does not exist")}

          %Connection{type: connection_type} ->
            if DataSourceType.for_type(type).connection_type() == connection_type,
              do: :ok,
              else: {:error, :connection_type_mismatch}
        end
    end
  end

  ## Step parameters

  @doc "Sets what `data_source` needs to count `step`, replacing the previous parameters."
  def put_step_parameters(%DataSource{} = data_source, %Step{} = step, attrs) do
    existing =
      Repo.get_by(StepParameter, data_source_id: data_source.id, step_id: step.id) ||
        %StepParameter{data_source_id: data_source.id, step_id: step.id}

    existing
    |> StepParameter.changeset(data_source, attrs)
    |> Repo.insert_or_update()
  end

  @doc "Stops `data_source` measuring `step`; its cached counts for the step go too."
  def delete_step_parameters(%DataSource{} = data_source, %Step{} = step) do
    Repo.transaction(fn ->
      Repo.delete_all(
        from p in StepParameter,
          where: p.data_source_id == ^data_source.id and p.step_id == ^step.id
      )

      Repo.delete_all(
        from c in PixelAudit.Api.Reporting.DailyCount,
          where: c.data_source_id == ^data_source.id and c.step_id == ^step.id
      )

      :ok
    end)
  end

  ## Types

  @doc "The data source types as the API presents them."
  def data_source_types do
    for module <- DataSourceType.all() do
      %{
        type: module.type(),
        label: module.label(),
        description: module.description(),
        connection_type: module.connection_type(),
        settings: Enum.map(module.settings_schema(), &PixelAudit.Api.FieldSpec.to_api/1),
        parameters: Enum.map(module.parameter_schema(), &PixelAudit.Api.FieldSpec.to_api/1)
      }
    end
  end
end
