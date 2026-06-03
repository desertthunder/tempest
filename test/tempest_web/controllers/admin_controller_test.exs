defmodule TempestWeb.AdminControllerTest do
  use TempestWeb.ConnCase

  alias Tempest.{Accounts, AdminAuth}

  setup do
    old_hash = Application.get_env(:tempest, :admin_token_hash)

    on_exit(fn ->
      if old_hash do
        Application.put_env(:tempest, :admin_token_hash, old_hash)
      else
        Application.delete_env(:tempest, :admin_token_hash)
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
end
