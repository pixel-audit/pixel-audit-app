defmodule PixelAudit.ApiWeb.Cors do
  @moduledoc """
  CORS for the admin panel. Corsica with the origins read at request time,
  so a CORS_ORIGINS change needs no recompilation.
  """

  @behaviour Plug

  @impl true
  def init(opts), do: opts

  @impl true
  def call(conn, _opts) do
    origins = Application.get_env(:pixelaudit_api, :cors_origins, [])

    Corsica.call(
      conn,
      Corsica.init(
        origins: origins,
        allow_headers: :all,
        allow_methods: :all,
        max_age: 600
      )
    )
  end
end
