defmodule TempestWeb.Xrpc.SyncReadsTest do
  use TempestWeb.ConnCase, async: false

  import Ecto.Query
  import ExUnit.CaptureLog

  alias Tempest.Accounts.Account
  alias Tempest.Repo
  alias Tempest.RepoCore.{Car, CarVerifier, Cid, Drisl}

  @password "correct horse battery staple"

  setup context do
    Tempest.LexiconFixtures.install!(context)
    Req.Test.set_req_test_from_context(context)
    Req.Test.verify_on_exit!(context)

    old_sync_config = Application.get_env(:tempest, Tempest.Sync, [])
    old_blob_config = Application.get_env(:tempest, Tempest.Blobs, [])

    on_exit(fn ->
      Application.put_env(:tempest, Tempest.Sync, old_sync_config)
      Application.put_env(:tempest, Tempest.Blobs, old_blob_config)
      clear_request_crawl_rate_limits()
    end)

    clear_request_crawl_rate_limits()
  end

  test "getRepo exports a CAR rooted at the latest commit", %{conn: conn} do
    account = create_account!(conn, "sync-alice.test", "sync-alice@example.com")
    created = create_profile!(conn, account, "Alice")

    latest_conn =
      conn
      |> recycle()
      |> get(~p"/xrpc/com.atproto.sync.getLatestCommit", %{"did" => account["did"]})

    latest = json_response(latest_conn, 200)
    assert latest == created["commit"]

    repo_conn =
      conn
      |> recycle()
      |> get(~p"/xrpc/com.atproto.sync.getRepo", %{"did" => account["did"]})

    assert get_resp_header(repo_conn, "content-type") == ["application/vnd.ipld.car; charset=utf-8"]
    assert {:ok, car} = Car.decode(repo_conn.resp_body)
    assert car.roots == [Cid.parse!(latest["cid"])]
    assert Enum.any?(car.blocks, &(Cid.to_string(&1.cid) == created["cid"]))

    assert {:ok, verified} = CarVerifier.verify_repo_car(repo_conn.resp_body, did: account["did"])
    assert verified.commit_cid == Cid.parse!(latest["cid"])
    assert Map.fetch!(verified.entries, "app.bsky.actor.profile/self") == Cid.parse!(created["cid"])
  end

  test "sync getRecord returns a CAR for an existing record", %{conn: conn} do
    account = create_account!(conn, "sync-bob.test", "sync-bob@example.com")
    created = create_profile!(conn, account, "Bob")
    other = create_note!(conn, account, "first", "not part of the selected record read")

    record_conn =
      conn
      |> recycle()
      |> get(~p"/xrpc/com.atproto.sync.getRecord", %{
        "did" => account["did"],
        "collection" => "app.bsky.actor.profile",
        "rkey" => "self"
      })

    assert get_resp_header(record_conn, "content-type") == ["application/vnd.ipld.car; charset=utf-8"]
    assert {:ok, car} = Car.decode(record_conn.resp_body)
    assert car.roots == [Cid.parse!(other["commit"]["cid"])]
    assert Enum.any?(car.blocks, &(Cid.to_string(&1.cid) == created["cid"]))
    refute Enum.any?(car.blocks, &(Cid.to_string(&1.cid) == other["cid"]))
  end

  test "sync getRecord can read records at a historical commit", %{conn: conn} do
    account = create_account!(conn, "sync-bea.test", "sync-bea@example.com")
    created = create_profile!(conn, account, "Bea")
    updated = put_profile!(conn, account, created, "Bea Updated")

    current_conn =
      conn
      |> recycle()
      |> get(~p"/xrpc/com.atproto.sync.getRecord", %{
        "did" => account["did"],
        "collection" => "app.bsky.actor.profile",
        "rkey" => "self"
      })

    assert {:ok, current_car} = Car.decode(current_conn.resp_body)
    assert current_car.roots == [Cid.parse!(updated["commit"]["cid"])]
    assert Enum.any?(current_car.blocks, &(Cid.to_string(&1.cid) == updated["cid"]))
    refute Enum.any?(current_car.blocks, &(Cid.to_string(&1.cid) == created["cid"]))

    historical_conn =
      conn
      |> recycle()
      |> get(~p"/xrpc/com.atproto.sync.getRecord", %{
        "did" => account["did"],
        "collection" => "app.bsky.actor.profile",
        "rkey" => "self",
        "commit" => created["commit"]["cid"]
      })

    assert {:ok, historical_car} = Car.decode(historical_conn.resp_body)
    assert historical_car.roots == [Cid.parse!(created["commit"]["cid"])]
    assert Enum.any?(historical_car.blocks, &(Cid.to_string(&1.cid) == created["cid"]))
    refute Enum.any?(historical_car.blocks, &(Cid.to_string(&1.cid) == updated["cid"]))
  end

  test "sync getRecord traverses nested MST nodes for current and historical reads", %{conn: conn} do
    account = create_account!(conn, "sync-nested.test", "sync-nested@example.com")
    target = create_note!(conn, account, "YR", "target before update")

    neighboring_records =
      for rkey <- ["5", "1D", "8A", "1UF"] do
        create_note!(conn, account, rkey, "neighbor #{rkey}")
      end

    historical_commit = List.last(neighboring_records)["commit"]["cid"]
    updated = put_note!(conn, account, target, "YR", "target after update")

    current_conn =
      conn
      |> recycle()
      |> get(~p"/xrpc/com.atproto.sync.getRecord", %{
        "did" => account["did"],
        "collection" => "app.tempest.note",
        "rkey" => "YR"
      })

    assert {:ok, current_car} = Car.decode(current_conn.resp_body)
    assert current_car.roots == [Cid.parse!(updated["commit"]["cid"])]
    assert car_cids(current_car) |> Enum.member?(updated["cid"])
    refute car_cids(current_car) |> Enum.member?(target["cid"])
    refute Enum.any?(neighboring_records, &Enum.member?(car_cids(current_car), &1["cid"]))
    assert record_text(current_car, updated["cid"]) == "target after update"

    historical_conn =
      conn
      |> recycle()
      |> get(~p"/xrpc/com.atproto.sync.getRecord", %{
        "did" => account["did"],
        "collection" => "app.tempest.note",
        "rkey" => "YR",
        "commit" => historical_commit
      })

    assert {:ok, historical_car} = Car.decode(historical_conn.resp_body)
    assert historical_car.roots == [Cid.parse!(historical_commit)]
    assert car_cids(historical_car) |> Enum.member?(target["cid"])
    refute car_cids(historical_car) |> Enum.member?(updated["cid"])
    refute Enum.any?(neighboring_records, &Enum.member?(car_cids(historical_car), &1["cid"]))
    assert record_text(historical_car, target["cid"]) == "target before update"
  end

  test "sync getRecord reports missing records", %{conn: conn} do
    account = create_account!(conn, "sync-cara.test", "sync-cara@example.com")

    record_conn =
      conn
      |> recycle()
      |> get(~p"/xrpc/com.atproto.sync.getRecord", %{
        "did" => account["did"],
        "collection" => "app.bsky.actor.profile",
        "rkey" => "self"
      })

    assert %{"error" => "RecordNotFound"} = json_response(record_conn, 400)
  end

  test "getBlocks returns only requested blocks and rejects invalid CID lists", %{conn: conn} do
    account = create_account!(conn, "sync-blocks.test", "sync-blocks@example.com")
    created = create_profile!(conn, account, "Blocks")

    blocks_conn =
      conn
      |> recycle()
      |> get(~p"/xrpc/com.atproto.sync.getBlocks", %{
        "did" => account["did"],
        "cids" => [created["cid"], created["commit"]["cid"]]
      })

    assert get_resp_header(blocks_conn, "content-type") == ["application/vnd.ipld.car; charset=utf-8"]
    assert {:ok, car} = Car.decode(blocks_conn.resp_body)
    assert car_cids(car) == [created["cid"], created["commit"]["cid"]]

    invalid_conn =
      conn
      |> recycle()
      |> get(~p"/xrpc/com.atproto.sync.getBlocks", %{
        "did" => account["did"],
        "cids" => ["not-a-cid"]
      })

    assert %{"error" => "InvalidRequest"} = json_response(invalid_conn, 400)
  end

  test "listRepos pages hosted accounts with latest commit metadata", %{conn: conn} do
    first = create_account!(conn, "sync-list-a.test", "sync-list-a@example.com")
    second = create_account!(conn, "sync-list-b.test", "sync-list-b@example.com")
    first_record = create_profile!(conn, first, "List A")
    second_record = create_profile!(conn, second, "List B")

    page_conn =
      conn
      |> recycle()
      |> get(~p"/xrpc/com.atproto.sync.listRepos", %{"limit" => "1000"})

    repos = json_response(page_conn, 200)["repos"]
    first_repo = Enum.find(repos, &(&1["did"] == first["did"]))
    second_repo = Enum.find(repos, &(&1["did"] == second["did"]))

    assert first_repo["active"] == true
    assert first_repo["head"] == first_record["commit"]["cid"]
    assert first_repo["rev"] == first_record["commit"]["rev"]
    assert second_repo["active"] == true
    assert second_repo["head"] == second_record["commit"]["cid"]
  end

  test "listBlobs returns public blobs and suppresses inactive repos", %{conn: conn} do
    account = create_account!(conn, "sync-blobs.test", "sync-blobs@example.com")
    blob_cid = upload_blob!(conn, account, "blob bytes")["blob"]["ref"]["$link"]
    unreferenced_cid = upload_blob!(conn, account, "temp bytes")["blob"]["ref"]["$link"]

    create_blob_record!(conn, account, "avatar", blob_cid)

    blobs_conn =
      conn
      |> recycle()
      |> get(~p"/xrpc/com.atproto.sync.listBlobs", %{"did" => account["did"]})

    assert json_response(blobs_conn, 200) == %{"cids" => [blob_cid]}
    refute json_response(blobs_conn, 200)["cids"] |> Enum.member?(unreferenced_cid)

    Account
    |> where([account], account.did == ^account["did"])
    |> Repo.update_all(set: [active: false, status: "deactivated"])

    inactive_conn =
      conn
      |> recycle()
      |> get(~p"/xrpc/com.atproto.sync.listBlobs", %{"did" => account["did"]})

    assert %{"error" => "RepoDeactivated"} = json_response(inactive_conn, 400)
  end

  test "getBlob downloads public blobs with defensive headers and inactive suppression", %{conn: conn} do
    account = create_account!(conn, "sync-get-blob.test", "sync-get-blob@example.com")
    bytes = "downloadable blob"
    blob = upload_blob!(conn, account, bytes)["blob"]
    cid = blob["ref"]["$link"]
    unreferenced_cid = upload_blob!(conn, account, "private temp")["blob"]["ref"]["$link"]

    create_blob_record!(conn, account, "download", cid)

    blob_conn =
      conn
      |> recycle()
      |> get(~p"/xrpc/com.atproto.sync.getBlob", %{"did" => account["did"], "cid" => cid})

    assert blob_conn.status == 200
    assert blob_conn.resp_body == bytes
    assert get_resp_header(blob_conn, "content-type") == ["text/plain"]
    assert get_resp_header(blob_conn, "content-length") == [Integer.to_string(byte_size(bytes))]
    assert get_resp_header(blob_conn, "x-content-type-options") == ["nosniff"]
    assert get_resp_header(blob_conn, "content-security-policy") == ["default-src 'none'; sandbox"]

    missing_conn =
      conn
      |> recycle()
      |> get(~p"/xrpc/com.atproto.sync.getBlob", %{"did" => account["did"], "cid" => unreferenced_cid})

    assert %{"error" => "BlobNotFound"} = json_response(missing_conn, 400)

    Account
    |> where([account], account.did == ^account["did"])
    |> Repo.update_all(set: [active: false, status: "suspended"])

    inactive_conn =
      conn
      |> recycle()
      |> get(~p"/xrpc/com.atproto.sync.getBlob", %{"did" => account["did"], "cid" => cid})

    assert %{"error" => "RepoSuspended"} = json_response(inactive_conn, 400)
  end

  test "getBlob redirects to configured CDN only after public and active checks", %{conn: conn} do
    Application.put_env(:tempest, Tempest.Blobs, cdn_base_url: "https://cdn.example.test/pds")

    account = create_account!(conn, "sync-cdn-blob.test", "sync-cdn-blob@example.com")
    public_cid = upload_blob!(conn, account, "cdn public")["blob"]["ref"]["$link"]
    temp_cid = upload_blob!(conn, account, "cdn temp")["blob"]["ref"]["$link"]

    create_blob_record!(conn, account, "cdn", public_cid)

    redirect_conn =
      conn
      |> recycle()
      |> get(~p"/xrpc/com.atproto.sync.getBlob", %{"did" => account["did"], "cid" => public_cid})

    assert redirect_conn.status == 302

    assert get_resp_header(redirect_conn, "location") == [
             "https://cdn.example.test/pds/blobs/#{URI.encode(account["did"], &URI.char_unreserved?/1)}/#{public_cid}"
           ]

    assert get_resp_header(redirect_conn, "x-content-type-options") == ["nosniff"]

    temp_conn =
      conn
      |> recycle()
      |> get(~p"/xrpc/com.atproto.sync.getBlob", %{"did" => account["did"], "cid" => temp_cid})

    assert %{"error" => "BlobNotFound"} = json_response(temp_conn, 400)

    Account
    |> where([account], account.did == ^account["did"])
    |> Repo.update_all(set: [active: false, status: "deactivated"])

    inactive_conn =
      conn
      |> recycle()
      |> get(~p"/xrpc/com.atproto.sync.getBlob", %{"did" => account["did"], "cid" => public_cid})

    assert %{"error" => "RepoDeactivated"} = json_response(inactive_conn, 400)
    assert get_resp_header(inactive_conn, "location") == []
  end

  test "deleteRecord removes blob bytes when no current record references them", %{conn: conn} do
    account = create_account!(conn, "sync-delete-blob.test", "sync-delete-blob@example.com")
    blob = upload_blob!(conn, account, "delete blob")["blob"]
    cid = blob["ref"]["$link"]
    created = create_blob_record!(conn, account, "delete-me", cid)

    assert get_blob_status(conn, account["did"], cid) == 200

    delete_conn =
      conn
      |> auth_json(account)
      |> post(~p"/xrpc/com.atproto.repo.deleteRecord", %{
        "repo" => account["did"],
        "collection" => "app.tempest.blob",
        "rkey" => "delete-me",
        "swapRecord" => created["cid"],
        "swapCommit" => created["commit"]["cid"]
      })

    assert %{"commit" => %{"cid" => _cid}} = json_response(delete_conn, 200)

    deleted_blob_conn =
      conn
      |> recycle()
      |> get(~p"/xrpc/com.atproto.sync.getBlob", %{"did" => account["did"], "cid" => cid})

    assert %{"error" => "BlobNotFound"} = json_response(deleted_blob_conn, 400)

    list_conn =
      conn
      |> recycle()
      |> get(~p"/xrpc/com.atproto.sync.listBlobs", %{"did" => account["did"]})

    assert json_response(list_conn, 200) == %{"cids" => []}
  end

  test "requestCrawl fans out to configured relays", %{conn: conn} do
    Application.put_env(:tempest, Tempest.Sync,
      relays: ["https://relay.test"],
      request_crawl_window_ms: 0,
      http_req_options: [plug: {Req.Test, __MODULE__}]
    )

    Req.Test.expect(__MODULE__, fn req_conn ->
      assert req_conn.method == "POST"
      assert req_conn.host == "relay.test"
      assert req_conn.request_path == "/xrpc/com.atproto.sync.requestCrawl"
      assert {:ok, %{"hostname" => "localhost"}, _conn} = Plug.Conn.read_body(req_conn) |> decode_req_body(req_conn)

      Plug.Conn.send_resp(req_conn, 200, "{}")
    end)

    crawl_conn =
      conn
      |> recycle()
      |> put_req_header("content-type", "application/json")
      |> post(~p"/xrpc/com.atproto.sync.requestCrawl", %{"hostname" => "localhost"})

    assert json_response(crawl_conn, 200) == %{}
  end

  test "requestCrawl continues when a configured relay fails", %{conn: conn} do
    Application.put_env(:tempest, Tempest.Sync,
      relays: ["https://bad-relay.test", "https://relay.test"],
      request_crawl_window_ms: 0,
      http_req_options: [plug: {Req.Test, __MODULE__}]
    )

    Req.Test.expect(__MODULE__, 2, fn req_conn ->
      assert req_conn.method == "POST"
      assert req_conn.request_path == "/xrpc/com.atproto.sync.requestCrawl"
      assert {:ok, %{"hostname" => "localhost"}, _conn} = Plug.Conn.read_body(req_conn) |> decode_req_body(req_conn)

      case req_conn.host do
        "bad-relay.test" -> Plug.Conn.send_resp(req_conn, 503, "{}")
        "relay.test" -> Plug.Conn.send_resp(req_conn, 200, "{}")
      end
    end)

    log =
      capture_log(fn ->
        crawl_conn =
          conn
          |> recycle()
          |> put_req_header("content-type", "application/json")
          |> post(~p"/xrpc/com.atproto.sync.requestCrawl", %{"hostname" => "localhost"})

        assert json_response(crawl_conn, 200) == %{}
      end)

    assert log =~ ~s(requestCrawl relay "https://bad-relay.test" hostname="localhost" failed:)
    assert log =~ "{:relay_status, 503"
  end

  test "request_own_crawl requests configured relays for the local hostname" do
    Application.put_env(:tempest, Tempest.Sync,
      relays: ["https://relay.test"],
      request_crawl_window_ms: 0,
      http_req_options: [plug: {Req.Test, __MODULE__}]
    )

    Req.Test.expect(__MODULE__, fn req_conn ->
      assert req_conn.method == "POST"
      assert req_conn.host == "relay.test"
      assert req_conn.request_path == "/xrpc/com.atproto.sync.requestCrawl"
      assert {:ok, %{"hostname" => "localhost"}, _conn} = Plug.Conn.read_body(req_conn) |> decode_req_body(req_conn)

      Plug.Conn.send_resp(req_conn, 200, "{}")
    end)

    assert {:ok, %{}} = Tempest.Sync.request_own_crawl()
  end

  test "request_own_crawl does not consume the public requestCrawl rate limit", %{conn: conn} do
    Application.put_env(:tempest, Tempest.Sync,
      relays: [],
      request_crawl_window_ms: 60_000,
      http_req_options: [plug: {Req.Test, __MODULE__}]
    )

    assert {:ok, %{}} = Tempest.Sync.request_own_crawl()

    public_conn =
      conn
      |> recycle()
      |> put_req_header("content-type", "application/json")
      |> post(~p"/xrpc/com.atproto.sync.requestCrawl", %{"hostname" => "localhost"})

    assert json_response(public_conn, 200) == %{}
  end

  test "requestCrawl is rate limited per hostname", %{conn: conn} do
    Application.put_env(:tempest, Tempest.Sync,
      relays: [],
      request_crawl_window_ms: 60_000,
      http_req_options: [plug: {Req.Test, __MODULE__}]
    )

    first_conn =
      conn
      |> recycle()
      |> put_req_header("content-type", "application/json")
      |> post(~p"/xrpc/com.atproto.sync.requestCrawl", %{"hostname" => "localhost"})

    assert json_response(first_conn, 200) == %{}

    second_conn =
      conn
      |> recycle()
      |> put_req_header("content-type", "application/json")
      |> post(~p"/xrpc/com.atproto.sync.requestCrawl", %{"hostname" => "localhost"})

    assert %{"error" => "RateLimitExceeded"} = json_response(second_conn, 429)
  end

  test "latest commit remains consistent after storage bootstrap", %{conn: conn} do
    account = create_account!(conn, "sync-restart.test", "sync-restart@example.com")
    created = create_profile!(conn, account, "Restart")

    :ok =
      Tempest.Config.load!()
      |> Tempest.Storage.bootstrap!()

    latest_conn =
      conn
      |> recycle()
      |> get(~p"/xrpc/com.atproto.sync.getLatestCommit", %{"did" => account["did"]})

    assert json_response(latest_conn, 200) == created["commit"]
  end

  test "getRepoStatus exposes inactive hosted account status without exporting repo data", %{conn: conn} do
    account = create_account!(conn, "sync-dana.test", "sync-dana@example.com")

    Account
    |> where([account], account.did == ^account["did"])
    |> Repo.update_all(set: [active: false, status: "deactivated"])

    status_conn =
      conn
      |> recycle()
      |> get(~p"/xrpc/com.atproto.sync.getRepoStatus", %{"did" => account["did"]})

    assert json_response(status_conn, 200) == %{
             "did" => account["did"],
             "active" => false,
             "status" => "deactivated"
           }

    latest_conn =
      conn
      |> recycle()
      |> get(~p"/xrpc/com.atproto.sync.getLatestCommit", %{"did" => account["did"]})

    assert %{"error" => "RepoDeactivated"} = json_response(latest_conn, 400)

    repo_conn =
      conn
      |> recycle()
      |> get(~p"/xrpc/com.atproto.sync.getRepo", %{"did" => account["did"]})

    assert %{"error" => "RepoDeactivated"} = json_response(repo_conn, 400)
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

  defp decode_req_body({:ok, body, conn}, _req_conn), do: {:ok, Jason.decode!(body), conn}

  defp clear_request_crawl_rate_limits do
    case :ets.whereis(:tempest_request_crawl_limits) do
      :undefined -> :ok
      table -> :ets.delete_all_objects(table)
    end
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
    |> post(~p"/xrpc/com.atproto.repo.createRecord", %{
      "repo" => account["did"],
      "collection" => "app.bsky.actor.profile",
      "rkey" => "self",
      "record" => %{
        "$type" => "app.bsky.actor.profile",
        "displayName" => display_name
      }
    })
    |> json_response(200)
  end

  defp put_profile!(conn, account, created, display_name) do
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
        "displayName" => display_name
      }
    })
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

  defp create_blob_record!(conn, account, rkey, cid) do
    conn
    |> auth_json(account)
    |> post(~p"/xrpc/com.atproto.repo.createRecord", %{
      "repo" => account["did"],
      "collection" => "app.tempest.blob",
      "rkey" => rkey,
      "validate" => false,
      "record" => %{
        "$type" => "app.tempest.blob",
        "image" => %{
          "$type" => "blob",
          "ref" => %{"$link" => cid},
          "mimeType" => "text/plain",
          "size" => 10
        }
      }
    })
    |> json_response(200)
  end

  defp get_blob_status(conn, did, cid) do
    conn
    |> recycle()
    |> get(~p"/xrpc/com.atproto.sync.getBlob", %{"did" => did, "cid" => cid})
    |> Map.fetch!(:status)
  end

  defp upload_blob!(conn, account, bytes) do
    conn
    |> recycle()
    |> put_req_header("authorization", "Bearer #{account["accessJwt"]}")
    |> put_req_header("content-type", "text/plain")
    |> put_req_header("content-length", Integer.to_string(byte_size(bytes)))
    |> post(~p"/xrpc/com.atproto.repo.uploadBlob", bytes)
    |> json_response(200)
  end

  defp put_note!(conn, account, previous, rkey, text) do
    conn
    |> auth_json(account)
    |> post(~p"/xrpc/com.atproto.repo.putRecord", %{
      "repo" => account["did"],
      "collection" => "app.tempest.note",
      "rkey" => rkey,
      "validate" => false,
      "swapRecord" => previous["cid"],
      "record" => %{
        "$type" => "app.tempest.note",
        "text" => text
      }
    })
    |> json_response(200)
  end

  defp car_cids(car), do: Enum.map(car.blocks, &Cid.to_string(&1.cid))

  defp record_text(car, cid) do
    block = Enum.find(car.blocks, &(Cid.to_string(&1.cid) == cid))
    assert {:ok, %{"text" => text}} = Drisl.decode(block.data)
    text
  end
end
