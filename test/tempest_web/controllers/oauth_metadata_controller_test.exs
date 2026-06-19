defmodule TempestWeb.OAuthMetadataControllerTest do
  use TempestWeb.ConnCase, async: false

  setup do
    jwks_path = Path.join(System.tmp_dir!(), "tempest-oauth-jwks-#{System.unique_integer([:positive])}.json")
    original = Application.get_env(:tempest, Tempest.OAuth.Jwks, [])
    Application.put_env(:tempest, Tempest.OAuth.Jwks, path: jwks_path)

    on_exit(fn ->
      Application.put_env(:tempest, Tempest.OAuth.Jwks, original)
      File.rm(jwks_path)
    end)

    :ok
  end

  test "protected resource metadata is protocol-shaped", %{conn: conn} do
    conn = get(conn, "/.well-known/oauth-protected-resource")

    assert %{
             "resource" => "http://localhost:4002",
             "authorization_servers" => ["http://localhost:4002"],
             "scopes_supported" => scopes,
             "bearer_methods_supported" => ["header"]
           } = json_response(conn, 200)

    assert "atproto" in scopes
    assert "blob:*/*" in scopes
  end

  test "authorization server metadata advertises required atproto OAuth features", %{conn: conn} do
    conn = get(conn, "/.well-known/oauth-authorization-server")

    assert %{
             "issuer" => "http://localhost:4002",
             "authorization_endpoint" => "http://localhost:4002/oauth/authorize",
             "token_endpoint" => "http://localhost:4002/oauth/token",
             "introspection_endpoint" => "http://localhost:4002/oauth/introspect",
             "revocation_endpoint" => "http://localhost:4002/oauth/revoke",
             "jwks_uri" => "http://localhost:4002/oauth/jwks",
             "pushed_authorization_request_endpoint" => "http://localhost:4002/oauth/par",
             "require_pushed_authorization_requests" => true,
             "code_challenge_methods_supported" => ["S256"],
             "token_endpoint_auth_methods_supported" => auth_methods,
             "token_endpoint_auth_signing_alg_values_supported" => auth_algs,
             "dpop_signing_alg_values_supported" => dpop_algs
           } = json_response(conn, 200)

    assert "private_key_jwt" in auth_methods
    assert auth_algs == ["ES256"]
    assert "ES256" in dpop_algs
  end

  test "jwks endpoint publishes public signing keys only", %{conn: conn} do
    conn = get(conn, "/oauth/jwks")

    assert %{"keys" => [key]} = json_response(conn, 200)
    assert key["kty"] == "EC"
    assert key["crv"] == "P-256"
    assert key["alg"] == "ES256"
    assert is_binary(key["kid"])
    assert is_binary(key["x"])
    assert is_binary(key["y"])
    refute Map.has_key?(key, "d")
  end
end
