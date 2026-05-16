defmodule Tempest.Blobs.GarbageCollectorTest do
  use Tempest.DataCase, async: false

  alias Tempest.Blobs
  alias Tempest.Blobs.GarbageCollector
  alias Tempest.Blobs.LocalStorage
  alias Tempest.Repo

  setup do
    data_dir =
      Path.join(System.tmp_dir!(), "tempest_blob_gc_test_#{System.unique_integer([:positive])}")

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

    %{config: config, did: "did:plc:blobgc"}
  end

  test "run_once deletes expired temp metadata and bytes", %{config: config, did: did} do
    cid = Blobs.cid_for("expired temp")

    assert {:ok, %{path: temp_path}} = LocalStorage.put_temp_blob(config, did, cid, "expired temp")
    assert :ok = Blobs.put_temp_metadata(did, %{cid: cid, mime_type: "text/plain", size: 12})
    expire_temp!(did, cid, DateTime.add(DateTime.utc_now(), -1, :second))

    assert File.exists?(temp_path)
    assert {:ok, 1} = GarbageCollector.run_once(config)
    refute File.exists?(temp_path)
    assert {:error, :blob_not_found} = Blobs.get_metadata(did, cid)
  end

  test "run_once keeps unexpired temp and public blobs", %{config: config, did: did} do
    temp_cid = Blobs.cid_for("fresh temp")
    public_cid = Blobs.cid_for("public blob")

    assert {:ok, %{path: temp_path}} = LocalStorage.put_temp_blob(config, did, temp_cid, "fresh temp")
    assert :ok = Blobs.put_temp_metadata(did, %{cid: temp_cid, mime_type: "text/plain", size: 10})
    expire_temp!(did, temp_cid, DateTime.add(DateTime.utc_now(), 60 * 60, :second))

    assert {:ok, _stored} = LocalStorage.put_temp_blob(config, did, public_cid, "public blob")
    assert :ok = Blobs.put_temp_metadata(did, %{cid: public_cid, mime_type: "text/plain", size: 11})
    assert {:ok, public_path} = LocalStorage.promote_blob(config, did, public_cid)
    assert :ok = Blobs.mark_public(did, [public_cid])
    expire_temp!(did, public_cid, DateTime.add(DateTime.utc_now(), -1, :second))

    assert {:ok, 0} = GarbageCollector.run_once(config)
    assert File.exists?(temp_path)
    assert File.exists?(public_path)
    assert {:ok, %{state: "temp"}} = Blobs.get_metadata(did, temp_cid)
    assert {:ok, %{state: "public"}} = Blobs.get_metadata(did, public_cid)
  end

  defp expire_temp!(did, cid, expires_at) do
    {:ok, _result} =
      Repo.query(
        "UPDATE blob_metadata SET temp_expires_at = ?3 WHERE did = ?1 AND cid = ?2",
        [did, cid, DateTime.to_iso8601(expires_at)]
      )

    :ok
  end
end
