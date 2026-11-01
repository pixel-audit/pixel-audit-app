defmodule PixelAudit.Api.FunnelsTest do
  use PixelAudit.Api.DataCase, async: true

  import PixelAudit.Api.Fixtures

  alias PixelAudit.Api.Funnels

  describe "steps" do
    test "are appended in order, reordered, and compacted on delete" do
      funnel = funnel_fixture()
      a = step_fixture(funnel, %{code: "a"})
      b = step_fixture(funnel, %{code: "b"})
      c = step_fixture(funnel, %{code: "c"})
      assert [a.position, b.position, c.position] == [0, 1, 2]

      {:ok, steps} = Funnels.reorder_steps(funnel, [c.id, a.id, b.id])
      assert Enum.map(steps, &{&1.code, &1.position}) == [{"c", 0}, {"a", 1}, {"b", 2}]

      assert {:error, :invalid_order} = Funnels.reorder_steps(funnel, [a.id, b.id])
      assert {:error, :invalid_order} = Funnels.reorder_steps(funnel, [a.id, b.id, c.id, c.id])
      assert {:error, :invalid_order} = Funnels.reorder_steps(funnel, "nope")

      {:ok, _} = Funnels.delete_step(Funnels.get_step!(funnel, a.id))

      assert Enum.map(Funnels.get_funnel!(funnel.id).steps, &{&1.code, &1.position}) == [
               {"c", 0},
               {"b", 1}
             ]
    end

    test "codes are unique within a funnel, not across" do
      funnel = funnel_fixture()
      other = funnel_fixture()
      step_fixture(funnel, %{code: "visit"})

      assert {:error, changeset} =
               Funnels.create_step(funnel, %{"code" => "visit", "name" => "V"})

      assert %{code: ["has already been taken"]} = errors_on(changeset)
      assert {:ok, _} = Funnels.create_step(other, %{"code" => "visit", "name" => "V"})
    end
  end

  describe "data sources" do
    test "need a connection of the type's connection type" do
      funnel = funnel_fixture()
      postgres = connection_fixture(:postgres)
      meta = connection_fixture(:meta_api)

      assert {:error, :connection_type_mismatch} =
               Funnels.create_data_source(funnel, %{
                 "code" => "fb",
                 "name" => "FB",
                 "type" => "meta_pixel_api",
                 "connection_id" => postgres.id
               })

      assert {:ok, data_source} =
               Funnels.create_data_source(funnel, %{
                 "code" => "fb",
                 "name" => "FB",
                 "type" => "meta_pixel_api",
                 "connection_id" => meta.id
               })

      assert data_source.connection.code == meta.code
      assert data_source.position == 0
      assert data_source.color in PixelAudit.Api.Funnels.DataSource.palette()
    end

    test "are dealt a colour of their own, and take one when given" do
      funnel = funnel_fixture()
      connection = connection_fixture(:postgres)
      first = data_source_fixture(funnel, connection, :postgres_query)
      second = data_source_fixture(funnel, connection, :postgres_query)
      assert first.color != second.color

      {:ok, third} =
        Funnels.create_data_source(funnel, %{
          "code" => "c",
          "name" => "C",
          "type" => "postgres_query",
          "connection_id" => connection.id,
          "color" => "#1A2B3C"
        })

      assert third.color == "#1a2b3c"

      {:error, changeset} = Funnels.update_data_source(third, %{"color" => "red"})
      assert %{color: ["must be a colour like #1a2b3c"]} = errors_on(changeset)
    end

    test "validate their settings against the type" do
      funnel = funnel_fixture()
      bigquery = connection_fixture(:bigquery)

      assert {:error, changeset} =
               Funnels.create_data_source(funnel, %{
                 "code" => "ga",
                 "name" => "GA4",
                 "type" => "google_analytics_bigquery",
                 "connection_id" => bigquery.id,
                 "settings" => %{"bogus" => "x"}
               })

      assert %{"settings.dataset": ["can't be blank"], settings: ["is not a known field"]} =
               errors_on(changeset)

      assert {:ok, data_source} =
               Funnels.create_data_source(funnel, %{
                 "code" => "ga",
                 "name" => "GA4",
                 "type" => "google_analytics_bigquery",
                 "connection_id" => bigquery.id,
                 "settings" => %{"dataset" => "analytics_1"}
               })

      # An update without settings keeps them.
      assert {:ok, %{settings: %{"dataset" => "analytics_1"}}} =
               Funnels.update_data_source(data_source, %{"name" => "GA4 export"})
    end

    test "take parameters per step, validated against the type" do
      %{funnel: funnel, steps: [visit | _], data_source: data_source} = measured_funnel_fixture()

      assert {:error, changeset} =
               Funnels.put_step_parameters(data_source, visit, %{"parameters" => %{"sql" => ""}})

      assert %{"parameters.sql": ["can't be blank"]} = errors_on(changeset)

      assert {:ok, parameter} =
               Funnels.put_step_parameters(data_source, visit, %{
                 "parameters" => %{"sql" => "SELECT 1"}
               })

      assert parameter.parameters == %{"sql" => "SELECT 1"}

      # Replaced, not duplicated.
      assert length(Funnels.get_data_source!(funnel, data_source.id).step_parameters) == 3

      {:ok, :ok} = Funnels.delete_step_parameters(data_source, visit)
      assert length(Funnels.get_data_source!(funnel, data_source.id).step_parameters) == 2
    end

    test "a select parameter takes its default and refuses other values" do
      funnel = funnel_fixture()
      step = step_fixture(funnel)
      bigquery = connection_fixture(:bigquery)

      data_source =
        data_source_fixture(funnel, bigquery, :google_ads_bigquery, %{
          settings: %{"dataset" => "ads", "customer_id" => "123"}
        })

      {:ok, parameter} =
        Funnels.put_step_parameters(data_source, step, %{
          "parameters" => %{"conversion_action_name" => "Purchase"}
        })

      assert parameter.parameters["metric"] == "conversions"

      {:error, changeset} =
        Funnels.put_step_parameters(data_source, step, %{
          "parameters" => %{"conversion_action_name" => "Purchase", "metric" => "clicks"}
        })

      assert %{"parameters.metric": ["is invalid"]} = errors_on(changeset)
    end
  end

  test "data_source_types/0 describes every type for the panel" do
    types = Funnels.data_source_types()

    assert Enum.map(types, & &1.type) == [
             :meta_pixel_api,
             :google_analytics_bigquery,
             :google_ads_bigquery,
             :postgres_query,
             :clickhouse_query
           ]

    ga = Enum.find(types, &(&1.type == :google_analytics_bigquery))
    assert ga.connection_type == :bigquery
    assert [%{key: "dataset", required: true}] = ga.settings
    assert Enum.map(ga.parameters, & &1.key) == ["event_name", "where"]
  end
end
