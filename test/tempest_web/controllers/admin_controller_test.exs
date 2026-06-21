defmodule TempestWeb.AdminControllerTest do
  use TempestWeb.ConnCase

  alias Tempest.{Accounts, AdminAuth, PersonalBackups}

  setup context do
    Req.Test.set_req_test_from_context(context)
    Req.Test.verify_on_exit!(context)

    old_hash = Application.get_env(:tempest, :admin_token_hash)
    old_config = Application.get_env(:tempest, Tempest.Config)
    old_identity_config = Application.get_env(:tempest, Tempest.Identity)
    old_admin_auth_config = Application.get_env(:tempest, AdminAuth)

    on_exit(fn ->
      if old_hash do
        Application.put_env(:tempest, :admin_token_hash, old_hash)
      else
        Application.delete_env(:tempest, :admin_token_hash)
      end

      Application.put_env(:tempest, Tempest.Config, old_config)

      if old_identity_config do
        Application.put_env(:tempest, Tempest.Identity, old_identity_config)
      else
        Application.delete_env(:tempest, Tempest.Identity)
      end

      if old_admin_auth_config do
        Application.put_env(:tempest, AdminAuth, old_admin_auth_config)
      else
        Application.delete_env(:tempest, AdminAuth)
      end
    end)

    :ok
  end

  test "admin status requires configured admin token", %{conn: conn} do
    Application.delete_env(:tempest, :admin_token_hash)

    conn = get(conn, ~p"/xrpc/_admin/status")
    response = json_response(conn, 401)

    assert response["error"] == "AuthenticationRequired"
  end

  test "admin status rejects account bearer token", %{conn: conn} do
    Application.put_env(:tempest, :admin_token_hash, AdminAuth.hash_token("admin-secret-token"))

    {:ok, session} =
      Accounts.create_account(%{
        "handle" => "admin-status-user.test",
        "email" => "admin-status@example.com",
        "password" => "correct horse battery staple"
      })

    conn =
      conn
      |> put_req_header("authorization", "Bearer #{session["accessJwt"]}")
      |> get(~p"/xrpc/_admin/status")

    response = json_response(conn, 401)
    assert response["error"] == "InvalidToken"
  end

  test "admin UI rejects bearer tokens and browser session renders operator pages", %{conn: conn} do
    Application.put_env(:tempest, :admin_token_hash, AdminAuth.hash_token("admin-secret-token"))

    {:ok, session} =
      Accounts.create_account(%{
        "handle" => "admin-ui-user.test",
        "email" => "admin-ui@example.com",
        "password" => "correct horse battery staple"
      })

    rejected =
      conn
      |> put_req_header("authorization", "Bearer #{session["accessJwt"]}")
      |> get(~p"/admin")

    assert json_response(rejected, 401)["error"] == "AutomationOnly"

    admin_conn = admin_login_conn(conn, "admin-ui-admin.test", "admin-ui-admin@example.com")

    for {path, expected} <- [
          {~p"/admin", "Admin Dashboard"},
          {~p"/admin/accounts", "Hosted Accounts"},
          {~p"/admin/invites", "Invite Code Management"},
          {~p"/admin/repo", "Repo Verify, Export, and Import"},
          {~p"/admin/backups", "Backup Create and Restore Dry Run"},
          {~p"/admin/personal-backups", "External Account Backups"},
          {~p"/admin/personal-backups/new", "Register External Backup Account"},
          {~p"/admin/storage", "Storage Status"},
          {~p"/admin/compatibility", "Compatibility Status"}
        ] do
      html =
        admin_conn
        |> recycle()
        |> get(path)
        |> html_response(200)

      assert html =~ expected
    end
  end

  test "admin account detail inspects hosted account state", %{conn: conn} do
    admin_conn = admin_login_conn(conn, "admin-account-detail.test", "admin-account-detail@example.com")

    {:ok, account} =
      Accounts.create_account(%{
        "handle" => "admin-inspected-account.test",
        "email" => "admin-inspected-account@example.com",
        "password" => "correct horse battery staple"
      })

    html =
      admin_conn
      |> recycle()
      |> get(~p"/admin/accounts/#{account["did"]}")
      |> html_response(200)

    assert html =~ ~s(id="admin-account-detail")
    assert html =~ account["did"]
    assert html =~ account["handle"]
    assert html =~ "repo count"
  end

  test "admin external backup routes render account operations", %{conn: conn} do
    admin_conn = admin_login_conn(conn, "admin-external-backups.test", "admin-external-backups@example.com")
    did = "did:plc:bbbbbbbbbbbbbbbbbbbbbbbb"
    handle = "external-backup.test"

    Application.put_env(:tempest, Tempest.Identity,
      plc_directory_url: "https://plc.test",
      http_req_options: [plug: {Req.Test, __MODULE__}],
      dns_lookup: &public_test_dns/1,
      dns_txt_lookup: fn "_atproto." <> ^handle -> ["did=#{did}"] end
    )

    Req.Test.expect(__MODULE__, fn req_conn ->
      assert req_conn.request_path == "/" <> URI.encode(did)

      Req.Test.json(req_conn, %{
        "@context" => ["https://www.w3.org/ns/did/v1"],
        "id" => did,
        "alsoKnownAs" => ["at://#{handle}"],
        "service" => [
          %{
            "id" => "#atproto_pds",
            "type" => "AtprotoPersonalDataServer",
            "serviceEndpoint" => "https://external-pds.test"
          }
        ]
      })
    end)

    assert {:ok, account} =
             PersonalBackups.register_account(%{
               did: did,
               handle: handle,
               label: "External backup"
             })

    for {path, expected, selector} <- [
          {~p"/admin/personal-backups/#{account.id}", "Credential State", ~s(id="personal-backup-now-form")},
          {~p"/admin/personal-backups/#{account.id}/edit", "Edit External Backup Account",
           ~s(id="personal-backup-edit-form")},
          {~p"/admin/personal-backups/#{account.id}/delete", "Delete External Backup Account",
           ~s(id="personal-backup-delete-form")},
          {~p"/admin/personal-backups/#{account.id}/backup", "Operations", ~s(id="personal-backup-now-form")},
          {~p"/admin/personal-backups/#{account.id}/verify", "Snapshot History", ~s(id="personal-backup-verify-form")},
          {~p"/admin/personal-backups/#{account.id}/prune", "Retention and Schedule",
           ~s(id="personal-backup-prune-form")},
          {~p"/admin/personal-backups/#{account.id}/export", "Storage Totals and Missing Blobs",
           ~s(id="personal-backup-export-form")}
        ] do
      html =
        admin_conn
        |> recycle()
        |> get(path)
        |> html_response(200)

      assert html =~ expected
      assert html =~ selector
    end
  end

  test "admin mutation forms include csrf tokens and confirmations", %{conn: conn} do
    admin_conn = admin_login_conn(conn, "admin-confirmations.test", "admin-confirmations@example.com")

    repo_html =
      admin_conn
      |> recycle()
      |> get(~p"/admin/repo")
      |> html_response(200)

    assert repo_html =~ ~s(id="admin-repo-form")
    assert repo_html =~ ~s(name="_csrf_token")
    assert repo_html =~ ~s(data-confirm="Verify this repository)
    assert repo_html =~ ~s(data-confirm="Export this repository CAR)
    assert repo_html =~ ~s(data-confirm="Import this repository CAR)

    backup_html =
      admin_conn
      |> recycle()
      |> get(~p"/admin/backups")
      |> html_response(200)

    assert backup_html =~ ~s(id="admin-backup-create-form")
    assert backup_html =~ ~s(id="admin-backup-restore-form")
    assert backup_html =~ ~s(name="_csrf_token")
    assert backup_html =~ ~s(data-confirm="Create a service backup now?)
    assert backup_html =~ ~s(data-confirm="Run a restore dry-run)
  end

  test "admin operations are backed by context modules instead of internal xrpc calls" do
    source = File.read!("lib/tempest_web/controllers/admin_controller.ex")

    assert source =~ "Admin.RepoOps.verify"
    assert source =~ "Admin.RepoOps.export"
    assert source =~ "Admin.RepoOps.import"
    assert source =~ "Admin.Backup.create"
    refute source =~ "Req."
    refute source =~ ~s("/xrpc)
  end

  test "admin status reports database sequencer and blob store status", %{conn: conn} do
    Application.put_env(:tempest, :admin_token_hash, AdminAuth.hash_token("admin-secret-token"))

    {:ok, _session} =
      Accounts.create_account(%{
        "handle" => "admin-status-ok.test",
        "email" => "admin-status-ok@example.com",
        "password" => "correct horse battery staple"
      })

    conn =
      conn
      |> put_req_header("authorization", "Bearer admin-secret-token")
      |> get(~p"/xrpc/_admin/status")

    response = json_response(conn, 200)

    assert response["status"] == "ok"
    assert response["database"]["accountDb"]["exists"] == true
    assert is_integer(response["sequencer"]["currentSeq"])
    assert response["blobStore"]["accountCount"] >= 1
    assert [%{"did" => _, "repoCount" => 1} | _] = response["accounts"]
  end

  test "admin login stores only a browser admin session reference", %{conn: conn} do
    {:ok, account} =
      Accounts.create_account(%{
        "handle" => "admin-browser.test",
        "email" => "admin-browser@example.com",
        "password" => "correct horse battery staple"
      })

    configure_admin_did(account["did"])

    login_page =
      conn
      |> recycle()
      |> get(~p"/admin/login?#{[return_to: "/admin/storage"]}")
      |> html_response(200)

    assert login_page =~ ~s(id="admin-login-form")
    assert login_page =~ ~s(id="admin-login-close" href="/")
    assert login_page =~ ~s(id="admin-login-cancel" href="/")
    assert login_page =~ ~s(type="hidden" name="return_to" value="/admin/storage")
    assert login_page =~ ~s(/images/icons/lock-key.svg)
    assert login_page =~ account["did"]
    assert login_page =~ "local_account"

    login_conn =
      conn
      |> recycle()
      |> post(~p"/admin/login", %{
        "return_to" => "/admin/storage",
        "admin" => %{"identifier" => account["handle"], "password" => "correct horse battery staple"}
      })

    assert redirected_to(login_conn) == ~p"/admin/storage"
    assert is_integer(Plug.Conn.get_session(login_conn, :admin_session_id))
    assert is_binary(Plug.Conn.get_session(login_conn, :admin_session_family_id))
    assert Plug.Conn.get_session(login_conn, :admin_did) == account["did"]

    browser_session = Plug.Conn.get_session(login_conn)
    refute inspect(browser_session) =~ account["accessJwt"]
    refute inspect(browser_session) =~ account["refreshJwt"]

    html =
      login_conn
      |> recycle()
      |> get(~p"/admin/storage")
      |> html_response(200)

    assert html =~ "Storage Status"
  end

  test "external admin OAuth login stores only a server-side admin session reference", %{conn: conn} do
    admin_did = "did:plc:abcdefghijklmnopqrstuvwxyz234567"
    configure_admin_did(admin_did)

    Application.put_env(:tempest, Tempest.Identity,
      plc_directory_url: "https://plc.test",
      dns_lookup: &public_test_dns/1,
      http_req_options: [plug: {Req.Test, __MODULE__}]
    )

    Application.put_env(:tempest, AdminAuth, oauth_req_options: [plug: {Req.Test, __MODULE__}])

    Req.Test.stub(__MODULE__, fn req_conn ->
      case {req_conn.method, req_conn.request_path} do
        {"GET", "/did:plc:abcdefghijklmnopqrstuvwxyz234567"} ->
          Req.Test.json(req_conn, %{
            "id" => admin_did,
            "service" => [
              %{
                "id" => "#atproto_pds",
                "type" => "AtprotoPersonalDataServer",
                "serviceEndpoint" => "https://external-pds.test"
              }
            ]
          })

        {"GET", "/.well-known/oauth-protected-resource"} ->
          Req.Test.json(req_conn, %{"authorization_servers" => ["https://auth.test"]})

        {"GET", "/.well-known/oauth-authorization-server"} ->
          Req.Test.json(req_conn, %{"introspection_endpoint" => "https://auth.test/oauth/introspect"})

        {"POST", "/oauth/introspect"} ->
          Req.Test.json(req_conn, %{"active" => true, "sub" => admin_did, "scope" => "atproto"})
      end
    end)

    login_page =
      conn
      |> recycle()
      |> get(~p"/admin/login?#{[return_to: "/admin/accounts"]}")
      |> html_response(200)

    assert login_page =~ "OAuth access token"
    assert login_page =~ "oauth"

    login_conn =
      conn
      |> recycle()
      |> post(~p"/admin/login", %{
        "return_to" => "/admin/accounts",
        "admin" => %{"access_token" => "external-admin-oauth-token"}
      })

    assert redirected_to(login_conn) == ~p"/admin/accounts"
    assert is_binary(Plug.Conn.get_session(login_conn, :admin_session_id))
    assert is_binary(Plug.Conn.get_session(login_conn, :admin_session_family_id))
    assert Plug.Conn.get_session(login_conn, :admin_did) == admin_did

    browser_session = Plug.Conn.get_session(login_conn)
    refute inspect(browser_session) =~ "external-admin-oauth-token"

    html =
      login_conn
      |> recycle()
      |> get(~p"/admin/accounts")
      |> html_response(200)

    assert html =~ "Hosted Accounts"
  end

  test "admin login rejects non-admin account sessions", %{conn: conn} do
    {:ok, admin} =
      Accounts.create_account(%{
        "handle" => "configured-admin.test",
        "email" => "configured-admin@example.com",
        "password" => "correct horse battery staple"
      })

    {:ok, user} =
      Accounts.create_account(%{
        "handle" => "not-admin.test",
        "email" => "not-admin@example.com",
        "password" => "correct horse battery staple"
      })

    configure_admin_did(admin["did"])

    conn =
      post(conn, ~p"/admin/login", %{
        "admin" => %{"identifier" => user["handle"], "password" => "correct horse battery staple"}
      })

    html = html_response(conn, 401)
    assert html =~ "This account is not the configured admin DID."
    refute Plug.Conn.get_session(conn, :admin_session_id)
  end

  test "admin browser routes redirect to login when no browser session or bearer token exists", %{conn: conn} do
    conn = get(conn, ~p"/admin")
    assert redirected_to(conn) == ~p"/admin/login?#{[return_to: "/admin"]}"
  end

  test "admin bearer token remains available for automation status endpoint", %{conn: conn} do
    Application.put_env(:tempest, :admin_token_hash, AdminAuth.hash_token("admin-secret-token"))

    conn =
      conn
      |> put_req_header("authorization", "Bearer admin-secret-token")
      |> get(~p"/xrpc/_admin/status")

    assert json_response(conn, 200)["status"] == "ok"
  end

  test "account browser sessions cannot access admin pages", %{conn: conn} do
    {:ok, account} =
      Accounts.create_account(%{
        "handle" => "account-not-admin.test",
        "email" => "account-not-admin@example.com",
        "password" => "correct horse battery staple"
      })

    account_conn =
      conn
      |> recycle()
      |> post(~p"/account/login", %{
        "account" => %{"identifier" => account["handle"], "password" => "correct horse battery staple"}
      })

    admin_conn =
      account_conn
      |> recycle()
      |> get(~p"/admin")

    assert redirected_to(admin_conn) == ~p"/admin/login?#{[return_to: "/admin"]}"
  end

  test "admin browser sessions do not authorize account-only XRPC methods", %{conn: conn} do
    admin_conn = admin_login_conn(conn, "admin-not-account-xrpc.test", "admin-not-account-xrpc@example.com")

    xrpc_conn =
      admin_conn
      |> recycle()
      |> get(~p"/xrpc/com.atproto.server.getSession")

    assert json_response(xrpc_conn, 401)["error"] == "AuthenticationRequired"
  end

  defp configure_admin_did(did) do
    config =
      :tempest
      |> Application.fetch_env!(Tempest.Config)
      |> Keyword.put(:admin_did, did)

    Application.put_env(:tempest, Tempest.Config, config)
  end

  defp admin_login_conn(conn, handle, email) do
    {:ok, account} =
      Accounts.create_account(%{
        "handle" => handle,
        "email" => email,
        "password" => "correct horse battery staple"
      })

    configure_admin_did(account["did"])

    conn
    |> recycle()
    |> post(~p"/admin/login", %{
      "admin" => %{"identifier" => account["handle"], "password" => "correct horse battery staple"}
    })
  end

  defp public_test_dns("plc.test"), do: {:ok, [{93, 184, 216, 34}]}
  defp public_test_dns("external-pds.test"), do: {:ok, [{93, 184, 216, 34}]}
  defp public_test_dns("auth.test"), do: {:ok, [{93, 184, 216, 34}]}
  defp public_test_dns(_host), do: {:error, :nxdomain}
end
