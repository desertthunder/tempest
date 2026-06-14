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

  pipeline :well_known do
    plug :accepts, ["text", "json"]
  end

  pipeline :oauth_metadata do
    plug :accepts, ["json"]
  end

  pipeline :oauth do
    plug :accepts, ["html", "json", "urlencoded"]
    plug :fetch_session
  end

  pipeline :oauth_api do
    plug :accepts, ["json", "urlencoded"]
  end

  pipeline :xrpc do
    plug :put_xrpc_cors_headers
    plug :accepts, ["json"]
    plug TempestWeb.Plugs.XrpcAuth
  end

  scope "/", TempestWeb do
    pipe_through :browser

    get "/", PageController, :home
    get "/stats", PageController, :stats
    get "/account", OperatorAccountController, :dashboard
    get "/account/repo", OperatorAccountController, :repo
    get "/account/blobs", OperatorAccountController, :blobs
    get "/account/access", OperatorAccountController, :access
    get "/account/security", OperatorAccountController, :security
    get "/account/migration", OperatorAccountController, :migration
    get "/account/sequencer", OperatorAccountController, :sequencer
    get "/account/firehose", OperatorAccountController, :firehose

    get "/admin", AdminController, :dashboard
    get "/admin/invites", AdminController, :invites
    get "/admin/repo", AdminController, :repo
    post "/admin/repo", AdminController, :repo_action
    get "/admin/backups", AdminController, :backups
    post "/admin/backups", AdminController, :backup_action
    get "/admin/storage", AdminController, :storage
    get "/admin/compatibility", AdminController, :compatibility
  end

  scope "/", TempestWeb do
    pipe_through :oauth_metadata

    get "/.well-known/oauth-protected-resource", OAuthMetadataController, :protected_resource
    get "/.well-known/oauth-authorization-server", OAuthMetadataController, :authorization_server
    get "/oauth/jwks", OAuthMetadataController, :jwks
  end

  scope "/", TempestWeb do
    pipe_through :well_known

    get "/.well-known/atproto-did", WellKnownController, :atproto_did
    get "/.well-known/did.json", WellKnownController, :did_json
  end

  scope "/oauth", TempestWeb do
    pipe_through :oauth

    get "/authorize", OAuthController, :authorize
    post "/authorize", OAuthController, :approve
  end

  scope "/oauth", TempestWeb do
    pipe_through :oauth_api

    post "/par", OAuthController, :par
    post "/token", OAuthController, :token
    post "/revoke", OAuthController, :revoke
  end

  scope "/xrpc", TempestWeb do
    pipe_through :xrpc

    get "/_stats", HealthController, :stats
    get "/_health", HealthController, :show
    get "/_admin/status", AdminController, :status
    get "/com.atproto.sync.subscribeRepos", FirehoseController, :subscribe_repos
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
    |> Plug.Conn.put_resp_header("access-control-allow-credentials", "true")
    |> Plug.Conn.put_resp_header("access-control-allow-methods", "*")
    |> Plug.Conn.put_resp_header("access-control-allow-headers", "*")
    |> Plug.Conn.put_resp_header("access-control-expose-headers", "dpop-nonce")
    |> Plug.Conn.put_resp_header("access-control-max-age", "100000000")
  end
end
