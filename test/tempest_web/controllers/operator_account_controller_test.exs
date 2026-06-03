defmodule TempestWeb.OperatorAccountControllerTest do
  use TempestWeb.ConnCase, async: false

  @password "correct horse battery staple"

  test "account UX requires an account bearer token and renders account tools", %{conn: conn} do
    account = create_account!(conn, "account-ux.test", "account-ux@example.com")

    unauth_conn = get(conn, ~p"/account")
    assert json_response(unauth_conn, 401)["error"] == "AuthenticationRequired"

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

    assert_authed_html(conn, account, ~p"/account", "Operator Account")
    assert_authed_html(conn, account, ~p"/account/repo", "app.bsky.actor.profile/self")
    assert_authed_html(conn, account, ~p"/account/blobs", "Blob Browser")
    assert_authed_html(conn, account, ~p"/account/access", "Sessions and Delegated Access")
    assert_authed_html(conn, account, ~p"/account/security", "Email, Password, MFA, and Devices")
    assert_authed_html(conn, account, ~p"/account/migration", "Account Migration Status")
    assert_authed_html(conn, account, ~p"/account/sequencer", "Sequencer Viewer")
    assert_authed_html(conn, account, ~p"/account/firehose", "Firehose Viewer")
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
