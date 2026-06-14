defmodule Tempest.Identity.Multikey do
  @moduledoc """
  Decodes atproto secp256k1 public keys from DID document Multikey values.
  """

  @base58btc_alphabet ~c"123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz"
  @secp256k1_pub_multicodec <<0xE7, 0x01>>
  @secp256k1_p 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEFFFFFC2F

  def encode_secp256k1_did_key(public_key) when is_binary(public_key) do
    with {:ok, multikey} <- encode_secp256k1_public_key(public_key) do
      {:ok, "did:key:" <> multikey}
    end
  end

  def encode_secp256k1_did_key!(public_key) do
    case encode_secp256k1_did_key(public_key) do
      {:ok, did_key} -> did_key
      {:error, reason} -> raise ArgumentError, "invalid secp256k1 public key: #{inspect(reason)}"
    end
  end

  def encode_secp256k1_public_key(public_key) when is_binary(public_key) do
    with {:ok, key} <- decode_or_normalize_public_key(public_key),
         {:ok, compressed_key} <- compress_secp256k1_public_key(key) do
      {:ok, "z" <> base58btc_encode(@secp256k1_pub_multicodec <> compressed_key)}
    end
  end

  def encode_secp256k1_public_key!(public_key) do
    case encode_secp256k1_public_key(public_key) do
      {:ok, multikey} -> multikey
      {:error, reason} -> raise ArgumentError, "invalid secp256k1 public key: #{inspect(reason)}"
    end
  end

  def decode_secp256k1_public_key(multibase, opts \\ [])

  def decode_secp256k1_public_key(multibase, opts) when is_binary(multibase) do
    output = Keyword.get(opts, :output, :native)

    with {:ok, key} <- decode_multibase(multibase),
         {:ok, key} <- normalize_secp256k1_public_key(key) do
      case output do
        :native -> {:ok, key}
        :uncompressed -> uncompress_secp256k1_public_key(key)
        _other -> {:error, :invalid_public_key}
      end
    end
  end

  def decode_secp256k1_public_key(_multibase, _opts), do: {:error, :invalid_public_key}

  defp decode_or_normalize_public_key("did:key:" <> multibase), do: decode_multibase(multibase)
  defp decode_or_normalize_public_key("u" <> _rest = multibase), do: decode_multibase(multibase)
  defp decode_or_normalize_public_key("z" <> _rest = multibase), do: decode_multibase(multibase)
  defp decode_or_normalize_public_key(public_key), do: normalize_secp256k1_public_key(public_key)

  defp decode_multibase("u" <> encoded), do: Base.url_decode64(encoded, padding: false)

  defp decode_multibase("z" <> encoded) do
    with {:ok, bytes} <- base58btc_decode(encoded) do
      unwrap_secp256k1_multikey(bytes)
    end
  end

  defp decode_multibase(_value), do: {:error, :unsupported_key}

  defp unwrap_secp256k1_multikey(@secp256k1_pub_multicodec <> key), do: {:ok, key}
  defp unwrap_secp256k1_multikey(_bytes), do: {:error, :invalid_public_key}

  defp normalize_secp256k1_public_key(<<4, _rest::binary-size(64)>> = public_key), do: {:ok, public_key}
  defp normalize_secp256k1_public_key(<<2, _rest::binary-size(32)>> = public_key), do: {:ok, public_key}
  defp normalize_secp256k1_public_key(<<3, _rest::binary-size(32)>> = public_key), do: {:ok, public_key}
  defp normalize_secp256k1_public_key(_key), do: {:error, :invalid_public_key}

  defp compress_secp256k1_public_key(<<prefix, _rest::binary-size(32)>> = public_key) when prefix in [2, 3] do
    {:ok, public_key}
  end

  defp compress_secp256k1_public_key(<<4, x::binary-size(32), y::binary-size(32)>>) do
    prefix = if rem(:binary.decode_unsigned(y), 2) == 0, do: 2, else: 3
    {:ok, <<prefix, x::binary>>}
  end

  defp uncompress_secp256k1_public_key(<<4, _rest::binary-size(64)>> = public_key), do: {:ok, public_key}

  defp uncompress_secp256k1_public_key(<<prefix, x::binary-size(32)>>) when prefix in [2, 3] do
    x_int = :binary.decode_unsigned(x)
    y2 = rem(modular_pow(x_int, 3, @secp256k1_p) + 7, @secp256k1_p)
    y_root = modular_pow(y2, div(@secp256k1_p + 1, 4), @secp256k1_p)
    y_int = if rem(y_root, 2) == rem(prefix, 2), do: y_root, else: @secp256k1_p - y_root

    {:ok, <<4, x::binary, unsigned_256(y_int)::binary>>}
  end

  defp base58btc_decode(encoded) do
    encoded
    |> String.to_charlist()
    |> Enum.reduce_while({:ok, 0}, fn char, {:ok, acc} ->
      case base58_value(char) do
        {:ok, value} -> {:cont, {:ok, acc * 58 + value}}
        :error -> {:halt, {:error, :invalid_public_key}}
      end
    end)
    |> case do
      {:ok, value} ->
        leading_zero_count =
          encoded
          |> String.to_charlist()
          |> Enum.take_while(&(&1 == ?1))
          |> length()

        {:ok, :binary.copy(<<0>>, leading_zero_count) <> unsigned_bytes(value)}

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

  defp base58btc_encode(bytes) when is_binary(bytes) do
    leading_zero_count =
      bytes
      |> :binary.bin_to_list()
      |> Enum.take_while(&(&1 == 0))
      |> length()

    encoded =
      bytes
      |> :binary.decode_unsigned()
      |> do_base58btc_encode("")

    String.duplicate("1", leading_zero_count) <> encoded
  end

  defp do_base58btc_encode(0, acc), do: acc

  defp do_base58btc_encode(value, acc) do
    char = @base58btc_alphabet |> Enum.at(rem(value, 58)) |> then(&<<&1>>)
    do_base58btc_encode(div(value, 58), char <> acc)
  end

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
end
