defmodule TempestWeb.OperatorAccountControllerTest do
  use TempestWeb.ConnCase, async: false

  @password "correct horse battery staple"

  test "account UX requires an account bearer token and renders account tools", %{conn: conn} do
    account = create_account!(conn, "account-ux.test", "account-ux@example.com")

    unauth_conn = get(conn, ~p"/account")
    assert redirected_to(unauth_conn) == ~p"/account/login?#{[return_to: "/account"]}"

    create_conn =
      conn
      |> recycle()
      |> put_req_header("authorization", "Bearer #{account["accessJwt"]}")
      |> put_req_header("content-type", "application/json")
      |> post(~p"/xrpc/com.atproto.repo.createRecord", %{
        "repo" => account["did"],
        "collection" => "app.bsky.actor.profile",
        "rkey" => "self",
        "record" => %{"$type" => "app.bsky.actor.profile", "displayName" => "Account UX"}
      })

    assert %{"cid" => _cid} = json_response(create_conn, 200)

    assert_authed_html(conn, account, ~p"/account", "Account Control Panel")
    assert_authed_html(conn, account, ~p"/account/repo", "app.bsky.actor.profile/self")
    assert_authed_html(conn, account, ~p"/account/blobs", "Blob Browser")
    assert_authed_html(conn, account, ~p"/account/access", "Sessions and Delegated Access")
    assert_authed_html(conn, account, ~p"/account/security", "Email, Password, MFA, and Devices")
    assert_authed_html(conn, account, ~p"/account/migration", "Account Migration Status")
    assert_authed_html(conn, account, ~p"/account/sequencer", "Sequencer Viewer")
    assert_authed_html(conn, account, ~p"/account/firehose", "Firehose Viewer")
  end

  test "account login stores only a browser session reference and authorizes account pages", %{conn: conn} do
    account = create_account!(conn, "browser-account.test", "browser-account@example.com")

    login_page =
      conn
      |> recycle()
      |> get(~p"/account/login?#{[return_to: "/account/repo"]}")
      |> html_response(200)

    assert login_page =~ ~s(id="account-login-form")
    assert login_page =~ ~s(id="account-login-close")
    assert login_page =~ ~s(href="/account/repo")
    assert login_page =~ ~s(/images/icons/lock-key.svg)

    login_conn =
      conn
      |> recycle()
      |> post(~p"/account/login", %{
        "return_to" => "/account/repo",
        "account" => %{"identifier" => account["handle"], "password" => @password}
      })

    assert redirected_to(login_conn) == ~p"/account/repo"

    browser_session = Plug.Conn.get_session(login_conn)
    assert is_integer(Plug.Conn.get_session(login_conn, :account_session_id))
    assert is_binary(Plug.Conn.get_session(login_conn, :account_session_family_id))
    assert Plug.Conn.get_session(login_conn, :account_did) == account["did"]
    refute Map.has_key?(browser_session, :accessJwt)
    refute Map.has_key?(browser_session, :refreshJwt)
    refute inspect(browser_session) =~ account["accessJwt"]
    refute inspect(browser_session) =~ account["refreshJwt"]

    html =
      login_conn
      |> recycle()
      |> get(~p"/account/repo")
      |> html_response(200)

    assert html =~ "Repo Browser"
    assert html =~ account["did"]
  end

  test "account logout clears browser-session access", %{conn: conn} do
    account = create_account!(conn, "logout-account.test", "logout-account@example.com")

    login_conn =
      conn
      |> recycle()
      |> post(~p"/account/login", %{
        "account" => %{"identifier" => account["handle"], "password" => @password}
      })

    assert redirected_to(login_conn) == ~p"/account"

    logout_conn =
      login_conn
      |> recycle()
      |> get(~p"/account/logout?#{[return_to: "/stats"]}")

    assert redirected_to(logout_conn) == ~p"/stats"

    redirected_conn =
      logout_conn
      |> recycle()
      |> get(~p"/account")

    assert redirected_to(redirected_conn) == ~p"/account/login?#{[return_to: "/account"]}"
  end

  defp assert_authed_html(conn, account, path, expected) do
    html =
      conn
      |> recycle()
      |> put_req_header("authorization", "Bearer #{account["accessJwt"]}")
      |> get(path)
      |> html_response(200)

    assert html =~ expected
    assert html =~ account["did"]
  end

  defp create_account!(conn, handle, email) do
    conn
    |> put_req_header("content-type", "application/json")
    |> post(~p"/xrpc/com.atproto.server.createAccount", %{
      "handle" => handle,
      "email" => email,
      "password" => @password
    })
    |> json_response(200)
  end
end
