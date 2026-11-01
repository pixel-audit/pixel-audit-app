defmodule PixelAudit.Api.FieldSpec do
  @moduledoc """
  A declared set of string-valued fields: what a connection type needs as
  credentials, what a data source type takes as settings, and what it takes
  per funnel step as parameters.

  The same declaration drives three things: the validation of what the API
  receives, the mapping of `CONNECTION_<id>_<KEY>` environment variables
  (`PixelAudit.Api.Connections.EnvSync`), and the form the panel renders
  (the specs are part of the OpenAPI document, see
  `PixelAudit.ApiWeb.OpenApi.Schemas.FieldSpec`).
  """

  @type kind :: :string | :text | :secret | :url | :select | :sql

  @type t :: %{
          key: String.t(),
          label: String.t(),
          kind: kind(),
          required: boolean(),
          default: String.t() | nil,
          options: [String.t()] | nil,
          description: String.t() | nil
        }

  @doc "Declares a field. `kind` defaults to `:string`, `required` to `false`."
  @spec field(String.t(), keyword()) :: t()
  def field(key, opts) do
    %{
      key: key,
      label: Keyword.fetch!(opts, :label),
      kind: Keyword.get(opts, :kind, :string),
      required: Keyword.get(opts, :required, false),
      default: Keyword.get(opts, :default),
      options: Keyword.get(opts, :options),
      description: Keyword.get(opts, :description)
    }
  end

  @doc """
  Checks `params` (a map with string keys) against `specs`.

  Answers the normalised map — unknown keys refused, blanks of optional
  fields dropped, defaults filled in — or the problems keyed by field.
  """
  @spec validate([t()], map()) :: {:ok, map()} | {:error, %{String.t() => String.t()}}
  def validate(specs, params) when is_map(params) do
    known = MapSet.new(specs, & &1.key)

    unknown =
      params
      |> Map.keys()
      |> Enum.reject(&(is_binary(&1) and MapSet.member?(known, &1)))
      |> Map.new(fn key -> {to_string(key), "is not a known field"} end)

    {values, errors} =
      Enum.reduce(specs, {%{}, unknown}, fn spec, {values, errors} ->
        case Map.get(params, spec.key) do
          nil -> missing(spec, values, errors)
          value when is_binary(value) -> present(spec, String.trim(value), values, errors)
          _other -> {values, Map.put(errors, spec.key, "must be a string")}
        end
      end)

    if errors == %{}, do: {:ok, values}, else: {:error, errors}
  end

  def validate(_specs, _params), do: {:error, %{"_" => "must be an object"}}

  defp missing(%{required: true} = spec, values, errors),
    do: {values, Map.put(errors, spec.key, "can't be blank")}

  defp missing(%{default: nil}, values, errors), do: {values, errors}
  defp missing(spec, values, errors), do: {Map.put(values, spec.key, spec.default), errors}

  defp present(spec, "", values, errors), do: missing(spec, values, errors)

  defp present(%{kind: :select, options: options} = spec, value, values, errors) do
    if value in options,
      do: {Map.put(values, spec.key, value), errors},
      else: {values, Map.put(errors, spec.key, "is invalid")}
  end

  defp present(spec, value, values, errors), do: {Map.put(values, spec.key, value), errors}

  @doc "The spec as the API presents it."
  @spec to_api(t()) :: map()
  def to_api(spec) do
    %{
      key: spec.key,
      label: spec.label,
      kind: spec.kind,
      required: spec.required,
      default: spec.default,
      options: spec.options,
      description: spec.description
    }
  end

  @doc """
  The values as the API shows them: a `:secret` is left out, a `:url` is
  shown with its password hidden (`postgres://user:***@host/db`), the
  rest as stored.
  """
  @spec preview([t()], map()) :: map()
  def preview(specs, values) do
    kinds = Map.new(specs, &{&1.key, &1.kind})

    for {key, value} <- values, kinds[key] != :secret, into: %{} do
      if kinds[key] == :url, do: {key, redact_url(value)}, else: {key, value}
    end
  end

  @doc "A URL with its password, when it has one, replaced by `***`."
  @spec redact_url(String.t()) :: String.t()
  def redact_url(url) when is_binary(url) do
    case URI.parse(url) do
      %URI{userinfo: info} = uri when is_binary(info) ->
        case String.split(info, ":", parts: 2) do
          [user, _password] -> URI.to_string(%{uri | userinfo: user <> ":***"})
          [_user] -> url
        end

      _ ->
        url
    end
  end
end
