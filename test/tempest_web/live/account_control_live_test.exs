defmodule TempestWeb.AccountControlLiveTest do
  use TempestWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  alias Tempest.Accounts
  alias Tempest.Accounts.AppPassword
  alias Tempest.Security
  alias Tempest.Security.Totp

  @password "correct horse battery staple"

  test "account browser login logout and protected LiveView access", %{conn: conn} do
    account = create_account!("account-live-auth.test", "account-live-auth@example.com")

    unauth_conn = get(conn, ~p"/account")
    assert redirected_to(unauth_conn) == ~p"/account/login?#{[return_to: "/account"]}"

    login_conn = login_conn(conn, account["handle"])
    assert redirected_to(login_conn) == ~p"/account"

    {:ok, view, _html} =
      login_conn
      |> recycle()
      |> live(~p"/account")

    assert has_element?(view, "#account-dashboard")
    assert has_element?(view, ~s(a#account-control-home[href="/"]))

    logout_conn =
      login_conn
      |> recycle()
      |> get(~p"/account/logout")

    assert redirected_to(logout_conn) == ~p"/"

    redirected_conn =
      logout_conn
      |> recycle()
      |> get(~p"/account")

    assert redirected_to(redirected_conn) == ~p"/account/login?#{[return_to: "/account"]}"
  end

  test "account LiveView pages render key panel IDs", %{conn: conn} do
    account = create_account!("account-live-routes.test", "account-live-routes@example.com")
    login_conn = login_conn(conn, account["handle"])

    for {path, selector} <- [
          {~p"/account", "#account-dashboard"},
          {~p"/account/repo", "#repo-browser"},
          {~p"/account/blobs", "#blob-browser"},
          {~p"/account/access", "#account-access"},
          {~p"/account/security", "#account-security"},
          {~p"/account/migration", "#account-migration"},
          {~p"/account/sequencer", "#sequencer-viewer"},
          {~p"/account/firehose", "#firehose-viewer"}
        ] do
      {:ok, view, _html} =
        login_conn
        |> recycle()
        |> live(path)

      assert has_element?(view, selector)
      assert has_element?(view, ~s(a#account-control-home[href="/"]))
    end
  end

  test "account sequencer page remains scoped to signed in account DID", %{conn: conn} do
    account = create_account!("account-live-seq.test", "account-live-seq@example.com")
    login_conn = login_conn(conn, account["handle"])

    {:ok, view, html} =
      login_conn
      |> recycle()
      |> live(~p"/account/sequencer?#{[did: "did:plc:other", type: "#commit"]}")

    assert has_element?(view, "#account-sequencer-filter input[name='did'][readonly]")
    assert html =~ account["did"]
    refute html =~ "did:plc:other"
  end

  test "account access and security pages do not render stored or one-time secrets", %{conn: conn} do
    account = create_account!("account-live-redact.test", "account-live-redact@example.com")
    account_record = Tempest.Repo.get_by!(Tempest.Accounts.Account, did: account["did"])

    app_password_secret = create_app_password!(conn, account["accessJwt"])
    app_password = Tempest.Repo.get_by!(AppPassword, account_id: account_record.id, name: "redaction")

    {:ok, %{credential: credential, secret: totp_secret, uri: totp_uri}} =
      Security.start_totp_enrollment(account_record)

    assert {:ok, %{backup_codes: backup_codes}} =
             Security.confirm_totp(account_record, credential.id, Totp.code(totp_secret))

    [backup_code | _rest] = backup_codes
    login_conn = login_conn(conn, account["handle"])

    {:ok, access_view, access_html} =
      login_conn
      |> recycle()
      |> live(~p"/account/access")

    assert has_element?(access_view, "#account-app-passwords")
    assert access_html =~ "redaction"
    refute access_html =~ app_password_secret
    refute access_html =~ app_password.token_hash

    {:ok, security_view, security_html} =
      login_conn
      |> recycle()
      |> live(~p"/account/security")

    assert has_element?(security_view, "#account-mfa-credentials")
    assert has_element?(security_view, "#account-backup-codes")
    refute security_html =~ account_record.password_hash
    refute security_html =~ totp_secret
    refute security_html =~ totp_uri
    refute security_html =~ backup_code
  end

  defp create_account!(handle, email) do
    {:ok, account} =
      Accounts.create_account(%{
        "handle" => handle,
        "email" => email,
        "password" => @password
      })

    account
  end

  defp create_app_password!(conn, access_jwt) do
    conn
    |> recycle()
    |> put_req_header("authorization", "Bearer #{access_jwt}")
    |> put_req_header("content-type", "application/json")
    |> post(~p"/xrpc/com.atproto.server.createAppPassword", %{"name" => "redaction", "scope" => "atproto"})
    |> json_response(200)
    |> Map.fetch!("password")
  end

  defp login_conn(conn, handle) do
    post(conn, ~p"/account/login", %{
      "account" => %{"identifier" => handle, "password" => @password}
    })
  end
end
