defmodule PixelAudit.Api.Repo.Migrations.AddDescriptionToFunnelStepParameters do
  use Ecto.Migration

  def change do
    alter table(:funnel_step_parameters) do
      # A note on how the data source counts the step; the panel shows it
      # as a tooltip on the count.
      add :description, :text
    end
  end
end
