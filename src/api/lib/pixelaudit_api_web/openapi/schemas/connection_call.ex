defmodule PixelAudit.ApiWeb.OpenApi.Schemas.ConnectionCall do
  @moduledoc false
  require OpenApiSpex
  alias OpenApiSpex.Schema
  alias PixelAudit.ApiWeb.OpenApi.Schemas

  OpenApiSpex.schema(%{
    title: "ConnectionCall",
    description:
      "One call made through a connection, as the gateway recorded it, whole: a `query` " <>
        "carries `sql`, `params` and `result`; an `api_call` the method, URL, content types " <>
        "and bodies. With its provenance: why it was made (`purpose`, and the refresh run, " <>
        "data source, step and `date` it served, when it served one) and what cites it.",
    type: :object,
    properties: %{
      id: %Schema{type: :string, format: :uuid, description: "A UUIDv7: time-ordered."},
      connection_id: %Schema{type: :string, format: :uuid},
      connection: %Schema{allOf: [Schemas.ConnectionRef], nullable: true},
      kind: %Schema{type: :string, enum: ["query", "api_call"]},
      status: %Schema{type: :string, enum: ["ok", "error"]},
      started_at: %Schema{type: :string, format: :"date-time"},
      duration_ms: %Schema{type: :integer},
      error: %Schema{type: :string, nullable: true},
      purpose: %Schema{
        type: :string,
        enum: ["count", "meta_stats_pull", "check"],
        nullable: true,
        description: "Null for a call recorded before purposes were kept."
      },
      date: %Schema{
        type: :string,
        format: :date,
        nullable: true,
        description: "The day the call counted, for a `count`."
      },
      refresh_run_id: %Schema{type: :string, format: :uuid, nullable: true},
      data_source: %Schema{allOf: [Schemas.EntityRef], nullable: true},
      step: %Schema{allOf: [Schemas.EntityRef], nullable: true},
      cited_by: Schemas.CallCitedBy,
      sql: %Schema{type: :string, nullable: true},
      params: %Schema{nullable: true, description: "The parameters as sent, as JSON."},
      result: %Schema{
        type: :array,
        items: %Schema{type: :array, items: %Schema{nullable: true}},
        nullable: true,
        description: "The rows answered, every one."
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
      :connection,
      :purpose,
      :date,
      :refresh_run_id,
      :data_source,
      :step,
      :cited_by,
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
