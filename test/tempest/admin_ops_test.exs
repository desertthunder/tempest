defmodule Tempest.AdminOpsTest do
  use Tempest.DataCase

  alias Tempest.Accounts
  alias Tempest.Accounts.{Account, AuthContext}
  alias Tempest.Admin.{Backup, RepoOps}
  alias Tempest.Identity.{KeyStore, SigningKey}
  alias Tempest.{Blobs, Config, OAuth, Records, Repo, RepoStorage, Sequencer, Storage}
  alias Tempest.RepoCore.Car

  setup do
    unique = System.unique_integer([:positive])

    {:ok, session} =
      Accounts.create_account(%{
        "handle" => "admin-ops-#{unique}.test",
        "email" => "admin-ops-#{unique}@example.com",
        "password" => "correct horse battery staple"
      })

    %{did: session["did"], config: Config.load!()}
  end

  test "repo verify and export operate on hosted repositories", %{did: did} do
    assert {:ok, verified} = RepoOps.verify(did)
    assert verified.did == did
    assert verified.record_count == 0
    assert verified.block_count > 0

    path = Path.join(System.tmp_dir!(), "#{System.unique_integer([:positive])}.car")
    assert {:ok, exported} = RepoOps.export(did, path)
    assert exported.path == path
    assert exported.bytes > 0
    assert {:ok, _car} = path |> File.read!() |> Car.decode()
  end

  test "repo import verifies and replaces the account repository", %{did: did} do
    assert {:ok, exported} = RepoStorage.export_car(did)
    path = Path.join(System.tmp_dir!(), "#{System.unique_integer([:positive])}-import.car")
    File.write!(path, exported.bytes)

    assert {:ok, result} = RepoOps.import(did, path)
    assert result["cid"] == exported.root
    assert result["recordCount"] == 0
  end

  test "sequencer status exposes current sequence and torn write count" do
    assert {:ok, seq} = Sequencer.current_seq()
    assert is_integer(seq)
    assert seq >= 0

    assert {:ok, torn} = Sequencer.torn_write_count()
    assert is_integer(torn)
    assert torn >= 0
  end

  test "blob gc removes expired temp blob metadata and bytes", %{did: did, config: config} do
    cid = Blobs.cid_for("expired temp bytes")
    expires_at = DateTime.utc_now() |> DateTime.add(-60, :second) |> DateTime.to_iso8601()

    assert {:ok, _stored} = Tempest.Blobs.LocalStorage.put_temp_blob(config, did, cid, "expired temp bytes")

    assert {:ok, _result} =
             Repo.query(
               """
               INSERT INTO blob_metadata (did, cid, mime_type, size, state, inserted_at, updated_at, temp_expires_at, referenced_at)
               VALUES (?1, ?2, 'text/plain', 18, 'temp', ?3, ?3, ?4, NULL)
               """,
               [did, cid, expires_at, expires_at]
             )

    assert {:ok, 1} = Tempest.Blobs.GarbageCollector.run_once(config)
    assert {:error, :blob_not_found} = Blobs.get_metadata(did, cid)
  end

  test "backup create and restore refuse unsafe overwrite", %{config: config} do
    backup_dir = tmp_path!("backup-test")
    restore_dir = tmp_path!("restore-test")

    on_exit(fn ->
      File.rm_rf(backup_dir)
      File.rm_rf(restore_dir)
    end)

    assert {:ok, %{path: ^backup_dir}} = Backup.create(config: config, path: backup_dir)
    assert File.exists?(Path.join(backup_dir, "manifest.json"))
    assert File.exists?(Path.join(backup_dir, "account.sqlite"))

    assert {:ok, %{path: ^restore_dir}} = Backup.restore(backup_dir, config: config, target: restore_dir)
    assert File.exists?(Path.join(restore_dir, "account.sqlite"))
    assert File.exists?(Path.join(restore_dir, "sequencer.sqlite"))

    assert {:error, :target_not_empty} = Backup.restore(backup_dir, config: config, target: restore_dir)
    assert {:ok, %{path: ^restore_dir}} = Backup.restore(backup_dir, config: config, target: restore_dir, force?: true)
  end

  # This drill intentionally verifies restored state through filesystem, SQLite, and
  # storage contexts instead of booting a second HTTP endpoint against restore_dir.
  #
  # Public HTTP coverage for the same compatibility surface lives in
  # test/smoke/local-pds-compat.sh.
  test "local restore drill preserves DBs, repos, blobs, signing keys, and OAuth keys" do
    unique = System.unique_integer([:positive])
    data_dir = Path.join([System.tmp_dir!(), "tempest-restore-drill-source-#{unique}"])
    backup_dir = Path.join([System.tmp_dir!(), "tempest-restore-drill-backup-#{unique}"])
    restore_dir = Path.join([System.tmp_dir!(), "tempest-restore-drill-target-#{unique}"])

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

    previous_dynamic_repo = Repo.get_dynamic_repo()
    previous_config = Application.get_env(:tempest, Tempest.Config)
    original_jwks_config = Application.get_env(:tempest, OAuth.Jwks, [])

    Application.put_env(:tempest, Tempest.Config,
      hostname: "localhost",
      public_url: "http://localhost:4000",
      data_dir: data_dir,
      blob_max_bytes: 10_000_000
    )

    Application.put_env(:tempest, OAuth.Jwks, [])
    assert :ok = Storage.bootstrap!(config)
    repo_pid = start_repo!(Config.account_db_path(config))
    Repo.put_dynamic_repo(repo_pid)
    migrate!(repo_pid)

    on_exit(fn ->
      Repo.put_dynamic_repo(previous_dynamic_repo)
      Application.put_env(:tempest, Tempest.Config, previous_config)
      Application.put_env(:tempest, OAuth.Jwks, original_jwks_config)
      stop_repo(repo_pid)
      File.rm_rf(data_dir)
      File.rm_rf(backup_dir)
      File.rm_rf(restore_dir)
    end)

    assert {:ok, created} =
             Accounts.create_account(%{
               "handle" => "restore-drill-#{unique}.test",
               "email" => "restore-drill-#{unique}@example.com",
               "password" => "correct horse battery staple"
             })

    did = created["did"]
    account = Repo.get_by!(Account, did: did)
    blob_bytes = "restore drill blob #{unique}"
    blob_cid = Blobs.cid_for(blob_bytes)
    auth = %AuthContext{account: account, token_type: :access}

    assert {:ok, _stored_blob} = Tempest.Blobs.LocalStorage.put_temp_blob(config, did, blob_cid, blob_bytes)
    assert :ok = Blobs.put_temp_metadata(did, %{cid: blob_cid, mime_type: "text/plain", size: byte_size(blob_bytes)})

    assert {:ok, _record} =
             Records.create_record(auth, %{
               "repo" => did,
               "collection" => "app.tempest.note",
               "rkey" => "restore-drill",
               "validate" => false,
               "record" => %{
                 "$type" => "app.tempest.note",
                 "text" => "restore drill",
                 "attachment" => %{
                   "$type" => "blob",
                   "ref" => %{"$link" => blob_cid},
                   "mimeType" => "text/plain",
                   "size" => byte_size(blob_bytes)
                 }
               }
             })

    assert {:ok, oauth_key} = OAuth.Jwks.active_key()
    assert {:ok, latest} = RepoStorage.latest_commit(did)
    assert {:ok, original_car} = RepoStorage.export_car(did)

    assert {:ok, %{path: ^backup_dir}} = Backup.create(config: config, path: backup_dir)
    assert {:ok, %{path: ^restore_dir}} = Backup.restore(backup_dir, config: config, target: restore_dir)

    restored_config = %{config | data_dir: restore_dir}
    restored_account_db = Config.account_db_path(restored_config)
    restored_seq_db = Config.sequencer_db_path(restored_config)

    assert File.exists?(restored_account_db)
    assert File.exists?(restored_seq_db)
    assert File.exists?(Config.repo_db_path(restored_config, did))
    assert File.read!(Path.join([restore_dir, "blobs", path_did(did), blob_cid])) == blob_bytes

    assert [^did, "active"] = sqlite_one!(restored_account_db, "SELECT did, status FROM accounts WHERE did = ?1", [did])

    assert [1] =
             sqlite_one!(
               restored_account_db,
               "SELECT COUNT(*) FROM blob_metadata WHERE did = ?1 AND cid = ?2 AND state = 'public'",
               [did, blob_cid]
             )

    assert [key_ciphertext] =
             sqlite_one!(
               restored_account_db,
               "SELECT private_key_ciphertext FROM signing_keys WHERE account_id = ?1 AND active = 1",
               [account.id]
             )

    assert {:ok, private_key} = KeyStore.decrypt_private_key(%SigningKey{private_key_ciphertext: key_ciphertext})
    assert byte_size(private_key) > 0

    assert [seq] = sqlite_one!(restored_seq_db, "SELECT MAX(seq) FROM repo_seq WHERE did = ?1", [did])
    assert is_integer(seq) and seq > 0

    assert {:ok, restored_latest} = RepoStorage.latest_commit(did, restored_config)
    assert restored_latest == latest
    assert {:ok, restored_car} = RepoStorage.export_car(did, restored_config)
    assert restored_car.root == original_car.root
    assert byte_size(restored_car.bytes) == byte_size(original_car.bytes)

    assert %{"active_kid" => active_kid, "keys" => keys} =
             restore_dir |> Path.join("oauth_jwks.json") |> File.read!() |> Jason.decode!()

    assert active_kid == oauth_key["kid"]
    assert Enum.any?(keys, &(&1["kid"] == oauth_key["kid"] and Map.has_key?(&1, "d")))
  end

  defp stop_repo(pid) do
    Supervisor.stop(pid)
  catch
    :exit, _reason -> :ok
  end

  defp start_repo!(database) do
    {:ok, pid} =
      Repo.start_link(
        name: nil,
        database: database,
        pool: DBConnection.ConnectionPool,
        pool_size: 2,
        journal_mode: :wal,
        busy_timeout: 5_000,
        default_transaction_mode: :immediate
      )

    pid
  end

  defp migrate!(repo_pid) do
    ignore_module_conflict? = Code.compiler_options().ignore_module_conflict
    Code.compiler_options(ignore_module_conflict: true)

    try do
      Ecto.Migrator.run(Repo, "priv/repo/migrations", :up,
        all: true,
        dynamic_repo: repo_pid,
        log: false,
        log_migrations_sql: false,
        log_migrator_sql: false
      )
    after
      Code.compiler_options(ignore_module_conflict: ignore_module_conflict?)
    end
  end

  defp sqlite_one!(path, sql, params) do
    {:ok, conn} = Exqlite.Sqlite3.open(path)
    {:ok, statement} = Exqlite.Sqlite3.prepare(conn, sql)
    :ok = Exqlite.Sqlite3.bind(statement, params)
    {:ok, rows} = Exqlite.Sqlite3.fetch_all(conn, statement)
    :ok = Exqlite.Sqlite3.release(conn, statement)
    :ok = Exqlite.Sqlite3.close(conn)

    case rows do
      [row] -> row
      other -> flunk("expected one sqlite row from #{path}, got #{inspect(other)}")
    end
  end

  defp path_did(did), do: String.replace(did, ~r/[^A-Za-z0-9._-]/, "_")

  defp tmp_path!(name) do
    suffix = 8 |> :crypto.strong_rand_bytes() |> Base.url_encode64(padding: false)
    Path.join(System.tmp_dir!(), "tempest-#{name}-#{suffix}")
  end
end
