defmodule TempestWeb.Xrpc.IdentityHandlesTest do
  use TempestWeb.ConnCase, async: false

  import Plug.Conn

  alias Tempest.Accounts.Account
  alias Tempest.Identity
  alias Tempest.Identity.DidDocument
  alias Tempest.Repo

  @password "correct horse battery staple"

  setup context do
    Req.Test.set_req_test_from_context(context)
    Req.Test.verify_on_exit!(context)

    old_identity_config = Application.get_env(:tempest, Tempest.Identity, [])

    on_exit(fn ->
      Application.put_env(:tempest, Tempest.Identity, old_identity_config)
    end)

    :ok
  end

  test "local handle resolves to DID through well-known and XRPC", %{conn: conn} do
    account = create_account!(conn, "alice.test", "alice@example.com")

    well_known_conn =
      conn
      |> recycle()
      |> Map.put(:host, "alice.test")
      |> get(~p"/.well-known/atproto-did")

    assert response(well_known_conn, 200) == account["did"]
    assert get_resp_header(well_known_conn, "content-type") == ["text/plain; charset=utf-8"]

    resolve_conn =
      conn
      |> recycle()
      |> get(~p"/xrpc/com.atproto.identity.resolveHandle", %{"handle" => "alice.test"})

    assert json_response(resolve_conn, 200) == %{"did" => account["did"]}
  end

  test "DID document claims local handle", %{conn: conn} do
    account = create_account!(conn, "brigid.test", "brigid@example.com")
    stored_account = Repo.get_by!(Account, did: account["did"])

    document = Identity.did_document_for_account(stored_account)

    assert document["id"] == account["did"]
    assert DidDocument.claims_handle?(document, "brigid.test")
    assert [%{"type" => "Multikey", "publicKeyMultibase" => "u" <> _public_key}] = document["verificationMethod"]

    assert [%{"type" => "AtprotoPersonalDataServer", "serviceEndpoint" => "http://localhost:4002"}] =
             document["service"]
  end

  test "invalid handle fails validation", %{conn: conn} do
    create_conn =
      conn
      |> put_req_header("content-type", "application/json")
      |> post(~p"/xrpc/com.atproto.server.createAccount", %{
        "handle" => "not-a-handle",
        "email" => "invalid@example.com",
        "password" => @password
      })

    assert %{"error" => "InvalidRequest", "message" => message} = json_response(create_conn, 400)
    assert message =~ "handle has invalid syntax"

    resolve_conn = get(conn, ~p"/xrpc/com.atproto.identity.resolveHandle", %{"handle" => "not-a-handle"})

    assert %{"error" => "InvalidRequest"} = json_response(resolve_conn, 400)
  end

  test "external handle resolves through fake HTTPS handle service", %{conn: conn} do
    did = "did:plc:abcdefghijklmnopqrstuvwxyz234567"

    put_identity_test_config(%{
      "remote.test" => {:ok, [{93, 184, 216, 34}]}
    })

    Req.Test.expect(__MODULE__, fn req_conn ->
      assert req_conn.scheme == :https
      assert req_conn.host == "remote.test"
      assert req_conn.request_path == "/.well-known/atproto-did"

      send_resp(req_conn, 200, did)
    end)

    resolve_conn = get(conn, ~p"/xrpc/com.atproto.identity.resolveHandle", %{"handle" => "remote.test"})

    assert json_response(resolve_conn, 200) == %{"did" => did}
  end

  test "outbound handle verification rejects private IP targets", %{conn: conn} do
    account = create_account!(conn, "claire.test", "claire@example.com")

    put_identity_test_config(%{
      "private.test" => {:ok, [{127, 0, 0, 1}]}
    })

    update_conn =
      conn
      |> recycle()
      |> put_req_header("authorization", "Bearer #{account["accessJwt"]}")
      |> put_req_header("content-type", "application/json")
      |> post(~p"/xrpc/com.atproto.identity.updateHandle", %{"handle" => "private.test"})

    response = json_response(update_conn, 400)

    assert response["error"] == "InvalidRequest"
    assert response["message"] =~ "private or local address"
  end

  test "updateHandle succeeds after bidirectional local verification", %{conn: conn} do
    account = create_account!(conn, "diana.test", "diana@example.com")

    update_conn =
      conn
      |> recycle()
      |> put_req_header("authorization", "Bearer #{account["accessJwt"]}")
      |> put_req_header("content-type", "application/json")
      |> post(~p"/xrpc/com.atproto.identity.updateHandle", %{"handle" => "diana.test"})

    response = json_response(update_conn, 200)

    assert response["did"] == account["did"]
    assert response["handle"] == "diana.test"
    assert sequencer_event_count(account["did"], "identity.handle.update") == 1
  end

  defp create_account!(conn, handle, email) do
    conn
    |> put_req_header("content-type", "application/json")
    |> post(~p"/xrpc/com.atproto.server.createAccount", %{
      "handle" => handle,
      "email" => email,
      "password" => @password
    })
    |> json_response(200)
  end

  defp put_identity_test_config(addresses_by_host) do
    Application.put_env(:tempest, Tempest.Identity,
      dns_txt_lookup: fn _query -> [] end,
      dns_lookup: fn host -> Map.get(addresses_by_host, host, {:error, :nxdomain}) end,
      http_req_options: [plug: {Req.Test, __MODULE__}]
    )
  end

  defp sequencer_event_count(did, event_type) do
    path =
      Tempest.Config.load!()
      |> Tempest.Config.sequencer_db_path()

    {:ok, conn} = Exqlite.Sqlite3.open(path)

    {:ok, statement} =
      Exqlite.Sqlite3.prepare(conn, "SELECT COUNT(*) FROM repo_seq WHERE did = ?1 AND event_type = ?2")

    :ok = Exqlite.Sqlite3.bind(statement, [did, event_type])
    {:ok, [[count]]} = Exqlite.Sqlite3.fetch_all(conn, statement)
    :ok = Exqlite.Sqlite3.release(conn, statement)
    :ok = Exqlite.Sqlite3.close(conn)

    count
  end
end
