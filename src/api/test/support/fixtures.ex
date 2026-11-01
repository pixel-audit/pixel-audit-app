defmodule PixelAudit.Api.Fixtures do
  @moduledoc """
  Rows for tests: connections of every type, funnels with steps and data
  sources, and the stubbed Meta answers.
  """

  alias PixelAudit.Api.{Funnels, Settings}

  @doc "The test database as a `postgres://` URL — a real Postgres the Postgres connector can hit."
  def test_database_url do
    config = PixelAudit.Api.Repo.config()

    "postgres://#{config[:username]}:#{config[:password]}@#{config[:hostname]}:#{config[:port]}/#{config[:database]}"
  end

  def credentials_for(:meta),
    do: %{"access_token" => "EAAtoken", "pixel_id" => "123456", "api_version" => "v25.0"}

  def credentials_for(:bigquery),
    do: %{
      "credentials_json" =>
        Jason.encode!(%{
          "type" => "service_account",
          "project_id" => "pa-project",
          "client_email" => "pa@pa-project.iam.gserviceaccount.com",
          "private_key" => "-----BEGIN PRIVATE KEY-----\\nabc\\n-----END PRIVATE KEY-----\\n"
        }),
      "project_id" => "pa-project"
    }

  def credentials_for(:postgres), do: %{"url" => test_database_url()}

  def credentials_for(:clickhouse), do: %{"url" => "http://sample:sample@localhost:18123/shop"}

  def connection_fixture(type \\ :postgres, attrs \\ %{}) do
    {:ok, connection} =
      Settings.create_connection(
        Map.merge(
          %{
            "name" => attrs[:name] || "Connection #{System.unique_integer([:positive])}",
            "type" => Atom.to_string(type),
            "credentials" => attrs[:credentials] || credentials_for(type)
          },
          Map.new(Map.drop(attrs, [:name, :credentials]), fn {k, v} -> {to_string(k), v} end)
        )
      )

    connection
  end

  def variable_fixture(attrs \\ %{}) do
    key = attrs[:key] || "v#{System.unique_integer([:positive])}"

    {:ok, variable} =
      Settings.create_variable(%{
        "key" => key,
        "value" => Map.get(attrs, :value, "value of #{key}"),
        "description" => attrs[:description]
      })

    variable
  end

  def funnel_fixture(attrs \\ %{}) do
    {:ok, funnel} =
      Funnels.create_funnel(%{
        "name" => attrs[:name] || "Funnel #{System.unique_integer([:positive])}",
        "description" => attrs[:description]
      })

    Funnels.get_funnel!(funnel.id)
  end

  def step_fixture(funnel, attrs \\ %{}) do
    {:ok, step} =
      Funnels.create_step(funnel, %{
        "name" => attrs[:name] || "Step #{System.unique_integer([:positive])}"
      })

    step
  end

  def data_source_fixture(funnel, connection, type, attrs \\ %{}) do
    {:ok, data_source} =
      Funnels.create_data_source(funnel, %{
        "name" => attrs[:name] || "Source #{System.unique_integer([:positive])}",
        "type" => Atom.to_string(type),
        "connection_id" => connection.id,
        "settings" => attrs[:settings] || %{}
      })

    data_source
  end

  @doc "A funnel with three steps, measured by a Postgres query source on the test database."
  def measured_funnel_fixture do
    funnel = funnel_fixture()

    [visit, cart, purchase] =
      for name <- ~w(visit cart purchase), do: step_fixture(funnel, %{name: name})

    connection = connection_fixture(:postgres)
    data_source = data_source_fixture(funnel, connection, :postgres_query)

    for {step, count} <- [{visit, 100}, {cart, 40}, {purchase, 10}] do
      {:ok, _} =
        Funnels.put_step_parameters(data_source, step, %{
          "parameters" => %{"sql" => "SELECT #{count} WHERE $1::date <= $2::date"}
        })
    end

    %{
      funnel: Funnels.get_funnel!(funnel.id),
      steps: [visit, cart, purchase],
      connection: connection,
      data_source: Funnels.get_data_source!(funnel, data_source.id)
    }
  end

  @doc "A Meta /stats page: one hour per entry, `{iso8601 start, [{event, count}]}`."
  def meta_stats_page(hours, paging \\ nil) do
    data =
      for {start_time, events} <- hours do
        %{
          "start_time" => start_time,
          "count" => Enum.sum(Enum.map(events, &elem(&1, 1))),
          "data" => for({event, count} <- events, do: %{"value" => event, "count" => count})
        }
      end

    body = %{"data" => data}
    if paging, do: Map.put(body, "paging", paging), else: body
  end
end
