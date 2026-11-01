defmodule PixelAudit.Api.Funnels.StepParameter do
  @moduledoc """
  What one data source needs to count one step: the Meta event name, the
  GA4 event name, the SQL query. Keyed by the data source type's parameter
  declaration. A step with no row for a data source is not measured by it.
  """

  use Ecto.Schema

  import Ecto.Changeset

  alias PixelAudit.Api.Funnels.{DataSource, DataSourceType, Step}

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "funnel_step_parameters" do
    belongs_to :data_source, DataSource
    belongs_to :step, Step
    field :parameters, :map, default: %{}

    timestamps(type: :utc_datetime)
  end

  def changeset(step_parameter, %DataSource{type: type}, attrs) do
    sent = attrs["parameters"] || attrs[:parameters]
    specs = DataSourceType.for_type(type).parameter_schema()

    changeset = change(step_parameter)

    cond do
      not is_map(sent) ->
        add_error(changeset, :parameters, "must be an object")

      true ->
        sent = Map.new(sent, fn {k, v} -> {to_string(k), v} end)

        case PixelAudit.Api.FieldSpec.validate(specs, sent) do
          {:ok, normalised} ->
            put_change(changeset, :parameters, normalised)

          {:error, errors} ->
            known = Enum.map(specs, & &1.key)

            Enum.reduce(errors, changeset, fn {key, message}, changeset ->
              field = if key in known, do: String.to_atom("parameters." <> key), else: :parameters
              add_error(changeset, field, message)
            end)
        end
    end
    |> unique_constraint([:data_source_id, :step_id],
      name: :funnel_step_parameters_data_source_id_step_id_index
    )
  end
end
