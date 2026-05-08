defmodule Tempest.RepoCore.Commit do
  @moduledoc """
  AT Protocol repository commit objects.

  Commit signatures follow the atproto secp256k1 convention: sign the
  SHA-256 digest of the unsigned DRISL-CBOR commit bytes and store a compact
  64-byte low-S ECDSA signature in the `sig` byte string field.
  """

  alias Tempest.RepoCore.{Cid, Did, Drisl, Tid}
  alias Tempest.RepoCore.Drisl.Bytes

  @version 3
  @secp256k1_order 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEBAAEDCE6AF48A03BBFD25E8CD0364141
  @half_secp256k1_order div(@secp256k1_order, 2)

  @enforce_keys [:did, :data, :rev, :prev]
  defstruct [:did, :version, :data, :rev, :prev, :sig]

  @type t :: %__MODULE__{
          did: String.t(),
          version: 3,
          data: Cid.t(),
          rev: String.t(),
          prev: Cid.t() | nil,
          sig: binary() | nil
        }

  @type error ::
          :invalid_commit
          | :invalid_did
          | :invalid_data
          | :invalid_prev
          | :invalid_rev
          | :invalid_signature
          | :already_signed
          | :unsigned_commit
          | :unsupported_key
          | :invalid_public_key
          | :invalid_private_key
          | {:encode_error, term()}
          | {:decode_error, term()}

  @spec new(keyword() | map()) :: {:ok, t()} | {:error, error()}
  def new(attrs) when is_list(attrs), do: attrs |> Map.new() |> new()

  def new(attrs) when is_map(attrs) do
    with {:ok, did} <- parse_did(fetch(attrs, :did)),
         {:ok, data} <- parse_data(fetch(attrs, :data)),
         {:ok, rev} <- parse_rev(fetch(attrs, :rev)),
         {:ok, prev} <- parse_prev(fetch_required(attrs, :prev)),
         {:ok, sig} <- parse_optional_sig(fetch(attrs, :sig)) do
      {:ok, %__MODULE__{did: did, version: @version, data: data, rev: rev, prev: prev, sig: sig}}
    end
  end

  def new(_attrs), do: {:error, :invalid_commit}

  @spec new!(keyword() | map()) :: t()
  def new!(attrs) do
    case new(attrs) do
      {:ok, commit} -> commit
      {:error, reason} -> raise ArgumentError, "invalid commit: #{inspect(reason)}"
    end
  end

  @spec unsigned_map(t()) :: map()
  def unsigned_map(%__MODULE__{} = commit) do
    %{
      "did" => commit.did,
      "version" => @version,
      "data" => commit.data,
      "rev" => commit.rev,
      "prev" => commit.prev
    }
  end

  @spec signed_map(t()) :: map()
  def signed_map(%__MODULE__{sig: sig} = commit) when is_binary(sig) do
    commit
    |> unsigned_map()
    |> Map.put("sig", Drisl.bytes(sig))
  end

  @spec encode_unsigned(t()) :: {:ok, binary()} | {:error, error()}
  def encode_unsigned(%__MODULE__{} = commit) do
    commit
    |> unsigned_map()
    |> Drisl.encode()
    |> wrap_encode_error()
  end

  @spec encode(t()) :: {:ok, binary()} | {:error, error()}
  def encode(%__MODULE__{sig: sig}) when not is_binary(sig), do: {:error, :unsigned_commit}

  def encode(%__MODULE__{} = commit) do
    commit
    |> signed_map()
    |> Drisl.encode()
    |> wrap_encode_error()
  end

  @spec encode!(t()) :: binary()
  def encode!(%__MODULE__{} = commit) do
    case encode(commit) do
      {:ok, bytes} -> bytes
      {:error, reason} -> raise ArgumentError, "invalid signed commit: #{inspect(reason)}"
    end
  end

  @spec decode(binary()) :: {:ok, t()} | {:error, error()}
  def decode(bytes) when is_binary(bytes) do
    with {:ok, map} <- decode_drisl(bytes),
         {:ok, commit} <- from_decoded_map(map) do
      {:ok, commit}
    end
  end

  def decode(_bytes), do: {:error, :invalid_commit}

  @spec cid(t()) :: {:ok, Cid.t()} | {:error, error()}
  def cid(%__MODULE__{} = commit) do
    with {:ok, bytes} <- encode(commit) do
      {:ok, Cid.for_drisl(bytes)}
    end
  end

  @spec cid!(t()) :: Cid.t()
  def cid!(%__MODULE__{} = commit), do: commit |> encode!() |> Cid.for_drisl()

  @spec sign(t(), binary()) :: {:ok, t()} | {:error, error()}
  def sign(%__MODULE__{sig: sig}, _private_key) when is_binary(sig), do: {:error, :already_signed}

  def sign(%__MODULE__{} = commit, <<_::binary-size(32)>> = private_key) do
    with {:ok, unsigned_bytes} <- encode_unsigned(commit),
         {:ok, signature} <- sign_bytes(unsigned_bytes, private_key) do
      {:ok, %__MODULE__{commit | sig: signature}}
    end
  end

  def sign(%__MODULE__{}, _private_key), do: {:error, :invalid_private_key}

  @spec verify(t(), binary()) :: {:ok, boolean()} | {:error, error()}
  def verify(%__MODULE__{sig: sig}, _public_key) when not is_binary(sig), do: {:error, :unsigned_commit}

  def verify(%__MODULE__{} = commit, public_key) when is_binary(public_key) do
    with {:ok, public_key} <- normalize_public_key(public_key),
         :ok <- validate_compact_signature(commit.sig),
         {:ok, unsigned_bytes} <- encode_unsigned(commit),
         {:ok, der_signature} <- compact_to_der(commit.sig) do
      {:ok, verify_der(unsigned_bytes, der_signature, public_key)}
    end
  end

  def verify(%__MODULE__{}, _public_key), do: {:error, :invalid_public_key}

  @spec verify_with_did_document(t(), map()) :: {:ok, boolean()} | {:error, error()}
  def verify_with_did_document(%__MODULE__{} = commit, %{"verificationMethod" => methods}) when is_list(methods) do
    with {:ok, public_key} <- public_key_for_commit(methods, commit.did) do
      verify(commit, public_key)
    end
  end

  def verify_with_did_document(%__MODULE__{}, _document), do: {:error, :invalid_public_key}

  defp from_decoded_map(%{
         "did" => did,
         "version" => @version,
         "data" => %Cid{} = data,
         "rev" => rev,
         "prev" => prev,
         "sig" => %Bytes{bytes: sig}
       }) do
    new(%{did: did, data: data, rev: rev, prev: prev, sig: sig})
  end

  defp from_decoded_map(_map), do: {:error, :invalid_commit}

  defp decode_drisl(bytes) do
    case Drisl.decode(bytes) do
      {:ok, map} -> {:ok, map}
      {:error, reason} -> {:error, {:decode_error, reason}}
    end
  end

  defp fetch(map, key) do
    Map.get(map, key, Map.get(map, Atom.to_string(key)))
  end

  defp fetch_required(map, key) do
    cond do
      Map.has_key?(map, key) -> Map.fetch!(map, key)
      Map.has_key?(map, Atom.to_string(key)) -> Map.fetch!(map, Atom.to_string(key))
      true -> :missing
    end
  end

  defp parse_did(did) do
    case Did.parse(did) do
      {:ok, did} -> {:ok, did}
      {:error, _reason} -> {:error, :invalid_did}
    end
  end

  defp parse_data(%Cid{codec: :drisl} = cid), do: {:ok, cid}
  defp parse_data(%Cid{}), do: {:error, :invalid_data}
  defp parse_data(_data), do: {:error, :invalid_data}

  defp parse_prev(nil), do: {:ok, nil}
  defp parse_prev(%Cid{codec: :drisl} = cid), do: {:ok, cid}
  defp parse_prev(%Cid{}), do: {:error, :invalid_prev}
  defp parse_prev(_prev), do: {:error, :invalid_prev}

  defp parse_rev(%Tid{value: rev}), do: {:ok, rev}

  defp parse_rev(rev) when is_binary(rev) do
    case Tid.parse(rev) do
      {:ok, %Tid{value: rev}} -> {:ok, rev}
      {:error, _reason} -> {:error, :invalid_rev}
    end
  end

  defp parse_rev(_rev), do: {:error, :invalid_rev}

  defp parse_optional_sig(nil), do: {:ok, nil}
  defp parse_optional_sig(sig), do: parse_required_sig(sig)

  defp parse_required_sig(<<_::binary-size(64)>> = sig) do
    with :ok <- validate_compact_signature(sig), do: {:ok, sig}
  end

  defp parse_required_sig(_sig), do: {:error, :invalid_signature}

  defp wrap_encode_error({:ok, bytes}), do: {:ok, bytes}
  defp wrap_encode_error({:error, reason}), do: {:error, {:encode_error, reason}}

  defp sign_bytes(unsigned_bytes, private_key) do
    try do
      :ecdsa
      |> :crypto.sign(:sha256, unsigned_bytes, [private_key, :secp256k1])
      |> der_to_compact_low_s()
    rescue
      _error -> {:error, :invalid_private_key}
    end
  end

  defp verify_der(unsigned_bytes, der_signature, public_key) do
    :crypto.verify(:ecdsa, :sha256, unsigned_bytes, der_signature, [public_key, :secp256k1])
  rescue
    _error -> false
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

  defp compact_to_der(<<r::binary-size(32), s::binary-size(32)>>) do
    r = :binary.decode_unsigned(r)
    s = :binary.decode_unsigned(s)
    {:ok, <<0x30, byte_size(der_integer(r)) + byte_size(der_integer(s))>> <> der_integer(r) <> der_integer(s)}
  end

  defp compact_to_der(_sig), do: {:error, :invalid_signature}

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

  defp der_integer(integer) do
    bytes = :binary.encode_unsigned(integer)
    bytes = if :binary.first(bytes) >= 0x80, do: <<0, bytes::binary>>, else: bytes
    <<0x02, byte_size(bytes), bytes::binary>>
  end

  defp fixed_uint(integer), do: integer |> :binary.encode_unsigned() |> pad_uint()

  defp pad_uint(bytes) when byte_size(bytes) < 32 do
    padding = 32 - byte_size(bytes)
    <<0::size(padding * 8), bytes::binary>>
  end

  defp pad_uint(bytes) when byte_size(bytes) == 32, do: bytes

  defp normalize_public_key(<<4, _::binary-size(64)>> = public_key), do: {:ok, public_key}
  defp normalize_public_key(<<2, _::binary-size(32)>> = public_key), do: {:ok, public_key}
  defp normalize_public_key(<<3, _::binary-size(32)>> = public_key), do: {:ok, public_key}
  defp normalize_public_key(_public_key), do: {:error, :invalid_public_key}

  defp public_key_for_commit(methods, did) do
    methods
    |> Enum.find(fn
      %{"id" => id, "publicKeyMultibase" => key} when is_binary(id) and is_binary(key) ->
        id in [did <> "#atproto", "#atproto"]

      _method ->
        false
    end)
    |> case do
      %{"publicKeyMultibase" => public_key_multibase} -> decode_public_key_multibase(public_key_multibase)
      _method -> {:error, :invalid_public_key}
    end
  end

  defp decode_public_key_multibase("u" <> encoded) do
    case Base.url_decode64(encoded, padding: false) do
      {:ok, public_key} -> normalize_public_key(public_key)
      :error -> {:error, :invalid_public_key}
    end
  end

  defp decode_public_key_multibase(_value), do: {:error, :unsupported_key}
end
