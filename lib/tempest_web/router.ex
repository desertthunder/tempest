defmodule TempestWeb.Router do
  use TempestWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :reject_unknown_doc_slug
    plug :put_root_layout, html: {TempestWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :account_browser do
    plug TempestWeb.Plugs.AccountBrowserAuth
  end

  pipeline :admin_browser do
    plug TempestWeb.Plugs.AdminBrowserAuth
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

    live "/", HomeLive, :home
    live "/stats", HomeLive, :stats
    live "/changelog", ChangelogLive, :show
    live "/docs", DocLive, :show
    live "/docs/:slug", DocLive, :show
    get "/account/login", AccountSessionController, :new
    post "/account/login", AccountSessionController, :create
    get "/account/logout", AccountSessionController, :delete
    get "/admin/login", AdminSessionController, :new
    post "/admin/login", AdminSessionController, :create
    get "/admin/logout", AdminSessionController, :delete
  end

  scope "/account", TempestWeb do
    pipe_through [:browser, :account_browser]

    live_session :account_control_panel,
      on_mount: [{TempestWeb.ControlPanelAuth, :account}],
      session: {TempestWeb.ControlPanelAuth, :account_session, []} do
      live "/", AccountControlLive, :dashboard
      live "/repo", AccountControlLive, :repo
      live "/blobs", AccountControlLive, :blobs
      live "/access", AccountControlLive, :access
      live "/security", AccountControlLive, :security
      live "/migration", AccountControlLive, :migration
      live "/sequencer", AccountControlLive, :sequencer
      live "/firehose", AccountControlLive, :firehose
    end
  end

  scope "/admin", TempestWeb do
    pipe_through [:browser, :admin_browser]

    live_session :admin_control_panel,
      on_mount: [{TempestWeb.ControlPanelAuth, :admin}],
      session: {TempestWeb.ControlPanelAuth, :admin_session, []} do
      live "/", AdminControlLive, :dashboard
      live "/accounts", AdminControlLive, :accounts
      live "/accounts/:did", AdminControlLive, :account_detail
      live "/invites", AdminControlLive, :invites
      live "/repo", AdminControlLive, :repo
      live "/backups", AdminControlLive, :backups
      live "/storage", AdminControlLive, :storage
      live "/compatibility", AdminControlLive, :compatibility
      live "/personal-backups", AdminControlLive, :backup_accounts
      live "/personal-backups/new", AdminControlLive, :backup_new
      live "/personal-backups/:id", AdminControlLive, :backup_detail
      live "/personal-backups/:id/edit", AdminControlLive, :backup_edit
      live "/personal-backups/:id/delete", AdminControlLive, :backup_delete
      live "/personal-backups/:id/backup", AdminControlLive, :backup_now
      live "/personal-backups/:id/verify", AdminControlLive, :backup_verify
      live "/personal-backups/:id/prune", AdminControlLive, :backup_prune
      live "/personal-backups/:id/export", AdminControlLive, :backup_export
    end

    post "/repo", AdminController, :repo_action
    post "/backups", AdminController, :backup_action
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
    post "/introspect", OAuthController, :introspect
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

  defp reject_unknown_doc_slug(%Plug.Conn{method: "GET", path_info: ["docs", slug]} = conn, _opts) do
    if Tempest.Docs.known_document_slug?(slug) do
      conn
    else
      conn
      |> Plug.Conn.put_resp_content_type("text/html")
      |> Plug.Conn.send_resp(:not_found, "Not Found")
      |> Plug.Conn.halt()
    end
  end

  defp reject_unknown_doc_slug(conn, _opts), do: conn
end
