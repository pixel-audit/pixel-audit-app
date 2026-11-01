defmodule PixelAudit.Api.Settings.Connector.PostgresTest do
  use ExUnit.Case, async: true

  import PixelAudit.Api.Fixtures

  alias PixelAudit.Api.Settings.Connector.Postgres

  test "runs a query with bound dates against a real Postgres" do
    credentials = %{"url" => test_database_url()}

    assert {:ok, [[42]]} =
             Postgres.query(credentials, "SELECT 42 WHERE $1::date <= $2::date", [
               ~D[2026-10-01],
               ~D[2026-10-02]
             ])

    assert {:ok, []} =
             Postgres.query(credentials, "SELECT 42 WHERE $1::date > $2::date", [
               ~D[2026-10-01],
               ~D[2026-10-02]
             ])
  end

  test "reports a SQL error" do
    assert {:error, "PostgreSQL: " <> message} =
             Postgres.query(
               %{"url" => test_database_url()},
               "SELECT * FROM no_such_table",
               []
             )

    assert message =~ "no_such_table"
  end

  test "refuses a URL that is not Postgres" do
    assert {:error, message} = Postgres.query(%{"url" => "mysql://h/d"}, "SELECT 1", [])
    assert message =~ "postgres://"
  end

  test "parses the URL's parts and sslmode" do
    assert {:ok, opts} =
             Postgres.connection_options(
               "postgresql://us%40er:p%3Ass@db.example.com:6543/shop?sslmode=require"
             )

    assert opts[:hostname] == "db.example.com"
    assert opts[:port] == 6543
    assert opts[:username] == "us@er"
    assert opts[:password] == "p:ss"
    assert opts[:database] == "shop"
    assert opts[:ssl] == [verify: :verify_none]

    assert {:ok, opts} = Postgres.connection_options("postgres://localhost/shop")
    assert opts[:port] == 5432
    assert opts[:ssl] == false
  end
end
