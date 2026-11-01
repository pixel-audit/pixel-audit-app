defmodule PixelAudit.Api.Vault do
  @moduledoc """
  The Cloak vault the connection credentials are encrypted with
  (`PixelAudit.Api.Encrypted.Map`, the `connections.credentials` column).

  One AES-GCM-256 cipher, tagged `AES.GCM.V1`, keyed from the
  `:credentials_encryption_key` config — 64 hex characters, fixed in dev
  and test, `CREDENTIALS_ENCRYPTION_KEY` in production (config/runtime.exs).
  The tag travels with every ciphertext, so rotating the key is: add a `V2`
  cipher as the default here, re-encrypt the table, then drop `V1`.
  """

  use Cloak.Vault, otp_app: :pixelaudit_api

  @impl GenServer
  def init(config) do
    key =
      :pixelaudit_api
      |> Application.fetch_env!(:credentials_encryption_key)
      |> Base.decode16!(case: :mixed)

    config =
      Keyword.put(config, :ciphers,
        default: {Cloak.Ciphers.AES.GCM, tag: "AES.GCM.V1", key: key, iv_length: 12}
      )

    {:ok, config}
  end
end
