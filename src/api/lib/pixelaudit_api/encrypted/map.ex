defmodule PixelAudit.Api.Encrypted.Map do
  @moduledoc """
  An Ecto type for a map stored encrypted as one blob: JSON-encoded, then
  through `PixelAudit.Api.Vault`. The database sees a `bytea` with the
  cipher tag, never a key or a value.
  """

  use Cloak.Ecto.Map, vault: PixelAudit.Api.Vault
end
