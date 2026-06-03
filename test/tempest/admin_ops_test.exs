defmodule Tempest.AdminOpsTest do
  use Tempest.DataCase

  alias Tempest.Accounts
  alias Tempest.Admin.{Backup, RepoOps}
  alias Tempest.{Blobs, Config, Repo, RepoStorage, Sequencer}
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
    backup_dir = Path.join([System.tmp_dir!(), "tempest-backup-test-#{System.unique_integer([:positive])}"])
    restore_dir = Path.join([System.tmp_dir!(), "tempest-restore-test-#{System.unique_integer([:positive])}"])

    assert {:ok, %{path: ^backup_dir}} = Backup.create(config: config, path: backup_dir)
    assert File.exists?(Path.join(backup_dir, "manifest.json"))
    assert File.exists?(Path.join(backup_dir, "account.sqlite"))

    assert {:ok, %{path: ^restore_dir}} = Backup.restore(backup_dir, config: config, target: restore_dir)
    assert File.exists?(Path.join(restore_dir, "account.sqlite"))
    assert File.exists?(Path.join(restore_dir, "sequencer.sqlite"))

    assert {:error, :target_not_empty} = Backup.restore(backup_dir, config: config, target: restore_dir)
    assert {:ok, %{path: ^restore_dir}} = Backup.restore(backup_dir, config: config, target: restore_dir, force?: true)
  end
end
