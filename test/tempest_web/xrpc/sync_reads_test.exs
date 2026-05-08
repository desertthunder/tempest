defmodule TempestWeb.Xrpc.SyncReadsTest do
  use TempestWeb.ConnCase, async: false

  import Ecto.Query

  alias Tempest.Accounts.Account
  alias Tempest.Repo
  alias Tempest.RepoCore.{Car, CarVerifier, Cid, Drisl}

  @password "correct horse battery staple"

  setup context do
    Tempest.LexiconFixtures.install!(context)
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

  test "listBlobs returns referenced blobs and suppresses inactive repos", %{conn: conn} do
    account = create_account!(conn, "sync-blobs.test", "sync-blobs@example.com")
    blob_cid = "blob bytes" |> Cid.for_raw() |> Cid.to_string()
    unreferenced_cid = "temp bytes" |> Cid.for_raw() |> Cid.to_string()

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
