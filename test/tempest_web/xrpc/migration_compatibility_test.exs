defmodule TempestWeb.Xrpc.MigrationCompatibilityTest do
  use TempestWeb.ConnCase, async: false

  alias Tempest.Accounts.Account
  alias Tempest.{Blobs, Identity, Repo}

  import Ecto.Query

  @password "correct horse battery staple"

  setup context do
    Req.Test.set_req_test_from_context(context)
    Req.Test.verify_on_exit!(context)

    old_identity_config = Application.get_env(:tempest, Tempest.Identity, [])

    Application.put_env(:tempest, Tempest.Identity,
      http_req_options: [plug: {Req.Test, __MODULE__}],
      dns_lookup: fn _host -> {:ok, [{93, 184, 216, 34}]} end
    )

    on_exit(fn -> Application.put_env(:tempest, Tempest.Identity, old_identity_config) end)
  end

  test "migration-out from one local Tempest instance and migration-in to another", %{conn: conn} do
    source_account = create_account!(conn, "migration-source.test", "migration-source@example.com")
    did = source_account["did"]
    source_access = source_account["accessJwt"]

    blob_bytes = <<137, 80, 78, 71, 13, 10, 26, 10, 0, 0, 0, 13, 73, 72, 68, 82>>
    blob = upload_blob!(conn, source_account, blob_bytes, "image/png")["blob"]
    blob_cid = blob["ref"]["$link"]

    _profile =
      conn
      |> recycle()
      |> auth_json(source_access)
      |> post(~p"/xrpc/com.atproto.repo.createRecord", %{
        "repo" => did,
        "collection" => "app.bsky.actor.profile",
        "rkey" => "self",
        "record" => %{
          "$type" => "app.bsky.actor.profile",
          "displayName" => "Portable Account",
          "avatar" => blob
        }
      })
      |> json_response(200)

    exported_car =
      conn
      |> recycle()
      |> get(~p"/xrpc/com.atproto.sync.getRepo", %{"did" => did})
      |> response(200)

    assert byte_size(exported_car) > 0

    service_auth =
      conn
      |> recycle()
      |> put_req_header("authorization", "Bearer #{source_access}")
      |> get(~p"/xrpc/com.atproto.server.getServiceAuth", %{
        "aud" => Tempest.Config.load!().public_url,
        "lxm" => "com.atproto.server.createAccount"
      })
      |> json_response(200)
      |> Map.fetch!("token")

    source = account!(did)
    source_document = Identity.did_document_for_account(source)

    assert %{} = source_document

    assert %{} =
             conn
             |> recycle()
             |> put_req_header("authorization", "Bearer #{source_access}")
             |> put_req_header("content-type", "application/json")
             |> post(~p"/xrpc/com.atproto.server.deactivateAccount", %{})
             |> json_response(200)

    assert %{"error" => "RepoDeactivated"} =
             conn
             |> recycle()
             |> get(~p"/xrpc/com.atproto.sync.getRepo", %{"did" => did})
             |> json_response(400)

    # The source and target HTTP clients below represent two local Tempest instances.
    # ConnCase gives them a shared test database, so remove the source row after the
    # public migration-out assertions to model the target instance's empty account DB.
    Repo.delete!(account!(did))
    remove_repo_database!(did)
    :ok = Blobs.delete_metadata(did, [blob_cid])

    Req.Test.expect(__MODULE__, fn req_conn ->
      assert req_conn.request_path in ["/#{URI.encode(did)}", "/#{did}"]
      Req.Test.json(req_conn, source_document)
    end)

    target_account =
      conn
      |> recycle()
      |> put_req_header("content-type", "application/json")
      |> post(~p"/xrpc/com.atproto.server.createAccount", %{
        "did" => did,
        "handle" => "migration-target.test",
        "email" => "migration-target@example.com",
        "password" => @password,
        "serviceAuth" => service_auth
      })
      |> json_response(200)

    assert target_account["did"] == did
    assert target_account["active"] == false
    assert target_account["status"] == "deactivated"

    Req.Test.expect(__MODULE__, fn req_conn ->
      assert req_conn.request_path in ["/#{URI.encode(did)}", "/#{did}"]
      Req.Test.json(req_conn, source_document)
    end)

    assert %{"cid" => _, "rev" => _, "recordCount" => 1} =
             conn
             |> recycle()
             |> put_req_header("authorization", "Bearer #{target_account["accessJwt"]}")
             |> put_req_header("content-type", "application/vnd.ipld.car")
             |> post(~p"/xrpc/com.atproto.repo.importRepo", exported_car)
             |> json_response(200)

    assert %{"blobs" => [%{"cid" => ^blob_cid}]} =
             conn
             |> recycle()
             |> put_req_header("authorization", "Bearer #{target_account["accessJwt"]}")
             |> get(~p"/xrpc/com.atproto.repo.listMissingBlobs")
             |> json_response(200)

    assert %{"migrationReady" => false, "missingBlobCount" => 1} =
             conn
             |> recycle()
             |> put_req_header("authorization", "Bearer #{target_account["accessJwt"]}")
             |> get(~p"/xrpc/com.atproto.server.checkAccountStatus")
             |> json_response(200)

    assert {:ok, upload} =
             Blobs.validate_upload(blob_bytes, byte_size(blob_bytes), "image/png", Tempest.Config.load!())

    assert upload.cid == blob_cid
    assert :ok = Blobs.put_temp_metadata(did, upload)
    assert :ok = Blobs.mark_public(did, [blob_cid])

    assert %{"blobs" => []} =
             conn
             |> recycle()
             |> put_req_header("authorization", "Bearer #{target_account["accessJwt"]}")
             |> get(~p"/xrpc/com.atproto.repo.listMissingBlobs")
             |> json_response(200)

    assert %{} =
             conn
             |> recycle()
             |> put_req_header("authorization", "Bearer #{target_account["accessJwt"]}")
             |> put_req_header("content-type", "application/json")
             |> post(~p"/xrpc/com.atproto.server.activateAccount", %{})
             |> json_response(200)

    assert %{"value" => %{"displayName" => "Portable Account"}} =
             conn
             |> recycle()
             |> get(~p"/xrpc/com.atproto.repo.getRecord", %{
               "repo" => did,
               "collection" => "app.bsky.actor.profile",
               "rkey" => "self"
             })
             |> json_response(200)
  end

  defp create_account!(conn, handle, email) do
    conn
    |> recycle()
    |> put_req_header("content-type", "application/json")
    |> post(~p"/xrpc/com.atproto.server.createAccount", %{
      "handle" => handle,
      "email" => email,
      "password" => @password
    })
    |> json_response(200)
  end

  defp upload_blob!(conn, account, bytes, mime_type) do
    conn
    |> recycle()
    |> put_req_header("authorization", "Bearer #{account["accessJwt"]}")
    |> put_req_header("content-type", mime_type)
    |> put_req_header("content-length", Integer.to_string(byte_size(bytes)))
    |> post(~p"/xrpc/com.atproto.repo.uploadBlob", bytes)
    |> json_response(200)
  end

  defp auth_json(conn, access_jwt) do
    conn
    |> put_req_header("authorization", "Bearer #{access_jwt}")
    |> put_req_header("content-type", "application/json")
  end

  defp account!(did) do
    Repo.one!(from account in Account, where: account.did == ^did)
  end

  defp remove_repo_database!(did) do
    path = Tempest.RepoStorage.repo_db_path!(Tempest.Config.load!(), did)

    for suffix <- ["", "-wal", "-shm"] do
      path
      |> Kernel.<>(suffix)
      |> File.rm()
    end

    :ok
  end
end
