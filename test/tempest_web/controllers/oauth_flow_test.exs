defmodule TempestWeb.OAuthFlowTest do
  use TempestWeb.ConnCase, async: false

  alias Tempest.Accounts
  alias Tempest.OAuth.Dpop
  alias Tempest.Security.ExternalMetadataFetcher

  @password "correct horse battery staple"
  @client_id "https://client.example.com/oauth/client-metadata.json"
  @redirect_uri "https://client.example.com/cb"

  setup context do
    Req.Test.set_req_test_from_context(context)
    Req.Test.verify_on_exit!(context)

    original_fetcher_config = Application.get_env(:tempest, ExternalMetadataFetcher, [])

    Application.put_env(:tempest, ExternalMetadataFetcher,
      dns_lookup: fn "client.example.com" -> {:ok, [{93, 184, 216, 34}]} end,
      req_options: [plug: {Req.Test, __MODULE__}]
    )

    {:ok, account} =
      Accounts.create_account(%{
        "handle" => "oauth-flow-#{System.unique_integer([:positive])}.test",
        "email" => "oauth-flow-#{System.unique_integer([:positive])}@example.com",
        "password" => @password
      })

    on_exit(fn ->
      Application.put_env(:tempest, ExternalMetadataFetcher, original_fetcher_config)
    end)

    {:ok, account: account}
  end

  test "authorization-code flow issues scoped DPoP token and revokes it", %{conn: conn, account: account} do
    Req.Test.stub(__MODULE__, fn conn ->
      Req.Test.json(conn, client_metadata())
    end)

    par_conn =
      conn
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

    token_response = json_response(token_conn, 200)

    assert token_response["token_type"] == "DPoP"
    assert token_response["scope"] == "atproto"
    assert token_response["sub"] == account["did"]
    assert is_binary(token_response["access_token"])
    assert is_binary(token_response["refresh_token"])

    refresh_conn =
      conn
      |> recycle()
      |> put_req_header("dpop", dpop("POST", "http://localhost:4002/oauth/token", Dpop.issue_nonce()))
      |> post(~p"/oauth/token", %{
        "grant_type" => "refresh_token",
        "client_id" => @client_id,
        "refresh_token" => token_response["refresh_token"]
      })

    refreshed_response = json_response(refresh_conn, 200)

    assert refreshed_response["token_type"] == "DPoP"
    assert refreshed_response["scope"] == "atproto"
    assert refreshed_response["sub"] == account["did"]
    assert is_binary(refreshed_response["access_token"])
    assert is_binary(refreshed_response["refresh_token"])
    refute refreshed_response["access_token"] == token_response["access_token"]
    refute refreshed_response["refresh_token"] == token_response["refresh_token"]

    revoke_conn =
      conn
      |> recycle()
      |> post(~p"/oauth/revoke", %{"token" => refreshed_response["access_token"], "client_id" => @client_id})

    assert response(revoke_conn, 200) == ""
  end

  test "private_key_jwt client auth works for PAR, token exchange, and refresh", %{conn: conn, account: account} do
    client_key = JOSE.JWK.generate_key({:ec, "P-256"})
    client_jwks = %{"keys" => [public_client_jwk(client_key)]}

    Req.Test.stub(__MODULE__, fn conn ->
      Req.Test.json(conn, client_metadata("private_key_jwt", client_jwks))
    end)

    par_assertion = client_assertion(client_key, "par-jti")

    par_conn =
      conn
      |> put_req_header("dpop", dpop("POST", "http://localhost:4002/oauth/par", Dpop.issue_nonce()))
      |> post(~p"/oauth/par", %{
        "client_id" => @client_id,
        "redirect_uri" => @redirect_uri,
        "scope" => "atproto",
        "response_type" => "code",
        "code_challenge" => code_challenge("verifier"),
        "code_challenge_method" => "S256",
        "client_assertion_type" => client_assertion_type(),
        "client_assertion" => par_assertion
      })

    %{"request_uri" => request_uri} = json_response(par_conn, 200)

    replay_par_conn =
      conn
      |> recycle()
      |> put_req_header("dpop", dpop("POST", "http://localhost:4002/oauth/par", Dpop.issue_nonce()))
      |> post(~p"/oauth/par", %{
        "client_id" => @client_id,
        "redirect_uri" => @redirect_uri,
        "scope" => "atproto",
        "response_type" => "code",
        "code_challenge" => code_challenge("verifier"),
        "code_challenge_method" => "S256",
        "client_assertion_type" => client_assertion_type(),
        "client_assertion" => par_assertion
      })

    assert %{"error" => "invalid_client"} = json_response(replay_par_conn, 400)

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

    missing_assertion_conn =
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

    assert %{"error" => "invalid_client"} = json_response(missing_assertion_conn, 400)

    token_assertion = client_assertion(client_key, "token-jti")

    token_conn =
      conn
      |> recycle()
      |> put_req_header("dpop", dpop("POST", "http://localhost:4002/oauth/token", Dpop.issue_nonce()))
      |> post(~p"/oauth/token", %{
        "grant_type" => "authorization_code",
        "client_id" => @client_id,
        "redirect_uri" => @redirect_uri,
        "code" => code,
        "code_verifier" => "verifier",
        "client_assertion_type" => client_assertion_type(),
        "client_assertion" => token_assertion
      })

    token_response = json_response(token_conn, 200)
    assert token_response["token_type"] == "DPoP"
    assert is_binary(token_response["refresh_token"])

    refresh_assertion = client_assertion(client_key, "refresh-jti")

    refresh_conn =
      conn
      |> recycle()
      |> put_req_header("dpop", dpop("POST", "http://localhost:4002/oauth/token", Dpop.issue_nonce()))
      |> post(~p"/oauth/token", %{
        "grant_type" => "refresh_token",
        "client_id" => @client_id,
        "refresh_token" => token_response["refresh_token"],
        "client_assertion_type" => client_assertion_type(),
        "client_assertion" => refresh_assertion
      })

    refreshed_response = json_response(refresh_conn, 200)
    assert refreshed_response["token_type"] == "DPoP"

    replay_refresh_conn =
      conn
      |> recycle()
      |> put_req_header("dpop", dpop("POST", "http://localhost:4002/oauth/token", Dpop.issue_nonce()))
      |> post(~p"/oauth/token", %{
        "grant_type" => "refresh_token",
        "client_id" => @client_id,
        "refresh_token" => refreshed_response["refresh_token"],
        "client_assertion_type" => client_assertion_type(),
        "client_assertion" => refresh_assertion
      })

    assert %{"error" => "invalid_client"} = json_response(replay_refresh_conn, 400)
  end

  defp dpop(method, url, nonce), do: Tempest.DpopProof.proof(method, url, nonce)

  defp code_challenge(verifier) do
    :crypto.hash(:sha256, verifier) |> Base.url_encode64(padding: false)
  end

  defp client_metadata(auth_method \\ "none", jwks \\ nil) do
    %{
      "client_id" => @client_id,
      "client_name" => "OAuth Flow Test Client",
      "redirect_uris" => [@redirect_uri],
      "grant_types" => ["authorization_code", "refresh_token"],
      "response_types" => ["code"],
      "scope" => "atproto",
      "token_endpoint_auth_method" => "none",
      "application_type" => "web",
      "dpop_bound_access_tokens" => true
    }
    |> put_private_key_jwt_metadata(auth_method, jwks)
  end

  defp put_private_key_jwt_metadata(metadata, "none", _jwks), do: metadata

  defp put_private_key_jwt_metadata(metadata, "private_key_jwt", jwks) do
    metadata
    |> Map.put("token_endpoint_auth_method", "private_key_jwt")
    |> Map.put("token_endpoint_auth_signing_alg", "ES256")
    |> Map.put("jwks", jwks)
  end

  defp public_client_jwk(key) do
    key
    |> JOSE.JWK.to_public()
    |> JOSE.JWK.to_map()
    |> elem(1)
    |> Map.put("kid", "client-key-1")
    |> Map.put("alg", "ES256")
  end

  defp client_assertion(key, jti) do
    now = DateTime.utc_now() |> DateTime.to_unix()

    headers = %{
      "typ" => "JWT",
      "alg" => "ES256",
      "kid" => "client-key-1"
    }

    claims = %{
      "iss" => @client_id,
      "sub" => @client_id,
      "aud" => "http://localhost:4002",
      "iat" => now,
      "exp" => now + 60,
      "jti" => jti
    }

    {_modules, compact} = JOSE.JWT.sign(key, headers, claims) |> JOSE.JWS.compact()
    compact
  end

  defp client_assertion_type do
    "urn:ietf:params:oauth:client-assertion-type:jwt-bearer"
  end
end
