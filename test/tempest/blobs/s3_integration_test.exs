defmodule Tempest.Blobs.S3IntegrationTest do
  use TempestWeb.ConnCase

  alias Tempest.Blobs

  @password "correct horse battery staple"

  setup context do
    Req.Test.set_req_test_from_context(context)
    Req.Test.verify_on_exit!(context)

    old_blob_config = Application.get_env(:tempest, Blobs)

    Application.put_env(:tempest, Blobs,
      storage_adapter: Tempest.Blobs.S3Storage,
      storage_config: [
        endpoint_url: "https://objects.example.test",
        bucket: "tempest-test",
        req_options: [plug: {Req.Test, __MODULE__}],
        headers: [{"authorization", "Bearer test-token"}]
      ]
    )

    on_exit(fn ->
      if old_blob_config do
        Application.put_env(:tempest, Blobs, old_blob_config)
      else
        Application.delete_env(:tempest, Blobs)
      end
    end)

    :ok
  end

  test "upload, record reference, and sync getBlob use configured S3 adapter", %{conn: conn} do
    account = create_account!(conn)
    cid = Blobs.cid_for("s3 integration bytes")

    Req.Test.expect(__MODULE__, fn conn ->
      assert conn.method == "PUT"
      assert conn.request_path == "/tempest-test/temp/blobs/#{encoded_did(account["did"])}/#{cid}"
      assert Plug.Conn.get_req_header(conn, "authorization") == ["Bearer test-token"]
      assert {:ok, "s3 integration bytes", conn} = Plug.Conn.read_body(conn)
      Plug.Conn.send_resp(conn, 200, "")
    end)

    blob = upload_blob!(conn, account, "s3 integration bytes")["blob"]
    assert blob["ref"]["$link"] == cid

    Req.Test.expect(__MODULE__, fn conn ->
      assert conn.method == "PUT"
      assert conn.request_path == "/tempest-test/blobs/#{encoded_did(account["did"])}/#{cid}"

      assert Plug.Conn.get_req_header(conn, "x-amz-copy-source") == [
               "/tempest-test/temp/blobs/#{account["did"]}/#{cid}"
             ]

      Plug.Conn.send_resp(conn, 200, "")
    end)

    Req.Test.expect(__MODULE__, fn conn ->
      assert conn.method == "DELETE"
      assert conn.request_path == "/tempest-test/temp/blobs/#{encoded_did(account["did"])}/#{cid}"
      Plug.Conn.send_resp(conn, 204, "")
    end)

    conn
    |> auth_json(account)
    |> post(~p"/xrpc/com.atproto.repo.createRecord", %{
      "repo" => account["did"],
      "collection" => "app.tempest.blob",
      "rkey" => "s3",
      "validate" => false,
      "record" => %{"$type" => "app.tempest.blob", "image" => blob}
    })
    |> json_response(200)

    Req.Test.expect(__MODULE__, fn conn ->
      assert conn.method == "GET"
      assert conn.request_path == "/tempest-test/blobs/#{encoded_did(account["did"])}/#{cid}"
      conn |> Plug.Conn.put_resp_content_type("text/plain") |> Plug.Conn.send_resp(200, "s3 integration bytes")
    end)

    response =
      conn
      |> recycle()
      |> get(~p"/xrpc/com.atproto.sync.getBlob", %{"did" => account["did"], "cid" => cid})

    assert response(response, 200) == "s3 integration bytes"
  end

  defp create_account!(conn) do
    unique = System.unique_integer([:positive])

    conn
    |> put_req_header("content-type", "application/json")
    |> post(~p"/xrpc/com.atproto.server.createAccount", %{
      "handle" => "s3-integration-#{unique}.test",
      "email" => "s3-integration-#{unique}@example.com",
      "password" => @password
    })
    |> json_response(200)
  end

  defp upload_blob!(conn, account, bytes) do
    conn
    |> recycle()
    |> put_req_header("authorization", "Bearer #{account["accessJwt"]}")
    |> put_req_header("content-type", "text/plain")
    |> put_req_header("content-length", Integer.to_string(byte_size(bytes)))
    |> post(~p"/xrpc/com.atproto.repo.uploadBlob", bytes)
    |> json_response(200)
  end

  defp auth_json(conn, account) do
    conn
    |> recycle()
    |> put_req_header("authorization", "Bearer #{account["accessJwt"]}")
    |> put_req_header("content-type", "application/json")
  end

  defp encoded_did(did), do: URI.encode(did, &URI.char_unreserved?/1)
end
