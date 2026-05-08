defmodule Tempest.RepoCore.Drisl do
  @moduledoc """
  DRISL-CBOR encoder and decoder for atproto repo-core values.

  This is intentionally a narrow CBOR implementation. It only accepts the
  atproto data model: null, booleans, signed 64-bit integers, UTF-8 strings,
  byte strings, CID links, arrays, and maps with string keys.
  """

  import Kernel, except: [to_string: 1]

  alias Tempest.RepoCore.Cid

  @tag_cid 42
  @int_min -0x8000_0000_0000_0000
  @int_max 0x7FFF_FFFF_FFFF_FFFF

  @default_limits %{
    max_bytes: 1_048_576,
    max_depth: 64,
    max_items: 1_000_000,
    max_array_length: 100_000,
    max_map_length: 100_000,
    max_string_bytes: 1_048_576,
    max_bytestring_bytes: 1_048_576
  }

  defmodule Bytes do
    @moduledoc """
    Explicit byte-string wrapper for DRISL values.

    Elixir uses binaries for both UTF-8 strings and arbitrary bytes, so raw CBOR
    byte strings need an explicit wrapper at the repo-core boundary.
    """

    @enforce_keys [:bytes]
    defstruct [:bytes]

    @type t :: %__MODULE__{bytes: binary()}
  end

  @type value ::
          nil
          | boolean()
          | integer()
          | String.t()
          | Bytes.t()
          | Cid.t()
          | [value()]
          | %{String.t() => value()}

  @type limit_key ::
          :max_bytes
          | :max_depth
          | :max_items
          | :max_array_length
          | :max_map_length
          | :max_string_bytes
          | :max_bytestring_bytes

  @type error ::
          :unsupported_type
          | :invalid_integer_range
          | :invalid_string
          | :invalid_map_key
          | :duplicate_map_key
          | :non_canonical_map_order
          | :invalid_cbor
          | :trailing_bytes
          | :unsupported_simple_value
          | :unsupported_float
          | :unsupported_tag
          | :invalid_cid_link
          | :indefinite_length
          | :non_minimal_integer
          | :reserved_additional_info
          | :max_bytes_exceeded
          | :max_depth_exceeded
          | :max_items_exceeded
          | :max_array_length_exceeded
          | :max_map_length_exceeded
          | :max_string_bytes_exceeded
          | :max_bytestring_bytes_exceeded
          | {:invalid_cid, term()}

  @spec bytes(binary()) :: Bytes.t()
  def bytes(value) when is_binary(value), do: %Bytes{bytes: value}

  @spec default_limits() :: map()
  def default_limits, do: @default_limits

  @spec encode(value()) :: {:ok, binary()} | {:error, error()}
  def encode(value) do
    encode_value(value)
  end

  @spec encode!(value()) :: binary()
  def encode!(value) do
    case encode(value) do
      {:ok, bytes} -> bytes
      {:error, reason} -> raise ArgumentError, "invalid DRISL value: #{inspect(reason)}"
    end
  end

  @spec decode(binary(), keyword() | map()) :: {:ok, value()} | {:error, error()}
  def decode(bytes, opts \\ [])

  def decode(bytes, opts) when is_binary(bytes) do
    limits = limits(opts)

    with :ok <- check_input_size(bytes, limits),
         {:ok, value, rest, _state} <- decode_value(bytes, 0, new_state(limits)) do
      if rest == "" do
        {:ok, value}
      else
        {:error, :trailing_bytes}
      end
    end
  end

  def decode(_bytes, _opts), do: {:error, :invalid_cbor}

  @spec decode!(binary(), keyword() | map()) :: value()
  def decode!(bytes, opts \\ []) do
    case decode(bytes, opts) do
      {:ok, value} -> value
      {:error, reason} -> raise ArgumentError, "invalid DRISL-CBOR: #{inspect(reason)}"
    end
  end

  @spec cid(value()) :: {:ok, Cid.t()} | {:error, error()}
  def cid(value) do
    with {:ok, bytes} <- encode(value) do
      {:ok, Cid.for_drisl(bytes)}
    end
  end

  @spec cid!(value()) :: Cid.t()
  def cid!(value), do: value |> encode!() |> Cid.for_drisl()

  defp encode_value(nil), do: {:ok, <<0xF6>>}
  defp encode_value(false), do: {:ok, <<0xF4>>}
  defp encode_value(true), do: {:ok, <<0xF5>>}

  defp encode_value(integer) when is_integer(integer) and integer in 0..@int_max do
    {:ok, encode_head(0, integer)}
  end

  defp encode_value(integer) when is_integer(integer) and integer in @int_min..-1 do
    {:ok, encode_head(1, -1 - integer)}
  end

  defp encode_value(integer) when is_integer(integer) do
    {:error, :invalid_integer_range}
  end

  defp encode_value(%Bytes{bytes: bytes}) when is_binary(bytes) do
    {:ok, encode_head(2, byte_size(bytes)) <> bytes}
  end

  defp encode_value(%Cid{} = cid) do
    cid_link = Cid.to_cbor_link(cid)
    {:ok, encode_head(6, @tag_cid) <> encode_head(2, byte_size(cid_link)) <> cid_link}
  end

  defp encode_value(string) when is_binary(string) do
    if String.valid?(string) do
      {:ok, encode_head(3, byte_size(string)) <> string}
    else
      {:error, :invalid_string}
    end
  end

  defp encode_value(list) when is_list(list) do
    with {:ok, encoded_items} <- encode_list_items(list) do
      {:ok, encode_head(4, length(list)) <> encoded_items}
    end
  end

  defp encode_value(map) when is_map(map) do
    encode_map(map)
  end

  defp encode_value(_value), do: {:error, :unsupported_type}

  defp encode_list_items(items) do
    Enum.reduce_while(items, {:ok, []}, fn item, {:ok, encoded} ->
      case encode_value(item) do
        {:ok, bytes} -> {:cont, {:ok, [encoded, bytes]}}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
    |> case do
      {:ok, iodata} -> {:ok, IO.iodata_to_binary(iodata)}
      {:error, reason} -> {:error, reason}
    end
  end

  defp encode_map(map) do
    with {:ok, pairs} <- encode_map_pairs(map) do
      pairs = Enum.sort_by(pairs, fn {encoded_key, _encoded_value} -> encoded_key end)

      iodata =
        Enum.map(pairs, fn {encoded_key, encoded_value} ->
          [encoded_key, encoded_value]
        end)

      {:ok, encode_head(5, map_size(map)) <> IO.iodata_to_binary(iodata)}
    end
  end

  defp encode_map_pairs(map) do
    Enum.reduce_while(map, {:ok, []}, fn {key, value}, {:ok, pairs} ->
      with :ok <- validate_map_key(key),
           {:ok, encoded_key} <- encode_value(key),
           {:ok, encoded_value} <- encode_value(value) do
        {:cont, {:ok, [{encoded_key, encoded_value} | pairs]}}
      else
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
  end

  defp validate_map_key(key) when is_binary(key) do
    if String.valid?(key), do: :ok, else: {:error, :invalid_map_key}
  end

  defp validate_map_key(_key), do: {:error, :invalid_map_key}

  defp encode_head(major, value) when value <= 23, do: <<major::3, value::5>>
  defp encode_head(major, value) when value <= 0xFF, do: <<major::3, 24::5, value::8>>
  defp encode_head(major, value) when value <= 0xFFFF, do: <<major::3, 25::5, value::16>>
  defp encode_head(major, value) when value <= 0xFFFF_FFFF, do: <<major::3, 26::5, value::32>>
  defp encode_head(major, value), do: <<major::3, 27::5, value::64>>

  defp decode_value(bytes, depth, state) do
    with :ok <- check_depth(depth, state.limits),
         {:ok, state} <- consume_item(state),
         {:ok, major, value, rest, head} <- take_head(bytes) do
      decode_by_major(major, value, rest, depth, state, head)
    end
  end

  defp decode_by_major(0, value, rest, _depth, state, _head) do
    if value <= @int_max, do: {:ok, value, rest, state}, else: {:error, :invalid_integer_range}
  end

  defp decode_by_major(1, value, rest, _depth, state, _head) do
    if value <= @int_max, do: {:ok, -1 - value, rest, state}, else: {:error, :invalid_integer_range}
  end

  defp decode_by_major(2, length, rest, _depth, state, _head) do
    with :ok <- check_length(:bytestring, length, state.limits),
         {:ok, bytes, rest} <- take_bytes(rest, length) do
      {:ok, %Bytes{bytes: bytes}, rest, state}
    end
  end

  defp decode_by_major(3, length, rest, _depth, state, _head) do
    with :ok <- check_length(:string, length, state.limits),
         {:ok, string, rest} <- take_bytes(rest, length),
         :ok <- validate_utf8(string) do
      {:ok, string, rest, state}
    end
  end

  defp decode_by_major(4, length, rest, depth, state, _head) do
    with :ok <- check_length(:array, length, state.limits) do
      decode_array(length, rest, depth + 1, state, [])
    end
  end

  defp decode_by_major(5, length, rest, depth, state, _head) do
    with :ok <- check_length(:map, length, state.limits) do
      decode_map(length, rest, depth + 1, state, %{}, nil)
    end
  end

  defp decode_by_major(6, @tag_cid, rest, _depth, state, _head) do
    with {:ok, state} <- consume_item(state),
         {:ok, 2, length, rest, _bytestring_head} <- take_head(rest),
         :ok <- check_length(:bytestring, length, state.limits),
         {:ok, cid_link, rest} <- take_bytes(rest, length),
         {:ok, cid} <- parse_cid_link(cid_link) do
      {:ok, cid, rest, state}
    else
      {:error, reason} -> {:error, reason}
      {:ok, _major, _length, _rest, _head} -> {:error, :invalid_cid_link}
    end
  end

  defp decode_by_major(6, _tag, _rest, _depth, _state, _head), do: {:error, :unsupported_tag}

  defp decode_by_major(7, _value, _rest, _depth, _state, <<float_head, _arg::binary>>)
       when float_head in [0xF9, 0xFA, 0xFB],
       do: {:error, :unsupported_float}

  defp decode_by_major(7, 20, rest, _depth, state, _head), do: {:ok, false, rest, state}
  defp decode_by_major(7, 21, rest, _depth, state, _head), do: {:ok, true, rest, state}
  defp decode_by_major(7, 22, rest, _depth, state, _head), do: {:ok, nil, rest, state}

  defp decode_by_major(7, _value, _rest, _depth, _state, _head), do: {:error, :unsupported_simple_value}

  defp decode_array(0, rest, _depth, state, items) do
    {:ok, Enum.reverse(items), rest, state}
  end

  defp decode_array(remaining, rest, depth, state, items) do
    with {:ok, item, rest, state} <- decode_value(rest, depth, state) do
      decode_array(remaining - 1, rest, depth, state, [item | items])
    end
  end

  defp decode_map(0, rest, _depth, state, map, _last_key_encoding) do
    {:ok, map, rest, state}
  end

  defp decode_map(remaining, rest, depth, state, map, last_key_encoding) do
    with {:ok, key, rest, state, key_encoding} <- decode_map_key(rest, depth, state),
         :ok <- check_duplicate_key(map, key),
         :ok <- check_map_order(last_key_encoding, key_encoding),
         {:ok, value, rest, state} <- decode_value(rest, depth, state) do
      decode_map(remaining - 1, rest, depth, state, Map.put(map, key, value), key_encoding)
    end
  end

  defp decode_map_key(bytes, depth, state) do
    with :ok <- check_depth(depth, state.limits),
         {:ok, state} <- consume_item(state),
         {:ok, major, length, rest, key_head} <- take_head(bytes),
         :ok <- expect_major(major, 3),
         :ok <- check_length(:string, length, state.limits),
         {:ok, key, rest} <- take_bytes(rest, length),
         :ok <- validate_utf8(key) do
      key_encoding = key_head <> key
      {:ok, key, rest, state, key_encoding}
    end
  end

  defp parse_cid_link(cid_link) do
    case Cid.from_cbor_link(cid_link) do
      {:ok, cid} -> {:ok, cid}
      {:error, reason} -> {:error, {:invalid_cid, reason}}
    end
  end

  defp take_head(<<major::3, additional::5, rest::binary>>) do
    with {:ok, value, rest, arg} <- take_argument(additional, rest),
         :ok <- reject_indefinite(additional),
         :ok <- reject_reserved(additional),
         :ok <- validate_minimal(additional, value) do
      {:ok, major, value, rest, <<major::3, additional::5, arg::binary>>}
    end
  end

  defp take_head(_bytes), do: {:error, :invalid_cbor}

  defp take_argument(additional, rest) when additional <= 23, do: {:ok, additional, rest, ""}
  defp take_argument(24, <<value::8, rest::binary>>), do: {:ok, value, rest, <<value::8>>}
  defp take_argument(25, <<value::16, rest::binary>>), do: {:ok, value, rest, <<value::16>>}
  defp take_argument(26, <<value::32, rest::binary>>), do: {:ok, value, rest, <<value::32>>}
  defp take_argument(27, <<value::64, rest::binary>>), do: {:ok, value, rest, <<value::64>>}
  defp take_argument(additional, rest) when additional in 24..27 and is_binary(rest), do: {:error, :invalid_cbor}
  defp take_argument(additional, rest) when additional in 28..31 and is_binary(rest), do: {:ok, additional, rest, ""}

  defp reject_indefinite(31), do: {:error, :indefinite_length}
  defp reject_indefinite(_additional), do: :ok

  defp reject_reserved(additional) when additional in 28..30, do: {:error, :reserved_additional_info}
  defp reject_reserved(_additional), do: :ok

  defp validate_minimal(additional, value) do
    cond do
      additional <= 23 -> :ok
      additional == 24 and value >= 24 -> :ok
      additional == 25 and value > 0xFF -> :ok
      additional == 26 and value > 0xFFFF -> :ok
      additional == 27 and value > 0xFFFF_FFFF -> :ok
      true -> {:error, :non_minimal_integer}
    end
  end

  defp take_bytes(bytes, length) do
    if byte_size(bytes) >= length do
      <<value::binary-size(length), rest::binary>> = bytes
      {:ok, value, rest}
    else
      {:error, :invalid_cbor}
    end
  end

  defp validate_utf8(value) do
    if String.valid?(value), do: :ok, else: {:error, :invalid_string}
  end

  defp expect_major(actual, expected) when actual == expected, do: :ok
  defp expect_major(_actual, _expected), do: {:error, :invalid_map_key}

  defp check_map_order(nil, _key_encoding), do: :ok

  defp check_map_order(last_key_encoding, key_encoding) do
    if last_key_encoding < key_encoding do
      :ok
    else
      {:error, :non_canonical_map_order}
    end
  end

  defp check_duplicate_key(map, key) do
    if Map.has_key?(map, key), do: {:error, :duplicate_map_key}, else: :ok
  end

  defp limits(opts) when is_list(opts), do: opts |> Map.new() |> limits()
  defp limits(opts) when is_map(opts), do: Map.merge(@default_limits, opts)

  defp new_state(limits), do: %{limits: limits, items_remaining: limits.max_items}

  defp consume_item(%{items_remaining: items_remaining} = state) when items_remaining > 0 do
    {:ok, %{state | items_remaining: items_remaining - 1}}
  end

  defp consume_item(_state), do: {:error, :max_items_exceeded}

  defp check_input_size(bytes, limits) do
    if byte_size(bytes) <= limits.max_bytes, do: :ok, else: {:error, :max_bytes_exceeded}
  end

  defp check_depth(depth, limits) do
    if depth <= limits.max_depth, do: :ok, else: {:error, :max_depth_exceeded}
  end

  defp check_length(:array, length, limits) do
    if length <= limits.max_array_length, do: :ok, else: {:error, :max_array_length_exceeded}
  end

  defp check_length(:map, length, limits) do
    if length <= limits.max_map_length, do: :ok, else: {:error, :max_map_length_exceeded}
  end

  defp check_length(:string, length, limits) do
    if length <= limits.max_string_bytes, do: :ok, else: {:error, :max_string_bytes_exceeded}
  end

  defp check_length(:bytestring, length, limits) do
    if length <= limits.max_bytestring_bytes, do: :ok, else: {:error, :max_bytestring_bytes_exceeded}
  end
end
