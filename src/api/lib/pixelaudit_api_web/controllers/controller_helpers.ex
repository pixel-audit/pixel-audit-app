defmodule PixelAudit.ApiWeb.ControllerHelpers do
  @moduledoc "What every controller of the admin API shares."

  @doc """
  Runs a `get_*!` lookup as a `with` step: a row that is not there, or an
  id that is not even a UUID, is `{:error, :not_found}` for the fallback.
  """
  def fetch_resource(fun) do
    {:ok, fun.()}
  rescue
    Ecto.NoResultsError -> {:error, :not_found}
    Ecto.Query.CastError -> {:error, :not_found}
  end

  @doc "`limit`/`offset` query parameters, refused outside their range."
  def pagination(params, max_limit \\ 200) do
    with {:ok, limit} <- integer_param(params["limit"], 50, 1..max_limit),
         {:ok, offset} <- integer_param(params["offset"], 0, 0..1_000_000) do
      {:ok, limit: limit, offset: offset}
    end
  end

  defp integer_param(nil, default, _range), do: {:ok, default}

  defp integer_param(value, _default, range) when is_binary(value) do
    case Integer.parse(value) do
      {int, ""} -> if int in range, do: {:ok, int}, else: {:error, :invalid_pagination}
      _ -> {:error, :invalid_pagination}
    end
  end

  defp integer_param(_value, _default, _range), do: {:error, :invalid_pagination}

  @doc "A query parameter against an enum: the atom, `nil` when absent, or the error."
  def enum_param(nil, _values, _error), do: {:ok, nil}

  def enum_param(value, values, error) when is_binary(value) do
    case Enum.find(values, &(to_string(&1) == value)) do
      nil -> {:error, error}
      atom -> {:ok, atom}
    end
  end

  def enum_param(_value, _values, error), do: {:error, error}
end
