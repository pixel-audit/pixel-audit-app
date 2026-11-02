defmodule PixelAudit.Api.Funnels.StepParameter do
  @moduledoc """
  What one data source needs to count one step: the Meta event name, the
  GA4 event name, the SQL query. Keyed by the data source type's parameter
  declaration, with an optional description of how the step is counted and
  whether this is the step's primary source — the one its count is most
  reliably read from; at most one per step. A step with no row for a data
  source is not measured by it.
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
    field :description, :string
    field :primary, :boolean, default: false

    timestamps(type: :utc_datetime)
  end

  def changeset(step_parameter, %DataSource{type: type}, attrs) do
    sent = attrs["parameters"] || attrs[:parameters]
    specs = DataSourceType.for_type(type).parameter_schema()

    changeset =
      step_parameter
      |> cast(attrs, [:description, :primary])
      |> validate_length(:description, max: 2000)

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
    |> unique_constraint(:primary,
      name: :funnel_step_parameters_one_primary_per_step_index,
      message: "another data source is already primary for this step"
    )
  end
end
