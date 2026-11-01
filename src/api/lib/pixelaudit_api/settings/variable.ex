defmodule PixelAudit.Api.Settings.Variable do
  @moduledoc """
  A variable: one string value under a key, with an optional description.
  Defined in the panel, or by the environment (`VARIABLE_<key>_VALUE`,
  `VARIABLE_<key>_DESCRIPTION`) through `PixelAudit.Api.Settings.EnvSync`.
  """

  use Ecto.Schema

  import Ecto.Changeset

  @key_format ~r/^[a-zA-Z0-9]+$/

  @primary_key {:id, :binary_id, autogenerate: true}
  schema "settings_variables" do
    field :key, :string
    field :value, :string
    field :description, :string
    # Set by the `boot` role's env sync: the key and value come from the
    # environment and the API refuses to change them.
    field :managed_by_env, :boolean, default: false

    timestamps(type: :utc_datetime)
  end

  def key_format, do: @key_format

  @doc "The changeset of a variable created or edited in the panel."
  def changeset(variable, attrs) do
    variable
    |> cast(attrs, [:key, :value, :description], empty_values: [])
    |> validate_required([:key])
    |> validate_format(:key, @key_format, message: "must be letters and digits only")
    |> validate_length(:key, max: 64)
    |> validate_value()
    |> validate_length(:description, max: 2000)
    |> unique_constraint(:key)
  end

  @doc "The changeset of a variable written from the environment."
  def env_changeset(variable, attrs) do
    variable
    |> cast(attrs, [:key, :value, :description, :managed_by_env], empty_values: [])
    |> validate_required([:key])
    |> validate_format(:key, @key_format)
    |> validate_value()
    |> unique_constraint(:key)
  end

  # The value is any string, the empty one included — `validate_required/2`
  # would refuse that one — but it has to be there.
  defp validate_value(changeset) do
    case get_field(changeset, :value) do
      nil -> add_error(changeset, :value, "can't be blank")
      _value -> validate_length(changeset, :value, max: 100_000)
    end
  end
end
