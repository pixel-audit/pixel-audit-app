defmodule PixelAudit.Api.Connections.Connector.ClickHouseTest do
  use ExUnit.Case, async: true

  alias PixelAudit.Api.Connections.Connector.ClickHouse

  test "parses the URL's user, password, host, port and database" do
    assert {:ok, opts} =
             ClickHouse.connection_options(%{
               "url" => "https://us%40er:p%3Ass@ch.example.com:9443/analytics"
             })

    assert opts[:scheme] == "https"
    assert opts[:hostname] == "ch.example.com"
    assert opts[:port] == 9443
    assert opts[:username] == "us@er"
    assert opts[:password] == "p:ss"
    assert opts[:database] == "analytics"
  end

  test "defaults the user, password, database and port" do
    assert {:ok, opts} = ClickHouse.connection_options(%{"url" => "http://ch"})
    assert opts[:port] == 8123
    assert opts[:username] == "default"
    assert opts[:password] == ""
    assert opts[:database] == "default"

    assert {:ok, opts} = ClickHouse.connection_options(%{"url" => "https://ch/"})
    assert opts[:port] == 8443
    assert opts[:database] == "default"
  end

  test "refuses a URL that is not HTTP" do
    assert {:error, message} = ClickHouse.query(%{"url" => "tcp://ch:9000"}, "SELECT 1", %{})
    assert message =~ "http://"
  end
end
