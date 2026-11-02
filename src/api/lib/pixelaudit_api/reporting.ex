defmodule PixelAudit.Api.Reporting do
  @moduledoc """
  The daily cache and what fills it: refresh runs — a pull of a Meta
  connection's pixel stats, or a recomputation of a data source's daily
  counts — enqueued by the cron (`PixelAudit.Api.Reporting.Schedule`), by a
  change to what a data source measures, or by a person in the panel; and
  the report built from the cache (`PixelAudit.Api.Reporting.Report`).
  """

  import Ecto.Query, warn: false

  alias PixelAudit.Api.Settings.Connection
  alias PixelAudit.Api.Funnels.{DataSource, Funnel, Step}
  alias PixelAudit.Api.Repo
  alias PixelAudit.Api.Reporting.{DailyCount, MetaPixelRefreshJob, RefreshJob, RefreshRun, Report}

  ## Date ranges

  @doc """
  Reads a `date_from`/`date_to` pair as the API receives it: both present
  and ISO dates (`:missing_date`, `:invalid_date`), in order
  (`:invalid_date_range`), at most `:max_refresh_days` long
  (`:range_too_large`).
  """
  def parse_range(date_from, date_to) do
    with {:ok, from} <- parse_date(date_from),
         {:ok, to} <- parse_date(date_to) do
      max_days = Application.fetch_env!(:pixelaudit_api, :max_refresh_days)

      cond do
        Date.compare(from, to) == :gt -> {:error, :invalid_date_range}
        Date.diff(to, from) + 1 > max_days -> {:error, :range_too_large}
        true -> {:ok, from, to}
      end
    end
  end

  defp parse_date(nil), do: {:error, :missing_date}
  defp parse_date(""), do: {:error, :missing_date}
  defp parse_date(%Date{} = date), do: {:ok, date}

  defp parse_date(value) when is_binary(value) do
    case Date.from_iso8601(value) do
      {:ok, date} -> {:ok, date}
      {:error, _} -> {:error, :invalid_date}
    end
  end

  defp parse_date(_), do: {:error, :invalid_date}

  @doc "The last `days` days up to today, as a range."
  def recent_range(days) do
    today = Date.utc_today()
    {Date.add(today, -(days - 1)), today}
  end

  ## Refresh runs

  @doc "Enqueues a pull of a Meta connection's pixel stats over the range."
  def refresh_meta_connection(
        %Connection{type: :meta} = connection,
        date_from,
        date_to,
        trigger
      ) do
    enqueue_run(
      %{
        kind: :meta_pixel,
        connection_id: connection.id,
        date_from: date_from,
        date_to: date_to,
        trigger: trigger
      },
      MetaPixelRefreshJob
    )
  end

  def refresh_meta_connection(%Connection{}, _date_from, _date_to, _trigger),
    do: {:error, :not_a_meta_connection}

  @doc "Enqueues a recomputation of a data source's daily counts over the range."
  def refresh_data_source(%DataSource{} = data_source, date_from, date_to, trigger) do
    enqueue_run(
      %{
        kind: :data_source,
        funnel_id: data_source.funnel_id,
        data_source_id: data_source.id,
        connection_id: data_source.connection_id,
        date_from: date_from,
        date_to: date_to,
        trigger: trigger
      },
      RefreshJob
    )
  end

  @doc """
  Enqueues a recomputation of every data source of a funnel (or the one
  named by `:data_source_id`) over the range; a Meta-type data source's
  connection is pulled first, so its stats are fresh.
  """
  def refresh_funnel(%Funnel{} = funnel, date_from, date_to, trigger, opts \\ []) do
    data_sources =
      case Keyword.get(opts, :data_source_id) do
        nil -> funnel.data_sources
        id -> Enum.filter(funnel.data_sources, &(&1.id == id))
      end

    if data_sources == [] and Keyword.get(opts, :data_source_id) do
      {:error, :not_found}
    else
      runs =
        Enum.flat_map(data_sources, fn data_source ->
          meta_runs =
            if data_source.type == :meta_pixel_api and data_source.connection,
              do: [
                elem(
                  refresh_meta_connection(data_source.connection, date_from, date_to, trigger),
                  1
                )
              ],
              else: []

          {:ok, run} = refresh_data_source(data_source, date_from, date_to, trigger)
          meta_runs ++ [run]
        end)

      {:ok, runs}
    end
  end

  @doc """
  What a change to a data source triggers: a recomputation of the last
  `:backfill_days` days, so the report shows the new definition at once.
  """
  def refresh_after_change(%DataSource{} = data_source) do
    {date_from, date_to} = recent_range(Application.fetch_env!(:pixelaudit_api, :backfill_days))
    data_source = Repo.preload(data_source, :connection)

    if data_source.type == :meta_pixel_api and data_source.connection do
      refresh_meta_connection(data_source.connection, date_from, date_to, :change)
    end

    refresh_data_source(data_source, date_from, date_to, :change)
  end

  @doc "What a new Meta connection triggers: a first pull of Meta's window."
  def refresh_after_connection_created(%Connection{type: :meta} = connection) do
    {date_from, date_to} = recent_range(Application.fetch_env!(:pixelaudit_api, :backfill_days))
    refresh_meta_connection(connection, date_from, date_to, :change)
  end

  def refresh_after_connection_created(%Connection{}), do: :ok

  defp enqueue_run(attrs, worker) do
    Repo.transaction(fn ->
      run =
        %RefreshRun{}
        |> RefreshRun.changeset(attrs)
        |> Repo.insert!()

      job = Oban.insert!(worker.new(%{refresh_run_id: run.id}))

      run
      |> Ecto.Changeset.change(oban_job_id: job.id)
      |> Repo.update!()
    end)
  end

  @doc "Refresh runs, newest first, filtered by `funnel_id`, `connection_id`, `data_source_id`, `status`, `kind`."
  def list_refresh_runs(filters \\ %{}, opts \\ []) do
    limit = Keyword.get(opts, :limit, 50)
    offset = Keyword.get(opts, :offset, 0)

    query =
      Enum.reduce(filters, from(r in RefreshRun), fn
        {:funnel_id, id}, q -> where(q, [r], r.funnel_id == ^id)
        {:connection_id, id}, q -> where(q, [r], r.connection_id == ^id)
        {:data_source_id, id}, q -> where(q, [r], r.data_source_id == ^id)
        {:status, status}, q -> where(q, [r], r.status == ^status)
        {:kind, kind}, q -> where(q, [r], r.kind == ^kind)
        _other, q -> q
      end)

    total = Repo.aggregate(query, :count)

    runs =
      query
      |> order_by([r], desc: r.inserted_at, desc: r.id)
      |> limit(^limit)
      |> offset(^offset)
      |> preload([:connection, :funnel, :data_source])
      |> Repo.all()

    %{runs: runs, total: total}
  end

  def get_refresh_run!(id), do: Repo.get!(RefreshRun, id)

  def get_refresh_run_with_assocs!(id),
    do: RefreshRun |> Repo.get!(id) |> Repo.preload([:connection, :funnel, :data_source])

  @doc """
  The days a data-source run computed, each with its step: what the run
  did, day by day, and why a day failed. A Meta pull has none.
  """
  def list_run_days(%RefreshRun{id: run_id}) do
    Repo.all(
      from c in DailyCount,
        join: s in assoc(c, :step),
        where: c.refresh_run_id == ^run_id,
        order_by: [asc: c.date, asc: s.position],
        preload: [step: s]
    )
  end

  @doc "Whether a pull of the connection's pixel stats is queued or running."
  def meta_run_active?(connection_id) do
    Repo.exists?(
      from r in RefreshRun,
        where:
          r.kind == :meta_pixel and r.connection_id == ^connection_id and
            r.status in [:queued, :running]
    )
  end

  @doc false
  def start_run(%RefreshRun{} = run), do: run |> RefreshRun.started() |> Repo.update!()

  @doc false
  def finish_run(%RefreshRun{} = run, result),
    do: run |> RefreshRun.finished(result) |> Repo.update!()

  ## Daily counts

  @doc "Stores one day's outcome for a data source and step."
  def put_daily_count(
        %RefreshRun{} = run,
        %DataSource{} = data_source,
        %Step{} = step,
        date,
        outcome
      ) do
    {status, count, error} =
      case outcome do
        {:ok, count} -> {:ok, count, nil}
        {:error, message} -> {:error, nil, String.slice(to_string(message), 0, 2000)}
      end

    Repo.insert_all(
      DailyCount,
      [
        %{
          id: Ecto.UUID.generate(),
          data_source_id: data_source.id,
          step_id: step.id,
          refresh_run_id: run.id,
          date: date,
          count: count,
          status: status,
          error: error,
          computed_at: DateTime.utc_now(:second)
        }
      ],
      on_conflict: {:replace, [:count, :status, :error, :computed_at, :refresh_run_id]},
      conflict_target: [:data_source_id, :step_id, :date]
    )

    :ok
  end

  ## Report

  @doc "The report of a funnel loaded by `PixelAudit.Api.Funnels.get_funnel!/1`."
  def report(%Funnel{} = funnel, %Date{} = date_from, %Date{} = date_to),
    do: Report.build(funnel, date_from, date_to)

  @doc "One step of the funnel day by day over the range, per data source."
  def step_series(%Funnel{} = funnel, %Step{} = step, %Date{} = date_from, %Date{} = date_to),
    do: Report.step_series(funnel, step, date_from, date_to)
end
