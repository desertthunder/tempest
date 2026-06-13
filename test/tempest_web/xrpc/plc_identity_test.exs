defmodule TempestWeb.Xrpc.PlcIdentityTest do
  use TempestWeb.ConnCase, async: false

  import Ecto.Query
  import Plug.Conn

  alias Tempest.Accounts.Account
  alias Tempest.Identity.PlcOperation
  alias Tempest.Identity.SigningKey
  alias Tempest.Repo
  alias Tempest.Security
  alias Tempest.Security.SecurityEvent
  alias Tempest.Sequencer

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
    assert response["rotationKeys"] == [signing_key.public_key_multibase]
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

      assert decoded["rotationKeys"] == [decoded["verificationMethods"]["atproto"]]
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
    assert response["verificationMethods"]["atproto"] in response["rotationKeys"]
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
    |> Map.take(["rotationKeys", "alsoKnownAs", "verificationMethods", "services"])
    |> Map.put("token", token)
  end

  defp put_identity_test_config do
    Application.put_env(:tempest, Tempest.Identity,
      plc_publish_enabled: true,
      plc_directory_url: "https://plc.test",
      http_req_options: [plug: {Req.Test, __MODULE__}]
    )
  end

  defp audit_event_count(%Account{} = account, event_type) do
    SecurityEvent
    |> where([event], event.account_id == ^account.id and event.event_type == ^event_type)
    |> Repo.aggregate(:count)
  end
end
