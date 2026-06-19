defmodule Tempest.OAuth.Metadata do
  @moduledoc """
  OAuth metadata documents for Tempest's atproto authorization surface.
  """

  @scopes [
    "atproto",
    "transition:generic",
    "transition:chat.bsky",
    "transition:email",
    "blob:*/*",
    "rpc:*"
  ]

  def protected_resource do
    base_url = base_url()

    %{
      "resource" => base_url,
      "authorization_servers" => [base_url],
      "scopes_supported" => @scopes,
      "bearer_methods_supported" => ["header"],
      "resource_documentation" => "https://atproto.com/specs/oauth"
    }
  end

  def authorization_server do
    base_url = base_url()

    %{
      "issuer" => base_url,
      "authorization_endpoint" => base_url <> "/oauth/authorize",
      "token_endpoint" => base_url <> "/oauth/token",
      "jwks_uri" => base_url <> "/oauth/jwks",
      "pushed_authorization_request_endpoint" => base_url <> "/oauth/par",
      "require_pushed_authorization_requests" => true,
      "client_id_metadata_document_supported" => true,
      "scopes_supported" => @scopes,
      "response_types_supported" => ["code"],
      "grant_types_supported" => ["authorization_code", "refresh_token"],
      "code_challenge_methods_supported" => ["S256"],
      "token_endpoint_auth_methods_supported" => ["none", "private_key_jwt"],
      "token_endpoint_auth_signing_alg_values_supported" => ["ES256"],
      "dpop_signing_alg_values_supported" => ["ES256", "ES384", "ES512", "RS256", "PS256"]
    }
  end

  defp base_url do
    Tempest.Config.load!().public_url
  end
end
