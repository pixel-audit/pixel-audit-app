defmodule PixelAudit.Api.Connections.Connection do
  @moduledoc """
  A connection: credentials for one external system — a Meta pixel's Graph
  API access, a BigQuery project, a Postgres or ClickHouse database — under
  a short code the environment and the panel address it by.

  `credentials` is a map keyed by the connector's field keys
  (`PixelAudit.Api.Connections.Connector.credential_params/0`), stored
  encrypted (`PixelAudit.Api.Encrypted.Map`) and never rendered by the API.
  """

  use Ecto.Schema

  import Ecto.Changeset

  alias PixelAudit.Api.Connections.Connector

  @type type :: :meta | :bigquery | :postgres | :clickhouse
  @types [:meta, :bigquery, :postgres, :clickhouse]

  @code_format ~r/^[a-z0-9]+$/

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  @derive {Inspect, except: [:credentials]}
  schema "connections" do
    field :code, :string
    field :name, :string
    field :description, :string
    field :type, Ecto.Enum, values: @types
    field :credentials, PixelAudit.Api.Encrypted.Map, redact: true
    # Set by the `boot` role's env sync: type and credentials come from the
    # environment and the API refuses to change them.
    field :managed_by_env, :boolean, default: false
    field :last_checked_at, :utc_datetime
    field :last_check_status, Ecto.Enum, values: [:ok, :error]
    field :last_check_error, :string

    timestamps(type: :utc_datetime)
  end

  def types, do: @types
  def code_format, do: @code_format

  @doc "The changeset of a connection created or edited in the panel."
  def changeset(connection, attrs) do
    connection
    |> cast(attrs, [:code, :name, :description, :type])
    |> validate_required([:code, :name, :type])
    |> validate_format(:code, @code_format, message: "must be lowercase letters and digits only")
    |> validate_length(:code, max: 64)
    |> validate_length(:name, max: 200)
    |> validate_length(:description, max: 2000)
    |> unique_constraint(:code)
    |> put_credentials(attrs)
  end

  @doc "The changeset of a connection written from the environment."
  def env_changeset(connection, attrs) do
    connection
    |> cast(attrs, [:code, :name, :description, :type, :managed_by_env])
    |> validate_required([:code, :name, :type])
    |> validate_format(:code, @code_format)
    |> unique_constraint(:code)
    |> put_credentials(attrs)
  end

  @doc "The outcome of a connection check."
  def check_changeset(connection, result) do
    {status, error} =
      case result do
        :ok -> {:ok, nil}
        {:error, message} -> {:error, message}
      end

    change(connection,
      last_checked_at: DateTime.utc_now(:second),
      last_check_status: status,
      last_check_error: error
    )
  end

  # The credentials are validated against the connector of the (possibly
  # just changed) type. A `PUT` sends only the keys it changes: they are
  # merged over what is stored, and a `nil` clears one. Problems are keyed
  # `credentials.<key>` so the client sees which field, not just that the
  # map was refused.
  defp put_credentials(changeset, attrs) do
    sent = attrs["credentials"] || attrs[:credentials]
    type = get_field(changeset, :type)

    cond do
      is_nil(type) ->
        changeset

      is_nil(sent) and is_nil(changeset.data.credentials) ->
        validate_credentials(changeset, type, %{})

      is_nil(sent) ->
        if get_change(changeset, :type),
          do: validate_credentials(changeset, type, changeset.data.credentials || %{}),
          else: changeset

      not is_map(sent) ->
        add_error(changeset, :credentials, "must be an object")

      true ->
        merged =
          (changeset.data.credentials || %{})
          |> Map.merge(Map.new(sent, fn {k, v} -> {to_string(k), v} end))
          |> Map.reject(fn {_k, v} -> is_nil(v) end)

        validate_credentials(changeset, type, merged)
    end
  end

  defp validate_credentials(changeset, type, credentials) do
    connector = Connector.for_type(type)

    case PixelAudit.Api.FieldSpec.validate(connector.credential_params(), credentials) do
      {:ok, normalised} ->
        put_change(changeset, :credentials, normalised)

      {:error, errors} ->
        Enum.reduce(errors, changeset, fn {key, message}, changeset ->
          add_error(changeset, credential_error_key(connector, key), message)
        end)
    end
  end

  # The error keys are atoms, so only keys the connector declares — plus
  # the one for an unknown key — ever become one.
  defp credential_error_key(connector, key) do
    if key in Enum.map(connector.credential_params(), & &1.key),
      do: String.to_atom("credentials." <> key),
      else: :credentials
  end
end
