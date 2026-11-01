defmodule PixelAudit.ApiWeb.OpenApi.Schemas.Connection do
  @moduledoc false
  require OpenApiSpex
  alias OpenApiSpex.Schema

  OpenApiSpex.schema(%{
    title: "Connection",
    description:
      "A connection to an external system. Credentials are never returned whole: " <>
        "`credential_keys` says which are set, `credentials_preview` carries the non-secret " <>
        "ones, a URL among them with its password hidden.",
    type: :object,
    properties: %{
      id: %Schema{type: :string, format: :uuid},
      name: %Schema{type: :string},
      description: %Schema{type: :string, nullable: true},
      type: %Schema{type: :string, enum: ["meta", "bigquery", "postgres", "clickhouse"]},
      managed_by_env: %Schema{
        type: :boolean,
        description:
          "Set by the boot role from CONNECTION_* variables; type and credentials are read-only."
      },
      credential_keys: %Schema{type: :array, items: %Schema{type: :string}},
      credentials_preview: %Schema{
        type: :object,
        additionalProperties: %Schema{type: :string},
        description: "The non-secret credential values; a URL with its password hidden."
      },
      last_checked_at: %Schema{type: :string, format: :"date-time", nullable: true},
      last_check_status: %Schema{type: :string, enum: ["ok", "error"], nullable: true},
      last_check_error: %Schema{type: :string, nullable: true},
      inserted_at: %Schema{type: :string, format: :"date-time"},
      updated_at: %Schema{type: :string, format: :"date-time"}
    },
    required: [
      :id,
      :name,
      :description,
      :type,
      :managed_by_env,
      :credential_keys,
      :credentials_preview,
      :last_checked_at,
      :last_check_status,
      :last_check_error,
      :inserted_at,
      :updated_at
    ]
  })
end
