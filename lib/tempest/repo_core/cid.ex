defmodule Tempest.RepoCore.Cid do
  @moduledoc """
  Blessed AT Protocol CID wrapper.

  Supports CIDv1 values with DRISL-CBOR (`dag-cbor`) or `raw` codecs and
  SHA-256 multihashes encoded as lowercase base32 multibase strings.
  """

  import Kernel, except: [to_string: 1]
  import Bitwise

  @version 1
  @codec_drisl 0x71
  @codec_raw 0x55
  @hash_sha2_256 0x12
  @hash_size 32
  @base32_alphabet "abcdefghijklmnopqrstuvwxyz234567"

  @codec_names %{
    @codec_drisl => :drisl,
    @codec_raw => :raw
  }

  @enforce_keys [:version, :codec, :hash_code, :digest, :bytes, :value]
  defstruct [:version, :codec, :hash_code, :digest, :bytes, :value]

  @type codec :: :drisl | :raw | 0x71 | 0x55
  @type t :: %__MODULE__{
          version: 1,
          codec: :drisl | :raw,
          hash_code: 0x12,
          digest: <<_::256>>,
          bytes: binary(),
          value: String.t()
        }

  @type error ::
          :invalid_cid_syntax
          | :not_ascii
          | :unsupported_multibase
          | :invalid_base32
          | :non_canonical_base32
          | :invalid_binary_cid
          | :unsupported_cid_version
          | :unsupported_codec
          | :unsupported_hash_type
          | :unsupported_hash_size
          | :digest_size_mismatch
          | :trailing_bytes

  @spec parse(term()) :: {:ok, t()} | {:error, error()}
  def parse("b" <> encoded = cid) do
    with :ok <- require_ascii(cid),
         {:ok, bytes} <- decode_base32(encoded),
         {:ok, parsed} <- from_bytes(bytes),
         ^cid <- to_string(parsed) do
      {:ok, parsed}
    else
      {:error, reason} -> {:error, reason}
      _non_canonical -> {:error, :non_canonical_base32}
    end
  end

  def parse(cid) when is_binary(cid) do
    with :ok <- require_ascii(cid) do
      {:error, :unsupported_multibase}
    end
  end

  def parse(_cid), do: {:error, :invalid_cid_syntax}

  @spec parse!(term()) :: t()
  def parse!(cid) do
    case parse(cid) do
      {:ok, parsed} -> parsed
      {:error, reason} -> raise ArgumentError, "invalid CID: #{inspect(reason)}"
    end
  end

  @spec valid?(term()) :: boolean()
  def valid?(cid), do: match?({:ok, _cid}, parse(cid))

  @spec for_drisl(binary()) :: t()
  def for_drisl(block_bytes) when is_binary(block_bytes) do
    new!(:drisl, :crypto.hash(:sha256, block_bytes))
  end

  @spec for_raw(binary()) :: t()
  def for_raw(blob_bytes) when is_binary(blob_bytes) do
    new!(:raw, :crypto.hash(:sha256, blob_bytes))
  end

  @spec new(codec(), binary()) :: {:ok, t()} | {:error, error()}
  def new(codec, digest) when is_binary(digest) do
    with {:ok, codec_code} <- codec_code_for(codec),
         :ok <- validate_digest(digest) do
      bytes =
        encode_varint(@version) <>
          encode_varint(codec_code) <> encode_varint(@hash_sha2_256) <> encode_varint(@hash_size) <> digest

      {:ok, build(codec_code, digest, bytes)}
    end
  end

  def new(_codec, _digest), do: {:error, :digest_size_mismatch}

  @spec new!(codec(), binary()) :: t()
  def new!(codec, digest) do
    case new(codec, digest) do
      {:ok, cid} -> cid
      {:error, reason} -> raise ArgumentError, "invalid CID parts: #{inspect(reason)}"
    end
  end

  @spec from_bytes(binary()) :: {:ok, t()} | {:error, error()}
  def from_bytes(bytes) when is_binary(bytes) do
    with {:ok, version, rest} <- take_varint(bytes),
         :ok <- expect(version, @version, :unsupported_cid_version),
         {:ok, codec_code, rest} <- take_varint(rest),
         :ok <- validate_codec_code(codec_code),
         {:ok, hash_code, rest} <- take_varint(rest),
         :ok <- expect(hash_code, @hash_sha2_256, :unsupported_hash_type),
         {:ok, hash_size, digest} <- take_varint(rest),
         :ok <- expect(hash_size, @hash_size, :unsupported_hash_size),
         :ok <- validate_digest(digest) do
      {:ok, build(codec_code, digest, bytes)}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  def from_bytes(_bytes), do: {:error, :invalid_binary_cid}

  @spec from_bytes!(binary()) :: t()
  def from_bytes!(bytes) do
    case from_bytes(bytes) do
      {:ok, cid} -> cid
      {:error, reason} -> raise ArgumentError, "invalid binary CID: #{inspect(reason)}"
    end
  end

  @spec to_bytes(t()) :: binary()
  def to_bytes(%__MODULE__{bytes: bytes}), do: bytes

  @spec to_cbor_link(t()) :: binary()
  def to_cbor_link(%__MODULE__{} = cid), do: <<0>> <> to_bytes(cid)

  @spec from_cbor_link(binary()) :: {:ok, t()} | {:error, error()}
  def from_cbor_link(<<0, bytes::binary>>), do: from_bytes(bytes)
  def from_cbor_link(_bytes), do: {:error, :invalid_binary_cid}

  @spec to_string(t()) :: String.t()
  def to_string(%__MODULE__{value: value}), do: value

  @spec codec_code(t()) :: 0x71 | 0x55
  def codec_code(%__MODULE__{codec: codec}), do: codec_code!(codec)

  defp build(codec_code, digest, bytes) do
    %__MODULE__{
      version: @version,
      codec: Map.fetch!(@codec_names, codec_code),
      hash_code: @hash_sha2_256,
      digest: digest,
      bytes: bytes,
      value: "b" <> encode_base32(bytes)
    }
  end

  defp require_ascii(cid) do
    if Tempest.RepoCore.Syntax.ascii?(cid) do
      :ok
    else
      {:error, :not_ascii}
    end
  end

  defp codec_code_for(:drisl), do: {:ok, @codec_drisl}
  defp codec_code_for(:dag_cbor), do: {:ok, @codec_drisl}
  defp codec_code_for(:raw), do: {:ok, @codec_raw}
  defp codec_code_for(@codec_drisl), do: {:ok, @codec_drisl}
  defp codec_code_for(@codec_raw), do: {:ok, @codec_raw}
  defp codec_code_for(_codec), do: {:error, :unsupported_codec}

  defp codec_code!(:drisl), do: @codec_drisl
  defp codec_code!(:raw), do: @codec_raw

  defp validate_codec_code(codec_code) do
    if Map.has_key?(@codec_names, codec_code) do
      :ok
    else
      {:error, :unsupported_codec}
    end
  end

  defp validate_digest(<<_::binary-size(@hash_size)>>), do: :ok
  defp validate_digest(_digest), do: {:error, :digest_size_mismatch}

  defp expect(actual, expected, _reason) when actual == expected, do: :ok
  defp expect(_actual, _expected, reason), do: {:error, reason}

  defp encode_base32(bytes) do
    padding = rem(5 - rem(bit_size(bytes), 5), 5)
    padded = <<bytes::bitstring, 0::size(padding)>>

    for <<index::5 <- padded>>, into: "" do
      <<:binary.at(@base32_alphabet, index)>>
    end
  end

  defp decode_base32(encoded) do
    with {:ok, bits} <- decode_base32_bits(encoded),
         :ok <- validate_base32_padding(bits) do
      bit_count = div(bit_size(bits), 8) * 8
      <<bytes::bitstring-size(bit_count), _padding::bitstring>> = bits
      {:ok, bytes}
    end
  end

  defp decode_base32_bits(encoded) do
    encoded
    |> :binary.bin_to_list()
    |> Enum.reduce_while({:ok, <<>>}, fn char, {:ok, bits} ->
      case :binary.match(@base32_alphabet, <<char>>) do
        {index, 1} -> {:cont, {:ok, <<bits::bitstring, index::5>>}}
        :nomatch -> {:halt, {:error, :invalid_base32}}
      end
    end)
  end

  defp validate_base32_padding(bits) do
    padding_bits = rem(bit_size(bits), 8)

    if padding_bits == 0 do
      :ok
    else
      data_bits = bit_size(bits) - padding_bits
      <<_data::bitstring-size(data_bits), padding::size(padding_bits)>> = bits

      if padding == 0 do
        :ok
      else
        {:error, :non_canonical_base32}
      end
    end
  end

  defp encode_varint(integer) when integer in 0..0x7F, do: <<integer>>

  defp encode_varint(integer) when integer > 0 do
    <<(integer &&& 0x7F) ||| 0x80>> <> encode_varint(integer >>> 7)
  end

  defp take_varint(bytes) do
    case do_take_varint(bytes, 0, 0, 0) do
      {:ok, value, rest} -> {:ok, value, rest}
      {:error, :invalid_binary_cid} -> {:error, :invalid_binary_cid}
      {:error, :varint_overflow} -> {:error, :invalid_binary_cid}
    end
  end

  defp do_take_varint(<<>>, _shift, _value, _count), do: {:error, :invalid_binary_cid}

  defp do_take_varint(_bytes, shift, _value, count) when shift >= 64 or count >= 10 do
    {:error, :varint_overflow}
  end

  defp do_take_varint(<<byte, rest::binary>>, shift, value, count) do
    value = value ||| (byte &&& 0x7F) <<< shift

    if (byte &&& 0x80) == 0 do
      {:ok, value, rest}
    else
      do_take_varint(rest, shift + 7, value, count + 1)
    end
  end
end
