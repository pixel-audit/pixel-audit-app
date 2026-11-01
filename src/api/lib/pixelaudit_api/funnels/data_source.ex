defmodule PixelAudit.Api.Funnels.DataSource do
  @moduledoc """
  Where a funnel's step counts are read from: a data source type
  (`PixelAudit.Api.Funnels.DataSourceType`) on a connection of the matching
  connection type, with the type's own `settings` (a GA4 dataset, a Google
  Ads customer id) and, per step, the parameters in
  `PixelAudit.Api.Funnels.StepParameter`.
  """

  use Ecto.Schema

  import Ecto.Changeset

  alias PixelAudit.Api.Funnels.{DataSourceType, Funnel}

  # The colours a new data source is dealt from (the first unused in its
  # funnel, at random): distinct hues that stay apart when overlaid.
  @palette ~w(#2563eb #db2777 #16a34a #ea580c #7c3aed #0891b2 #ca8a04 #dc2626 #0d9488 #9333ea #65a30d #4f46e5)
  @color_format ~r/^#[0-9a-f]{6}$/

  @types [
    :meta_pixel_api,
    :google_analytics_bigquery,
    :google_ads_bigquery,
    :postgres_query,
    :clickhouse_query
  ]

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "funnel_data_sources" do
    belongs_to :funnel, Funnel
    belongs_to :connection, PixelAudit.Api.Settings.Connection
    field :code, :string
    field :name, :string
    field :description, :string
    field :type, Ecto.Enum, values: @types
    field :settings, :map, default: %{}
    field :position, :integer
    # The data source's colour in the report (#rrggbb, lowercase).
    field :color, :string

    has_many :step_parameters, PixelAudit.Api.Funnels.StepParameter

    timestamps(type: :utc_datetime)
  end

  def types, do: @types
  def palette, do: @palette

  @doc "A colour of the palette not yet used in the funnel — any of them when all are."
  def random_color(used_colors) do
    free = @palette -- used_colors
    Enum.random(if free == [], do: @palette, else: free)
  end

  def changeset(data_source, attrs) do
    data_source
    |> cast(attrs, [:code, :name, :description, :type, :connection_id, :color])
    |> update_change(:color, &String.downcase/1)
    |> validate_required([:code, :name, :type, :connection_id, :color])
    |> validate_format(:color, @color_format, message: "must be a colour like #1a2b3c")
    |> validate_format(:code, Funnel.code_format(),
      message: "must be lowercase letters and digits only"
    )
    |> validate_length(:code, max: 64)
    |> validate_length(:name, max: 200)
    |> validate_length(:description, max: 2000)
    |> unique_constraint(:code, name: :funnel_data_sources_funnel_id_code_index)
    |> foreign_key_constraint(:connection_id)
    |> put_settings(attrs)
  end

  # Settings are validated against the type's declaration; a `PUT` without
  # `settings` keeps them unless the type changed.
  defp put_settings(changeset, attrs) do
    sent = attrs["settings"] || attrs[:settings]
    type = get_field(changeset, :type)

    cond do
      is_nil(type) ->
        changeset

      is_nil(sent) and is_nil(get_change(changeset, :type)) and changeset.data.id != nil ->
        changeset

      not is_nil(sent) and not is_map(sent) ->
        add_error(changeset, :settings, "must be an object")

      true ->
        specs = DataSourceType.for_type(type).settings_schema()
        sent = Map.new(sent || changeset.data.settings || %{}, fn {k, v} -> {to_string(k), v} end)

        case PixelAudit.Api.FieldSpec.validate(specs, sent) do
          {:ok, normalised} ->
            put_change(changeset, :settings, normalised)

          {:error, errors} ->
            known = Enum.map(specs, & &1.key)

            Enum.reduce(errors, changeset, fn {key, message}, changeset ->
              field = if key in known, do: String.to_atom("settings." <> key), else: :settings
              add_error(changeset, field, message)
            end)
        end
    end
  end
end
