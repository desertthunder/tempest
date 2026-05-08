defmodule Tempest.RepoStorageTest do
  use Tempest.DataCase, async: false

  alias Tempest.{Accounts, Config, RepoStorage}
  alias Tempest.RepoCore.{Commit, Tid}

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

  defp fetch_all(path, sql) do
    {:ok, conn} = Exqlite.Sqlite3.open(path)
    {:ok, statement} = Exqlite.Sqlite3.prepare(conn, sql)
    {:ok, rows} = Exqlite.Sqlite3.fetch_all(conn, statement)
    :ok = Exqlite.Sqlite3.release(conn, statement)
    :ok = Exqlite.Sqlite3.close(conn)
    rows
  end
end
