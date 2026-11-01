defmodule PixelAudit.Api.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      PixelAudit.ApiWeb.Telemetry,
      # The vault before the Repo: anything that reads a connection row
      # decrypts its credentials.
      PixelAudit.Api.Vault,
      PixelAudit.Api.Repo,
      {Oban, Application.fetch_env!(:pixelaudit_api, Oban)},
      {DNSCluster, query: Application.get_env(:pixelaudit_api, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: PixelAudit.Api.PubSub},
      # Connector calls to SQL databases run under here, unlinked from the
      # caller: a driver process that gives up on a refused connection must
      # not take an Oban job or a request down with it.
      {Task.Supervisor, name: PixelAudit.Api.Settings.Connector.TaskSupervisor},
      # Start to serve requests, typically the last entry
      PixelAudit.ApiWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: PixelAudit.Api.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    PixelAudit.ApiWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
