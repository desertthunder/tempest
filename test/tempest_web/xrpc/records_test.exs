defmodule TempestWeb.Xrpc.RecordsTest do
  use TempestWeb.ConnCase, async: false

  @password "correct horse battery staple"

  setup context do
    Tempest.LexiconFixtures.install!(context)
  end

  test "createRecord persists a profile record and advances repo commit", %{conn: conn} do
    account = create_account!(conn, "records-alice.test", "records-alice@example.com")

    create_conn =
      conn
      |> recycle()
      |> put_req_header("authorization", "Bearer #{account["accessJwt"]}")
      |> put_req_header("content-type", "application/json")
      |> post(~p"/xrpc/com.atproto.repo.createRecord", %{
        "repo" => "records-alice.test",
        "collection" => "app.bsky.actor.profile",
        "rkey" => "self",
        "record" => %{
          "$type" => "app.bsky.actor.profile",
          "displayName" => "Alice"
        }
      })

    response = json_response(create_conn, 200)

    assert response["uri"] == "at://#{account["did"]}/app.bsky.actor.profile/self"
    assert response["cid"] =~ "b"
    assert %{"cid" => commit_cid, "rev" => rev} = response["commit"]
    assert response["validationStatus"] == "valid"

    repo_db = repo_db(account["did"])
    assert scalar(repo_db, "SELECT COUNT(*) FROM records") == 1
    assert scalar(repo_db, "SELECT COUNT(*) FROM commits") == 2
    assert metadata(repo_db)["current_commit_cid"] == commit_cid
    assert metadata(repo_db)["current_rev"] == rev
    assert sequencer_event_count(account["did"], "repo.record.create") == 1
  end

  test "createRecord rejects duplicate rkey with conflict", %{conn: conn} do
    account = create_account!(conn, "records-bob.test", "records-bob@example.com")
    params = profile_params("records-bob.test", "Bob")

    first_conn =
      conn
      |> recycle()
      |> put_req_header("authorization", "Bearer #{account["accessJwt"]}")
      |> put_req_header("content-type", "application/json")
      |> post(~p"/xrpc/com.atproto.repo.createRecord", params)

    assert json_response(first_conn, 200)

    duplicate_conn =
      conn
      |> recycle()
      |> put_req_header("authorization", "Bearer #{account["accessJwt"]}")
      |> put_req_header("content-type", "application/json")
      |> post(~p"/xrpc/com.atproto.repo.createRecord", params)

    response = json_response(duplicate_conn, 409)

    assert response["error"] == "InvalidRequest"
    assert response["message"] =~ "already exists"
    assert scalar(repo_db(account["did"]), "SELECT COUNT(*) FROM records") == 1
  end

  test "createRecord enforces record validation boundary", %{conn: conn} do
    account = create_account!(conn, "records-cara.test", "records-cara@example.com")

    bad_conn =
      conn
      |> recycle()
      |> put_req_header("authorization", "Bearer #{account["accessJwt"]}")
      |> put_req_header("content-type", "application/json")
      |> post(~p"/xrpc/com.atproto.repo.createRecord", %{
        "repo" => account["did"],
        "collection" => "app.bsky.actor.profile",
        "rkey" => "self",
        "record" => %{
          "$type" => "app.bsky.actor.profile",
          "displayName" => 123
        }
      })

    response = json_response(bad_conn, 400)

    assert response["error"] == "InvalidRequest"
    assert response["message"] =~ "displayName"
  end

  test "createRecord rejects writes to another repo", %{conn: conn} do
    account = create_account!(conn, "records-dana.test", "records-dana@example.com")

    denied_conn =
      conn
      |> recycle()
      |> put_req_header("authorization", "Bearer #{account["accessJwt"]}")
      |> put_req_header("content-type", "application/json")
      |> post(~p"/xrpc/com.atproto.repo.createRecord", profile_params("other.test", "Dana"))

    assert %{"error" => "InvalidRequest"} = json_response(denied_conn, 400)
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

  defp profile_params(repo, display_name) do
    %{
      "repo" => repo,
      "collection" => "app.bsky.actor.profile",
      "rkey" => "self",
      "record" => %{
        "$type" => "app.bsky.actor.profile",
        "displayName" => display_name
      }
    }
  end

  defp repo_db(did) do
    Tempest.Config.load!()
    |> Tempest.Config.repo_db_path(did)
  end

  defp metadata(path) do
    path
    |> fetch_all("SELECT key, value FROM repo_metadata")
    |> Map.new(fn [key, value] -> {key, value} end)
  end

  defp scalar(path, sql) do
    [[value]] = fetch_all(path, sql)
    value
  end

  defp sequencer_event_count(did, event_type) do
    path =
      Tempest.Config.load!()
      |> Tempest.Config.sequencer_db_path()

    {:ok, conn} = Exqlite.Sqlite3.open(path)
    {:ok, statement} = Exqlite.Sqlite3.prepare(conn, "SELECT COUNT(*) FROM repo_seq WHERE did = ?1 AND event_type = ?2")
    :ok = Exqlite.Sqlite3.bind(statement, [did, event_type])
    {:ok, [[count]]} = Exqlite.Sqlite3.fetch_all(conn, statement)
    :ok = Exqlite.Sqlite3.release(conn, statement)
    :ok = Exqlite.Sqlite3.close(conn)
    count
  end

  defp fetch_all(path, sql) do
    {:ok, conn} = Exqlite.Sqlite3.open(path)
    {:ok, statement} = Exqlite.Sqlite3.prepare(conn, sql)
    {:ok, rows} = Exqlite.Sqlite3.fetch_all(conn, statement)
    :ok = Exqlite.Sqlite3.release(conn, statement)
    :ok = Exqlite.Sqlite3.close(conn)
    rows
  end
end
