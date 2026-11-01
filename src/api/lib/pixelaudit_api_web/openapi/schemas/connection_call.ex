defmodule PixelAudit.ApiWeb.OpenApi.Schemas.ConnectionCall do
  @moduledoc false
  require OpenApiSpex
  alias OpenApiSpex.Schema

  OpenApiSpex.schema(%{
    title: "ConnectionCall",
    description:
      "One call made through a connection, as the gateway recorded it: a `query` carries " <>
        "`sql`, `params` and `result`; an `api_call` the method, URL, content types and bodies. " <>
        "Bodies and results are cut at 64 KiB.",
    type: :object,
    properties: %{
      id: %Schema{type: :string, format: :uuid, description: "A UUIDv7: time-ordered."},
      connection_id: %Schema{type: :string, format: :uuid},
      kind: %Schema{type: :string, enum: ["query", "api_call"]},
      status: %Schema{type: :string, enum: ["ok", "error"]},
      started_at: %Schema{type: :string, format: :"date-time"},
      duration_ms: %Schema{type: :integer},
      error: %Schema{type: :string, nullable: true},
      sql: %Schema{type: :string, nullable: true},
      params: %Schema{nullable: true, description: "The parameters as sent, as JSON."},
      result: %Schema{
        type: :array,
        items: %Schema{type: :array, items: %Schema{nullable: true}},
        nullable: true,
        description: "The rows answered (the first 50)."
      },
      method: %Schema{type: :string, nullable: true},
      url: %Schema{type: :string, nullable: true},
      request_content_type: %Schema{type: :string, nullable: true},
      request_body: %Schema{type: :string, nullable: true},
      response_status: %Schema{type: :integer, nullable: true},
      response_content_type: %Schema{type: :string, nullable: true},
      response_body: %Schema{type: :string, nullable: true}
    },
    required: [
      :id,
      :connection_id,
      :kind,
      :status,
      :started_at,
      :duration_ms,
      :error,
      :sql,
      :params,
      :result,
      :method,
      :url,
      :request_content_type,
      :request_body,
      :response_status,
      :response_content_type,
      :response_body
    ]
  })
end
