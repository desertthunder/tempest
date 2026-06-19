defmodule Tempest.OAuth.ClientAssertionVerifier do
  @moduledoc """
  Verifies OAuth `private_key_jwt` client assertions.
  """

  alias Tempest.OAuth.{ClientAssertion, ClientMetadata, Dpop}
  alias Tempest.Repo

  @assertion_type "urn:ietf:params:oauth:client-assertion-type:jwt-bearer"
  @supported_alg "ES256"
  @max_lifetime_seconds 5 * 60
  @max_iat_skew_seconds 60

  @doc """
  Verifies the client authentication required by a client metadata document.

  Public clients using `token_endpoint_auth_method: "none"` return `{:ok, nil}`.
  Confidential clients must present a non-replayed ES256 `private_key_jwt`
  assertion signed by a key from the client's JWKS.
  """
  def verify(%ClientMetadata{token_endpoint_auth_method: "none"}, _params, _issuer), do: {:ok, nil}

  def verify(%ClientMetadata{token_endpoint_auth_method: "private_key_jwt"} = client, params, issuer)
      when is_map(params) and is_binary(issuer) do
    with @assertion_type <- Map.get(params, "client_assertion_type"),
         assertion when is_binary(assertion) and assertion != "" <- Map.get(params, "client_assertion"),
         {:ok, header} <- decode_protected_header(assertion),
         {:ok, jwk} <- matching_key(client, header),
         {:ok, claims} <- verify_signature(assertion, jwk),
         {:ok, binding} <- validate_claims(claims, client.client_id, issuer, header, jwk),
         :ok <- reject_replay(client.client_id, claims["jti"], claims["exp"]) do
      {:ok, binding}
    else
      {:error, reason} -> {:error, reason}
      _other -> {:error, :invalid_client}
    end
  end

  def verify(%ClientMetadata{}, _params, _issuer), do: {:error, :invalid_client}

  defp decode_protected_header(jwt) do
    case String.split(jwt, ".") do
      [encoded_header, _encoded_payload, _encoded_signature] ->
        with {:ok, header_json} <- Base.url_decode64(encoded_header, padding: false),
             {:ok, header} when is_map(header) <- Jason.decode(header_json) do
          {:ok, header}
        else
          _error -> {:error, :invalid_client}
        end

      _parts ->
        {:error, :invalid_client}
    end
  end

  defp matching_key(%ClientMetadata{jwks: %{"keys" => keys}}, %{"alg" => @supported_alg, "kid" => kid})
       when is_list(keys) and is_binary(kid) and kid != "" do
    case Enum.find(keys, &(Map.get(&1, "kid") == kid)) do
      %{"kty" => "EC", "crv" => "P-256"} = jwk -> {:ok, jwk}
      _missing -> {:error, :invalid_client}
    end
  end

  defp matching_key(_client, _header), do: {:error, :invalid_client}

  defp verify_signature(assertion, jwk) do
    case JOSE.JWT.verify_strict(JOSE.JWK.from_map(jwk), [@supported_alg], assertion) do
      {true, %JOSE.JWT{fields: claims}, _jws} when is_map(claims) -> {:ok, claims}
      _invalid -> {:error, :invalid_client}
    end
  rescue
    _error -> {:error, :invalid_client}
  end

  defp validate_claims(claims, client_id, issuer, header, jwk) do
    now = DateTime.utc_now() |> DateTime.to_unix()

    with :ok <- equals(claims["iss"], client_id),
         :ok <- equals(claims["sub"], client_id),
         :ok <- audience_matches?(claims["aud"], issuer),
         :ok <- require_binary(claims["jti"]),
         :ok <- validate_exp(claims["exp"], now),
         :ok <- validate_iat(claims["iat"], now),
         {:ok, jkt} <- Dpop.jwk_thumbprint(jwk) do
      {:ok,
       %{
         method: "private_key_jwt",
         kid: header["kid"],
         alg: header["alg"],
         jkt: jkt
       }}
    end
  end

  defp equals(value, value) when is_binary(value), do: :ok
  defp equals(_left, _right), do: {:error, :invalid_client}

  defp audience_matches?(aud, issuer) when is_binary(aud), do: equals(aud, issuer)

  defp audience_matches?(audiences, issuer) when is_list(audiences) do
    if issuer in audiences, do: :ok, else: {:error, :invalid_client}
  end

  defp audience_matches?(_aud, _issuer), do: {:error, :invalid_client}

  defp require_binary(value) when is_binary(value) and value != "", do: :ok
  defp require_binary(_value), do: {:error, :invalid_client}

  defp validate_exp(exp, now) when is_integer(exp) do
    cond do
      exp <= now -> {:error, :invalid_client}
      exp > now + @max_lifetime_seconds -> {:error, :invalid_client}
      true -> :ok
    end
  end

  defp validate_exp(_exp, _now), do: {:error, :invalid_client}

  defp validate_iat(iat, now) when is_integer(iat) do
    cond do
      iat > now + @max_iat_skew_seconds -> {:error, :invalid_client}
      iat < now - @max_lifetime_seconds -> {:error, :invalid_client}
      true -> :ok
    end
  end

  defp validate_iat(_iat, _now), do: {:error, :invalid_client}

  defp reject_replay(client_id, jti, exp) do
    attrs = %{
      client_id: client_id,
      jti_hash: hash(jti),
      expires_at: exp |> DateTime.from_unix!() |> DateTime.truncate(:second)
    }

    case %ClientAssertion{} |> ClientAssertion.changeset(attrs) |> Repo.insert() do
      {:ok, _assertion} -> :ok
      {:error, _changeset} -> {:error, :invalid_client}
    end
  end

  defp hash(value), do: :crypto.hash(:sha256, value) |> Base.encode16(case: :lower)
end
