defmodule PixelAudit.Api.Repo.Migrations.AddPrimaryToFunnelStepParameters do
  use Ecto.Migration

  def change do
    alter table(:funnel_step_parameters) do
      # The data source the step's count is most reliably read from; the
      # panel shows its count in bold. At most one per step, none is fine.
      add :primary, :boolean, null: false, default: false
    end

    create unique_index(:funnel_step_parameters, [:step_id],
             where: ~s("primary"),
             name: :funnel_step_parameters_one_primary_per_step_index
           )
  end
end
