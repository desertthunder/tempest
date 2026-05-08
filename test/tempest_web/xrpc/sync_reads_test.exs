defmodule TempestWeb.Xrpc.SyncReadsTest do
  use TempestWeb.ConnCase, async: false

  import Ecto.Query

  alias Tempest.Accounts.Account
  alias Tempest.Repo
  alias Tempest.RepoCore.{Car, Cid}

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
  end

  test "sync getRecord returns a CAR for an existing record", %{conn: conn} do
    account = create_account!(conn, "sync-bob.test", "sync-bob@example.com")
    created = create_profile!(conn, account, "Bob")

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
    assert car.roots == [Cid.parse!(created["commit"]["cid"])]
    assert Enum.any?(car.blocks, &(Cid.to_string(&1.cid) == created["cid"]))
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
end
