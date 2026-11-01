defmodule PixelAudit.Api.Repo.Migrations.CreatePixelauditSchema do
  use Ecto.Migration

  def change do
    ## Connections

    create table(:connections, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :code, :string, null: false
      add :name, :string, null: false
      add :description, :text
      add :type, :string, null: false
      # Encrypted by PixelAudit.Api.Vault (Cloak): the cipher tag and the ciphertext.
      add :credentials, :binary
      add :managed_by_env, :boolean, null: false, default: false
      add :last_checked_at, :utc_datetime
      add :last_check_status, :string
      add :last_check_error, :text

      timestamps(type: :utc_datetime)
    end

    create unique_index(:connections, [:code])

    create table(:connection_meta_pixel_stats, primary_key: false) do
      add :id, :binary_id, primary_key: true

      add :connection_id, references(:connections, type: :binary_id, on_delete: :delete_all),
        null: false

      add :date, :date, null: false
      add :hour, :integer, null: false
      add :event_name, :string, null: false
      add :count, :bigint, null: false

      timestamps(type: :utc_datetime, updated_at: false)
    end

    create unique_index(:connection_meta_pixel_stats, [:connection_id, :date, :hour, :event_name])

    ## Funnels

    create table(:funnels, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :code, :string, null: false
      add :name, :string, null: false
      add :description, :text

      timestamps(type: :utc_datetime)
    end

    create unique_index(:funnels, [:code])

    create table(:funnel_steps, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :funnel_id, references(:funnels, type: :binary_id, on_delete: :delete_all), null: false
      add :code, :string, null: false
      add :name, :string, null: false
      add :description, :text
      add :position, :integer, null: false

      timestamps(type: :utc_datetime)
    end

    create unique_index(:funnel_steps, [:funnel_id, :code])
    create index(:funnel_steps, [:funnel_id, :position])

    create table(:funnel_data_sources, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :funnel_id, references(:funnels, type: :binary_id, on_delete: :delete_all), null: false

      add :connection_id, references(:connections, type: :binary_id, on_delete: :restrict),
        null: false

      add :code, :string, null: false
      add :name, :string, null: false
      add :description, :text
      add :type, :string, null: false
      add :settings, :map, null: false, default: %{}
      add :position, :integer, null: false

      timestamps(type: :utc_datetime)
    end

    create unique_index(:funnel_data_sources, [:funnel_id, :code])
    create index(:funnel_data_sources, [:connection_id])

    create table(:funnel_step_parameters, primary_key: false) do
      add :id, :binary_id, primary_key: true

      add :data_source_id,
          references(:funnel_data_sources, type: :binary_id, on_delete: :delete_all),
          null: false

      add :step_id, references(:funnel_steps, type: :binary_id, on_delete: :delete_all),
        null: false

      add :parameters, :map, null: false, default: %{}

      timestamps(type: :utc_datetime)
    end

    create unique_index(:funnel_step_parameters, [:data_source_id, :step_id])
    create index(:funnel_step_parameters, [:step_id])

    ## Reporting

    create table(:reporting_refresh_runs, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :kind, :string, null: false
      add :connection_id, references(:connections, type: :binary_id, on_delete: :delete_all)
      add :funnel_id, references(:funnels, type: :binary_id, on_delete: :delete_all)

      add :data_source_id,
          references(:funnel_data_sources, type: :binary_id, on_delete: :delete_all)

      add :date_from, :date, null: false
      add :date_to, :date, null: false
      add :trigger, :string, null: false
      add :status, :string, null: false, default: "queued"
      add :started_at, :utc_datetime
      add :finished_at, :utc_datetime
      add :error, :text
      add :oban_job_id, :bigint

      timestamps(type: :utc_datetime)
    end

    create index(:reporting_refresh_runs, [:inserted_at])
    create index(:reporting_refresh_runs, [:funnel_id])
    create index(:reporting_refresh_runs, [:connection_id, :status])
    create index(:reporting_refresh_runs, [:data_source_id])

    create table(:reporting_daily_counts, primary_key: false) do
      add :id, :binary_id, primary_key: true

      add :data_source_id,
          references(:funnel_data_sources, type: :binary_id, on_delete: :delete_all),
          null: false

      add :step_id, references(:funnel_steps, type: :binary_id, on_delete: :delete_all),
        null: false

      add :refresh_run_id,
          references(:reporting_refresh_runs, type: :binary_id, on_delete: :nilify_all)

      add :date, :date, null: false
      add :count, :bigint
      add :status, :string, null: false
      add :error, :text
      add :computed_at, :utc_datetime, null: false
    end

    create unique_index(:reporting_daily_counts, [:data_source_id, :step_id, :date])
    create index(:reporting_daily_counts, [:step_id])
  end
end
