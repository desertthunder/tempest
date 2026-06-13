defmodule Tempest.Accounts.Tokens do
  @moduledoc """
  Access token signing and refresh token generation.
  """

  alias Tempest.Accounts.{Account, Session}
  alias Tempest.Identity
  alias Tempest.Identity.KeyStore
  alias TempestWeb.Endpoint

  @access_salt "tempest access token v1"
  @access_max_age_seconds 15 * 60
  @service_auth_lifetime_seconds 10 * 60
  @refresh_lifetime_seconds 60 * 60 * 24 * 30
  @refresh_prefix "tempest-refresh-v1."
  @base58btc_alphabet ~c"123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz"
  @secp256k1_pub_multicodec <<0xE7, 0x01>>
  @secp256k1_p 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEFFFFFC2F

  def sign_access_token(%Account{} = account, %Session{} = session) do
    Phoenix.Token.sign(Endpoint, @access_salt, %{
      "typ" => "access",
      "account_id" => account.id,
      "session_id" => session.id,
      "did" => account.did
    })
  end

  def verify_access_token(token) when is_binary(token) do
    Phoenix.Token.verify(Endpoint, @access_salt, token, max_age: @access_max_age_seconds)
  end

  def verify_access_token(_token), do: {:error, :invalid}

  def sign_service_auth(%Account{} = account, audience, method_nsid)
      when is_binary(audience) and is_binary(method_nsid) do
    now = DateTime.utc_now() |> DateTime.to_unix()
    key = KeyStore.active_key_for_account(account)
    jwk = service_auth_private_jwk!(key)

    headers = %{"typ" => "JWT", "alg" => "ES256K", "kid" => account.did <> key.kid}

    claims = %{
      "iss" => account.did,
      "sub" => account.did,
      "aud" => audience,
      "lxm" => method_nsid,
      "iat" => now,
      "exp" => now + @service_auth_lifetime_seconds
    }

    {_jws, compact} = JOSE.JWT.sign(jwk, headers, claims) |> JOSE.JWS.compact()
    compact
  end

  def verify_service_auth(token) when is_binary(token) do
    with {:ok, header} <- peek_service_auth_header(token),
         :ok <- validate_service_auth_header(header),
         {:ok, unverified_claims} <- peek_service_auth_claims(token),
         :ok <- validate_service_auth_claim_shape(unverified_claims),
         {:ok, public_jwk} <- service_auth_public_jwk(unverified_claims["iss"], header["kid"]),
         {:ok, claims} <- verify_service_auth_signature(token, public_jwk),
         :ok <- validate_service_auth_claims(claims) do
      {:ok, claims}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  def verify_service_auth(_token), do: {:error, :invalid}

  defp peek_service_auth_header(token) do
    %JOSE.JWS{fields: fields, alg: alg} = JOSE.JWT.peek_protected(token)

    case alg do
      {_, :ES256K} -> {:ok, Map.put(fields, "alg", "ES256K")}
      _ -> {:ok, fields}
    end
  rescue
    _error -> {:error, :invalid}
  end

  defp validate_service_auth_header(%{"alg" => "ES256K"} = header) do
    case Map.get(header, "typ") do
      nil -> :ok
      typ when is_binary(typ) -> if String.upcase(typ) == "JWT", do: :ok, else: {:error, :invalid}
      _other -> {:error, :invalid}
    end
  end

  defp validate_service_auth_header(_header), do: {:error, :invalid}

  defp peek_service_auth_claims(token) do
    case JOSE.JWT.peek_payload(token) do
      %JOSE.JWT{fields: claims} when is_map(claims) -> {:ok, claims}
      _other -> {:error, :invalid}
    end
  rescue
    _error -> {:error, :invalid}
  end

  defp validate_service_auth_claim_shape(%{"iss" => did, "aud" => aud, "lxm" => lxm} = claims)
       when is_binary(did) and did != "" and is_binary(aud) and aud != "" and is_binary(lxm) and lxm != "" do
    case Map.get(claims, "sub", did) do
      ^did -> :ok
      _other -> {:error, :invalid}
    end
  end

  defp validate_service_auth_claim_shape(_claims), do: {:error, :invalid}

  defp service_auth_public_jwk(did, kid) when kid in [nil, did <> "#atproto"] do
    expected_kid = did <> "#atproto"

    with {:ok, document} <- Identity.did_document_for_did(did),
         {:ok, public_key_multibase} <- find_atproto_public_key(document, expected_kid),
         {:ok, public_key} <- decode_public_key_multibase(public_key_multibase),
         {:ok, jwk} <- public_jwk_from_raw_secp256k1(public_key) do
      {:ok, jwk}
    else
      {:error, reason} -> {:error, reason}
      _other -> {:error, :invalid}
    end
  end

  defp service_auth_public_jwk(_did, _kid), do: {:error, :invalid}

  defp find_atproto_public_key(%{"verificationMethod" => methods}, expected_kid) when is_list(methods) do
    methods
    |> Enum.find(fn
      %{"id" => ^expected_kid, "publicKeyMultibase" => public_key} when is_binary(public_key) -> true
      _method -> false
    end)
    |> case do
      %{"publicKeyMultibase" => public_key} -> {:ok, public_key}
      _other -> {:error, :invalid}
    end
  end

  defp find_atproto_public_key(_document, _expected_kid), do: {:error, :invalid}

  defp verify_service_auth_signature(token, jwk) do
    case JOSE.JWT.verify_strict(jwk, ["ES256K"], token) do
      {true, %JOSE.JWT{fields: claims}, _jws} when is_map(claims) -> {:ok, claims}
      _invalid -> {:error, :invalid}
    end
  rescue
    _error -> {:error, :invalid}
  end

  defp validate_service_auth_claims(%{"iss" => did, "iat" => iat, "exp" => exp} = claims)
       when is_integer(iat) and is_integer(exp) do
    case Map.get(claims, "sub", did) do
      ^did -> validate_service_auth_times(iat, exp)
      _other -> {:error, :invalid}
    end
  end

  defp validate_service_auth_claims(_claims), do: {:error, :invalid}

  defp validate_service_auth_times(iat, exp) do
    now = DateTime.utc_now() |> DateTime.to_unix()

    cond do
      iat > now + 60 -> {:error, :invalid}
      exp <= now -> {:error, :expired}
      exp - iat > @service_auth_lifetime_seconds -> {:error, :invalid}
      true -> :ok
    end
  end

  defp service_auth_private_jwk!(key) do
    with {:ok, private_key} <- KeyStore.decrypt_private_key(key),
         {:ok, public_key} <- decode_public_key_multibase(key.public_key_multibase),
         {:ok, public_jwk} <- public_jwk_from_raw_secp256k1(public_key) do
      public_jwk |> JOSE.JWK.to_map() |> elem(1) |> Map.put("d", base64url(private_key)) |> JOSE.JWK.from_map()
    else
      _error -> raise ArgumentError, "account signing key cannot be converted to ES256K JWK"
    end
  end

  defp public_jwk_from_raw_secp256k1(<<4, x::binary-size(32), y::binary-size(32)>>) do
    {:ok, JOSE.JWK.from_map(%{"kty" => "EC", "crv" => "secp256k1", "x" => base64url(x), "y" => base64url(y)})}
  end

  defp public_jwk_from_raw_secp256k1(_public_key), do: {:error, :invalid}

  defp decode_public_key_multibase("u" <> encoded), do: Base.url_decode64(encoded, padding: false)

  defp decode_public_key_multibase("z" <> encoded) do
    with {:ok, bytes} <- base58btc_decode(encoded),
         {:ok, key_bytes} <- unwrap_secp256k1_multikey(bytes),
         {:ok, public_key} <- normalize_secp256k1_public_key(key_bytes) do
      {:ok, public_key}
    end
  end

  defp decode_public_key_multibase(_value), do: {:error, :invalid}

  defp unwrap_secp256k1_multikey(@secp256k1_pub_multicodec <> key), do: {:ok, key}
  defp unwrap_secp256k1_multikey(_bytes), do: {:error, :invalid}

  defp normalize_secp256k1_public_key(<<4, _rest::binary-size(64)>> = public_key), do: {:ok, public_key}

  defp normalize_secp256k1_public_key(<<prefix, x::binary-size(32)>>) when prefix in [2, 3] do
    x_int = :binary.decode_unsigned(x)
    y2 = rem(modular_pow(x_int, 3, @secp256k1_p) + 7, @secp256k1_p)
    y_root = modular_pow(y2, div(@secp256k1_p + 1, 4), @secp256k1_p)
    y_int = if rem(y_root, 2) == rem(prefix, 2), do: y_root, else: @secp256k1_p - y_root

    {:ok, <<4, x::binary, unsigned_256(y_int)::binary>>}
  end

  defp normalize_secp256k1_public_key(_key), do: {:error, :invalid}

  defp base58btc_decode(encoded) when is_binary(encoded) do
    encoded
    |> String.to_charlist()
    |> Enum.reduce_while({:ok, 0}, fn char, {:ok, acc} ->
      case base58_value(char) do
        {:ok, value} -> {:cont, {:ok, acc * 58 + value}}
        :error -> {:halt, {:error, :invalid}}
      end
    end)
    |> case do
      {:ok, value} ->
        leading_zero_count =
          encoded
          |> String.to_charlist()
          |> Enum.take_while(&(&1 == ?1))
          |> length()

        decoded = :binary.copy(<<0>>, leading_zero_count) <> unsigned_bytes(value)
        {:ok, decoded}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp base58_value(char) do
    case Enum.find_index(@base58btc_alphabet, &(&1 == char)) do
      nil -> :error
      index -> {:ok, index}
    end
  end

  defp modular_pow(_base, 0, modulus), do: rem(1, modulus)
  defp modular_pow(base, exponent, modulus), do: modular_pow(rem(base, modulus), exponent, modulus, 1)

  defp modular_pow(_base, 0, _modulus, result), do: result

  defp modular_pow(base, exponent, modulus, result) do
    result = if rem(exponent, 2) == 1, do: rem(result * base, modulus), else: result
    modular_pow(rem(base * base, modulus), div(exponent, 2), modulus, result)
  end

  defp unsigned_256(value) do
    value
    |> unsigned_bytes()
    |> pad_left(32)
  end

  defp unsigned_bytes(0), do: <<>>
  defp unsigned_bytes(value), do: :binary.encode_unsigned(value)

  defp pad_left(bytes, size) when byte_size(bytes) <= size do
    :binary.copy(<<0>>, size - byte_size(bytes)) <> bytes
  end

  def new_refresh_token do
    @refresh_prefix <> random_url_token(48)
  end

  def refresh_token_hash(token) when is_binary(token) do
    :crypto.hash(:sha256, token)
    |> Base.encode16(case: :lower)
  end

  def refresh_expires_at(now \\ DateTime.utc_now()) do
    now
    |> DateTime.add(@refresh_lifetime_seconds, :second)
    |> DateTime.truncate(:second)
  end

  defp base64url(value), do: Base.url_encode64(value, padding: false)

  defp random_url_token(bytes) do
    bytes
    |> :crypto.strong_rand_bytes()
    |> Base.url_encode64(padding: false)
  end
end
