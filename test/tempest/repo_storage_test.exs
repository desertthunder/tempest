defmodule Tempest.RepoStorageTest do
  use Tempest.DataCase, async: false

  alias Tempest.{Accounts, Config, RepoStorage}
  alias Tempest.Accounts.Account
  alias Tempest.Identity.KeyStore
  alias Tempest.RepoCore.{Car, CarVerifier, Cid, Commit, Tid}

  @password "correct horse battery staple"

  test "creates per-DID repo database with record API tables" do
    data_dir =
      Path.join(System.tmp_dir!(), "tempest_repo_storage_test_#{System.unique_integer([:positive])}")

    config =
      Config.validate!(
        [
          hostname: "localhost",
          public_url: "http://localhost:4000",
          data_dir: data_dir,
          blob_max_bytes: 10_000_000
        ],
        env: :test
      )

    did = "did:plc:abcdefghijklmnopqrstuvwx"
    on_exit(fn -> File.rm_rf(data_dir) end)

    assert path = RepoStorage.create_repo_database!(config, did)
    assert path == Path.join([data_dir, "repos", "did_plc_abcdefghijklmnopqrstuvwx.sqlite"])

    assert File.exists?(path)
    assert table_names(path) == ["blocks", "commits", "records", "repo_metadata"]
  end

  test "account creation initializes an empty signed repository" do
    assert {:ok, created} =
             Accounts.create_account(%{
               "handle" => "repo-init.test",
               "email" => "repo-init@example.com",
               "password" => @password
             })

    path =
      Config.load!()
      |> Config.repo_db_path(created["did"])

    on_exit(fn -> File.rm(path) end)

    assert File.exists?(path)
    assert scalar(path, "SELECT COUNT(*) FROM records") == 0
    assert scalar(path, "SELECT COUNT(*) FROM commits") == 1
    assert scalar(path, "SELECT COUNT(*) FROM blocks") == 2

    metadata = metadata(path)
    assert metadata["did"] == created["did"]
    assert metadata["version"] == "3"
    assert Tid.valid?(metadata["current_rev"])

    [[commit_bytes]] = fetch_all(path, "SELECT commit_bytes FROM commits")

    assert {:ok, commit} = Commit.decode(commit_bytes)
    assert commit.did == created["did"]
    assert commit.rev == metadata["current_rev"]
  end

  test "exports stored repository blocks as a CAR rooted at the current commit" do
    assert {:ok, created} =
             Accounts.create_account(%{
               "handle" => "repo-car.test",
               "email" => "repo-car@example.com",
               "password" => @password
             })

    path =
      Config.load!()
      |> Config.repo_db_path(created["did"])

    on_exit(fn -> File.rm(path) end)

    account = Repo.get_by!(Account, did: created["did"])
    signing_key = KeyStore.active_key_for_account(account)

    assert {:ok, _record} =
             RepoStorage.create_record(account, signing_key, %{
               collection: "app.bsky.actor.profile",
               rkey: "self",
               swap_commit: nil,
               record: %{
                 "$type" => "app.bsky.actor.profile",
                 "displayName" => "Alice"
               }
             })

    metadata = metadata(path)
    stored_cids = block_cids(path)

    assert {:ok, %{root: root, bytes: bytes}} = RepoStorage.export_car(created["did"])
    assert root == metadata["current_commit_cid"]

    assert {:ok, car} = Car.decode(bytes)
    assert car.roots == [Cid.parse!(metadata["current_commit_cid"])]
    assert Enum.map(car.blocks, &Cid.to_string(&1.cid)) == stored_cids
  end

  test "imported records normalize DRISL CID links before storing JSON" do
    assert {:ok, source_created} =
             Accounts.create_account(%{
               "handle" => "repo-import-source.test",
               "email" => "repo-import-source@example.com",
               "password" => @password
             })

    assert {:ok, target_created} =
             Accounts.create_account(%{
               "handle" => "repo-import-target.test",
               "email" => "repo-import-target@example.com",
               "password" => @password
             })

    source = Repo.get_by!(Account, did: source_created["did"])
    source_key = KeyStore.active_key_for_account(source)
    target = Repo.get_by!(Account, did: target_created["did"])

    blob_cid = Cid.for_raw("avatar bytes")

    assert {:ok, _record} =
             RepoStorage.create_record(source, source_key, %{
               collection: "app.bsky.actor.profile",
               rkey: "self",
               swap_commit: nil,
               record: %{
                 "$type" => "app.bsky.actor.profile",
                 "avatar" => %{
                   "$type" => "blob",
                   "ref" => %{"$link" => Cid.to_string(blob_cid)},
                   "mimeType" => "image/png",
                   "size" => 12
                 }
               }
             })

    assert {:ok, %{bytes: bytes}} = RepoStorage.export_car(source.did)
    assert {:ok, verified} = CarVerifier.verify_repo_car(bytes, did: source.did)
    verified = %{verified | commit: %{verified.commit | did: target.did}}

    assert {:ok, %{record_count: 1}} = RepoStorage.import_verified_car(target, verified)

    target_path = Config.load!() |> Config.repo_db_path(target.did)
    [[record_json]] = fetch_all(target_path, "SELECT record_json FROM records")
    assert %{"avatar" => %{"ref" => %{"$link" => cid}}} = Jason.decode!(record_json)
    assert cid == Cid.to_string(blob_cid)
  end

  defp table_names(path) do
    path
    |> fetch_all("""
    SELECT name
    FROM sqlite_master
    WHERE type = 'table'
      AND name IN ('blocks', 'records', 'commits', 'repo_metadata')
    ORDER BY name
    """)
    |> List.flatten()
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

  defp block_cids(path) do
    path
    |> fetch_all("SELECT cid FROM blocks ORDER BY inserted_at ASC, cid ASC")
    |> List.flatten()
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
