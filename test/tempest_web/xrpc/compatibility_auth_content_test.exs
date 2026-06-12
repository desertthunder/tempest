defmodule TempestWeb.Xrpc.CompatibilityAuthContentTest do
  use TempestWeb.ConnCase, async: false

  alias Tempest.{Accounts, AdminAuth}
  alias Tempest.OAuth.Dpop

  @password "correct horse battery staple"
  @client_id "did:web:compat-client.example.com"
  @redirect_uri "https://compat-client.example.com/cb"

  setup do
    old_hash = Application.get_env(:tempest, :admin_token_hash)

    on_exit(fn ->
      if old_hash do
        Application.put_env(:tempest, :admin_token_hash, old_hash)
      else
        Application.delete_env(:tempest, :admin_token_hash)
      end
    end)

    :ok
  end

  test "ConnCase auth matrix covers bearer, app password, OAuth, admin, and missing credentials", %{conn: conn} do
    account = create_account!("auth-matrix.test", "auth-matrix@example.com")
    access_jwt = account["accessJwt"]
    did = account["did"]

    assert %{"did" => ^did, "handle" => "auth-matrix.test"} =
             conn
             |> bearer(access_jwt)
             |> get(~p"/xrpc/com.atproto.server.getSession")
             |> json_response(200)

    assert_error(
      get(conn, ~p"/xrpc/com.atproto.server.getSession"),
      401,
      "AuthenticationRequired",
      "Bearer token is required"
    )

    app_password = create_app_password!(conn, access_jwt)

    assert %{"uri" => "at://" <> _, "commit" => %{"cid" => _}} =
             conn
             |> bearer_json(app_password)
             |> post(~p"/xrpc/com.atproto.repo.createRecord", %{
               "repo" => account["did"],
               "collection" => "app.tempest.note",
               "rkey" => "app-password",
               "validate" => false,
               "record" => %{"$type" => "app.tempest.note", "text" => "app password write"}
             })
             |> json_response(200)

    assert_error(
      conn
      |> bearer(app_password)
      |> get(~p"/xrpc/com.atproto.server.getSession"),
      403,
      "AuthScopeInsufficient",
      "Bearer token scope is insufficient"
    )

    oauth_access = issue_oauth_access_token!(conn, account)
    dpop = dpop("POST", "http://localhost:4000/xrpc/com.atproto.repo.createRecord", Dpop.issue_nonce())

    assert %{"uri" => "at://" <> _, "commit" => %{"cid" => _}} =
             conn
             |> recycle()
             |> put_req_header("authorization", "Bearer #{oauth_access}")
             |> put_req_header("dpop", dpop)
             |> put_req_header("content-type", "application/json")
             |> post(~p"/xrpc/com.atproto.repo.createRecord", %{
               "repo" => account["did"],
               "collection" => "app.tempest.note",
               "rkey" => "oauth",
               "validate" => false,
               "record" => %{"$type" => "app.tempest.note", "text" => "oauth write"}
             })
             |> json_response(200)

    assert_error(
      conn
      |> recycle()
      |> put_req_header("authorization", "Bearer #{oauth_access}")
      |> put_req_header("content-type", "application/json")
      |> post(~p"/xrpc/com.atproto.repo.createRecord", %{
        "repo" => account["did"],
        "collection" => "app.tempest.note",
        "rkey" => "oauth-missing-dpop",
        "validate" => false,
        "record" => %{"$type" => "app.tempest.note", "text" => "missing dpop"}
      }),
      401,
      "InvalidToken",
      "DPoP proof is required"
    )

    Application.put_env(:tempest, :admin_token_hash, AdminAuth.hash_token("admin-secret-token"))

    assert_error(
      conn
      |> recycle()
      |> put_req_header("authorization", "Bearer admin-secret-token")
      |> get(~p"/xrpc/com.atproto.server.getSession"),
      401,
      "InvalidToken",
      "Bearer token is invalid"
    )

    assert_error(
      conn
      |> recycle()
      |> put_req_header("authorization", "Bearer #{access_jwt}")
      |> get(~p"/xrpc/_admin/status"),
      401,
      "InvalidToken",
      "Admin bearer token is invalid"
    )
  end

  test "XRPC verb checks reject GET procedures and POST queries before handlers", %{conn: conn} do
    account = create_account!("verb-matrix.test", "verb-matrix@example.com")

    assert_error(
      post_json(conn, ~p"/xrpc/com.atproto.server.describeServer", %{}),
      400,
      "InvalidRequest",
      "com.atproto.server.describeServer is a query method and must use GET, not POST"
    )

    assert_error(
      get(conn, ~p"/xrpc/com.atproto.server.createSession"),
      400,
      "InvalidRequest",
      "com.atproto.server.createSession is a procedure method and must use POST, not GET"
    )

    assert_error(
      conn
      |> bearer(account["accessJwt"])
      |> post(~p"/xrpc/com.atproto.server.getSession", %{}),
      400,
      "InvalidRequest",
      "com.atproto.server.getSession is a query method and must use GET, not POST"
    )

    assert_error(
      conn
      |> bearer(account["accessJwt"])
      |> get(~p"/xrpc/com.atproto.repo.createRecord"),
      400,
      "InvalidRequest",
      "com.atproto.repo.createRecord is a procedure method and must use POST, not GET"
    )

    assert_error_contains(
      conn
      |> recycle()
      |> get(~p"/xrpc/com.atproto.sync.subscribeRepos"),
      426,
      "UpgradeRequired",
      "host"
    )
  end

  test "XRPC content-type checks cover JSON, blob, CAR, and empty-body procedures", %{conn: conn} do
    account = create_account!("content-type-matrix.test", "content-type-matrix@example.com")
    access_jwt = account["accessJwt"]

    assert_error(
      conn
      |> recycle()
      |> put_req_header("content-type", "text/plain")
      |> post(~p"/xrpc/com.atproto.server.createSession", "not json"),
      400,
      "InvalidRequest",
      "request body must use content-type application/json"
    )

    assert_error(
      raw_post_no_content_type(~p"/xrpc/com.atproto.repo.uploadBlob", access_jwt, "abc"),
      400,
      "InvalidRequest",
      "request body must include a content-type"
    )

    assert_error(
      conn
      |> bearer(access_jwt)
      |> put_req_header("content-type", "text/plain")
      |> post(~p"/xrpc/com.atproto.repo.importRepo", "not a car"),
      400,
      "InvalidRequest",
      "request body must use content-type application/vnd.ipld.car"
    )

    assert_error(
      conn
      |> bearer(access_jwt)
      |> put_req_header("content-type", "application/vnd.ipld.car")
      |> post(~p"/xrpc/com.atproto.repo.importRepo", "not a car"),
      400,
      "InvalidRequest",
      "import CAR is invalid"
    )

    assert %{"handle" => "content-type-matrix.test"} =
             conn
             |> bearer(account["refreshJwt"])
             |> post(~p"/xrpc/com.atproto.server.refreshSession")
             |> json_response(200)
  end

  defp create_account!(handle, email) do
    {:ok, account} =
      Accounts.create_account(%{
        "handle" => handle,
        "email" => email,
        "password" => @password
      })

    account
  end

  defp create_app_password!(conn, access_jwt) do
    conn
    |> bearer_json(access_jwt)
    |> post(~p"/xrpc/com.atproto.server.createAppPassword", %{"name" => "compat", "scope" => "atproto"})
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

    token_conn =
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

    token_conn
    |> json_response(200)
    |> Map.fetch!("access_token")
  end

  defp bearer(conn, token) do
    conn
    |> recycle()
    |> put_req_header("authorization", "Bearer #{token}")
  end

  defp bearer_json(conn, token) do
    conn
    |> bearer(token)
    |> put_req_header("content-type", "application/json")
  end

  defp raw_post_no_content_type(path, token, body) do
    conn =
      Plug.Test.conn("POST", path, body)
      |> put_req_header("authorization", "Bearer #{token}")

    TempestWeb.Endpoint.call(conn, [])
  end

  defp post_json(conn, path, params) do
    conn
    |> recycle()
    |> put_req_header("content-type", "application/json")
    |> post(path, params)
  end

  defp dpop(method, url, nonce) do
    header = %{
      "typ" => "dpop+jwt",
      "alg" => "ES256",
      "jwk" => %{"kty" => "EC", "crv" => "P-256", "x" => "x", "y" => "y"}
    }

    payload = %{
      "htu" => url,
      "htm" => method,
      "iat" => DateTime.utc_now() |> DateTime.to_unix(),
      "jti" => Ecto.UUID.generate(),
      "nonce" => nonce
    }

    [header, payload, "signature"]
    |> Enum.map(&encode_part/1)
    |> Enum.join(".")
  end

  defp encode_part(value) when is_map(value), do: value |> Jason.encode!() |> encode_part()
  defp encode_part(value), do: Base.url_encode64(value, padding: false)

  defp code_challenge(verifier) do
    :crypto.hash(:sha256, verifier) |> Base.url_encode64(padding: false)
  end

  defp assert_error(conn, status, error, message) do
    response = json_response(conn, status)

    assert get_resp_header(conn, "content-type") == ["application/json; charset=utf-8"]
    assert response == %{"error" => error, "message" => message}
  end

  defp assert_error_contains(conn, status, error, message_part) do
    response = json_response(conn, status)

    assert get_resp_header(conn, "content-type") == ["application/json; charset=utf-8"]
    assert response["error"] == error
    assert response["message"] =~ message_part
  end
end
