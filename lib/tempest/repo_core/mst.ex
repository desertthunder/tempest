defmodule Tempest.RepoCore.Mst do
  @moduledoc """
  Pure Elixir Merkle Search Tree for atproto repository paths.

  Mutations rebuild from the current key/value mapping. This keeps insert,
  update, and delete deterministic by construction and leaves incremental
  mutation optimization for a later pass.
  """

  import Bitwise

  alias Tempest.RepoCore.{Cid, Drisl}

  @max_key_bytes 1_024

  @enforce_keys [:entries]
  defstruct entries: %{}

  @type key :: binary()
  @type entry :: %{key: key(), value: Cid.t()}
  @type block :: {Cid.t(), binary()}
  @type t :: %__MODULE__{entries: %{key() => Cid.t()}}

  @type error ::
          :duplicate_key
          | :invalid_key
          | :invalid_value
          | :not_found
          | {:encode_error, term()}

  @spec new() :: t()
  def new, do: %__MODULE__{entries: %{}}

  @spec from_entries([{key(), Cid.t()}] | [entry()]) :: {:ok, t()} | {:error, error()}
  def from_entries(entries) when is_list(entries) do
    Enum.reduce_while(entries, {:ok, new()}, fn entry, {:ok, mst} ->
      {key, value} = entry_pair(entry)

      case insert(mst, key, value) do
        {:ok, mst} -> {:cont, {:ok, mst}}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
  end

  def from_entries(_entries), do: {:error, :invalid_key}

  @spec from_entries!([{key(), Cid.t()}] | [entry()]) :: t()
  def from_entries!(entries) do
    case from_entries(entries) do
      {:ok, mst} -> mst
      {:error, reason} -> raise ArgumentError, "invalid MST entries: #{inspect(reason)}"
    end
  end

  @spec depth(key()) :: non_neg_integer()
  def depth(key) when is_binary(key) do
    :crypto.hash(:sha256, key)
    |> leading_zero_bits()
    |> div(2)
  end

  @spec insert(t(), key(), Cid.t()) :: {:ok, t()} | {:error, error()}
  def insert(%__MODULE__{} = mst, key, %Cid{} = value) do
    with :ok <- validate_key(key) do
      if Map.has_key?(mst.entries, key) do
        {:error, :duplicate_key}
      else
        {:ok, %__MODULE__{mst | entries: Map.put(mst.entries, key, value)}}
      end
    end
  end

  def insert(%__MODULE__{}, _key, _value), do: {:error, :invalid_value}

  @spec put(t(), key(), Cid.t()) :: {:ok, t()} | {:error, error()}
  def put(%__MODULE__{} = mst, key, %Cid{} = value) do
    with :ok <- validate_key(key) do
      {:ok, %__MODULE__{mst | entries: Map.put(mst.entries, key, value)}}
    end
  end

  def put(%__MODULE__{}, _key, _value), do: {:error, :invalid_value}

  @spec get(t(), key()) :: {:ok, Cid.t()} | {:error, :not_found | :invalid_key}
  def get(%__MODULE__{} = mst, key) do
    with :ok <- validate_key(key) do
      case Map.fetch(mst.entries, key) do
        {:ok, value} -> {:ok, value}
        :error -> {:error, :not_found}
      end
    end
  end

  @spec delete(t(), key()) :: {:ok, t()} | {:error, :not_found | :invalid_key}
  def delete(%__MODULE__{} = mst, key) do
    with :ok <- validate_key(key) do
      if Map.has_key?(mst.entries, key) do
        {:ok, %__MODULE__{mst | entries: Map.delete(mst.entries, key)}}
      else
        {:error, :not_found}
      end
    end
  end

  @spec range(t(), keyword() | map()) :: [entry()]
  def range(%__MODULE__{} = mst, opts \\ []) do
    opts = opts_map(opts)
    after_key = Map.get(opts, :after)
    before_key = Map.get(opts, :before)
    prefix = Map.get(opts, :prefix)
    limit = Map.get(opts, :limit, :infinity)

    mst.entries
    |> Enum.sort_by(fn {key, _value} -> key end)
    |> Enum.reduce_while([], fn {key, value}, entries ->
      cond do
        after_key && key <= after_key ->
          {:cont, entries}

        before_key && key >= before_key ->
          {:halt, entries}

        prefix && not prefix?(key, prefix) ->
          if entries == [] and key < prefix, do: {:cont, entries}, else: {:halt, entries}

        limit != :infinity and length(entries) >= limit ->
          {:halt, entries}

        true ->
          {:cont, [%{key: key, value: value} | entries]}
      end
    end)
    |> Enum.reverse()
  end

  @spec count(t()) :: non_neg_integer()
  def count(%__MODULE__{} = mst), do: map_size(mst.entries)

  @spec serialize(t()) :: {:ok, %{root: Cid.t(), blocks: [block()], node: map()}} | {:error, error()}
  def serialize(%__MODULE__{} = mst) do
    pairs = sorted_pairs(mst.entries)
    layer = root_layer(pairs)

    with {:ok, node, blocks} <- build_node(pairs, layer),
         {:ok, bytes} <- Drisl.encode(node) do
      root = Cid.for_drisl(bytes)
      {:ok, %{root: root, blocks: [{root, bytes} | blocks], node: node}}
    else
      {:error, reason} -> {:error, {:encode_error, reason}}
    end
  end

  @spec root_cid(t()) :: {:ok, Cid.t()} | {:error, error()}
  def root_cid(%__MODULE__{} = mst) do
    with {:ok, %{root: root}} <- serialize(mst), do: {:ok, root}
  end

  defp build_node([], _layer), do: {:ok, %{"l" => nil, "e" => []}, []}

  defp build_node(pairs, layer) when layer <= 0 do
    encode_node(nil, Enum.map(pairs, fn {key, value} -> {key, value, nil} end))
  end

  defp build_node(pairs, layer) do
    {left_pairs, rest} = take_lower_depth(pairs, layer)

    with {:ok, left_cid, left_blocks} <- build_child(left_pairs, layer),
         {:ok, entries, blocks} <- build_entries(rest, layer, []) do
      encode_node(left_cid, entries, left_blocks ++ blocks)
    end
  end

  defp build_entries([], _layer, blocks), do: {:ok, [], blocks}

  defp build_entries([{key, value} | rest], layer, blocks) do
    key_depth = depth(key)

    cond do
      key_depth == layer ->
        {right_pairs, rest} = take_lower_depth(rest, layer)

        with {:ok, right_cid, right_blocks} <- build_child(right_pairs, layer),
             {:ok, entries, blocks} <- build_entries(rest, layer, blocks ++ right_blocks) do
          {:ok, [{key, value, right_cid} | entries], blocks}
        end

      key_depth < layer ->
        {:error, :invalid_key}

      true ->
        {:error, :invalid_key}
    end
  end

  defp build_child([], _parent_layer), do: {:ok, nil, []}

  defp build_child(pairs, parent_layer) do
    with {:ok, node, blocks} <- build_node(pairs, parent_layer - 1),
         {:ok, bytes} <- Drisl.encode(node) do
      cid = Cid.for_drisl(bytes)
      {:ok, cid, [{cid, bytes} | blocks]}
    end
  end

  defp encode_node(left_cid, entries), do: encode_node(left_cid, entries, [])

  defp encode_node(left_cid, entries, blocks) do
    encoded_entries =
      entries
      |> Enum.reduce({[], ""}, fn {key, value, tree}, {encoded, previous_key} ->
        prefix_length = common_prefix_length(previous_key, key)
        suffix = binary_part(key, prefix_length, byte_size(key) - prefix_length)

        entry = %{
          "p" => prefix_length,
          "k" => Drisl.bytes(suffix),
          "v" => value,
          "t" => tree
        }

        {[entry | encoded], key}
      end)
      |> elem(0)
      |> Enum.reverse()

    {:ok, %{"l" => left_cid, "e" => encoded_entries}, blocks}
  end

  defp take_lower_depth(pairs, layer) do
    Enum.split_while(pairs, fn {key, _value} -> depth(key) < layer end)
  end

  defp root_layer([]), do: 0

  defp root_layer(pairs) do
    pairs
    |> Enum.map(fn {key, _value} -> depth(key) end)
    |> Enum.max()
  end

  defp sorted_pairs(entries), do: Enum.sort_by(entries, fn {key, _value} -> key end)

  defp validate_key(key) when is_binary(key) do
    cond do
      key == "" -> {:error, :invalid_key}
      byte_size(key) > @max_key_bytes -> {:error, :invalid_key}
      true -> :ok
    end
  end

  defp validate_key(_key), do: {:error, :invalid_key}

  defp leading_zero_bits(hash), do: leading_zero_bits(hash, 0)
  defp leading_zero_bits(<<>>, count), do: count
  defp leading_zero_bits(<<0, rest::binary>>, count), do: leading_zero_bits(rest, count + 8)

  defp leading_zero_bits(<<byte, _rest::binary>>, count) do
    count + leading_zero_bits_in_byte(byte)
  end

  defp leading_zero_bits_in_byte(byte) do
    Enum.find_value(7..0//-1, 8, fn bit ->
      if band(byte, 1 <<< bit) != 0, do: 7 - bit
    end)
  end

  defp common_prefix_length(left, right), do: common_prefix_length(left, right, 0)

  defp common_prefix_length(<<a, left::binary>>, <<a, right::binary>>, count),
    do: common_prefix_length(left, right, count + 1)

  defp common_prefix_length(_left, _right, count), do: count

  defp prefix?(key, prefix) when byte_size(prefix) <= byte_size(key) do
    binary_part(key, 0, byte_size(prefix)) == prefix
  end

  defp prefix?(_key, _prefix), do: false

  defp entry_pair({key, value}), do: {key, value}
  defp entry_pair(%{key: key, value: value}), do: {key, value}
  defp entry_pair(%{"key" => key, "value" => value}), do: {key, value}
  defp entry_pair(_entry), do: {nil, nil}

  defp opts_map(opts) when is_list(opts), do: Map.new(opts)
  defp opts_map(opts) when is_map(opts), do: opts
end
