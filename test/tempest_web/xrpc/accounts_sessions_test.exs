defmodule TempestWeb.Xrpc.AccountsSessionsTest do
  use TempestWeb.ConnCase, async: false

  alias Tempest.Accounts.{Account, Session, Tokens}
  alias Tempest.Identity.SigningKey
  alias Tempest.Repo

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

  test "createAccount persists account and returns session tokens", %{conn: conn} do
    conn = create_account(conn, "alice.test", "alice@example.com")

    response = json_response(conn, 200)

    assert response["did"] =~ "did:plc:"
    assert response["handle"] == "alice.test"
    assert response["email"] == "alice@example.com"
    assert response["active"] == true
    assert is_binary(response["accessJwt"])
    assert is_binary(response["refreshJwt"])

    assert Repo.exists?(from a in Tempest.Accounts.Account, where: a.handle == "alice.test")

    assert Repo.exists?(
             from key in SigningKey, join: account in assoc(key, :account), where: account.handle == "alice.test"
           )

    assert [
             %Tempest.Sequencer.Event{event_type: "#identity", payload: %{"action" => "create"}},
             %Tempest.Sequencer.Event{event_type: "#account", payload: %{"action" => "create"}},
             %Tempest.Sequencer.Event{event_type: "#commit", payload: %{"action" => "repo.init", "ops" => []}}
           ] = sequencer_events(response["did"])
  end

  test "createSession logs in and getSession returns the account", %{conn: conn} do
    create_account(conn, "bob.test", "bob@example.com")

    login_conn = create_session(conn, "bob.test", @password)
    login = json_response(login_conn, 200)

    assert is_binary(login["accessJwt"])
    assert is_binary(login["refreshJwt"])

    session_conn =
      conn
      |> put_req_header("authorization", "Bearer #{login["accessJwt"]}")
      |> get(~p"/xrpc/com.atproto.server.getSession")

    session = json_response(session_conn, 200)

    assert session["did"] == login["did"]
    assert session["handle"] == "bob.test"
    refute Map.has_key?(session, "password_hash")
    refute Map.has_key?(session, "refreshJwt")
  end

  test "refreshSession rotates refresh tokens", %{conn: conn} do
    create_account(conn, "carol.test", "carol@example.com")
    login = conn |> create_session("carol.test", @password) |> json_response(200)

    refresh_conn =
      conn
      |> put_req_header("authorization", "Bearer #{login["refreshJwt"]}")
      |> post(~p"/xrpc/com.atproto.server.refreshSession")

    refreshed = json_response(refresh_conn, 200)

    assert refreshed["handle"] == "carol.test"
    assert refreshed["accessJwt"] != login["accessJwt"]
    assert refreshed["refreshJwt"] != login["refreshJwt"]

    old_session = Repo.get_by!(Session, token_hash: Tokens.refresh_token_hash(login["refreshJwt"]))
    new_session = Repo.get_by!(Session, token_hash: Tokens.refresh_token_hash(refreshed["refreshJwt"]))

    assert old_session.rotated_at
    assert old_session.revoked_at
    assert is_nil(new_session.revoked_at)
    assert old_session.family_id == new_session.family_id
  end

  test "deleteSession prevents future refresh", %{conn: conn} do
    create_account(conn, "dana.test", "dana@example.com")
    login = conn |> create_session("dana.test", @password) |> json_response(200)

    delete_conn =
      conn
      |> put_req_header("authorization", "Bearer #{login["refreshJwt"]}")
      |> post(~p"/xrpc/com.atproto.server.deleteSession")

    assert json_response(delete_conn, 200) == %{}

    refresh_conn =
      conn
      |> put_req_header("authorization", "Bearer #{login["refreshJwt"]}")
      |> post(~p"/xrpc/com.atproto.server.refreshSession")

    response = json_response(refresh_conn, 401)

    assert response["error"] == "InvalidToken"
  end

  test "checkAccountStatus reports repo and blob counts", %{conn: conn} do
    account = conn |> create_account("status.test", "status@example.com") |> json_response(200)

    status_conn =
      conn
      |> put_req_header("authorization", "Bearer #{account["accessJwt"]}")
      |> get(~p"/xrpc/com.atproto.server.checkAccountStatus")

    assert %{
             "did" => did,
             "active" => true,
             "status" => "active",
             "repoCount" => 1,
             "recordCount" => 0,
             "blobCount" => 0,
             "missingBlobCount" => 0,
             "migrationReady" => true
           } = json_response(status_conn, 200)

    assert did == account["did"]
  end

  test "getServiceAuth validates audience and method and returns a verifiable proof", %{conn: conn} do
    account = conn |> create_account("service.test", "service@example.com") |> json_response(200)

    auth_conn =
      conn
      |> put_req_header("authorization", "Bearer #{account["accessJwt"]}")
      |> get(~p"/xrpc/com.atproto.server.getServiceAuth", %{
        "aud" => "did:web:tempest.test",
        "lxm" => "com.atproto.repo.importRepo"
      })

    assert %{"token" => token} = json_response(auth_conn, 200)
    assert {:ok, claims} = Tokens.verify_service_auth(token)
    assert claims["iss"] == account["did"]
    assert claims["aud"] == "did:web:tempest.test"
    assert claims["lxm"] == "com.atproto.repo.importRepo"

    invalid_conn =
      conn
      |> put_req_header("authorization", "Bearer #{account["accessJwt"]}")
      |> get(~p"/xrpc/com.atproto.server.getServiceAuth", %{
        "aud" => "not a did",
        "lxm" => "com.atproto.repo.importRepo"
      })

    assert %{"error" => "InvalidRequest"} = json_response(invalid_conn, 400)
  end

  test "reserveSigningKey returns stable account signing key", %{conn: conn} do
    account = conn |> create_account("key.test", "key@example.com") |> json_response(200)

    first =
      conn
      |> put_req_header("authorization", "Bearer #{account["accessJwt"]}")
      |> put_req_header("content-type", "application/json")
      |> post(~p"/xrpc/com.atproto.server.reserveSigningKey", %{})
      |> json_response(200)

    second =
      conn
      |> put_req_header("authorization", "Bearer #{account["accessJwt"]}")
      |> put_req_header("content-type", "application/json")
      |> post(~p"/xrpc/com.atproto.server.reserveSigningKey", %{})
      |> json_response(200)

    assert first["did"] == account["did"]
    assert first["verificationMethod"] == account["did"] <> "#atproto"
    assert first["signingKey"] == second["signingKey"]
    assert String.starts_with?(first["signingKey"], "did:key:z")
  end

  test "createAccount with an existing DID requires service auth and starts deactivated", %{conn: conn} do
    did = "did:plc:" <> (:crypto.strong_rand_bytes(16) |> Base.encode32(case: :lower, padding: false))

    missing_proof_conn =
      conn
      |> put_req_header("content-type", "application/json")
      |> post(~p"/xrpc/com.atproto.server.createAccount", %{
        "did" => did,
        "handle" => "migrating.test",
        "email" => "migrating@example.com",
        "password" => @password
      })

    assert %{"error" => "InvalidRequest"} = json_response(missing_proof_conn, 400)

    {service_auth, did_document} =
      remote_service_auth(did, Tempest.Config.load!().public_url, "com.atproto.server.createAccount")

    Req.Test.expect(__MODULE__, fn req_conn ->
      assert req_conn.request_path == "/#{did}"
      Req.Test.json(req_conn, did_document)
    end)

    migrated =
      conn
      |> put_req_header("content-type", "application/json")
      |> post(~p"/xrpc/com.atproto.server.createAccount", %{
        "did" => did,
        "handle" => "migrating.test",
        "email" => "migrating@example.com",
        "password" => @password,
        "serviceAuth" => service_auth
      })
      |> json_response(200)

    assert migrated["did"] == did
    assert migrated["active"] == false
    assert migrated["status"] == "deactivated"

    status =
      conn
      |> put_req_header("authorization", "Bearer #{migrated["accessJwt"]}")
      |> get(~p"/xrpc/com.atproto.server.checkAccountStatus")
      |> json_response(200)

    assert status["active"] == false
    assert status["status"] == "deactivated"

    login_conn = create_session(conn, "migrating.test", @password)
    assert %{"error" => "AccountTakedown"} = json_response(login_conn, 403)
  end

  test "createAccount accepts Bluesky-style service auth without kid or sub", %{conn: conn} do
    did = "did:plc:" <> (:crypto.strong_rand_bytes(16) |> Base.encode32(case: :lower, padding: false))

    {service_auth, did_document} =
      remote_service_auth(did, "did:web:tempest.test", "com.atproto.server.createAccount",
        include_kid?: false,
        include_sub?: false,
        public_key_encoding: :base58btc_compressed_multikey,
        lifetime_seconds: 60
      )

    Req.Test.expect(__MODULE__, fn req_conn ->
      assert req_conn.request_path == "/#{did}"
      Req.Test.json(req_conn, did_document)
    end)

    migrated =
      conn
      |> put_req_header("content-type", "application/json")
      |> post(~p"/xrpc/com.atproto.server.createAccount", %{
        "did" => did,
        "handle" => "bluesky-service-auth.test",
        "email" => "bluesky-service-auth@example.com",
        "password" => @password,
        "serviceAuth" => service_auth
      })
      |> json_response(200)

    assert migrated["did"] == did
    assert migrated["active"] == false
    assert migrated["status"] == "deactivated"
  end

  test "refreshSession rotates tokens for deactivated migrated accounts", %{conn: conn} do
    did = "did:plc:" <> (:crypto.strong_rand_bytes(16) |> Base.encode32(case: :lower, padding: false))

    {service_auth, did_document} =
      remote_service_auth(did, "did:web:tempest.test", "com.atproto.server.createAccount",
        include_kid?: false,
        include_sub?: false,
        public_key_encoding: :base58btc_compressed_multikey,
        lifetime_seconds: 60
      )

    Req.Test.expect(__MODULE__, fn req_conn ->
      assert req_conn.request_path == "/#{did}"
      Req.Test.json(req_conn, did_document)
    end)

    migrated =
      conn
      |> put_req_header("content-type", "application/json")
      |> post(~p"/xrpc/com.atproto.server.createAccount", %{
        "did" => did,
        "handle" => "migrated-refresh.test",
        "email" => "migrated-refresh@example.com",
        "password" => @password,
        "serviceAuth" => service_auth
      })
      |> json_response(200)

    refreshed =
      conn
      |> recycle()
      |> put_req_header("authorization", "Bearer #{migrated["refreshJwt"]}")
      |> post(~p"/xrpc/com.atproto.server.refreshSession")
      |> json_response(200)

    assert refreshed["did"] == did
    assert refreshed["active"] == false
    assert refreshed["status"] == "deactivated"
    assert refreshed["accessJwt"] != migrated["accessJwt"]
    assert refreshed["refreshJwt"] != migrated["refreshJwt"]
  end

  test "migrated did:web account stays private until activation emits ordered events", %{conn: conn} do
    did = "did:web:migrated-#{System.unique_integer([:positive])}.example.com"

    {service_auth, did_document} =
      remote_service_auth(did, Tempest.Config.load!().public_url, "com.atproto.server.createAccount")

    Req.Test.expect(__MODULE__, fn req_conn ->
      assert req_conn.request_path == "/.well-known/did.json"
      Req.Test.json(req_conn, did_document)
    end)

    migrated =
      conn
      |> put_req_header("content-type", "application/json")
      |> post(~p"/xrpc/com.atproto.server.createAccount", %{
        "did" => did,
        "handle" => "migrated-web.test",
        "email" => "migrated-web@example.com",
        "password" => @password,
        "serviceAuth" => service_auth
      })
      |> json_response(200)

    assert migrated["active"] == false

    inactive_repo =
      conn
      |> get(~p"/xrpc/com.atproto.sync.getRepo", %{"did" => did})

    assert %{"error" => "RepoDeactivated"} = json_response(inactive_repo, 400)

    activate =
      conn
      |> put_req_header("authorization", "Bearer #{migrated["accessJwt"]}")
      |> put_req_header("content-type", "application/json")
      |> post(~p"/xrpc/com.atproto.server.activateAccount", %{})

    assert json_response(activate, 200) == %{}

    active_repo =
      conn
      |> get(~p"/xrpc/com.atproto.sync.getRepo", %{"did" => did})

    assert response(active_repo, 200) =~ "roots"

    assert [create_identity, create_account, activate_identity, activate_account, activate_commit] =
             sequencer_events(did)

    assert create_identity.event_type == "#identity"
    assert create_account.payload["active"] == false
    assert activate_identity.event_type == "#identity"
    assert activate_account.payload["active"] == true
    assert activate_commit.event_type == "#commit"
    assert activate_commit.payload["action"] == "repo.activate"
  end

  test "unavailable old PDS path fails closed without service auth", %{conn: conn} do
    did = "did:web:unavailable-#{System.unique_integer([:positive])}.example.com"

    rejected =
      conn
      |> put_req_header("content-type", "application/json")
      |> post(~p"/xrpc/com.atproto.server.createAccount", %{
        "did" => did,
        "handle" => "unavailable-old-pds.test",
        "email" => "unavailable-old-pds@example.com",
        "password" => @password
      })

    assert %{"error" => "InvalidRequest"} = json_response(rejected, 400)
    refute Repo.exists?(from a in Account, where: a.did == ^did)
  end

  test "activate, deactivate, request delete, and delete account lifecycle", %{conn: conn} do
    account = conn |> create_account("lifecycle.test", "lifecycle@example.com") |> json_response(200)

    deactivate =
      conn
      |> put_req_header("authorization", "Bearer #{account["accessJwt"]}")
      |> put_req_header("content-type", "application/json")
      |> post(~p"/xrpc/com.atproto.server.deactivateAccount", %{})

    assert json_response(deactivate, 200) == %{}

    status =
      conn
      |> put_req_header("authorization", "Bearer #{account["accessJwt"]}")
      |> get(~p"/xrpc/com.atproto.server.checkAccountStatus")
      |> json_response(200)

    assert status["active"] == false
    assert status["status"] == "deactivated"

    activate =
      conn
      |> put_req_header("authorization", "Bearer #{account["accessJwt"]}")
      |> put_req_header("content-type", "application/json")
      |> post(~p"/xrpc/com.atproto.server.activateAccount", %{})

    assert json_response(activate, 200) == %{}

    request_delete =
      conn
      |> put_req_header("authorization", "Bearer #{account["accessJwt"]}")
      |> put_req_header("content-type", "application/json")
      |> post(~p"/xrpc/com.atproto.server.requestAccountDelete", %{})

    assert json_response(request_delete, 200) == %{}

    delete =
      conn
      |> put_req_header("authorization", "Bearer #{account["accessJwt"]}")
      |> put_req_header("content-type", "application/json")
      |> post(~p"/xrpc/com.atproto.server.deleteAccount", %{})

    assert json_response(delete, 200) == %{}

    deleted_status =
      conn
      |> put_req_header("authorization", "Bearer #{account["accessJwt"]}")
      |> get(~p"/xrpc/com.atproto.server.checkAccountStatus")
      |> json_response(401)

    assert deleted_status["error"] == "InvalidToken"

    events = sequencer_events(account["did"])

    assert Enum.map(events, & &1.event_type) == [
             "#identity",
             "#account",
             "#commit",
             "#account",
             "#identity",
             "#account",
             "#commit",
             "#account",
             "#account"
           ]

    assert Enum.at(events, 3).payload["active"] == false
    assert Enum.at(events, 5).payload["active"] == true
    assert Enum.at(events, 6).payload["action"] == "repo.activate"
    assert Enum.at(events, 7).payload["action"] == "delete.request"
    assert Enum.at(events, 8).payload["status"] == "deleted"
  end

  test "protected endpoint rejects missing bearer token", %{conn: conn} do
    conn = get(conn, ~p"/xrpc/com.atproto.server.getSession")
    response = json_response(conn, 401)

    assert response["error"] == "AuthenticationRequired"
  end

  test "createSession rejects wrong password", %{conn: conn} do
    create_account(conn, "erin.test", "erin@example.com")

    conn = create_session(conn, "erin.test", "not the password")
    response = json_response(conn, 401)

    assert response["error"] == "AuthenticationRequired"
  end

  test "reused refresh token revokes the session family", %{conn: conn} do
    create_account(conn, "faye.test", "faye@example.com")
    login = conn |> create_session("faye.test", @password) |> json_response(200)

    refreshed =
      conn
      |> put_req_header("authorization", "Bearer #{login["refreshJwt"]}")
      |> post(~p"/xrpc/com.atproto.server.refreshSession")
      |> json_response(200)

    reuse_conn =
      conn
      |> put_req_header("authorization", "Bearer #{login["refreshJwt"]}")
      |> post(~p"/xrpc/com.atproto.server.refreshSession")

    assert %{"error" => "InvalidToken"} = json_response(reuse_conn, 401)

    family_id =
      Session
      |> where([s], s.token_hash == ^Tokens.refresh_token_hash(refreshed["refreshJwt"]))
      |> select([s], s.family_id)
      |> Repo.one!()

    assert Repo.aggregate(from(s in Session, where: s.family_id == ^family_id and is_nil(s.revoked_at)), :count) == 0
  end

  defp create_account(conn, handle, email) do
    conn
    |> put_req_header("content-type", "application/json")
    |> post(~p"/xrpc/com.atproto.server.createAccount", %{
      "handle" => handle,
      "email" => email,
      "password" => @password
    })
  end

  defp create_session(conn, identifier, password) do
    conn
    |> put_req_header("content-type", "application/json")
    |> post(~p"/xrpc/com.atproto.server.createSession", %{
      "identifier" => identifier,
      "password" => password
    })
  end

  defp sequencer_events(did) do
    {:ok, events} = Tempest.Sequencer.list_after(0, did: did)
    events
  end

  defp remote_service_auth(did, audience, method_nsid, opts \\ []) do
    key = JOSE.JWK.generate_key({:ec, "secp256k1"})
    {_kty, private_jwk} = JOSE.JWK.to_map(key)
    public_key_multibase = public_key_multibase(private_jwk, opts)
    now = DateTime.utc_now() |> DateTime.to_unix()

    headers =
      %{"typ" => "JWT", "alg" => "ES256K"}
      |> maybe_put(Keyword.get(opts, :include_kid?, true), "kid", did <> "#atproto")

    claims =
      %{
        "iss" => did,
        "aud" => audience,
        "lxm" => method_nsid,
        "iat" => now,
        "exp" => now + Keyword.get(opts, :lifetime_seconds, 600)
      }
      |> maybe_put(Keyword.get(opts, :include_sub?, true), "sub", did)

    {_jws, token} = JOSE.JWT.sign(key, headers, claims) |> JOSE.JWS.compact()

    document = %{
      "@context" => ["https://www.w3.org/ns/did/v1"],
      "id" => did,
      "verificationMethod" => [
        %{
          "id" => did <> "#atproto",
          "type" => "Multikey",
          "controller" => did,
          "publicKeyMultibase" => public_key_multibase
        }
      ]
    }

    {token, document}
  end

  defp public_key_multibase(private_jwk, opts) do
    case Keyword.get(opts, :public_key_encoding, :base64url_uncompressed) do
      :base58btc_compressed_multikey -> compressed_base58btc_multikey(private_jwk)
      :base64url_uncompressed -> base64url_uncompressed_multibase(private_jwk)
    end
  end

  defp base64url_uncompressed_multibase(%{"x" => encoded_x, "y" => encoded_y}) do
    x = Base.url_decode64!(encoded_x, padding: false)
    y = Base.url_decode64!(encoded_y, padding: false)
    "u" <> Base.url_encode64(<<4, x::binary, y::binary>>, padding: false)
  end

  defp compressed_base58btc_multikey(%{"x" => encoded_x, "y" => encoded_y}) do
    x = Base.url_decode64!(encoded_x, padding: false)
    y = Base.url_decode64!(encoded_y, padding: false)
    prefix = if rem(:binary.decode_unsigned(y), 2) == 0, do: 2, else: 3
    multikey = <<0xE7, 0x01, prefix, x::binary>>
    "z" <> base58btc_encode(multikey)
  end

  defp base58btc_encode(bytes) do
    alphabet = ~c"123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz"
    value = :binary.decode_unsigned(bytes)
    encoded = encode_base58_value(value, alphabet, [])

    leading_zeroes =
      bytes
      |> :binary.bin_to_list()
      |> Enum.take_while(&(&1 == 0))
      |> length()

    List.to_string(List.duplicate(?1, leading_zeroes) ++ encoded)
  end

  defp encode_base58_value(0, _alphabet, []), do: [?1]
  defp encode_base58_value(0, _alphabet, acc), do: acc

  defp encode_base58_value(value, alphabet, acc) do
    encode_base58_value(div(value, 58), alphabet, [Enum.at(alphabet, rem(value, 58)) | acc])
  end

  defp maybe_put(map, true, key, value), do: Map.put(map, key, value)
  defp maybe_put(map, false, _key, _value), do: map
end
