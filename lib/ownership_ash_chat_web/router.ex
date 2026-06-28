defmodule OwnershipAshChatWeb.Router do
  use OwnershipAshChatWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {OwnershipAshChatWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", OwnershipAshChatWeb do
    pipe_through :browser

    get "/", PageController, :home

    # Token entry (replaces auth): upstream tool links to /start?case_id=…
    get "/start", StartController, :start

    # Session-driven writing flow; reads session_id from the cookie set at entry.
    live "/study", StudySessionLive
  end

  # Other scopes may use custom stacks.
  # scope "/api", OwnershipAshChatWeb do
  #   pipe_through :api
  # end

  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:ownership_ash_chat, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: OwnershipAshChatWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end

    # Dev-only harness for the study writing flow (plan step #4), operating on a
    # single run by id — not the participant entry point.
    scope "/dev", OwnershipAshChatWeb do
      pipe_through :browser

      # One-click entry: create a randomized session and jump into /study.
      get "/study/new", DevStudyController, :new
      live "/study/run/:run_id", StudyWritingLive
    end
  end
end
