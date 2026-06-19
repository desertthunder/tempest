defmodule Tempest.OAuth.ClientMetadata do
  @moduledoc """
  OAuth client metadata fetch and validation.

  AT Protocol OAuth uses the `client_id` URL as the client metadata document.
  This module handles the OAuth-specific semantics after the shared external
  metadata fetcher has handled URL and network safety.
  """

  alias Tempest.Security.ExternalMetadataFetcher

  @max_body_bytes 64 * 1024

  @type t :: %__MODULE__{
          client_id: String.t(),
          redirect_uris: [String.t()],
          scope: String.t() | nil,
          token_endpoint_auth_method: String.t(),
          token_endpoint_auth_signing_alg: String.t() | nil,
          dpop_bound_access_tokens: boolean(),
          jwks: map() | nil
        }

  @enforce_keys [:client_id, :redirect_uris, :token_endpoint_auth_method, :dpop_bound_access_tokens]
  defstruct [
    :client_id,
    :redirect_uris,
    :scope,
    :token_endpoint_auth_method,
    :token_endpoint_auth_signing_alg,
    :dpop_bound_access_tokens,
    :jwks
  ]

  @doc """
  Fetches and validates client metadata for a PAR request.
  """
  @spec fetch_for_par(map()) :: {:ok, t()} | {:error, atom()}
  def fetch_for_par(params) when is_map(params) do
    with {:ok, client_id} <- fetch_param(params, "client_id"),
         {:ok, redirect_uri} <- fetch_param(params, "redirect_uri"),
         {:ok, requested_scope} <- fetch_param(params, "scope"),
         :ok <- validate_client_id_url(client_id),
         {:ok, metadata} <- fetch_metadata(client_id),
         {:ok, client} <- parse_metadata(metadata, client_id),
         :ok <- validate_redirect_uri(client, redirect_uri),
         :ok <- validate_requested_scope(client, requested_scope) do
      {:ok, client}
    end
  end

  def fetch_for_par(_params), do: {:error, :invalid_client}

  @doc """
  Fetches and validates a client metadata document by client id.
  """
  @spec fetch(String.t()) :: {:ok, t()} | {:error, atom()}
  def fetch(client_id) when is_binary(client_id) do
    with :ok <- validate_client_id_url(client_id),
         {:ok, metadata} <- fetch_metadata(client_id),
         {:ok, client} <- parse_metadata(metadata, client_id) do
      {:ok, client}
    end
  end

  def fetch(_client_id), do: {:error, :invalid_client}

  defp fetch_metadata(client_id) do
    case ExternalMetadataFetcher.fetch_json(client_id, max_body_bytes: @max_body_bytes) do
      {:ok, metadata} when is_map(metadata) -> {:ok, metadata}
      {:ok, _metadata} -> {:error, :invalid_client}
      {:error, _reason} -> {:error, :invalid_client}
    end
  end

  defp parse_metadata(metadata, client_id) do
    with ^client_id <- Map.get(metadata, "client_id"),
         redirect_uris when is_list(redirect_uris) <- Map.get(metadata, "redirect_uris"),
         true <- Enum.all?(redirect_uris, &valid_redirect_uri?/1),
         true <- contains_string?(Map.get(metadata, "response_types"), "code"),
         true <- contains_string?(Map.get(metadata, "grant_types"), "authorization_code"),
         auth_method when auth_method in ["none", "private_key_jwt"] <-
           Map.get(metadata, "token_endpoint_auth_method", "none"),
         true <- Map.get(metadata, "dpop_bound_access_tokens"),
         {:ok, signing_alg} <- validate_signing_alg(metadata, auth_method),
         {:ok, jwks} <- validate_jwks(metadata, auth_method) do
      {:ok,
       %__MODULE__{
         client_id: client_id,
         redirect_uris: redirect_uris,
         scope: metadata["scope"],
         token_endpoint_auth_method: auth_method,
         token_endpoint_auth_signing_alg: signing_alg,
         dpop_bound_access_tokens: true,
         jwks: jwks
       }}
    else
      _reason -> {:error, :invalid_client}
    end
  end

  defp validate_client_id_url(client_id) do
    case URI.parse(client_id) do
      %URI{scheme: "https", host: host, userinfo: nil, fragment: nil} when is_binary(host) -> :ok
      _uri -> {:error, :invalid_client}
    end
  end

  defp validate_redirect_uri(%__MODULE__{redirect_uris: redirect_uris}, redirect_uri) do
    if redirect_uri in redirect_uris do
      :ok
    else
      {:error, :invalid_request}
    end
  end

  defp validate_requested_scope(%__MODULE__{scope: nil}, _requested_scope), do: :ok

  defp validate_requested_scope(%__MODULE__{scope: client_scope}, requested_scope) when is_binary(client_scope) do
    client_scopes = String.split(client_scope, " ", trim: true)
    requested_scopes = String.split(requested_scope, " ", trim: true)

    if requested_scopes != [] and Enum.all?(requested_scopes, &scope_registered?(client_scopes, &1)) do
      :ok
    else
      {:error, :invalid_scope}
    end
  end

  defp validate_requested_scope(_client, _requested_scope), do: {:error, :invalid_client}

  defp validate_signing_alg(_metadata, "none"), do: {:ok, nil}

  defp validate_signing_alg(metadata, "private_key_jwt") do
    case Map.get(metadata, "token_endpoint_auth_signing_alg", "ES256") do
      "ES256" -> {:ok, "ES256"}
      _other -> {:error, :invalid_client}
    end
  end

  defp validate_jwks(metadata, "none") do
    if Map.has_key?(metadata, "jwks") or Map.has_key?(metadata, "jwks_uri") do
      {:error, :invalid_client}
    else
      {:ok, nil}
    end
  end

  defp validate_jwks(metadata, "private_key_jwt") do
    case {Map.get(metadata, "jwks"), Map.get(metadata, "jwks_uri")} do
      {%{} = jwks, nil} ->
        validate_jwks_object(jwks)

      {nil, jwks_uri} when is_binary(jwks_uri) ->
        with :ok <- validate_jwks_uri(jwks_uri),
             {:ok, jwks} <- fetch_metadata(jwks_uri) do
          validate_jwks_object(jwks)
        end

      _other ->
        {:error, :invalid_client}
    end
  end

  defp validate_jwks_uri(jwks_uri) do
    case URI.parse(jwks_uri) do
      %URI{scheme: "https", host: host, userinfo: nil, fragment: nil} when is_binary(host) ->
        :ok

      _uri ->
        {:error, :invalid_client}
    end
  end

  defp validate_jwks_object(%{"keys" => keys} = jwks) when is_list(keys) and keys != [] do
    if Enum.all?(keys, &valid_client_key?/1), do: {:ok, jwks}, else: {:error, :invalid_client}
  end

  defp validate_jwks_object(_jwks), do: {:error, :invalid_client}

  defp valid_client_key?(%{"kid" => kid, "kty" => "EC", "crv" => "P-256", "x" => x, "y" => y} = jwk) do
    is_binary(kid) and kid != "" and is_binary(x) and is_binary(y) and not Map.has_key?(jwk, "d") and
      Map.get(jwk, "alg", "ES256") == "ES256"
  end

  defp valid_client_key?(_jwk), do: false

  defp scope_registered?(client_scopes, requested_scope) do
    Enum.any?(client_scopes, fn client_scope ->
      client_scope == requested_scope or wildcard_scope_match?(client_scope, requested_scope)
    end)
  end

  defp wildcard_scope_match?(client_scope, requested_scope) do
    client_base = scope_base(client_scope)

    String.contains?(client_base, "*") and scope_resource(client_base) == scope_resource(scope_base(requested_scope))
  end

  defp scope_base(scope), do: scope |> String.split("?", parts: 2) |> hd()
  defp scope_resource(scope), do: scope |> String.split(":", parts: 2) |> hd()

  defp fetch_param(params, key) do
    case Map.get(params, key) do
      value when is_binary(value) and value != "" -> {:ok, value}
      _value -> {:error, :invalid_request}
    end
  end

  defp contains_string?(values, value) when is_list(values), do: value in values
  defp contains_string?(_values, _value), do: false

  defp valid_redirect_uri?(uri) when is_binary(uri) do
    case URI.parse(uri) do
      %URI{scheme: "https", host: host, fragment: nil} when is_binary(host) -> true
      _uri -> false
    end
  end

  defp valid_redirect_uri?(_uri), do: false
end
