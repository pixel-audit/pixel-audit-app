defmodule PixelAudit.Api.Repo.Migrations.SettingsNamespace do
  use Ecto.Migration

  # Connections live in the Settings context now (`PixelAudit.Api.Settings`),
  # beside the new variables; the tables follow, prefixed `settings_`. The
  # indexes are renamed too, since Ecto infers a unique constraint's name
  # from the table.
  def up do
    rename table(:connections), to: table(:settings_connections)
    execute "ALTER INDEX connections_pkey RENAME TO settings_connections_pkey"
    execute "ALTER INDEX connections_code_index RENAME TO settings_connections_code_index"

    rename table(:connection_meta_pixel_stats), to: table(:settings_connection_meta_pixel_stats)

    execute "ALTER INDEX connection_meta_pixel_stats_pkey " <>
              "RENAME TO settings_connection_meta_pixel_stats_pkey"

    execute "ALTER INDEX connection_meta_pixel_stats_connection_id_date_hour_event_name_index " <>
              "RENAME TO settings_connection_meta_pixel_stats_connection_id_date_hour_event_name_index"

    create table(:settings_variables, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :key, :string, null: false
      add :value, :text, null: false
      add :description, :text
      add :managed_by_env, :boolean, null: false, default: false

      timestamps(type: :utc_datetime)
    end

    create unique_index(:settings_variables, [:key])
  end

  def down do
    drop table(:settings_variables)

    execute "ALTER INDEX settings_connection_meta_pixel_stats_connection_id_date_hour_event_name_index " <>
              "RENAME TO connection_meta_pixel_stats_connection_id_date_hour_event_name_index"

    execute "ALTER INDEX settings_connection_meta_pixel_stats_pkey " <>
              "RENAME TO connection_meta_pixel_stats_pkey"

    rename table(:settings_connection_meta_pixel_stats), to: table(:connection_meta_pixel_stats)

    execute "ALTER INDEX settings_connections_code_index RENAME TO connections_code_index"
    execute "ALTER INDEX settings_connections_pkey RENAME TO connections_pkey"
    rename table(:settings_connections), to: table(:connections)
  end
end
