defmodule Tempest.StorageTest do
  use ExUnit.Case, async: false

  test "bootstraps SQLite data directory layout" do
    data_dir =
      Path.join(System.tmp_dir!(), "tempest_storage_test_#{System.unique_integer([:positive])}")

    config =
      Tempest.Config.validate!(
        [
          hostname: "localhost",
          public_url: "http://localhost:4000",
          data_dir: data_dir,
          blob_max_bytes: 10_000_000
        ],
        env: :test
      )

    on_exit(fn -> File.rm_rf(data_dir) end)

    assert :ok = Tempest.Storage.bootstrap!(config)

    assert File.dir?(Path.join(data_dir, "repos"))
    assert File.dir?(Path.join(data_dir, "blobs"))
    assert File.dir?(Path.join(data_dir, "tmp"))
    assert File.dir?(Path.join(data_dir, "backups"))
    assert File.exists?(Path.join(data_dir, "account.sqlite"))
    assert File.exists?(Path.join(data_dir, "sequencer.sqlite"))
    assert sequencer_table_exists?(Path.join(data_dir, "sequencer.sqlite"))

    assert %{
             "dataDir" => ^data_dir,
             "accountDb" => account_db,
             "sequencerDb" => sequencer_db,
             "writable" => true
           } = Tempest.Storage.health(config, :test)

    assert account_db == Path.join(data_dir, "account.sqlite")
    assert sequencer_db == Path.join(data_dir, "sequencer.sqlite")
  end

  test "redacts full paths from production health metadata" do
    config =
      Tempest.Config.validate!(
        [
          hostname: "tempest.example.com",
          public_url: "https://tempest.example.com",
          data_dir: "/var/lib/tempest",
          blob_max_bytes: 10_000_000
        ],
        env: :test
      )

    assert %{
             "dataDir" => "tempest",
             "accountDb" => "account.sqlite",
             "sequencerDb" => "sequencer.sqlite"
           } = Tempest.Storage.health(config, :prod)
  end

  defp sequencer_table_exists?(path) do
    {:ok, conn} = Exqlite.Sqlite3.open(path)

    {:ok, statement} =
      Exqlite.Sqlite3.prepare(conn, "SELECT name FROM sqlite_master WHERE name = 'repo_seq'")

    {:ok, [["repo_seq"]]} = Exqlite.Sqlite3.fetch_all(conn, statement)
    :ok = Exqlite.Sqlite3.release(conn, statement)
    :ok = Exqlite.Sqlite3.close(conn)

    true
  end
end
