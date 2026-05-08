defmodule Tempest.RepoCore.Car do
  @moduledoc """
  CAR v1 reader and writer for repo-core blocks.

  This implementation follows the DASL/atproto profile: CAR headers are DRISL,
  CIDs are the blessed 36-byte DASL CID form already enforced by
  `Tempest.RepoCore.Cid`, and block data is verified against the CID digest.
  """

  import Bitwise

  alias Tempest.RepoCore.{Cid, Drisl}

  @cid_bytes 36
  @default_limits %{
    max_bytes: 512 * 1_024 * 1_024,
    max_header_bytes: 1_048_576,
    max_section_bytes: 32 * 1_024 * 1_024,
    max_block_bytes: 32 * 1_024 * 1_024,
    max_blocks: 1_000_000,
    max_roots: 1_024
  }

  @enforce_keys [:version, :roots, :metadata, :blocks]
  defstruct [:version, :roots, :metadata, :blocks]

  @type block :: %{required(:cid) => Cid.t(), required(:data) => binary(), required(:size) => non_neg_integer()}
  @type t :: %__MODULE__{
          version: 1,
          roots: [Cid.t()],
          metadata: map(),
          blocks: [block()]
        }

  @type error ::
          :invalid_car
          | :invalid_header
          | :invalid_version
          | :invalid_roots
          | :invalid_block
          | :invalid_block_cid
          | :root_block_missing
          | :zero_length_header
          | :zero_length_section
          | :section_too_short
          | :truncated_header
          | :truncated_section
          | :invalid_varint
          | :non_minimal_varint
          | :varint_overflow
          | :max_bytes_exceeded
          | :max_header_bytes_exceeded
          | :max_section_bytes_exceeded
          | :max_block_bytes_exceeded
          | :max_blocks_exceeded
          | :max_roots_exceeded
          | {:invalid_cid, term()}
          | {:invalid_header_cbor, term()}

  @spec default_limits() :: map()
  def default_limits, do: @default_limits

  @spec encode([Cid.t()], list(), keyword() | map()) :: {:ok, binary()} | {:error, error()}
  def encode(roots, blocks, opts \\ []) do
    opts = opts_map(opts)
    extra_metadata = Map.get(opts, :metadata, %{})

    with {:ok, roots} <- validate_roots(roots, limits(opts)),
         {:ok, blocks} <- normalize_blocks(blocks),
         :ok <- validate_block_cids(blocks),
         :ok <- validate_roots_present(roots, blocks, Map.get(opts, :require_roots_present, true)),
         {:ok, header} <- encode_header(roots, extra_metadata),
         {:ok, body} <- encode_blocks(blocks),
         car = encode_varint(byte_size(header)) <> header <> body,
         :ok <- check_total_size(car, limits(opts)) do
      {:ok, car}
    end
  end

  @spec encode!(list(Cid.t()), list(), keyword() | map()) :: binary()
  def encode!(roots, blocks, opts \\ []) do
    case encode(roots, blocks, opts) do
      {:ok, bytes} -> bytes
      {:error, reason} -> raise ArgumentError, "invalid CAR: #{inspect(reason)}"
    end
  end

  @spec decode(binary(), keyword() | map()) :: {:ok, t()} | {:error, error()}
  def decode(bytes, opts \\ [])

  def decode(bytes, opts) when is_binary(bytes) do
    opts = opts_map(opts)
    limits = limits(opts)

    with :ok <- check_total_size(bytes, limits),
         {:ok, header_length, rest} <- take_varint(bytes),
         :ok <- check_header_length(header_length, limits),
         {:ok, header_bytes, rest} <- take_exact(rest, header_length, :truncated_header),
         {:ok, metadata} <- decode_header(header_bytes, limits),
         {:ok, roots} <- validate_header(metadata, limits),
         {:ok, blocks} <- decode_blocks(rest, limits, Map.get(opts, :verify_cids, true), []),
         :ok <- validate_roots_present(roots, blocks, Map.get(opts, :require_roots_present, true)) do
      {:ok, %__MODULE__{version: 1, roots: roots, metadata: metadata, blocks: blocks}}
    end
  end

  def decode(_bytes, _opts), do: {:error, :invalid_car}

  @spec decode!(binary(), keyword() | map()) :: t()
  def decode!(bytes, opts \\ []) do
    case decode(bytes, opts) do
      {:ok, car} -> car
      {:error, reason} -> raise ArgumentError, "invalid CAR: #{inspect(reason)}"
    end
  end

  defp encode_header(roots, extra_metadata) when is_map(extra_metadata) do
    extra_metadata
    |> Map.put("version", 1)
    |> Map.put("roots", roots)
    |> Drisl.encode()
    |> case do
      {:ok, bytes} -> {:ok, bytes}
      {:error, reason} -> {:error, {:invalid_header_cbor, reason}}
    end
  end

  defp encode_header(_roots, _extra_metadata), do: {:error, :invalid_header}

  defp encode_blocks(blocks) do
    Enum.reduce_while(blocks, {:ok, []}, fn %{cid: cid, data: data}, {:ok, encoded} ->
      section = Cid.to_bytes(cid) <> data
      {:cont, {:ok, [encoded, encode_varint(byte_size(section)), section]}}
    end)
    |> case do
      {:ok, iodata} -> {:ok, IO.iodata_to_binary(iodata)}
      {:error, reason} -> {:error, reason}
    end
  end

  defp decode_header(header_bytes, limits) do
    drisl_limits =
      Drisl.default_limits()
      |> Map.put(:max_bytes, limits.max_header_bytes)
      |> Map.put(:max_string_bytes, limits.max_header_bytes)
      |> Map.put(:max_bytestring_bytes, @cid_bytes + 1)
      |> Map.put(:max_array_length, limits.max_roots)

    case Drisl.decode(header_bytes, drisl_limits) do
      {:ok, metadata} -> {:ok, metadata}
      {:error, reason} -> {:error, {:invalid_header_cbor, reason}}
    end
  end

  defp validate_header(%{"version" => 1, "roots" => roots}, limits) when is_list(roots) do
    validate_roots(roots, limits)
  end

  defp validate_header(_metadata, _limits), do: {:error, :invalid_header}

  defp validate_roots(roots, limits) when is_list(roots) do
    cond do
      length(roots) > limits.max_roots ->
        {:error, :max_roots_exceeded}

      Enum.all?(roots, &match?(%Cid{}, &1)) ->
        {:ok, roots}

      true ->
        {:error, :invalid_roots}
    end
  end

  defp validate_roots(_roots, _limits), do: {:error, :invalid_roots}

  defp normalize_blocks(blocks) when is_list(blocks) do
    Enum.reduce_while(blocks, {:ok, []}, fn block, {:ok, normalized} ->
      case normalize_block(block) do
        {:ok, block} -> {:cont, {:ok, [block | normalized]}}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
    |> case do
      {:ok, normalized} -> {:ok, Enum.reverse(normalized)}
      {:error, reason} -> {:error, reason}
    end
  end

  defp normalize_blocks(_blocks), do: {:error, :invalid_block}

  defp normalize_block({%Cid{} = cid, data}) when is_binary(data) do
    {:ok, %{cid: cid, data: data, size: byte_size(data)}}
  end

  defp normalize_block(%{cid: %Cid{} = cid, data: data}) when is_binary(data) do
    {:ok, %{cid: cid, data: data, size: byte_size(data)}}
  end

  defp normalize_block(_block), do: {:error, :invalid_block}

  defp decode_blocks("", _limits, _verify_cids, blocks), do: {:ok, Enum.reverse(blocks)}

  defp decode_blocks(bytes, limits, verify_cids, blocks) do
    with :ok <- check_block_count(blocks, limits),
         {:ok, section_length, rest} <- take_varint(bytes),
         :ok <- check_section_length(section_length, limits),
         {:ok, section, rest} <- take_exact(rest, section_length, :truncated_section),
         {:ok, block} <- decode_block(section, verify_cids) do
      decode_blocks(rest, limits, verify_cids, [block | blocks])
    end
  end

  defp decode_block(section, verify_cids) do
    with :ok <- require_minimum_section(section),
         <<cid_bytes::binary-size(@cid_bytes), data::binary>> <- section,
         {:ok, cid} <- parse_cid(cid_bytes),
         block = %{cid: cid, data: data, size: byte_size(data)},
         :ok <- maybe_validate_block_cid(block, verify_cids) do
      {:ok, block}
    else
      {:error, reason} -> {:error, reason}
      _other -> {:error, :invalid_block}
    end
  end

  defp parse_cid(cid_bytes) do
    case Cid.from_bytes(cid_bytes) do
      {:ok, cid} -> {:ok, cid}
      {:error, reason} -> {:error, {:invalid_cid, reason}}
    end
  end

  defp validate_block_cids(blocks) do
    Enum.reduce_while(blocks, :ok, fn block, :ok ->
      case maybe_validate_block_cid(block, true) do
        :ok -> {:cont, :ok}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
  end

  defp maybe_validate_block_cid(_block, false), do: :ok

  defp maybe_validate_block_cid(%{cid: %Cid{digest: digest}, data: data}, true) do
    if :crypto.hash(:sha256, data) == digest do
      :ok
    else
      {:error, :invalid_block_cid}
    end
  end

  defp validate_roots_present(_roots, _blocks, false), do: :ok

  defp validate_roots_present(roots, blocks, true) do
    block_cids =
      blocks
      |> Enum.map(fn %{cid: cid} -> Cid.to_string(cid) end)
      |> MapSet.new()

    if Enum.all?(roots, &MapSet.member?(block_cids, Cid.to_string(&1))) do
      :ok
    else
      {:error, :root_block_missing}
    end
  end

  defp require_minimum_section(section) do
    cond do
      byte_size(section) == 0 -> {:error, :zero_length_section}
      byte_size(section) < @cid_bytes -> {:error, :section_too_short}
      true -> :ok
    end
  end

  defp check_total_size(bytes, limits) do
    if byte_size(bytes) <= limits.max_bytes, do: :ok, else: {:error, :max_bytes_exceeded}
  end

  defp check_header_length(0, _limits), do: {:error, :zero_length_header}

  defp check_header_length(length, limits) do
    if length <= limits.max_header_bytes, do: :ok, else: {:error, :max_header_bytes_exceeded}
  end

  defp check_section_length(0, _limits), do: {:error, :zero_length_section}

  defp check_section_length(length, limits) do
    cond do
      length > limits.max_section_bytes -> {:error, :max_section_bytes_exceeded}
      max(length - @cid_bytes, 0) > limits.max_block_bytes -> {:error, :max_block_bytes_exceeded}
      true -> :ok
    end
  end

  defp check_block_count(blocks, limits) do
    if length(blocks) < limits.max_blocks, do: :ok, else: {:error, :max_blocks_exceeded}
  end

  defp take_exact(bytes, length, error) do
    if byte_size(bytes) >= length do
      <<value::binary-size(length), rest::binary>> = bytes
      {:ok, value, rest}
    else
      {:error, error}
    end
  end

  defp encode_varint(integer) when integer in 0..0x7F, do: <<integer>>

  defp encode_varint(integer) when integer > 0 do
    <<(integer &&& 0x7F) ||| 0x80>> <> encode_varint(integer >>> 7)
  end

  defp take_varint(bytes), do: do_take_varint(bytes, 0, 0, 0, <<>>)

  defp do_take_varint(<<>>, _shift, _value, _count, _prefix), do: {:error, :invalid_varint}

  defp do_take_varint(_bytes, shift, _value, count, _prefix) when shift >= 64 or count >= 10 do
    {:error, :varint_overflow}
  end

  defp do_take_varint(<<byte, rest::binary>>, shift, value, count, prefix) do
    value = value ||| (byte &&& 0x7F) <<< shift
    prefix = <<prefix::binary, byte>>

    if (byte &&& 0x80) == 0 do
      if encode_varint(value) == prefix do
        {:ok, value, rest}
      else
        {:error, :non_minimal_varint}
      end
    else
      do_take_varint(rest, shift + 7, value, count + 1, prefix)
    end
  end

  defp opts_map(opts) when is_list(opts), do: Map.new(opts)
  defp opts_map(opts) when is_map(opts), do: opts

  defp limits(opts) do
    direct_limits = Map.take(opts, Map.keys(@default_limits))
    nested_limits = Map.get(opts, :limits, %{})

    @default_limits
    |> Map.merge(direct_limits)
    |> Map.merge(nested_limits)
  end
end
