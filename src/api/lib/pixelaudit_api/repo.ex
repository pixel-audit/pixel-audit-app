defmodule PixelAudit.Api.Repo do
  use Ecto.Repo,
    otp_app: :pixelaudit_api,
    adapter: Ecto.Adapters.Postgres
end
