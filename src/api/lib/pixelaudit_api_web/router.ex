defmodule PixelAudit.ApiWeb.Router do
  use PixelAudit.ApiWeb, :router

  # One API, for the admin panel, under /api/admin/v1 — deliberately
  # without authentication: PixelAudit is deployed behind a network
  # boundary (see specs/api.md at the repository root). The OpenAPI document
  # at /openapi/admin.json is what the panel's client is generated from.

  pipeline :health do
    plug :accepts, ["json"]
  end

  pipeline :admin_api do
    plug :accepts, ["json"]
    plug OpenApiSpex.Plug.PutApiSpec, module: PixelAudit.ApiWeb.OpenApi.AdminSpec
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

    scope "/connections", Connections do
      # Before the resource routes, or "types" would be taken for an id.
      get "/types", ConnectionController, :types
      # Spelled out rather than `resources`, which would add a PATCH twin of
      # every update and a second operation in the OpenAPI document.
      get "/", ConnectionController, :index
      post "/", ConnectionController, :create
      get "/:id", ConnectionController, :show
      put "/:id", ConnectionController, :update
      delete "/:id", ConnectionController, :delete
      post "/:id/check", ConnectionController, :check
      post "/:id/refresh", ConnectionController, :refresh
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
      put "/:funnel_id/data-sources/:id", DataSourceController, :update
      delete "/:funnel_id/data-sources/:id", DataSourceController, :delete

      put "/:funnel_id/data-sources/:data_source_id/steps/:step_id/parameters",
          StepParameterController,
          :update

      delete "/:funnel_id/data-sources/:data_source_id/steps/:step_id/parameters",
             StepParameterController,
             :delete

      get "/:funnel_id/report", ReportController, :show
      post "/:funnel_id/refresh", RefreshController, :create
    end

    scope "/reporting", Reporting do
      get "/refresh-runs", RefreshRunController, :index
      get "/refresh-runs/:id", RefreshRunController, :show
      get "/refresh-runs/:id/days", RefreshRunController, :days
    end
  end
end
