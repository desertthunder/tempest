defmodule TempestWeb.AdminControllerTest do
  use TempestWeb.ConnCase

  alias Tempest.{Accounts, AdminAuth}

  setup do
    old_hash = Application.get_env(:tempest, :admin_token_hash)
    old_config = Application.get_env(:tempest, Tempest.Config)

    on_exit(fn ->
      if old_hash do
        Application.put_env(:tempest, :admin_token_hash, old_hash)
      else
        Application.delete_env(:tempest, :admin_token_hash)
      end

      Application.put_env(:tempest, Tempest.Config, old_config)
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
          {~p"/admin/invites", "Invite Code Management"},
          {~p"/admin/repo", "Repo Verify, Export, and Import"},
          {~p"/admin/backups", "Backup Create and Restore Dry Run"},
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
end
