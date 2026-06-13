defmodule Tempest.Identity.PlcOperation do
  @moduledoc """
  Builds PLC operation-shaped maps from the current local account state.
  """

  alias Tempest.Accounts.Account
  alias Tempest.Identity.{KeyStore, Multikey}

  @secp256k1_order 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEBAAEDCE6AF48A03BBFD25E8CD0364141
  @half_secp256k1_order div(@secp256k1_order, 2)

  def for_account(%Account{} = account, opts \\ []) do
    signing_key = KeyStore.active_key_for_account(account)

    %{
      "type" => "plc_operation",
      "prev" => Keyword.get(opts, :prev),
      "rotationKeys" => rotation_keys(),
      "verificationMethods" => %{"atproto" => Multikey.encode_secp256k1_did_key!(signing_key.public_key_multibase)},
      "alsoKnownAs" => ["at://#{account.handle}"],
      "services" => %{
        "atproto_pds" => %{
          "type" => "AtprotoPersonalDataServer",
          "endpoint" => pds_service_endpoint()
        }
      }
    }
  end

  def sign(%Account{} = account, operation) when is_map(operation) do
    with :ok <- validate_for_account(account, operation),
         {:ok, signing_key} <- active_key(account),
         {:ok, private_key} <- KeyStore.decrypt_private_key(signing_key),
         {:ok, unsigned_bytes} <- unsigned_operation_bytes(operation),
         {:ok, signature} <- sign_bytes(unsigned_bytes, private_key) do
      {:ok, Map.put(operation, "sig", Base.url_encode64(signature, padding: false))}
    end
  end

  def sign(%Account{}, _operation), do: {:error, :invalid_operation}

  def validate_signed_for_account(%Account{} = account, operation) when is_map(operation) do
    with sig when is_binary(sig) and sig != "" <- Map.get(operation, "sig"),
         {:ok, signature} <- Base.url_decode64(sig, padding: false),
         :ok <- validate_compact_signature(signature),
         unsigned_operation = Map.delete(operation, "sig"),
         :ok <- validate_for_account(account, unsigned_operation) do
      :ok
    else
      nil -> {:error, :missing_signature}
      "" -> {:error, :missing_signature}
      :error -> {:error, :invalid_signature}
      {:error, reason} -> {:error, reason}
    end
  end

  def validate_signed_for_account(%Account{}, _operation), do: {:error, :invalid_operation}

  def validate_for_account(%Account{} = account, operation) when is_map(operation) do
    recommended = for_account(account)

    cond do
      Map.get(operation, "type") != "plc_operation" ->
        {:error, :invalid_operation}

      Map.get(operation, "verificationMethods") != Map.fetch!(recommended, "verificationMethods") ->
        {:error, :invalid_verification_method}

      Map.get(operation, "alsoKnownAs") != Map.fetch!(recommended, "alsoKnownAs") ->
        {:error, :invalid_also_known_as}

      Map.get(operation, "services") != Map.fetch!(recommended, "services") ->
        {:error, :service_diversion}

      not recoverable?(operation, recommended) ->
        {:error, :unrecoverable_operation}

      true ->
        :ok
    end
  end

  def validate_for_account(%Account{}, _operation), do: {:error, :invalid_operation}

  defp rotation_keys do
    configured_keys =
      [:plc_rotation_key, :plc_recovery_key]
      |> Enum.map(&identity_config/1)
      |> Enum.reject(&is_nil/1)
      |> Enum.map(&public_did_key!/1)

    if configured_keys == [] do
      [public_did_key!(fallback_rotation_key_material())]
    else
      Enum.uniq(configured_keys)
    end
  end

  defp public_did_key!("did:key:" <> _rest = did_key), do: did_key

  defp public_did_key!(private_key_material) when is_binary(private_key_material) do
    private_key = decode_private_key!(private_key_material)
    {public_key, _private_key} = :crypto.generate_key(:ecdh, :secp256k1, private_key)
    Multikey.encode_secp256k1_did_key!(public_key)
  end

  defp decode_private_key!("u" <> encoded), do: Base.url_decode64!(encoded, padding: false)
  defp decode_private_key!(encoded), do: Base.url_decode64!(encoded, padding: false)

  defp fallback_rotation_key_material do
    secret_key_base =
      :tempest
      |> Application.fetch_env!(TempestWeb.Endpoint)
      |> Keyword.fetch!(:secret_key_base)

    :crypto.hash(:sha256, "Tempest.Identity.PlcOperation.rotation_key:" <> secret_key_base)
    |> multibase64()
  end

  defp multibase64(key), do: "u" <> Base.url_encode64(key, padding: false)

  defp pds_service_endpoint do
    %{scheme: scheme, host: host, port: port} = URI.parse(Tempest.Config.load!().public_url)
    default_port? = (scheme == "http" and port in [nil, 80]) or (scheme == "https" and port in [nil, 443])

    if default_port?, do: "#{scheme}://#{host}", else: "#{scheme}://#{host}:#{port}"
  end

  defp recoverable?(operation, recommended) do
    operation_keys = Map.get(operation, "rotationKeys")
    recommended_keys = Map.fetch!(recommended, "rotationKeys")
    signing_key = get_in(recommended, ["verificationMethods", "atproto"])

    is_list(operation_keys) and operation_keys != [] and signing_key not in operation_keys and
      Enum.any?(recommended_keys, &(&1 in operation_keys))
  end

  defp active_key(account) do
    case KeyStore.active_key_for_account(account) do
      nil -> {:error, :missing_signing_key}
      signing_key -> {:ok, signing_key}
    end
  end

  defp unsigned_operation_bytes(operation) do
    operation
    |> Map.delete("sig")
    |> Jason.encode()
  end

  defp sign_bytes(unsigned_bytes, private_key) do
    try do
      :ecdsa
      |> :crypto.sign(:sha256, unsigned_bytes, [private_key, :secp256k1])
      |> der_to_compact_low_s()
    rescue
      _error -> {:error, :invalid_private_key}
    end
  end

  defp validate_compact_signature(<<r::binary-size(32), s::binary-size(32)>>) do
    r = :binary.decode_unsigned(r)
    s = :binary.decode_unsigned(s)

    cond do
      r not in 1..(@secp256k1_order - 1) -> {:error, :invalid_signature}
      s not in 1..@half_secp256k1_order -> {:error, :invalid_signature}
      true -> :ok
    end
  end

  defp validate_compact_signature(_sig), do: {:error, :invalid_signature}

  defp der_to_compact_low_s(der) do
    with {:ok, r, s} <- parse_der_signature(der) do
      s = if s > @half_secp256k1_order, do: @secp256k1_order - s, else: s
      {:ok, fixed_uint(r) <> fixed_uint(s)}
    end
  end

  defp parse_der_signature(<<0x30, len, body::binary>>) when byte_size(body) == len do
    with {:ok, r, rest} <- take_der_integer(body),
         {:ok, s, ""} <- take_der_integer(rest) do
      {:ok, r, s}
    end
  end

  defp parse_der_signature(_der), do: {:error, :invalid_signature}

  defp take_der_integer(<<0x02, len, bytes::binary-size(len), rest::binary>>) do
    {:ok, :binary.decode_unsigned(bytes), rest}
  end

  defp take_der_integer(_bytes), do: {:error, :invalid_signature}

  defp identity_config(key) do
    :tempest
    |> Application.get_env(Tempest.Identity, [])
    |> Keyword.get(key)
  end

  defp fixed_uint(integer), do: integer |> :binary.encode_unsigned() |> pad_uint()

  defp pad_uint(bytes) when byte_size(bytes) < 32 do
    padding = 32 - byte_size(bytes)
    <<0::size(padding * 8), bytes::binary>>
  end

  defp pad_uint(bytes) when byte_size(bytes) == 32, do: bytes
end
