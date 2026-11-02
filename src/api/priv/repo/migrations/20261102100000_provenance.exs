defmodule PixelAudit.Api.Repo.Migrations.Provenance do
  @moduledoc """
  Where every value comes from (specs/provenance.md): a call records why
  it was made, a stored value cites the calls that produced it, and a
  cited call cannot be deleted. A refresh run may target one step.
  """

  use Ecto.Migration

  def change do
    alter table(:settings_connection_calls) do
      add :purpose, :string
      add :date, :date

      add :refresh_run_id,
          references(:reporting_refresh_runs, type: :binary_id, on_delete: :nilify_all)

      add :data_source_id,
          references(:funnel_data_sources, type: :binary_id, on_delete: :nilify_all)

      add :step_id, references(:funnel_steps, type: :binary_id, on_delete: :nilify_all)
    end

    create index(:settings_connection_calls, [:data_source_id, :step_id, :date])
    create index(:settings_connection_calls, [:refresh_run_id])

    alter table(:reporting_refresh_runs) do
      add :step_id, references(:funnel_steps, type: :binary_id, on_delete: :nilify_all)
    end

    # A value's citations: a daily count or a cached Meta hour, and a call.
    # The call cannot go while cited (NO ACTION: checked at the end of the
    # statement, so a connection's deletion — which takes its Meta hours,
    # their citations and its calls in one statement — still goes through).
    # A value's citations go with the value.
    create table(:reporting_citations, primary_key: false) do
      add :id, :uuid, primary_key: true, default: fragment("uuidv7()")

      add :daily_count_id,
          references(:reporting_daily_counts, type: :binary_id, on_delete: :delete_all)

      add :meta_pixel_stat_id,
          references(:settings_connection_meta_pixel_stats,
            type: :binary_id,
            on_delete: :delete_all
          )

      add :call_id,
          references(:settings_connection_calls, type: :binary_id, on_delete: :nothing),
          null: false

      add :inserted_at, :utc_datetime, null: false, default: fragment("now()")
    end

    create constraint(:reporting_citations, :one_value,
             check: "num_nonnulls(daily_count_id, meta_pixel_stat_id) = 1"
           )

    create unique_index(:reporting_citations, [:daily_count_id, :call_id])
    create unique_index(:reporting_citations, [:meta_pixel_stat_id, :call_id])
    create index(:reporting_citations, [:call_id])
  end
end
