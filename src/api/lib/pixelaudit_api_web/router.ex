defmodule PixelAudit.ApiWeb.Router do
  use PixelAudit.ApiWeb, :router

  # One API, for the admin panel, under /api/admin/v1 — deliberately
  # without authentication: PixelAudit is deployed behind a network
  # boundary (see specs/api.md at the repository root). The OpenAPI document
  # at /openapi/admin.json is what the panel's client is generated from.
  #
  # The panel itself is served from here too (PanelController): its build
  # sits in priv/static, /config.js is rendered from the environment, and
  # every other path answers the panel's index.html so its own router takes
  # over. One origin, no CORS.

  pipeline :health do
    plug :accepts, ["json"]
  end

  pipeline :admin_api do
    plug :accepts, ["json"]
    plug OpenApiSpex.Plug.PutApiSpec, module: PixelAudit.ApiWeb.OpenApi.AdminSpec
  end

  pipeline :panel do
    plug :accepts, ["html", "js"]
  end

  scope "/", PixelAudit.ApiWeb do
    pipe_through :health
    get "/health", HealthController, :show
  end

  scope "/openapi" do
    pipe_through :admin_api
    get "/admin.json", OpenApiSpex.Plug.RenderSpec, []
  end

  scope "/api/admin/v1", PixelAudit.ApiWeb.Admin do
    pipe_through :admin_api

    scope "/settings", Settings do
      # Before the resource routes, or "types" would be taken for an id.
      get "/connections/types", ConnectionController, :types
      # Spelled out rather than `resources`, which would add a PATCH twin of
      # every update and a second operation in the OpenAPI document.
      get "/connections", ConnectionController, :index
      post "/connections", ConnectionController, :create
      get "/connections/:id", ConnectionController, :show
      put "/connections/:id", ConnectionController, :update
      delete "/connections/:id", ConnectionController, :delete
      post "/connections/:id/check", ConnectionController, :check
      get "/connections/:id/calls", ConnectionController, :calls
      get "/connections/:id/calls/:call_id", ConnectionController, :show_call
      post "/connections/:id/refresh", ConnectionController, :refresh

      get "/variables", VariableController, :index
      post "/variables", VariableController, :create
      get "/variables/:id", VariableController, :show
      put "/variables/:id", VariableController, :update
      delete "/variables/:id", VariableController, :delete
    end

    scope "/funnels", Funnels do
      get "/data-source-types", DataSourceController, :types
      get "/", FunnelController, :index
      post "/", FunnelController, :create
      get "/:id", FunnelController, :show
      put "/:id", FunnelController, :update
      delete "/:id", FunnelController, :delete

      post "/:funnel_id/steps", StepController, :create
      put "/:funnel_id/steps/order", StepController, :reorder
      put "/:funnel_id/steps/:id", StepController, :update
      delete "/:funnel_id/steps/:id", StepController, :delete

      post "/:funnel_id/data-sources", DataSourceController, :create
      put "/:funnel_id/data-sources/order", DataSourceController, :reorder
      put "/:funnel_id/data-sources/:id", DataSourceController, :update
      delete "/:funnel_id/data-sources/:id", DataSourceController, :delete

      put "/:funnel_id/data-sources/:data_source_id/steps/:step_id/parameters",
          StepParameterController,
          :update

      delete "/:funnel_id/data-sources/:data_source_id/steps/:step_id/parameters",
             StepParameterController,
             :delete

      get "/:funnel_id/report", ReportController, :show
      get "/:funnel_id/steps/:step_id/report", ReportController, :step

      get "/:funnel_id/data-sources/:data_source_id/steps/:step_id/days",
          ReportController,
          :days

      post "/:funnel_id/refresh", RefreshController, :create
    end

    scope "/reporting", Reporting do
      get "/refresh-runs", RefreshRunController, :index
      get "/refresh-runs/:id", RefreshRunController, :show
      get "/refresh-runs/:id/days", RefreshRunController, :days
    end
  end

  scope "/", PixelAudit.ApiWeb do
    pipe_through :panel
    get "/config.js", PanelController, :config
    # Last: whatever no route above claimed is a panel address.
    get "/*path", PanelController, :index
  end
end
