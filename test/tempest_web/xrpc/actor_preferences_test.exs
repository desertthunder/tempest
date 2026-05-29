defmodule TempestWeb.Xrpc.ActorPreferencesTest do
  use TempestWeb.ConnCase, async: false

  @password "correct horse battery staple"

  test "getPreferences and putPreferences round-trip private account preferences", %{conn: conn} do
    account = create_account!(conn, "prefs-alice.test", "prefs-alice@example.com")

    empty_conn =
      conn
      |> auth(account)
      |> get(~p"/xrpc/app.bsky.actor.getPreferences")

    assert json_response(empty_conn, 200) == %{"preferences" => []}

    preferences = [
      %{"$type" => "app.bsky.actor.defs#adultContentPref", "enabled" => true},
      %{"$type" => "app.bsky.actor.defs#savedFeedsPrefV2", "items" => []}
    ]

    put_conn =
      conn
      |> auth_json(account)
      |> post(~p"/xrpc/app.bsky.actor.putPreferences", %{"preferences" => preferences})

    assert json_response(put_conn, 200) == %{}

    get_conn =
      conn
      |> auth(account)
      |> get(~p"/xrpc/app.bsky.actor.getPreferences")

    assert json_response(get_conn, 200) == %{"preferences" => preferences}
  end

  test "putPreferences rejects non-array payloads", %{conn: conn} do
    account = create_account!(conn, "prefs-bob.test", "prefs-bob@example.com")

    rejected_conn =
      conn
      |> auth_json(account)
      |> post(~p"/xrpc/app.bsky.actor.putPreferences", %{"preferences" => %{}})

    assert %{"error" => "InvalidRequest"} = json_response(rejected_conn, 400)
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

  defp auth(conn, account) do
    conn
    |> recycle()
    |> put_req_header("authorization", "Bearer #{account["accessJwt"]}")
  end

  defp auth_json(conn, account) do
    conn
    |> auth(account)
    |> put_req_header("content-type", "application/json")
  end
end
