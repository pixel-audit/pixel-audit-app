defmodule PixelAudit.Api.JSON do
  @moduledoc """
  An Ecto type for any JSON value in a `jsonb` column — a list as readily
  as a map, which Ecto's own `:map` refuses. What goes in has to be
  JSON-encodable already; the gateway normalises before storing.
  """

  use Ecto.Type

  @impl true
  def type, do: :map

  @impl true
  def cast(value), do: {:ok, value}

  @impl true
  def dump(value), do: {:ok, value}

  @impl true
  def load(value), do: {:ok, value}
end
