defmodule PixelAudit.ApiWeb.OpenApi.Schemas.RefreshRunRef do
  @moduledoc false
  require OpenApiSpex
  alias OpenApiSpex.Schema

  OpenApiSpex.schema(%{
    title: "RefreshRunRef",
    description: "The refresh run that wrote a daily count, in short.",
    type: :object,
    properties: %{
      id: %Schema{type: :string, format: :uuid},
      trigger: %Schema{type: :string, enum: ["cron", "manual", "change"]},
      status: %Schema{type: :string, enum: ["queued", "running", "done", "failed"]},
      started_at: %Schema{type: :string, format: :"date-time", nullable: true},
      finished_at: %Schema{type: :string, format: :"date-time", nullable: true}
    },
    required: [:id, :trigger, :status, :started_at, :finished_at]
  })
end
