defmodule Tempest.Blobs.S3StorageTest do
  use ExUnit.Case, async: false

  alias Tempest.Blobs
  alias Tempest.Blobs.S3Storage

  setup context do
    Req.Test.set_req_test_from_context(context)
    Req.Test.verify_on_exit!(context)

    config = [
      endpoint_url: "https://objects.example.test",
      bucket: "tempest-test",
      req_options: [plug: {Req.Test, __MODULE__}],
      headers: [{"authorization", "Bearer test-token"}]
    ]

    %{config: config, did: "did:plc:s3storage", cid: Blobs.cid_for("s3 bytes")}
  end

  test "put_temp_blob writes to the temp object key", %{config: config, did: did, cid: cid} do
    Req.Test.expect(__MODULE__, fn conn ->
      assert conn.method == "PUT"
      assert conn.request_path == "/tempest-test/temp/blobs/did%3Aplc%3As3storage/#{cid}"
      assert Plug.Conn.get_req_header(conn, "authorization") == ["Bearer test-token"]
      assert {:ok, "s3 bytes", conn} = Plug.Conn.read_body(conn)

      Plug.Conn.send_resp(conn, 200, "")
    end)

    assert {:ok, stored} = S3Storage.put_temp_blob(config, did, cid, "s3 bytes")
    assert stored == %{cid: cid, path: "temp/blobs/#{did}/#{cid}", size: 8}
  end

  test "promote_blob copies temp object into the public blob key and deletes temp", %{
    config: config,
    did: did,
    cid: cid
  } do
    Req.Test.expect(__MODULE__, fn conn ->
      assert conn.method == "PUT"
      assert conn.request_path == "/tempest-test/blobs/did%3Aplc%3As3storage/#{cid}"

      assert Plug.Conn.get_req_header(conn, "x-amz-copy-source") == [
               "/tempest-test/temp/blobs/#{did}/#{cid}"
             ]

      Plug.Conn.send_resp(conn, 200, "")
    end)

    Req.Test.expect(__MODULE__, fn conn ->
      assert conn.method == "DELETE"
      assert conn.request_path == "/tempest-test/temp/blobs/did%3Aplc%3As3storage/#{cid}"

      Plug.Conn.send_resp(conn, 204, "")
    end)

    assert {:ok, promoted_path} = S3Storage.promote_blob(config, did, cid)
    assert promoted_path == "blobs/#{did}/#{cid}"
  end

  test "get_blob reads public object bytes", %{config: config, did: did, cid: cid} do
    Req.Test.expect(__MODULE__, fn conn ->
      assert conn.method == "GET"
      assert conn.request_path == "/tempest-test/blobs/did%3Aplc%3As3storage/#{cid}"

      conn
      |> Plug.Conn.put_resp_content_type("text/plain")
      |> Plug.Conn.send_resp(200, "s3 bytes")
    end)

    assert {:ok, %{bytes: "s3 bytes", content_length: 8, mime_type: "text/plain"}} =
             S3Storage.get_blob(config, did, cid, "text/plain")
  end

  test "delete_blob deletes temp and public keys", %{config: config, did: did, cid: cid} do
    Req.Test.expect(__MODULE__, fn conn ->
      assert conn.method == "DELETE"
      assert conn.request_path == "/tempest-test/temp/blobs/did%3Aplc%3As3storage/#{cid}"

      Plug.Conn.send_resp(conn, 404, "")
    end)

    Req.Test.expect(__MODULE__, fn conn ->
      assert conn.method == "DELETE"
      assert conn.request_path == "/tempest-test/blobs/did%3Aplc%3As3storage/#{cid}"

      Plug.Conn.send_resp(conn, 204, "")
    end)

    assert :ok = S3Storage.delete_blob(config, did, cid)
  end

  test "list_blobs remains metadata-authoritative", %{config: config, did: did} do
    assert {:error, :metadata_authoritative} = S3Storage.list_blobs(config, did, limit: 10)
  end
end
