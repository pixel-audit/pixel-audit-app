defmodule PixelAudit.Api.Repo.Migrations.RenameMetaApiConnectionType do
  use Ecto.Migration

  # The Meta connection type is `meta`, no longer `meta_api`.
  def up, do: execute("UPDATE connections SET type = 'meta' WHERE type = 'meta_api'")
  def down, do: execute("UPDATE connections SET type = 'meta_api' WHERE type = 'meta'")
end
