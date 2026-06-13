defmodule TempestWeb.Xrpc.PlcIdentityTest do
  use TempestWeb.ConnCase, async: false

  import Ecto.Query
  import Plug.Conn

  alias Tempest.Accounts.Account
  alias Tempest.Identity.SigningKey
  alias Tempest.Repo
  alias Tempest.Security
  alias Tempest.Security.SecurityEvent

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
