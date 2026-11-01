defmodule PixelAudit.Api.Repo.Migrations.AddColorToFunnelDataSources do
  use Ecto.Migration

  def change do
    alter table(:funnel_data_sources) do
      # The data source's colour in the report (#rrggbb).
      add :color, :string, size: 7
    end

    # Existing rows are dealt the palette in their funnel's order, so the
    # column can be NOT NULL from the start.
    execute(
      """
      UPDATE funnel_data_sources SET color = (ARRAY[
        '#2563eb','#db2777','#16a34a','#ea580c','#7c3aed','#0891b2',
        '#ca8a04','#dc2626','#0d9488','#9333ea','#65a30d','#4f46e5'
      ])[1 + (numbered.n - 1) % 12]
      FROM (
        SELECT id, row_number() OVER (PARTITION BY funnel_id ORDER BY position) AS n
        FROM funnel_data_sources
      ) AS numbered
      WHERE funnel_data_sources.id = numbered.id
      """,
      "SELECT 1"
    )

    alter table(:funnel_data_sources) do
      modify :color, :string, size: 7, null: false
    end
  end
end
