defmodule TempestWeb.Router do
  use TempestWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {TempestWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  pipeline :xrpc do
    plug :accepts, ["json"]
    plug :put_xrpc_cors_headers
  end

  scope "/", TempestWeb do
    pipe_through :browser

    get "/", PageController, :home
  end

  scope "/xrpc", TempestWeb do
    pipe_through :xrpc

    get "/_health", HealthController, :show
    match :*, "/:method", XrpcController, :handle
  end

  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:tempest, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: TempestWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end

  defp put_xrpc_cors_headers(conn, _opts) do
    conn
    |> Plug.Conn.put_resp_header("access-control-allow-origin", "*")
    |> Plug.Conn.put_resp_header("access-control-allow-methods", "GET, POST, OPTIONS")
    |> Plug.Conn.put_resp_header("access-control-allow-headers", "authorization, content-type")
  end
end
