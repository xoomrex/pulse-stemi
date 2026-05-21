defmodule StemiWeb.Router do
  use StemiWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {StemiWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug StemiWeb.Plugs.DeviceDetector
    plug StemiWeb.Auth
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  # Public routes (no auth required)
  scope "/", StemiWeb do
    pipe_through :browser

    # Login
    live "/login", LoginLive, :index

    # Install / desktop wall — public so non-admin desktop users can see instructions.
    live "/install", InstallLive, :index

    # Session management (regular controller for cookie handling)
    post "/session", SessionController, :create
    post "/logout", SessionController, :delete

    # Uploaded file serving
    get "/uploads/:filename", UploadController, :show

    # Root redirect
    get "/", PageController, :home
  end

  # Authenticated routes
  scope "/", StemiWeb do
    pipe_through [:browser]

    live_session :authenticated,
      on_mount: {StemiWeb.Auth, :default} do
      live "/dashboard", DashboardLive, :index
      live "/phc/cases", Phc.CasesLive, :index
      live "/er/review", Er.ReviewLive, :index
      live "/cardio/review", Cardio.ReviewLive, :index
      live "/elig/cases", Elig.CasesLive, :index
      live "/ems/dispatch", Ems.DispatchLive, :index
      live "/cath-lab/prepare", CathLab.PrepareLive, :index
    end
  end

  # Admin routes (admin role required)
  scope "/admin", StemiWeb.Admin do
    pipe_through [:browser]

    live_session :admin,
      on_mount: {StemiWeb.Auth, :admin_only} do
      live "/users", UsersLive, :index
      live "/cases", CasesLive, :index
    end
  end
end
