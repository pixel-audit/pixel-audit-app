defmodule PixelAudit.Api.Repo.Migrations.DropCodes do
  use Ecto.Migration

  # Connections, funnels, steps and data sources are addressed by id; the
  # environment addresses a connection by its name, which is unique now.
  def up do
    drop index(:settings_connections, [:code], name: :settings_connections_code_index)
    alter table(:settings_connections), do: remove(:code)
    create unique_index(:settings_connections, [:name])

    drop index(:funnels, [:code])
    alter table(:funnels), do: remove(:code)

    drop index(:funnel_steps, [:funnel_id, :code])
    alter table(:funnel_steps), do: remove(:code)

    drop index(:funnel_data_sources, [:funnel_id, :code])
    alter table(:funnel_data_sources), do: remove(:code)
  end

  def down do
    alter table(:funnel_data_sources), do: add(:code, :string)
    execute "UPDATE funnel_data_sources SET code = replace(id::text, '-', '')"
    execute "ALTER TABLE funnel_data_sources ALTER COLUMN code SET NOT NULL"
    create unique_index(:funnel_data_sources, [:funnel_id, :code])

    alter table(:funnel_steps), do: add(:code, :string)
    execute "UPDATE funnel_steps SET code = replace(id::text, '-', '')"
    execute "ALTER TABLE funnel_steps ALTER COLUMN code SET NOT NULL"
    create unique_index(:funnel_steps, [:funnel_id, :code])

    alter table(:funnels), do: add(:code, :string)
    execute "UPDATE funnels SET code = replace(id::text, '-', '')"
    execute "ALTER TABLE funnels ALTER COLUMN code SET NOT NULL"
    create unique_index(:funnels, [:code])

    drop unique_index(:settings_connections, [:name])
    alter table(:settings_connections), do: add(:code, :string)
    execute "UPDATE settings_connections SET code = replace(id::text, '-', '')"
    execute "ALTER TABLE settings_connections ALTER COLUMN code SET NOT NULL"
    create unique_index(:settings_connections, [:code], name: :settings_connections_code_index)
  end
end
