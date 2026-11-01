defmodule PixelAudit.Api.Funnels.Step do
  @moduledoc "One step of a funnel's user journey; steps are ordered by `position`."

  use Ecto.Schema

  import Ecto.Changeset

  alias PixelAudit.Api.Funnels.Funnel

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "funnel_steps" do
    belongs_to :funnel, Funnel
    field :name, :string
    field :description, :string
    field :position, :integer

    timestamps(type: :utc_datetime)
  end

  def changeset(step, attrs) do
    step
    |> cast(attrs, [:name, :description])
    |> validate_required([:name])
    |> validate_length(:name, max: 200)
    |> validate_length(:description, max: 2000)
  end
end
