defmodule Tempest.RepoCore.CarVerifier do
  @moduledoc """
  Verification helper for repository CAR exports.

  This validates the CAR container, root commit block, commit CID, optional DID,
  complete MST graph, and the presence of every record block referenced by the
  MST.
  """

  alias Tempest.RepoCore.{Car, Cid, Commit, Drisl, Mst}

  @firehose_max_frame_bytes 5_000_000
  @firehose_max_car_bytes 2_000_000
  @firehose_max_record_bytes 1_000_000
  @firehose_max_ops 200

  @type result :: %{
          car: Car.t(),
          commit: Commit.t(),
          commit_cid: Cid.t(),
          entries: %{String.t() => Cid.t()}
        }

  @type error ::
          :missing_commit_root
          | :commit_block_missing
          | :commit_cid_mismatch
          | :did_mismatch
          | :mst_cycle
          | :too_many_ops
          | :firehose_frame_too_large
          | :firehose_car_too_large
          | :firehose_record_too_large
          | :commit_rev_mismatch
          | :commit_root_mismatch
          | :commit_event_mismatch
          | :invalid_commit_event
          | :invalid_mst_node
          | :invalid_mst_entry
          | {:car_error, term()}
          | {:commit_error, term()}
          | {:missing_block, String.t()}

  @spec verify_repo_car(binary(), keyword() | map()) :: {:ok, result()} | {:error, error()}
  def verify_repo_car(bytes, opts \\ [])

  def verify_repo_car(bytes, opts) when is_binary(bytes) do
    opts = opts_map(opts)

    with {:ok, car} <- decode_car(bytes),
         {:ok, commit_cid} <- first_root(car),
         blocks = blocks_by_cid(car),
         {:ok, commit_bytes} <- fetch_block(blocks, commit_cid, :commit_block_missing),
         {:ok, commit} <- decode_commit(commit_bytes),
         :ok <- verify_commit_cid(commit, commit_cid),
         :ok <- verify_did(commit, Map.get(opts, :did)),
         {:ok, proof} <- collect_mst(blocks, commit.data, MapSet.new(), %{}),
         entries = proof.entries,
         :ok <- verify_record_blocks(blocks, entries) do
      {:ok, %{car: car, commit: commit, commit_cid: commit_cid, entries: entries}}
    end
  end

  def verify_repo_car(_bytes, _opts), do: {:error, {:car_error, :invalid_car}}

  @spec verify_commit_event(map()) :: :ok | {:error, error()}
  def verify_commit_event(payload) when is_map(payload) do
    with {:ok, blocks} <- commit_event_blocks(payload),
         :ok <- verify_firehose_car_size(blocks),
         :ok <- verify_frame_size(payload),
         :ok <- verify_ops_size(Map.get(payload, "ops", [])),
         {:ok, car} <- decode_car(blocks),
         {:ok, commit_cid} <- first_root(car),
         :ok <- verify_payload_commit(payload, commit_cid),
         blocks_by_cid = blocks_by_cid(car),
         {:ok, commit_bytes} <- fetch_block(blocks_by_cid, commit_cid, :commit_block_missing),
         {:ok, commit} <- decode_commit(commit_bytes),
         :ok <- verify_commit_cid(commit, commit_cid),
         :ok <- verify_did(commit, Map.get(payload, "did")),
         :ok <- verify_rev(commit, Map.get(payload, "rev")),
         {:ok, proof} <- collect_mst(blocks_by_cid, commit.data, MapSet.new(), %{}),
         :ok <- verify_record_block_sizes(blocks_by_cid, Map.get(payload, "ops", [])),
         :ok <- verify_mst_inversion(proof.entries, payload) do
      :ok
    end
  end

  def verify_commit_event(_payload), do: {:error, :invalid_commit_event}

  defp decode_car(bytes) do
    case Car.decode(bytes) do
      {:ok, car} -> {:ok, car}
      {:error, reason} -> {:error, {:car_error, reason}}
    end
  end

  defp first_root(%Car{roots: [commit_cid | _rest]}), do: {:ok, commit_cid}
  defp first_root(%Car{}), do: {:error, :missing_commit_root}

  defp blocks_by_cid(%Car{blocks: blocks}) do
    Map.new(blocks, fn %{cid: cid, data: data} -> {Cid.to_string(cid), data} end)
  end

  defp fetch_block(blocks, %Cid{} = cid, error) do
    case Map.fetch(blocks, Cid.to_string(cid)) do
      {:ok, bytes} -> {:ok, bytes}
      :error -> {:error, error}
    end
  end

  defp decode_commit(bytes) do
    case Commit.decode(bytes) do
      {:ok, commit} -> {:ok, commit}
      {:error, reason} -> {:error, {:commit_error, reason}}
    end
  end

  defp verify_commit_cid(commit, expected_cid) do
    if Commit.cid!(commit) == expected_cid, do: :ok, else: {:error, :commit_cid_mismatch}
  end

  defp verify_did(_commit, nil), do: :ok
  defp verify_did(%Commit{did: did}, did), do: :ok
  defp verify_did(%Commit{}, _did), do: {:error, :did_mismatch}

  defp verify_rev(_commit, nil), do: :ok
  defp verify_rev(%Commit{rev: rev}, rev), do: :ok
  defp verify_rev(%Commit{}, _rev), do: {:error, :commit_rev_mismatch}

  defp verify_payload_commit(payload, commit_cid) do
    case Map.get(payload, "commit") do
      nil ->
        :ok

      value ->
        with {:ok, expected} <- cid_value(value) do
          if expected == commit_cid, do: :ok, else: {:error, :commit_root_mismatch}
        end
    end
  end

  defp commit_event_blocks(%{"blocks" => %Drisl.Bytes{bytes: bytes}}), do: {:ok, bytes}
  defp commit_event_blocks(_payload), do: {:error, :invalid_commit_event}

  defp verify_firehose_car_size(bytes) do
    if byte_size(bytes) <= @firehose_max_car_bytes do
      :ok
    else
      {:error, :firehose_car_too_large}
    end
  end

  defp verify_frame_size(payload) do
    case Drisl.encode(payload) do
      {:ok, bytes} when byte_size(bytes) <= @firehose_max_frame_bytes -> :ok
      {:ok, _bytes} -> {:error, :firehose_frame_too_large}
      {:error, reason} -> {:error, {:commit_event_encode_error, reason}}
    end
  end

  defp verify_ops_size(ops) when is_list(ops) and length(ops) <= @firehose_max_ops, do: :ok
  defp verify_ops_size(ops) when is_list(ops), do: {:error, :too_many_ops}
  defp verify_ops_size(_ops), do: {:error, :invalid_commit_event}

  defp verify_record_block_sizes(blocks, ops) when is_list(ops) do
    Enum.reduce_while(ops, :ok, fn op, :ok ->
      case cid_value(Map.get(op, "cid")) do
        {:ok, cid} ->
          case Map.fetch(blocks, Cid.to_string(cid)) do
            {:ok, bytes} when byte_size(bytes) <= @firehose_max_record_bytes -> {:cont, :ok}
            {:ok, _bytes} -> {:halt, {:error, :firehose_record_too_large}}
            :error -> {:cont, :ok}
          end

        {:error, :missing_cid} ->
          {:cont, :ok}

        {:error, reason} ->
          {:halt, {:error, reason}}
      end
    end)
  end

  defp verify_mst_inversion(_entries, %{"tooBig" => true}), do: :ok
  defp verify_mst_inversion(_entries, %{"action" => "repo.init"}), do: :ok

  defp verify_mst_inversion(entries, %{"prevData" => prev_data, "ops" => ops})
       when is_list(ops) and not is_nil(prev_data) do
    with {:ok, expected_prev_root} <- cid_value(prev_data),
         {:ok, inverted_entries} <- invert_ops(entries, ops),
         {:ok, mst} <- Mst.from_entries(Map.to_list(inverted_entries)),
         {:ok, actual_prev_root} <- Mst.root_cid(mst) do
      if actual_prev_root == expected_prev_root do
        :ok
      else
        {:error, :commit_event_mismatch}
      end
    end
  end

  defp verify_mst_inversion(_entries, _payload), do: :ok

  defp invert_ops(entries, ops) do
    Enum.reduce_while(Enum.reverse(ops), {:ok, entries}, fn op, {:ok, acc} ->
      with {:ok, path} <- op_path(op),
           {:ok, updated} <- invert_op(acc, path, op) do
        {:cont, {:ok, updated}}
      else
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
  end

  defp invert_op(entries, path, %{"action" => "create"}) do
    {:ok, Map.delete(entries, path)}
  end

  defp invert_op(entries, path, %{"action" => action} = op) when action in ["update", "delete"] do
    with {:ok, previous_cid} <- cid_value(Map.get(op, "prev")) do
      {:ok, Map.put(entries, path, previous_cid)}
    end
  end

  defp invert_op(_entries, _path, _op), do: {:error, :invalid_commit_event}

  defp op_path(%{"path" => path}) when is_binary(path) and path != "", do: {:ok, path}
  defp op_path(_op), do: {:error, :invalid_commit_event}

  defp cid_value(nil), do: {:error, :missing_cid}
  defp cid_value(%Cid{} = cid), do: {:ok, cid}

  defp cid_value(value) when is_binary(value) do
    case Cid.parse(value) do
      {:ok, cid} -> {:ok, cid}
      {:error, reason} -> {:error, {:invalid_cid, reason}}
    end
  end

  defp cid_value(_value), do: {:error, :invalid_cid}

  @typep blocks_by_cid :: %{String.t() => binary()}
  @typep mst_entries :: %{String.t() => Cid.t()}
  @typep mst_proof :: %{visited: MapSet.t(String.t()), entries: mst_entries()}

  @spec collect_mst(blocks_by_cid(), Cid.t() | nil, MapSet.t(String.t()), mst_entries()) ::
          {:ok, mst_proof()} | {:error, error()}
  defp collect_mst(_blocks, nil, visited, entries), do: {:ok, %{visited: visited, entries: entries}}

  defp collect_mst(blocks, %Cid{} = cid, visited, entries) do
    cid_value = Cid.to_string(cid)

    cond do
      MapSet.member?(visited, cid_value) ->
        {:error, :mst_cycle}

      not Map.has_key?(blocks, cid_value) ->
        {:error, {:missing_block, cid_value}}

      true ->
        with {:ok, node} <- decode_mst_node(Map.fetch!(blocks, cid_value)),
             visited = MapSet.put(visited, cid_value),
             {:ok, left_proof} <- collect_mst(blocks, Map.fetch!(node, "l"), visited, entries) do
          collect_mst_entries(blocks, Map.fetch!(node, "e"), left_proof.visited, left_proof.entries)
        end
    end
  end

  @spec collect_mst_entries(blocks_by_cid(), list(), MapSet.t(String.t()), mst_entries()) ::
          {:ok, mst_proof()} | {:error, error()}
  defp collect_mst_entries(blocks, entries, visited, acc_entries) when is_list(entries) do
    Enum.reduce_while(entries, {:ok, %{visited: visited, entries: acc_entries, previous_key: ""}}, fn entry,
                                                                                                      {:ok, proof} ->
      with {:ok, key, value, tree} <- decode_mst_entry(entry, proof.previous_key),
           {:ok, child_proof} <- collect_mst(blocks, tree, proof.visited, Map.put(proof.entries, key, value)) do
        {:cont, {:ok, %{visited: child_proof.visited, entries: child_proof.entries, previous_key: key}}}
      else
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
    |> case do
      {:ok, proof} -> {:ok, Map.delete(proof, :previous_key)}
      {:error, reason} -> {:error, reason}
    end
  end

  defp collect_mst_entries(_blocks, _entries, _visited, _acc_entries), do: {:error, :invalid_mst_node}

  defp decode_mst_node(bytes) do
    case Drisl.decode(bytes) do
      {:ok, %{"l" => left, "e" => entries} = node} when is_list(entries) ->
        if cid_or_nil?(left), do: {:ok, node}, else: {:error, :invalid_mst_node}

      {:ok, _value} ->
        {:error, :invalid_mst_node}

      {:error, _reason} ->
        {:error, :invalid_mst_node}
    end
  end

  defp decode_mst_entry(
         %{"p" => prefix_length, "k" => %Drisl.Bytes{bytes: suffix}, "v" => %Cid{} = value, "t" => tree},
         previous_key
       )
       when is_integer(prefix_length) and prefix_length >= 0 do
    if cid_or_nil?(tree) and prefix_length <= byte_size(previous_key) do
      {:ok, binary_part(previous_key, 0, prefix_length) <> suffix, value, tree}
    else
      {:error, :invalid_mst_entry}
    end
  end

  defp decode_mst_entry(_entry, _previous_key), do: {:error, :invalid_mst_entry}

  defp verify_record_blocks(blocks, entries) do
    Enum.reduce_while(entries, :ok, fn {_path, cid}, :ok ->
      cid_value = Cid.to_string(cid)

      if Map.has_key?(blocks, cid_value) do
        {:cont, :ok}
      else
        {:halt, {:error, {:missing_block, cid_value}}}
      end
    end)
  end

  defp cid_or_nil?(nil), do: true
  defp cid_or_nil?(%Cid{}), do: true
  defp cid_or_nil?(_value), do: false

  defp opts_map(opts) when is_list(opts), do: Map.new(opts)
  defp opts_map(opts) when is_map(opts), do: opts
end
