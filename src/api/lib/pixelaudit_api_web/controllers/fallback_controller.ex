defmodule PixelAudit.ApiWeb.FallbackController do
  @moduledoc """
  Translates controller action results into valid `Plug.Conn` responses.

  Domain functions return `{:error, reason}` where reason is an atom naming
  what went wrong. Mapping those to a status happens **here, once**, rather
  than in each controller, because the mapping is a property of the reason
  and not of the endpoint. The atom travels to the client as
  `errors.detail`, the same shape as the framework's own errors and
  deliberately machine-readable.
  """

  use PixelAudit.ApiWeb, :controller

  # 409 — the request was well formed, but the world is in a state that
  # refuses it. Retrying unchanged will not help; something has to give first.
  @conflicts [
    # A data source still reads through the connection; move it first.
    :connection_in_use,
    # The environment sets the connection's type and credentials; the stored
    # values would be overwritten on the next boot, so refusing the write is
    # kinder than accepting a value that would not last.
    :managed_by_env
  ]

  # 422 — the request cannot be satisfied as asked, and the caller can act
  # on it: pick a connection of the right type, send a valid date.
  @unprocessable [
    # The data source type reads through a different kind of connection.
    :connection_type_mismatch,
    # Only a Meta connection has pixel stats to refresh.
    :not_a_meta_connection,
    # `step_ids` / `data_source_ids` did not name every step / data source
    # of the funnel exactly once.
    :invalid_order,
    :missing_date,
    :invalid_date,
    :invalid_date_range,
    :range_too_large,
    # `limit`/`offset` outside their documented range, or not integers.
    :invalid_pagination,
    # A list filter named a value its enum does not hold.
    :invalid_status,
    :invalid_kind
  ]

  def call(conn, {:error, %Ecto.Changeset{} = changeset}) do
    conn
    |> put_status(:unprocessable_entity)
    |> put_view(json: PixelAudit.ApiWeb.ChangesetJSON)
    |> render(:error, changeset: changeset)
  end

  def call(conn, {:error, :not_found}), do: detail(conn, :not_found, :not_found)

  def call(conn, {:error, reason}) when reason in @conflicts, do: detail(conn, :conflict, reason)

  def call(conn, {:error, reason}) when reason in @unprocessable,
    do: detail(conn, :unprocessable_entity, reason)

  defp detail(conn, status, reason) do
    conn
    |> put_status(status)
    |> json(%{errors: %{detail: to_string(reason)}})
  end
end
