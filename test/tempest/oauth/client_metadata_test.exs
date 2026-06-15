defmodule Tempest.OAuth.ClientMetadataTest do
  use ExUnit.Case, async: false

  alias Tempest.OAuth.ClientMetadata
  alias Tempest.Security.ExternalMetadataFetcher

  @client_id "https://client.example.com/oauth/client-metadata.json"
  @redirect_uri "https://client.example.com/callback"

  setup context do
    Req.Test.set_req_test_from_context(context)
    Req.Test.verify_on_exit!(context)

    original_fetcher_config = Application.get_env(:tempest, ExternalMetadataFetcher, [])

    Application.put_env(:tempest, ExternalMetadataFetcher,
      dns_lookup: fn "client.example.com" -> {:ok, [{93, 184, 216, 34}]} end,
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

  test "rejects unsupported client auth methods for now" do
    Req.Test.expect(__MODULE__, fn conn ->
      Req.Test.json(conn, Map.put(metadata(), "token_endpoint_auth_method", "private_key_jwt"))
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

  defp metadata do
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
    }
  end
end
