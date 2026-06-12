defmodule Tempest.OAuth.Dpop do
  @moduledoc """
  DPoP nonce creation and proof validation.

  The verifier validates JWT shape, the protected JWS header, the signature using
  the embedded public JWK, required proof claims (`htm`, `htu`, `iat`, `jti`,
  `nonce`), nonce freshness/single use, and the public-key JWK thumbprint used
  for token binding. Callers must treat a missing/invalid proof as fatal.
  """

  import Ecto.Query

  alias Tempest.OAuth.DpopNonce
  alias Tempest.Repo

  @nonce_lifetime_seconds 5 * 60
  @max_iat_skew_seconds 60
  @supported_algs ["ES256", "ES384", "ES512", "RS256", "PS256"]

  def issue_nonce do
    nonce = random_token(32)
    now = now()

    attrs = %{
      nonce_hash: hash(nonce),
      expires_at: DateTime.add(now, @nonce_lifetime_seconds, :second)
    }

    case %DpopNonce{} |> DpopNonce.changeset(attrs) |> Repo.insert() do
      {:ok, _record} -> nonce
      {:error, _changeset} -> issue_nonce()
    end
  end

  def verify_proof(proof, method, url, opts \\ [])

  def verify_proof(nil, _method, _url, _opts), do: {:error, :missing_dpop}
  def verify_proof("", _method, _url, _opts), do: {:error, :missing_dpop}

  def verify_proof(proof, method, url, opts) when is_binary(proof) do
    with {:ok, header} <- decode_protected_header(proof),
         :ok <- validate_header(header),
         %{"alg" => alg, "jwk" => jwk} when is_map(jwk) <- header,
         :ok <- validate_key_alg(jwk, alg),
         {:ok, jkt} <- jwk_thumbprint(jwk),
         {:ok, payload} <- verify_signature(proof, jwk, alg),
         :ok <- validate_payload(payload, method, url),
         :ok <- validate_bound_jkt(jkt, Keyword.get(opts, :bound_jkt)) do
      {:ok, %{jkt: jkt, jwk: jwk, nonce: payload["nonce"], jti: payload["jti"]}}
    else
      {:error, reason} -> {:error, reason}
      _other -> {:error, :invalid_dpop}
    end
  end

  def verify_proof(_proof, _method, _url, _opts), do: {:error, :invalid_dpop}

  defp validate_payload(payload, method, url) do
    with :ok <- require_binary(payload, "jti"),
         :ok <- require_binary(payload, "nonce"),
         :ok <- validate_method(payload["htm"], method),
         :ok <- validate_url(payload["htu"], url),
         :ok <- validate_iat(payload["iat"]),
         :ok <- consume_nonce(payload["nonce"]) do
      :ok
    end
  end

  defp validate_bound_jkt(_jkt, nil), do: :ok
  defp validate_bound_jkt(jkt, jkt), do: :ok
  defp validate_bound_jkt(_jkt, _bound_jkt), do: {:error, :dpop_key_mismatch}

  defp validate_method(htm, method) when is_binary(htm) do
    if String.upcase(htm) == String.upcase(method), do: :ok, else: {:error, :invalid_dpop}
  end

  defp validate_method(_htm, _method), do: {:error, :invalid_dpop}

  defp validate_url(htu, url) when is_binary(htu) and is_binary(url) do
    if normalize_url(htu) == normalize_url(url), do: :ok, else: {:error, :invalid_dpop}
  end

  defp validate_url(_htu, _url), do: {:error, :invalid_dpop}

  defp validate_iat(iat) when is_integer(iat) do
    now_seconds = DateTime.utc_now() |> DateTime.to_unix()

    if abs(now_seconds - iat) <= @max_iat_skew_seconds do
      :ok
    else
      {:error, :invalid_dpop}
    end
  end

  defp validate_iat(_iat), do: {:error, :invalid_dpop}

  defp consume_nonce(nonce) when is_binary(nonce) do
    now = now()
    nonce_hash = hash(nonce)

    {count, _rows} =
      DpopNonce
      |> where([n], n.nonce_hash == ^nonce_hash)
      |> where([n], is_nil(n.used_at))
      |> where([n], n.expires_at > ^now)
      |> Repo.update_all(set: [used_at: now])

    if count == 1, do: :ok, else: {:error, :invalid_dpop_nonce}
  end

  defp consume_nonce(_nonce), do: {:error, :invalid_dpop_nonce}

  def jwk_thumbprint(%{"kty" => "EC", "crv" => crv, "x" => x, "y" => y}) do
    thumbprint(%{"crv" => crv, "kty" => "EC", "x" => x, "y" => y})
  end

  def jwk_thumbprint(%{"kty" => "RSA", "e" => e, "n" => n}) do
    thumbprint(%{"e" => e, "kty" => "RSA", "n" => n})
  end

  def jwk_thumbprint(_jwk), do: {:error, :unsupported_dpop_key}

  defp thumbprint(fields) do
    {:ok, fields |> Jason.encode!() |> then(&:crypto.hash(:sha256, &1)) |> Base.url_encode64(padding: false)}
  end

  defp decode_protected_header(jwt) do
    case String.split(jwt, ".") do
      [encoded_header, _encoded_payload, _encoded_signature] ->
        with {:ok, header_json} <- Base.url_decode64(encoded_header, padding: false),
             {:ok, header} <- Jason.decode(header_json) do
          {:ok, header}
        else
          _error -> {:error, :invalid_dpop}
        end

      _parts ->
        {:error, :invalid_dpop}
    end
  end

  defp validate_header(%{"alg" => alg, "jwk" => jwk} = header) when is_binary(alg) and is_map(jwk) do
    with :ok <- validate_typ(Map.get(header, "typ")),
         true <- alg in @supported_algs do
      :ok
    else
      {:error, reason} -> {:error, reason}
      false -> {:error, :unsupported_dpop_alg}
    end
  end

  defp validate_header(_header), do: {:error, :invalid_dpop}

  defp validate_typ(nil), do: :ok

  defp validate_typ(typ) when is_binary(typ) do
    if String.downcase(typ) == "dpop+jwt", do: :ok, else: {:error, :invalid_dpop}
  end

  defp validate_typ(_typ), do: {:error, :invalid_dpop}

  defp validate_key_alg(%{"kty" => "EC", "crv" => "P-256"}, "ES256"), do: :ok
  defp validate_key_alg(%{"kty" => "EC", "crv" => "P-384"}, "ES384"), do: :ok
  defp validate_key_alg(%{"kty" => "EC", "crv" => "P-521"}, "ES512"), do: :ok
  defp validate_key_alg(%{"kty" => "RSA"}, alg) when alg in ["RS256", "PS256"], do: :ok
  defp validate_key_alg(_jwk, _alg), do: {:error, :unsupported_dpop_key}

  defp verify_signature(proof, jwk, alg) do
    public_jwk = JOSE.JWK.from_map(jwk)

    case JOSE.JWT.verify_strict(public_jwk, [alg], proof) do
      {true, %JOSE.JWT{fields: payload}, _jws} when is_map(payload) -> {:ok, payload}
      _invalid -> {:error, :invalid_dpop}
    end
  rescue
    _error -> {:error, :invalid_dpop}
  end

  defp require_binary(map, key) do
    case Map.get(map, key) do
      value when is_binary(value) and value != "" -> :ok
      _value -> {:error, :invalid_dpop}
    end
  end

  defp normalize_url(url) do
    uri = URI.parse(url)
    port = uri.port

    default_port? = (uri.scheme == "https" and port == 443) or (uri.scheme == "http" and port == 80)
    port_part = if is_nil(port) or default_port?, do: "", else: ":#{port}"
    path = if uri.path in [nil, ""], do: "/", else: uri.path
    query = if is_nil(uri.query), do: "", else: "?" <> uri.query

    "#{uri.scheme}://#{uri.host}#{port_part}#{path}#{query}"
  end

  defp hash(value), do: :crypto.hash(:sha256, value) |> Base.encode16(case: :lower)

  defp random_token(bytes), do: bytes |> :crypto.strong_rand_bytes() |> Base.url_encode64(padding: false)

  defp now, do: DateTime.utc_now() |> DateTime.truncate(:second)
end
