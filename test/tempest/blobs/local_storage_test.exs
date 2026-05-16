defmodule Tempest.Blobs.LocalStorageTest do
  use ExUnit.Case, async: true

  alias Tempest.Blobs
  alias Tempest.Blobs.LocalStorage

  setup do
    data_dir = Path.join(System.tmp_dir!(), "tempest_local_blob_storage_test_#{System.unique_integer([:positive])}")

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

    %{config: config, did: "did:plc:localstorage"}
  end

  test "stores temp blobs, promotes them, and reads content metadata", %{config: config, did: did} do
    bytes = "hello blob"
    cid = Blobs.cid_for(bytes)

    assert {:ok, %{path: temp_path, size: 10}} = LocalStorage.put_temp_blob(config, did, cid, bytes)
    assert File.exists?(temp_path)
    assert {:error, :blob_not_found} = LocalStorage.get_blob(config, did, cid, "text/plain")

    assert {:ok, permanent_path} = LocalStorage.promote_blob(config, did, cid)
    assert permanent_path == Path.join([config.data_dir, "blobs", "did_plc_localstorage", cid])
    refute File.exists?(temp_path)

    assert {:ok, %{bytes: ^bytes, content_length: 10, mime_type: "text/plain"}} =
             LocalStorage.get_blob(config, did, cid, "text/plain")
  end

  test "lists promoted blobs with cursor pagination", %{config: config, did: did} do
    cids =
      ["first", "second", "third"]
      |> Enum.map(fn bytes ->
        cid = Blobs.cid_for(bytes)
        assert {:ok, _stored} = LocalStorage.put_temp_blob(config, did, cid, bytes)
        assert {:ok, _path} = LocalStorage.promote_blob(config, did, cid)
        cid
      end)
      |> Enum.sort()

    assert {:ok, %{cids: [first], cursor: first}} = LocalStorage.list_blobs(config, did, limit: 1)
    assert first == Enum.at(cids, 0)
    assert {:ok, %{cids: remaining}} = LocalStorage.list_blobs(config, did, limit: 10, cursor: first)
    assert remaining == Enum.drop(cids, 1)
  end

  test "temp blobs are not listed", %{config: config, did: did} do
    cid = Blobs.cid_for("temporary")

    assert {:ok, _stored} = LocalStorage.put_temp_blob(config, did, cid, "temporary")
    assert {:ok, %{cids: []}} = LocalStorage.list_blobs(config, did)
  end

  test "delete removes temp and promoted copies", %{config: config, did: did} do
    cid = Blobs.cid_for("delete me")

    assert {:ok, _stored} = LocalStorage.put_temp_blob(config, did, cid, "delete me")
    assert {:ok, _path} = LocalStorage.promote_blob(config, did, cid)
    assert :ok = LocalStorage.delete_blob(config, did, cid)
    assert {:error, :blob_not_found} = LocalStorage.get_blob(config, did, cid)
    assert :ok = LocalStorage.delete_blob(config, did, cid)
  end

  test "rejects unsafe identifiers before touching paths", %{config: config} do
    cid = Blobs.cid_for("hello")

    assert {:error, :invalid_did} = LocalStorage.put_temp_blob(config, "../did", cid, "hello")
    assert {:error, :invalid_cid} = LocalStorage.put_temp_blob(config, "did:plc:localstorage", "../cid", "hello")
  end
end
