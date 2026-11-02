defmodule PixelAudit.ApiWeb.OpenApi.Schemas.RefreshRun do
  @moduledoc false
  require OpenApiSpex
  alias OpenApiSpex.Schema
  alias PixelAudit.ApiWeb.OpenApi.Schemas

  OpenApiSpex.schema(%{
    title: "RefreshRun",
    description:
      "One refresh: a pull of a Meta connection's pixel stats (`meta_pixel`) or a " <>
        "recomputation of a data source's daily counts (`data_source`) over a date range.",
    type: :object,
    properties: %{
      id: %Schema{type: :string, format: :uuid},
      kind: %Schema{type: :string, enum: ["meta_pixel", "data_source"]},
      connection: %Schema{allOf: [Schemas.EntityRef], nullable: true},
      funnel: %Schema{allOf: [Schemas.EntityRef], nullable: true},
      data_source: %Schema{allOf: [Schemas.EntityRef], nullable: true},
      step: %Schema{allOf: [Schemas.EntityRef], nullable: true},
      date_from: %Schema{type: :string, format: :date},
      date_to: %Schema{type: :string, format: :date},
      trigger: %Schema{type: :string, enum: ["cron", "manual", "change"]},
      status: %Schema{type: :string, enum: ["queued", "running", "done", "failed"]},
      started_at: %Schema{type: :string, format: :"date-time", nullable: true},
      finished_at: %Schema{type: :string, format: :"date-time", nullable: true},
      error: %Schema{type: :string, nullable: true},
      inserted_at: %Schema{type: :string, format: :"date-time"}
    },
    required: [
      :id,
      :kind,
      :connection,
      :funnel,
      :data_source,
      :step,
      :date_from,
      :date_to,
      :trigger,
      :status,
      :started_at,
      :finished_at,
      :error,
      :inserted_at
    ]
  })
end
