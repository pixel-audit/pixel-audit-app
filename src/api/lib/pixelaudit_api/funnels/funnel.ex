defmodule PixelAudit.Api.Funnels.Funnel do
  @moduledoc """
  A funnel: a user journey as an ordered list of steps, measured by one or
  more data sources so their counts can be compared.
  """

  use Ecto.Schema

  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "funnels" do
    field :name, :string
    field :description, :string

    has_many :steps, PixelAudit.Api.Funnels.Step, preload_order: [asc: :position]
    has_many :data_sources, PixelAudit.Api.Funnels.DataSource, preload_order: [asc: :position]

    timestamps(type: :utc_datetime)
  end

  def changeset(funnel, attrs) do
    funnel
    |> cast(attrs, [:name, :description])
    |> validate_required([:name])
    |> validate_length(:name, max: 200)
    |> validate_length(:description, max: 2000)
  end
end
