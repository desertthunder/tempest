defmodule TempestWeb.Xrpc.PlcIdentityTest do
  use TempestWeb.ConnCase, async: false

  import Ecto.Query
  import Plug.Conn

  alias Tempest.Accounts.Account
  alias Tempest.AdminAuth
  alias Tempest.Identity.PlcOperation
  alias Tempest.Identity.SigningKey
  alias Tempest.Repo
  alias Tempest.Security
  alias Tempest.OAuth.Dpop
  alias Tempest.Security.SecurityEvent
  alias Tempest.Sequencer

  @password "correct horse battery staple"
  @client_id "did:web:plc-identity-client.example.com"
  @redirect_uri "https://plc-identity-client.example.com/cb"

  setup context do
    Req.Test.set_req_test_from_context(context)
    Req.Test.verify_on_exit!(context)

    old_identity_config = Application.get_env(:tempest, Tempest.Identity, [])
    old_admin_hash = Application.get_env(:tempest, :admin_token_hash)

    on_exit(fn ->
      Application.put_env(:tempest, Tempest.Identity, old_identity_config)

      if old_admin_hash do
        Application.put_env(:tempest, :admin_token_hash, old_admin_hash)
      else
        Application.delete_env(:tempest, :admin_token_hash)
      end
    end)

    :ok
  end

  test "getRecommendedDidCredentials requires bearer auth", %{conn: conn} do
    conn = get(conn, ~p"/xrpc/com.atproto.identity.getRecommendedDidCredentials")

    assert %{"error" => "AuthenticationRequired", "message" => "Bearer token is required"} = json_response(conn, 401)
  end

  test "getRecommendedDidCredentials returns local key-store and PLC operation shape", %{conn: conn} do
    account = create_account!(conn, "plc-creds.test", "plc-creds@example.com")
    stored_account = Repo.get_by!(Account, did: account["did"])
    signing_key = Repo.get_by!(SigningKey, account_id: stored_account.id, active: true)

    conn =
      conn
      |> recycle()
      |> put_req_header("authorization", "Bearer #{account["accessJwt"]}")
      |> get(~p"/xrpc/com.atproto.identity.getRecommendedDidCredentials")

    response = json_response(conn, 200)

    assert response["did"] == account["did"]
    assert response["handle"] == "plc-creds.test"
    assert response["signingKey"] == signing_key.public_key_multibase
    assert response["verificationMethods"] == %{"atproto" => signing_key.public_key_multibase}
    assert [rotation_key] = response["rotationKeys"]
    assert String.starts_with?(rotation_key, "did:key:u")
    refute rotation_key == signing_key.public_key_multibase
    assert response["alsoKnownAs"] == ["at://plc-creds.test"]

    assert response["services"] == %{
             "atproto_pds" => %{
               "type" => "AtprotoPersonalDataServer",
               "endpoint" => "http://localhost:4002"
             }
           }
  end

  test "getRecommendedDidCredentials is consistent with fake PLC publication boundary", %{conn: conn} do
    put_identity_test_config()

    Req.Test.expect(__MODULE__, fn req_conn ->
      assert req_conn.method == "POST"
      assert req_conn.host == "plc.test"
      assert req_conn.request_path =~ "/did:plc:"

      {:ok, body, req_conn} = Plug.Conn.read_body(req_conn)
      decoded = Jason.decode!(body)

      assert [rotation_key] = decoded["rotationKeys"]
      assert String.starts_with?(rotation_key, "did:key:u")
      refute rotation_key == decoded["verificationMethods"]["atproto"]
      assert decoded["services"]["atproto_pds"]["endpoint"] == "http://localhost:4002"

      send_resp(req_conn, 200, Jason.encode!(%{"ok" => true}))
    end)

    account = create_account!(conn, "plc-publish.test", "plc-publish@example.com")

    conn =
      conn
      |> recycle()
      |> put_req_header("authorization", "Bearer #{account["accessJwt"]}")
      |> get(~p"/xrpc/com.atproto.identity.getRecommendedDidCredentials")

    response = json_response(conn, 200)
    refute response["verificationMethods"]["atproto"] in response["rotationKeys"]
  end

  test "getRecommendedDidCredentials derives rotation keys from configured private material", %{conn: conn} do
    private_key = :crypto.strong_rand_bytes(32)
    expected_rotation_key = public_did_key(private_key)
    Application.put_env(:tempest, Tempest.Identity, plc_rotation_key: multibase64(private_key))

    account = create_account!(conn, "plc-configured-key.test", "plc-configured-key@example.com")

    conn =
      conn
      |> recycle()
      |> put_req_header("authorization", "Bearer #{account["accessJwt"]}")
      |> get(~p"/xrpc/com.atproto.identity.getRecommendedDidCredentials")

    response = json_response(conn, 200)
    assert response["rotationKeys"] == [expected_rotation_key]
    refute response["signingKey"] in response["rotationKeys"]
  end

  test "signPlcOperation fetches existing PLC state before building update operation", %{conn: conn} do
    put_identity_test_config(fetch_existing_plc_state: true)

    Req.Test.expect(__MODULE__, 3, fn req_conn ->
      case req_conn.method do
        "POST" ->
          send_resp(req_conn, 200, Jason.encode!(%{"ok" => true}))

        "GET" ->
          send_resp(req_conn, 200, Jason.encode!(%{"cid" => "bafy-old-plc-op"}))
      end
    end)

    account = create_account!(conn, "plc-prev.test", "plc-prev@example.com")
    stored_account = Repo.get_by!(Account, did: account["did"])
    operation = PlcOperation.for_account(stored_account, prev: "bafy-old-plc-op")
    token = request_plc_token!(conn, account["accessJwt"])

    conn =
      conn
      |> recycle()
      |> put_req_header("authorization", "Bearer #{account["accessJwt"]}")
      |> put_req_header("content-type", "application/json")
      |> post(~p"/xrpc/com.atproto.identity.signPlcOperation", sign_params(operation, token))

    assert %{"operation" => %{"prev" => "bafy-old-plc-op"}} = json_response(conn, 200)
  end

  test "migration-out PLC endpoint chain builds signs and submits through fake PLC", %{conn: conn} do
    account = create_account!(conn, "plc-migration-out.test", "plc-migration-out@example.com")
    {:ok, seq_before} = Sequencer.current_seq()

    credentials =
      conn
      |> recycle()
      |> put_req_header("authorization", "Bearer #{account["accessJwt"]}")
      |> get(~p"/xrpc/com.atproto.identity.getRecommendedDidCredentials")
      |> json_response(200)

    token = request_plc_token!(conn, account["accessJwt"])

    sign_input =
      credentials
      |> Map.take(["rotationKeys", "alsoKnownAs", "verificationMethods", "services"])
      |> Map.put("token", token)

    signed_operation =
      conn
      |> recycle()
      |> put_req_header("authorization", "Bearer #{account["accessJwt"]}")
      |> put_req_header("content-type", "application/json")
      |> post(~p"/xrpc/com.atproto.identity.signPlcOperation", sign_input)
      |> json_response(200)
      |> Map.fetch!("operation")

    put_identity_test_config()

    Req.Test.expect(__MODULE__, fn req_conn ->
      assert req_conn.method == "POST"
      assert req_conn.request_path == "/" <> URI.encode(account["did"])

      {:ok, body, req_conn} = Plug.Conn.read_body(req_conn)
      submitted = Jason.decode!(body)

      assert submitted == signed_operation
      assert submitted["services"]["atproto_pds"]["endpoint"] == "http://localhost:4002"
      assert [rotation_key] = submitted["rotationKeys"]
      assert String.starts_with?(rotation_key, "did:key:u")
      refute rotation_key == submitted["verificationMethods"]["atproto"]

      send_resp(req_conn, 200, Jason.encode!(%{"ok" => true}))
    end)

    assert %{} =
             conn
             |> recycle()
             |> put_req_header("authorization", "Bearer #{account["accessJwt"]}")
             |> put_req_header("content-type", "application/json")
             |> post(~p"/xrpc/com.atproto.identity.submitPlcOperation", %{"operation" => signed_operation})
             |> json_response(200)

    assert {:ok, events} = Sequencer.list_after(seq_before, did: account["did"], type: "#identity")
    assert Enum.any?(events, &(&1.payload["action"] == "plc.submit"))
  end

  test "PLC operation endpoints enforce auth matrix for migration-sensitive actions", %{conn: conn} do
    account = create_account!(conn, "plc-auth-matrix.test", "plc-auth-matrix@example.com")
    stored_account = Repo.get_by!(Account, did: account["did"])
    operation = PlcOperation.for_account(stored_account)

    assert %{"token" => token} =
             conn
             |> recycle()
             |> put_req_header("authorization", "Bearer #{account["accessJwt"]}")
             |> put_req_header("content-type", "application/json")
             |> post(~p"/xrpc/com.atproto.identity.requestPlcOperationSignature", %{"password" => @password})
             |> json_response(200)

    signed_operation =
      conn
      |> recycle()
      |> put_req_header("authorization", "Bearer #{account["accessJwt"]}")
      |> put_req_header("content-type", "application/json")
      |> post(~p"/xrpc/com.atproto.identity.signPlcOperation", sign_params(operation, token))
      |> json_response(200)
      |> Map.fetch!("operation")

    put_identity_test_config()

    Req.Test.expect(__MODULE__, fn req_conn ->
      send_resp(req_conn, 200, Jason.encode!(%{"ok" => true}))
    end)

    assert %{} =
             conn
             |> recycle()
             |> put_req_header("authorization", "Bearer #{account["accessJwt"]}")
             |> put_req_header("content-type", "application/json")
             |> post(~p"/xrpc/com.atproto.identity.submitPlcOperation", %{"operation" => signed_operation})
             |> json_response(200)

    assert_error(
      get(conn, ~p"/xrpc/com.atproto.identity.getRecommendedDidCredentials"),
      401,
      "AuthenticationRequired",
      "Bearer token is required"
    )

    app_password = create_app_password!(conn, account["accessJwt"])

    assert_error(
      conn
      |> recycle()
      |> put_req_header("authorization", "Bearer #{app_password}")
      |> get(~p"/xrpc/com.atproto.identity.getRecommendedDidCredentials"),
      403,
      "AuthScopeInsufficient",
      "Bearer token scope is insufficient"
    )

    oauth_access = issue_oauth_access_token!(conn, account)

    assert_error(
      conn
      |> recycle()
      |> put_req_header("authorization", "Bearer #{oauth_access}")
      |> put_req_header(
        "dpop",
        dpop("GET", "http://localhost:4000/xrpc/com.atproto.identity.getRecommendedDidCredentials", Dpop.issue_nonce())
      )
      |> get(~p"/xrpc/com.atproto.identity.getRecommendedDidCredentials"),
      403,
      "AuthScopeInsufficient",
      "Bearer token scope is insufficient"
    )

    Application.put_env(:tempest, :admin_token_hash, AdminAuth.hash_token("admin-secret-token"))

    assert_error(
      conn
      |> recycle()
      |> put_req_header("authorization", "Bearer admin-secret-token")
      |> get(~p"/xrpc/com.atproto.identity.getRecommendedDidCredentials"),
      401,
      "InvalidToken",
      "Bearer token is invalid"
    )
  end

  test "requestPlcOperationSignature requires bearer auth and JSON error shape", %{conn: conn} do
    conn =
      conn
      |> put_req_header("content-type", "application/json")
      |> post(~p"/xrpc/com.atproto.identity.requestPlcOperationSignature", %{"password" => @password})

    assert %{"error" => "AuthenticationRequired", "message" => "Bearer token is required"} = json_response(conn, 401)
  end

  test "requestPlcOperationSignature enforces strong password reauth", %{conn: conn} do
    account = create_account!(conn, "plc-reauth.test", "plc-reauth@example.com")

    conn =
      conn
      |> recycle()
      |> put_req_header("authorization", "Bearer #{account["accessJwt"]}")
      |> put_req_header("content-type", "application/json")
      |> post(~p"/xrpc/com.atproto.identity.requestPlcOperationSignature", %{"password" => "wrong password"})

    assert %{"error" => "AuthenticationRequired", "message" => "password is invalid"} = json_response(conn, 401)
  end

  test "requestPlcOperationSignature returns single-use token and writes audit log", %{conn: conn} do
    account = create_account!(conn, "plc-token.test", "plc-token@example.com")
    stored_account = Repo.get_by!(Account, did: account["did"])

    conn =
      conn
      |> recycle()
      |> put_req_header("authorization", "Bearer #{account["accessJwt"]}")
      |> put_req_header("content-type", "application/json")
      |> post(~p"/xrpc/com.atproto.identity.requestPlcOperationSignature", %{"password" => @password})

    assert %{"token" => token} = json_response(conn, 200)
    assert is_binary(token)
    assert byte_size(token) >= 40

    assert audit_event_count(stored_account, "plc_operation_signature.requested") == 1
    assert {:ok, _token_record} = Security.consume_plc_operation_token(stored_account, token)
    assert {:error, :invalid_token} = Security.consume_plc_operation_token(stored_account, token)
    assert audit_event_count(stored_account, "plc_operation_signature.token_consumed") == 1
  end

  test "requestPlcOperationSignature returns InvalidRequest when password is missing", %{conn: conn} do
    account = create_account!(conn, "plc-error.test", "plc-error@example.com")

    conn =
      conn
      |> recycle()
      |> put_req_header("authorization", "Bearer #{account["accessJwt"]}")
      |> put_req_header("content-type", "application/json")
      |> post(~p"/xrpc/com.atproto.identity.requestPlcOperationSignature", %{})

    assert %{"error" => "InvalidRequest", "message" => "password is required"} = json_response(conn, 400)
  end

  test "signPlcOperation consumes reauth token and returns signed operation", %{conn: conn} do
    account = create_account!(conn, "plc-sign.test", "plc-sign@example.com")
    stored_account = Repo.get_by!(Account, did: account["did"])
    operation = PlcOperation.for_account(stored_account)
    token = request_plc_token!(conn, account["accessJwt"])

    conn =
      conn
      |> recycle()
      |> put_req_header("authorization", "Bearer #{account["accessJwt"]}")
      |> put_req_header("content-type", "application/json")
      |> post(~p"/xrpc/com.atproto.identity.signPlcOperation", sign_params(operation, token))

    assert %{"operation" => signed_operation} = json_response(conn, 200)
    assert is_binary(signed_operation["sig"])
    assert {:ok, _signature} = Base.url_decode64(signed_operation["sig"], padding: false)
    assert Map.delete(signed_operation, "sig") == operation
    assert audit_event_count(stored_account, "plc_operation_signature.token_consumed") == 1
    assert audit_event_count(stored_account, "plc_operation.signed") == 1

    conn =
      conn
      |> recycle()
      |> put_req_header("authorization", "Bearer #{account["accessJwt"]}")
      |> put_req_header("content-type", "application/json")
      |> post(~p"/xrpc/com.atproto.identity.signPlcOperation", sign_params(operation, token))

    assert %{"error" => "AuthenticationRequired", "message" => "PLC operation token is invalid"} =
             json_response(conn, 401)
  end

  test "signPlcOperation rejects service-diverting and unrecoverable operations", %{conn: conn} do
    account = create_account!(conn, "plc-invalid-sign.test", "plc-invalid-sign@example.com")
    stored_account = Repo.get_by!(Account, did: account["did"])
    operation = PlcOperation.for_account(stored_account)
    token = request_plc_token!(conn, account["accessJwt"])

    diverted =
      put_in(operation, ["services", "atproto_pds", "endpoint"], "https://elsewhere.invalid")

    conn =
      conn
      |> recycle()
      |> put_req_header("authorization", "Bearer #{account["accessJwt"]}")
      |> put_req_header("content-type", "application/json")
      |> post(~p"/xrpc/com.atproto.identity.signPlcOperation", sign_params(diverted, token))

    assert %{"error" => "InvalidRequest", "message" => "PLC operation must point at this PDS"} =
             json_response(conn, 400)

    token = request_plc_token!(conn, account["accessJwt"])
    unrecoverable = Map.put(operation, "rotationKeys", ["did:key:zUnusable"])

    conn =
      conn
      |> recycle()
      |> put_req_header("authorization", "Bearer #{account["accessJwt"]}")
      |> put_req_header("content-type", "application/json")
      |> post(~p"/xrpc/com.atproto.identity.signPlcOperation", sign_params(unrecoverable, token))

    assert %{"error" => "InvalidRequest", "message" => "PLC operation must preserve account recovery"} =
             json_response(conn, 400)
  end

  test "submitPlcOperation submits signed operation through fake PLC and records events", %{conn: conn} do
    account = create_account!(conn, "plc-submit.test", "plc-submit@example.com")
    stored_account = Repo.get_by!(Account, did: account["did"])
    operation = PlcOperation.for_account(stored_account)
    signed_operation = sign_operation!(conn, account["accessJwt"], operation)
    {:ok, seq_before} = Sequencer.current_seq()

    put_identity_test_config()

    Req.Test.expect(__MODULE__, fn req_conn ->
      assert req_conn.method == "POST"
      assert req_conn.host == "plc.test"
      assert req_conn.request_path == "/" <> URI.encode(account["did"])

      {:ok, body, req_conn} = Plug.Conn.read_body(req_conn)
      decoded = Jason.decode!(body)

      assert decoded == signed_operation
      assert is_binary(decoded["sig"])
      assert decoded["services"]["atproto_pds"]["endpoint"] == "http://localhost:4002"

      send_resp(req_conn, 200, Jason.encode!(%{"ok" => true}))
    end)

    conn =
      conn
      |> recycle()
      |> put_req_header("authorization", "Bearer #{account["accessJwt"]}")
      |> put_req_header("content-type", "application/json")
      |> post(~p"/xrpc/com.atproto.identity.submitPlcOperation", %{"operation" => signed_operation})

    assert %{} = json_response(conn, 200)
    assert audit_event_count(stored_account, "plc_operation.submitted") == 1

    assert {:ok, events} = Sequencer.list_after(seq_before, did: account["did"], type: "#identity")
    assert Enum.any?(events, &(&1.payload["action"] == "plc.submit"))

    Req.Test.expect(__MODULE__, fn req_conn ->
      {:ok, body, req_conn} = Plug.Conn.read_body(req_conn)

      assert Jason.decode!(body) == signed_operation
      send_resp(req_conn, 200, Jason.encode!(%{"ok" => true}))
    end)

    conn =
      conn
      |> recycle()
      |> put_req_header("authorization", "Bearer #{account["accessJwt"]}")
      |> put_req_header("content-type", "application/json")
      |> post(~p"/xrpc/com.atproto.identity.submitPlcOperation", %{"operation" => signed_operation})

    assert %{} = json_response(conn, 200)
    assert audit_event_count(stored_account, "plc_operation.submitted") == 2
  end

  test "submitPlcOperation rejects unsigned, diverted, and failed PLC operations", %{conn: conn} do
    account = create_account!(conn, "plc-submit-fail.test", "plc-submit-fail@example.com")
    stored_account = Repo.get_by!(Account, did: account["did"])
    operation = PlcOperation.for_account(stored_account)

    conn =
      conn
      |> recycle()
      |> put_req_header("authorization", "Bearer #{account["accessJwt"]}")
      |> put_req_header("content-type", "application/json")
      |> post(~p"/xrpc/com.atproto.identity.submitPlcOperation", %{"operation" => operation})

    assert %{"error" => "InvalidRequest", "message" => "signed PLC operation is required"} =
             json_response(conn, 400)

    signed_operation = sign_operation!(conn, account["accessJwt"], operation)

    diverted =
      put_in(signed_operation, ["services", "atproto_pds", "endpoint"], "https://elsewhere.invalid")

    conn =
      conn
      |> recycle()
      |> put_req_header("authorization", "Bearer #{account["accessJwt"]}")
      |> put_req_header("content-type", "application/json")
      |> post(~p"/xrpc/com.atproto.identity.submitPlcOperation", %{"operation" => diverted})

    assert %{"error" => "InvalidRequest", "message" => "PLC operation must point at this PDS"} =
             json_response(conn, 400)

    put_identity_test_config()

    Req.Test.expect(__MODULE__, fn req_conn ->
      send_resp(req_conn, 500, Jason.encode!(%{"error" => "bad"}))
    end)

    conn =
      conn
      |> recycle()
      |> put_req_header("authorization", "Bearer #{account["accessJwt"]}")
      |> put_req_header("content-type", "application/json")
      |> post(~p"/xrpc/com.atproto.identity.submitPlcOperation", %{"operation" => signed_operation})

    assert %{"error" => "UpstreamFailure", "message" => "PLC directory rejected the operation"} =
             json_response(conn, 502)

    assert audit_event_count(stored_account, "plc_operation.submit_failed") == 3
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

  defp create_app_password!(conn, access_jwt) do
    conn
    |> recycle()
    |> put_req_header("authorization", "Bearer #{access_jwt}")
    |> put_req_header("content-type", "application/json")
    |> post(~p"/xrpc/com.atproto.server.createAppPassword", %{"name" => "plc-auth", "scope" => "atproto"})
    |> json_response(200)
    |> Map.fetch!("password")
  end

  defp issue_oauth_access_token!(conn, account) do
    par_conn =
      conn
      |> recycle()
      |> put_req_header("dpop", dpop("POST", "http://localhost:4002/oauth/par", Dpop.issue_nonce()))
      |> post(~p"/oauth/par", %{
        "client_id" => @client_id,
        "redirect_uri" => @redirect_uri,
        "scope" => "atproto",
        "response_type" => "code",
        "code_challenge" => code_challenge("verifier"),
        "code_challenge_method" => "S256"
      })

    %{"request_uri" => request_uri} = json_response(par_conn, 200)

    authorize_conn =
      conn
      |> recycle()
      |> post(~p"/oauth/authorize", %{
        "request_uri" => request_uri,
        "identifier" => account["handle"],
        "password" => @password
      })

    [location] = get_resp_header(authorize_conn, "location")
    code = location |> URI.parse() |> Map.fetch!(:query) |> URI.decode_query() |> Map.fetch!("code")

    conn
    |> recycle()
    |> put_req_header("dpop", dpop("POST", "http://localhost:4002/oauth/token", Dpop.issue_nonce()))
    |> post(~p"/oauth/token", %{
      "grant_type" => "authorization_code",
      "client_id" => @client_id,
      "redirect_uri" => @redirect_uri,
      "code" => code,
      "code_verifier" => "verifier"
    })
    |> json_response(200)
    |> Map.fetch!("access_token")
  end

  defp request_plc_token!(conn, access_jwt) do
    conn
    |> recycle()
    |> put_req_header("authorization", "Bearer #{access_jwt}")
    |> put_req_header("content-type", "application/json")
    |> post(~p"/xrpc/com.atproto.identity.requestPlcOperationSignature", %{"password" => @password})
    |> json_response(200)
    |> Map.fetch!("token")
  end

  defp sign_operation!(conn, access_jwt, operation) do
    token = request_plc_token!(conn, access_jwt)

    conn
    |> recycle()
    |> put_req_header("authorization", "Bearer #{access_jwt}")
    |> put_req_header("content-type", "application/json")
    |> post(~p"/xrpc/com.atproto.identity.signPlcOperation", sign_params(operation, token))
    |> json_response(200)
    |> Map.fetch!("operation")
  end

  defp sign_params(operation, token) do
    operation
    |> Map.take(["rotationKeys", "alsoKnownAs", "verificationMethods", "services", "prev"])
    |> Map.put("token", token)
  end

  defp put_identity_test_config(extra \\ []) do
    Application.put_env(
      :tempest,
      Tempest.Identity,
      [
        plc_publish_enabled: true,
        plc_directory_url: "https://plc.test",
        http_req_options: [plug: {Req.Test, __MODULE__}]
      ] ++ extra
    )
  end

  defp public_did_key(private_key) do
    {public_key, _private_key} = :crypto.generate_key(:ecdh, :secp256k1, private_key)
    "did:key:" <> multibase64(public_key)
  end

  defp multibase64(key), do: "u" <> Base.url_encode64(key, padding: false)

  defp dpop(method, url, nonce), do: Tempest.DpopProof.proof(method, url, nonce)

  defp code_challenge(verifier) do
    :crypto.hash(:sha256, verifier) |> Base.url_encode64(padding: false)
  end

  defp assert_error(conn, status, error, message) do
    response = json_response(conn, status)

    assert get_resp_header(conn, "content-type") == ["application/json; charset=utf-8"]
    assert response == %{"error" => error, "message" => message}
  end

  defp audit_event_count(%Account{} = account, event_type) do
    SecurityEvent
    |> where([event], event.account_id == ^account.id and event.event_type == ^event_type)
    |> Repo.aggregate(:count)
  end
end
