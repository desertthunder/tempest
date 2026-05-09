defmodule TempestWeb.Xrpc.RecordsTest do
  use TempestWeb.ConnCase, async: false

  alias Tempest.RepoCore.{Car, Drisl}

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
    assert sequencer_event_count(account["did"], "#commit", "create") == 1
    assert_commit_event_car_slice(account["did"], commit_cid, response["cid"])

    get_conn =
      conn
      |> recycle()
      |> get(~p"/xrpc/com.atproto.repo.getRecord", %{
        "repo" => "records-alice.test",
        "collection" => "app.bsky.actor.profile",
        "rkey" => "self"
      })

    get_response = json_response(get_conn, 200)
    assert get_response["uri"] == response["uri"]
    assert get_response["cid"] == response["cid"]
    assert get_response["value"]["displayName"] == "Alice"

    list_conn =
      conn
      |> recycle()
      |> get(~p"/xrpc/com.atproto.repo.listRecords", %{
        "repo" => account["did"],
        "collection" => "app.bsky.actor.profile"
      })

    list_response = json_response(list_conn, 200)
    assert [listed] = list_response["records"]
    assert listed["uri"] == response["uri"]
    assert listed["cid"] == response["cid"]
    assert listed["value"]["displayName"] == "Alice"

    describe_conn =
      conn
      |> recycle()
      |> get(~p"/xrpc/com.atproto.repo.describeRepo", %{"repo" => account["did"]})

    describe_response = json_response(describe_conn, 200)
    assert describe_response["did"] == account["did"]
    assert describe_response["handle"] == "records-alice.test"
    assert describe_response["didDoc"]["id"] == account["did"]
    assert describe_response["collections"] == ["app.bsky.actor.profile"]
    assert describe_response["handleIsCorrect"] == true
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

  test "putRecord enforces swapRecord and swapCommit before replacing a record", %{conn: conn} do
    account = create_account!(conn, "records-erin.test", "records-erin@example.com")
    created = create_profile!(conn, account, "Erin")

    wrong_swap_conn =
      conn
      |> auth_json(account)
      |> post(~p"/xrpc/com.atproto.repo.putRecord", %{
        "repo" => account["did"],
        "collection" => "app.bsky.actor.profile",
        "rkey" => "self",
        "swapRecord" => created["commit"]["cid"],
        "record" => %{
          "$type" => "app.bsky.actor.profile",
          "displayName" => "Erin Updated"
        }
      })

    assert %{"error" => "InvalidSwap"} = json_response(wrong_swap_conn, 409)

    put_conn =
      conn
      |> auth_json(account)
      |> post(~p"/xrpc/com.atproto.repo.putRecord", %{
        "repo" => account["did"],
        "collection" => "app.bsky.actor.profile",
        "rkey" => "self",
        "swapRecord" => created["cid"],
        "swapCommit" => created["commit"]["cid"],
        "record" => %{
          "$type" => "app.bsky.actor.profile",
          "displayName" => "Erin Updated"
        }
      })

    updated = json_response(put_conn, 200)
    assert updated["uri"] == created["uri"]
    assert updated["cid"] != created["cid"]
    assert updated["commit"]["cid"] != created["commit"]["cid"]
    assert updated["validationStatus"] == "valid"

    get_conn =
      conn
      |> recycle()
      |> get(~p"/xrpc/com.atproto.repo.getRecord", %{
        "repo" => account["did"],
        "collection" => "app.bsky.actor.profile",
        "rkey" => "self"
      })

    assert json_response(get_conn, 200)["value"]["displayName"] == "Erin Updated"
    assert sequencer_event_count(account["did"], "#commit", "update") == 1
  end

  test "deleteRecord removes current record from getRecord and listRecords", %{conn: conn} do
    account = create_account!(conn, "records-finn.test", "records-finn@example.com")
    created = create_profile!(conn, account, "Finn")

    delete_conn =
      conn
      |> auth_json(account)
      |> post(~p"/xrpc/com.atproto.repo.deleteRecord", %{
        "repo" => account["did"],
        "collection" => "app.bsky.actor.profile",
        "rkey" => "self",
        "swapRecord" => created["cid"],
        "swapCommit" => created["commit"]["cid"]
      })

    deleted = json_response(delete_conn, 200)
    assert deleted["commit"]["cid"] != created["commit"]["cid"]

    get_conn =
      conn
      |> recycle()
      |> get(~p"/xrpc/com.atproto.repo.getRecord", %{
        "repo" => account["did"],
        "collection" => "app.bsky.actor.profile",
        "rkey" => "self"
      })

    assert %{"error" => "RecordNotFound"} = json_response(get_conn, 400)

    list_conn =
      conn
      |> recycle()
      |> get(~p"/xrpc/com.atproto.repo.listRecords", %{
        "repo" => account["did"],
        "collection" => "app.bsky.actor.profile"
      })

    assert json_response(list_conn, 200)["records"] == []
    assert scalar(repo_db(account["did"]), "SELECT COUNT(*) FROM records") == 0
    assert sequencer_event_count(account["did"], "#commit", "delete") == 1

    absent_delete_conn =
      conn
      |> auth_json(account)
      |> post(~p"/xrpc/com.atproto.repo.deleteRecord", %{
        "repo" => account["did"],
        "collection" => "app.bsky.actor.profile",
        "rkey" => "self",
        "swapRecord" => created["cid"],
        "swapCommit" => created["commit"]["cid"]
      })

    refute Map.has_key?(json_response(absent_delete_conn, 200), "commit")
    assert sequencer_event_count(account["did"], "#commit", "delete") == 1
  end

  test "listRecords paginates within a collection", %{conn: conn} do
    account = create_account!(conn, "records-gia.test", "records-gia@example.com")

    create_note!(conn, account, "a", "first")
    create_note!(conn, account, "b", "second")
    create_note!(conn, account, "c", "third")

    first_page_conn =
      conn
      |> recycle()
      |> get(~p"/xrpc/com.atproto.repo.listRecords", %{
        "repo" => account["did"],
        "collection" => "app.tempest.note",
        "limit" => "2"
      })

    first_page = json_response(first_page_conn, 200)

    assert Enum.map(first_page["records"], & &1["uri"]) == [
             "at://#{account["did"]}/app.tempest.note/a",
             "at://#{account["did"]}/app.tempest.note/b"
           ]

    assert first_page["cursor"] == "b"

    second_page_conn =
      conn
      |> recycle()
      |> get(~p"/xrpc/com.atproto.repo.listRecords", %{
        "repo" => account["did"],
        "collection" => "app.tempest.note",
        "limit" => "2",
        "cursor" => first_page["cursor"]
      })

    second_page = json_response(second_page_conn, 200)
    assert Enum.map(second_page["records"], & &1["uri"]) == ["at://#{account["did"]}/app.tempest.note/c"]
    refute Map.has_key?(second_page, "cursor")

    reverse_conn =
      conn
      |> recycle()
      |> get(~p"/xrpc/com.atproto.repo.listRecords", %{
        "repo" => account["did"],
        "collection" => "app.tempest.note",
        "limit" => "2",
        "reverse" => "true"
      })

    reverse_page = json_response(reverse_conn, 200)

    assert Enum.map(reverse_page["records"], & &1["uri"]) == [
             "at://#{account["did"]}/app.tempest.note/c",
             "at://#{account["did"]}/app.tempest.note/b"
           ]
  end

  test "records survive storage bootstrap and repository reopen", %{conn: conn} do
    account = create_account!(conn, "records-hana.test", "records-hana@example.com")
    created = create_profile!(conn, account, "Hana")

    :ok =
      Tempest.Config.load!()
      |> Tempest.Storage.bootstrap!()

    get_conn =
      conn
      |> recycle()
      |> get(~p"/xrpc/com.atproto.repo.getRecord", %{
        "repo" => account["did"],
        "collection" => "app.bsky.actor.profile",
        "rkey" => "self"
      })

    response = json_response(get_conn, 200)
    assert response["uri"] == created["uri"]
    assert response["cid"] == created["cid"]
    assert response["value"]["displayName"] == "Hana"
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

  defp auth_json(conn, account) do
    conn
    |> recycle()
    |> put_req_header("authorization", "Bearer #{account["accessJwt"]}")
    |> put_req_header("content-type", "application/json")
  end

  defp create_profile!(conn, account, display_name) do
    conn
    |> auth_json(account)
    |> post(~p"/xrpc/com.atproto.repo.createRecord", profile_params(account["did"], display_name))
    |> json_response(200)
  end

  defp create_note!(conn, account, rkey, text) do
    conn
    |> auth_json(account)
    |> post(~p"/xrpc/com.atproto.repo.createRecord", %{
      "repo" => account["did"],
      "collection" => "app.tempest.note",
      "rkey" => rkey,
      "validate" => false,
      "record" => %{
        "$type" => "app.tempest.note",
        "text" => text
      }
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

  defp sequencer_event_count(did, event_type, action) do
    {:ok, events} = Tempest.Sequencer.list_after(0, did: did)

    Enum.count(events, fn event ->
      event.did == did and event.event_type == event_type and event.payload["action"] == action
    end)
  end

  defp assert_commit_event_car_slice(did, commit_cid, record_cid) do
    {:ok, events} = Tempest.Sequencer.list_after(0, did: did)

    event =
      Enum.find(events, fn event ->
        event.event_type == "#commit" and event.commit_cid == commit_cid
      end)

    assert %Drisl.Bytes{bytes: car_bytes} = event.payload["blocks"]
    assert {:ok, car} = Car.decode(car_bytes)
    assert Enum.map(car.roots, &Tempest.RepoCore.Cid.to_string/1) == [commit_cid]
    assert Enum.any?(car.blocks, &(Tempest.RepoCore.Cid.to_string(&1.cid) == record_cid))
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
