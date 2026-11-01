defmodule PixelAudit.Api.Repo.Migrations.CreateSettingsConnectionCalls do
  use Ecto.Migration

  # Every query and API call made through a connection, as the gateway
  # records it. The id is a UUIDv7 from Postgres 18's uuidv7(): time-ordered.
  def change do
    create table(:settings_connection_calls, primary_key: false) do
      add :id, :uuid, primary_key: true, default: fragment("uuidv7()")

      add :connection_id,
          references(:settings_connections, type: :binary_id, on_delete: :delete_all),
          null: false

      add :kind, :string, null: false
      add :status, :string, null: false
      add :started_at, :utc_datetime_usec, null: false
      add :duration_ms, :integer, null: false
      add :error, :text

      add :sql, :text
      add :params, :jsonb
      add :result, :jsonb

      add :method, :string
      add :url, :text
      add :request_content_type, :string
      add :request_body, :text
      add :response_status, :integer
      add :response_content_type, :string
      add :response_body, :text
    end

    create index(:settings_connection_calls, [:connection_id, :started_at])
    create index(:settings_connection_calls, [:started_at])
  end
end
