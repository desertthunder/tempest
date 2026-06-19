defmodule Tempest.OAuth.ClientMetadataTest do
  use ExUnit.Case, async: false

  alias Tempest.OAuth.ClientMetadata
  alias Tempest.Security.ExternalMetadataFetcher

  @client_id "https://client.example.com/oauth/client-metadata.json"
  @reserved_root_client_id "https://client.example/oauth/client-metadata.json"
  @redirect_uri "https://client.example.com/callback"

  setup context do
    Req.Test.set_req_test_from_context(context)
    Req.Test.verify_on_exit!(context)

    original_fetcher_config = Application.get_env(:tempest, ExternalMetadataFetcher, [])

    Application.put_env(:tempest, ExternalMetadataFetcher,
      dns_lookup: fn
        "client.example.com" -> {:ok, [{93, 184, 216, 34}]}
        "client.example" -> {:ok, [{93, 184, 216, 34}]}
      end,
      req_options: [plug: {Req.Test, __MODULE__}]
    )

    on_exit(fn ->
      Application.put_env(:tempest, ExternalMetadataFetcher, original_fetcher_config)
    end)

    :ok
  end

  test "accepts public DPoP-bound client metadata registered for the request" do
    Req.Test.expect(__MODULE__, fn conn ->
      Req.Test.json(conn, metadata())
    end)

    assert {:ok, %ClientMetadata{} = client} =
             ClientMetadata.fetch_for_par(%{
               "client_id" => @client_id,
               "redirect_uri" => @redirect_uri,
               "scope" => "atproto"
             })

    assert client.client_id == @client_id
    assert client.redirect_uris == [@redirect_uri]
    assert client.scope == "atproto rpc:*"
  end

  test "rejects mismatched redirect_uri" do
    Req.Test.expect(__MODULE__, fn conn ->
      Req.Test.json(conn, metadata())
    end)

    assert {:error, :invalid_request} =
             ClientMetadata.fetch_for_par(%{
               "client_id" => @client_id,
               "redirect_uri" => "https://client.example.com/other",
               "scope" => "atproto"
             })
  end

  test "rejects unregistered requested scopes" do
    Req.Test.expect(__MODULE__, fn conn ->
      Req.Test.json(conn, metadata())
    end)

    assert {:error, :invalid_scope} =
             ClientMetadata.fetch_for_par(%{
               "client_id" => @client_id,
               "redirect_uri" => @redirect_uri,
               "scope" => "transition:email"
             })
  end

  test "allows wildcard scope registration within a resource family" do
    Req.Test.expect(__MODULE__, fn conn ->
      Req.Test.json(conn, metadata())
    end)

    assert {:ok, %ClientMetadata{}} =
             ClientMetadata.fetch_for_par(%{
               "client_id" => @client_id,
               "redirect_uri" => @redirect_uri,
               "scope" => "rpc:com.atproto.server.getSession"
             })
  end

  test "accepts private_key_jwt metadata with inline jwks" do
    Req.Test.expect(__MODULE__, fn conn ->
      Req.Test.json(conn, private_key_jwt_metadata())
    end)

    assert {:ok, %ClientMetadata{} = client} =
             ClientMetadata.fetch_for_par(%{
               "client_id" => @client_id,
               "redirect_uri" => @redirect_uri,
               "scope" => "atproto"
             })

    assert client.token_endpoint_auth_method == "private_key_jwt"
    assert client.token_endpoint_auth_signing_alg == "ES256"
    assert %{"keys" => [%{"kid" => "client-key-1"}]} = client.jwks
  end

  test "accepts private_key_jwt metadata with remote jwks_uri" do
    Req.Test.expect(__MODULE__, 2, fn %{request_path: request_path} = conn ->
      case request_path do
        "/oauth/client-metadata.json" ->
          Req.Test.json(
            conn,
            private_key_jwt_metadata()
            |> Map.delete("jwks")
            |> Map.put("jwks_uri", "https://client.example.com/oauth/jwks.json")
          )

        "/oauth/jwks.json" ->
          Req.Test.json(conn, jwks())
      end
    end)

    assert {:ok, %ClientMetadata{jwks: %{"keys" => [%{"kid" => "client-key-1"}]}}} =
             ClientMetadata.fetch_for_par(%{
               "client_id" => @client_id,
               "redirect_uri" => @redirect_uri,
               "scope" => "atproto"
             })
  end

  test "rejects private_key_jwt metadata without a keyset" do
    Req.Test.expect(__MODULE__, fn conn ->
      Req.Test.json(
        conn,
        metadata()
        |> Map.put("token_endpoint_auth_method", "private_key_jwt")
        |> Map.put("token_endpoint_auth_signing_alg", "ES256")
      )
    end)

    assert {:error, :invalid_client} =
             ClientMetadata.fetch_for_par(%{
               "client_id" => @client_id,
               "redirect_uri" => @redirect_uri,
               "scope" => "atproto"
             })
  end

  test "rejects non-url client ids before fetching" do
    assert {:error, :invalid_client} =
             ClientMetadata.fetch_for_par(%{
               "client_id" => "did:web:client.example.com",
               "redirect_uri" => @redirect_uri,
               "scope" => "atproto"
             })
  end

  test "accepts reverse-domain private-use redirects for native clients" do
    Req.Test.expect(__MODULE__, fn conn ->
      Req.Test.json(conn, native_metadata(%{"redirect_uris" => ["com.example.client:/callback"]}))
    end)

    assert {:ok, %ClientMetadata{} = client} =
             ClientMetadata.fetch_for_par(%{
               "client_id" => @client_id,
               "redirect_uri" => "com.example.client:/callback",
               "scope" => "atproto"
             })

    assert client.redirect_uris == ["com.example.client:/callback"]
  end

  test "accepts same-origin https redirects for native clients" do
    Req.Test.expect(__MODULE__, fn conn ->
      Req.Test.json(conn, native_metadata(%{"redirect_uris" => ["https://client.example.com/native/callback"]}))
    end)

    assert {:ok, %ClientMetadata{}} =
             ClientMetadata.fetch_for_par(%{
               "client_id" => @client_id,
               "redirect_uri" => "https://client.example.com/native/callback",
               "scope" => "atproto"
             })
  end

  test "rejects private-use redirects for web clients" do
    Req.Test.expect(__MODULE__, fn conn ->
      Req.Test.json(conn, metadata(%{"redirect_uris" => ["com.example.client:/callback"]}))
    end)

    assert {:error, :invalid_client} =
             ClientMetadata.fetch_for_par(%{
               "client_id" => @client_id,
               "redirect_uri" => "com.example.client:/callback",
               "scope" => "atproto"
             })
  end

  test "rejects malformed or reserved private-use redirect schemes for native clients" do
    invalid_redirects = [
      "com.example.client://callback",
      "com.example.client:callback",
      "com.example.client:/callback#fragment",
      "com.example.other:/callback"
    ]

    for redirect_uri <- invalid_redirects do
      Req.Test.expect(__MODULE__, fn conn ->
        Req.Test.json(conn, native_metadata(%{"redirect_uris" => [redirect_uri]}))
      end)

      assert {:error, :invalid_client} =
               ClientMetadata.fetch_for_par(%{
                 "client_id" => @client_id,
                 "redirect_uri" => redirect_uri,
                 "scope" => "atproto"
               })
    end
  end

  test "rejects reserved private-use redirect scheme roots even when reverse-domain matched" do
    redirect_uri = "example.client:/callback"

    Req.Test.expect(__MODULE__, fn conn ->
      Req.Test.json(
        conn,
        native_metadata(%{
          "client_id" => @reserved_root_client_id,
          "redirect_uris" => [redirect_uri]
        })
      )
    end)

    assert {:error, :invalid_client} =
             ClientMetadata.fetch_for_par(%{
               "client_id" => @reserved_root_client_id,
               "redirect_uri" => redirect_uri,
               "scope" => "atproto"
             })
  end

  test "rejects native https redirects on a different origin" do
    Req.Test.expect(__MODULE__, fn conn ->
      Req.Test.json(conn, native_metadata(%{"redirect_uris" => ["https://other.example.com/callback"]}))
    end)

    assert {:error, :invalid_client} =
             ClientMetadata.fetch_for_par(%{
               "client_id" => @client_id,
               "redirect_uri" => "https://other.example.com/callback",
               "scope" => "atproto"
             })
  end

  test "synthesizes metadata for localhost development clients" do
    client_id =
      "http://localhost?redirect_uri=http%3A%2F%2F127.0.0.1%2Fcallback&scope=atproto%20rpc%3A*"

    assert {:ok, %ClientMetadata{} = client} =
             ClientMetadata.fetch_for_par(%{
               "client_id" => client_id,
               "redirect_uri" => "http://127.0.0.1:49152/callback",
               "scope" => "rpc:com.atproto.server.getSession"
             })

    assert client.client_id == client_id
    assert client.redirect_uris == ["http://127.0.0.1/callback"]
    assert client.scope == "atproto rpc:*"
    assert client.token_endpoint_auth_method == "none"
  end

  test "localhost development clients default to loopback callbacks and atproto scope" do
    assert {:ok, %ClientMetadata{} = client} =
             ClientMetadata.fetch_for_par(%{
               "client_id" => "http://localhost",
               "redirect_uri" => "http://[::1]:38291/",
               "scope" => "atproto"
             })

    assert client.redirect_uris == ["http://127.0.0.1/", "http://[::1]/"]
    assert client.scope == "atproto"
  end

  test "rejects localhost development client ids with a port or path" do
    for client_id <- ["http://localhost:8080", "http://localhost/oauth/client-metadata.json"] do
      assert {:error, :invalid_client} =
               ClientMetadata.fetch_for_par(%{
                 "client_id" => client_id,
                 "redirect_uri" => "http://127.0.0.1:49152/",
                 "scope" => "atproto"
               })
    end
  end

  test "rejects localhost development redirect uris that are not HTTP loopback hosts" do
    for redirect_uri <- ["https://127.0.0.1/callback", "http://example.com/callback"] do
      client_id = "http://localhost?redirect_uri=#{URI.encode_www_form(redirect_uri)}"

      assert {:error, :invalid_client} =
               ClientMetadata.fetch_for_par(%{
                 "client_id" => client_id,
                 "redirect_uri" => redirect_uri,
                 "scope" => "atproto"
               })
    end
  end

  defp metadata(overrides \\ %{}) do
    Map.merge(
      %{
        "client_id" => @client_id,
        "client_name" => "Client Metadata Test",
        "redirect_uris" => [@redirect_uri],
        "grant_types" => ["authorization_code", "refresh_token"],
        "response_types" => ["code"],
        "scope" => "atproto rpc:*",
        "token_endpoint_auth_method" => "none",
        "application_type" => "web",
        "dpop_bound_access_tokens" => true
      },
      overrides
    )
  end

  defp native_metadata(overrides) do
    metadata(
      Map.merge(
        %{
          "application_type" => "native"
        },
        overrides
      )
    )
  end

  defp private_key_jwt_metadata do
    metadata()
    |> Map.put("token_endpoint_auth_method", "private_key_jwt")
    |> Map.put("token_endpoint_auth_signing_alg", "ES256")
    |> Map.put("jwks", jwks())
  end

  defp jwks do
    %{
      "keys" => [
        %{
          "kid" => "client-key-1",
          "kty" => "EC",
          "crv" => "P-256",
          "x" => "f83OJ3D2xF4N5t0vY8FfB7PRY1hUu1b8kG0xQ2K9u1Y",
          "y" => "x_FEzRu9dNwmDc3jcpQK7fG1P0MxEf_0wM9xV8k6KJs",
          "alg" => "ES256"
        }
      ]
    }
  end
end
