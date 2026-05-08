defmodule TempestWeb.Xrpc.AccountsSessionsTest do
  use TempestWeb.ConnCase, async: false

  alias Tempest.Accounts.{Session, Tokens}
  alias Tempest.Repo

  import Ecto.Query

  @password "correct horse battery staple"

  test "createAccount persists account and returns session tokens", %{conn: conn} do
    conn = create_account(conn, "alice.test", "alice@example.com")

    response = json_response(conn, 200)

    assert response["did"] =~ "did:tempest:"
    assert response["handle"] == "alice.test"
    assert response["email"] == "alice@example.com"
    assert response["active"] == true
    assert is_binary(response["accessJwt"])
    assert is_binary(response["refreshJwt"])

    assert Repo.exists?(from a in Tempest.Accounts.Account, where: a.handle == "alice.test")
  end

  test "createSession logs in and getSession returns the account", %{conn: conn} do
    create_account(conn, "bob.test", "bob@example.com")

    login_conn = create_session(conn, "bob.test", @password)
    login = json_response(login_conn, 200)

    assert is_binary(login["accessJwt"])
    assert is_binary(login["refreshJwt"])

    session_conn =
      conn
      |> put_req_header("authorization", "Bearer #{login["accessJwt"]}")
      |> get(~p"/xrpc/com.atproto.server.getSession")

    session = json_response(session_conn, 200)

    assert session["did"] == login["did"]
    assert session["handle"] == "bob.test"
    refute Map.has_key?(session, "password_hash")
    refute Map.has_key?(session, "refreshJwt")
  end

  test "refreshSession rotates refresh tokens", %{conn: conn} do
    create_account(conn, "carol.test", "carol@example.com")
    login = conn |> create_session("carol.test", @password) |> json_response(200)

    refresh_conn =
      conn
      |> put_req_header("authorization", "Bearer #{login["refreshJwt"]}")
      |> post(~p"/xrpc/com.atproto.server.refreshSession")

    refreshed = json_response(refresh_conn, 200)

    assert refreshed["handle"] == "carol.test"
    assert refreshed["accessJwt"] != login["accessJwt"]
    assert refreshed["refreshJwt"] != login["refreshJwt"]

    old_session = Repo.get_by!(Session, token_hash: Tokens.refresh_token_hash(login["refreshJwt"]))
    new_session = Repo.get_by!(Session, token_hash: Tokens.refresh_token_hash(refreshed["refreshJwt"]))

    assert old_session.rotated_at
    assert old_session.revoked_at
    assert is_nil(new_session.revoked_at)
    assert old_session.family_id == new_session.family_id
  end

  test "deleteSession prevents future refresh", %{conn: conn} do
    create_account(conn, "dana.test", "dana@example.com")
    login = conn |> create_session("dana.test", @password) |> json_response(200)

    delete_conn =
      conn
      |> put_req_header("authorization", "Bearer #{login["refreshJwt"]}")
      |> post(~p"/xrpc/com.atproto.server.deleteSession")

    assert json_response(delete_conn, 200) == %{}

    refresh_conn =
      conn
      |> put_req_header("authorization", "Bearer #{login["refreshJwt"]}")
      |> post(~p"/xrpc/com.atproto.server.refreshSession")

    response = json_response(refresh_conn, 401)

    assert response["error"] == "InvalidToken"
  end

  test "protected endpoint rejects missing bearer token", %{conn: conn} do
    conn = get(conn, ~p"/xrpc/com.atproto.server.getSession")
    response = json_response(conn, 401)

    assert response["error"] == "AuthenticationRequired"
  end

  test "createSession rejects wrong password", %{conn: conn} do
    create_account(conn, "erin.test", "erin@example.com")

    conn = create_session(conn, "erin.test", "not the password")
    response = json_response(conn, 401)

    assert response["error"] == "AuthenticationRequired"
  end

  test "reused refresh token revokes the session family", %{conn: conn} do
    create_account(conn, "faye.test", "faye@example.com")
    login = conn |> create_session("faye.test", @password) |> json_response(200)

    refreshed =
      conn
      |> put_req_header("authorization", "Bearer #{login["refreshJwt"]}")
      |> post(~p"/xrpc/com.atproto.server.refreshSession")
      |> json_response(200)

    reuse_conn =
      conn
      |> put_req_header("authorization", "Bearer #{login["refreshJwt"]}")
      |> post(~p"/xrpc/com.atproto.server.refreshSession")

    assert %{"error" => "InvalidToken"} = json_response(reuse_conn, 401)

    family_id =
      Session
      |> where([s], s.token_hash == ^Tokens.refresh_token_hash(refreshed["refreshJwt"]))
      |> select([s], s.family_id)
      |> Repo.one!()

    assert Repo.aggregate(from(s in Session, where: s.family_id == ^family_id and is_nil(s.revoked_at)), :count) == 0
  end

  defp create_account(conn, handle, email) do
    conn
    |> put_req_header("content-type", "application/json")
    |> post(~p"/xrpc/com.atproto.server.createAccount", %{
      "handle" => handle,
      "email" => email,
      "password" => @password
    })
  end

  defp create_session(conn, identifier, password) do
    conn
    |> put_req_header("content-type", "application/json")
    |> post(~p"/xrpc/com.atproto.server.createSession", %{
      "identifier" => identifier,
      "password" => password
    })
  end
end
