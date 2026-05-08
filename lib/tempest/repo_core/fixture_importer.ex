defmodule Tempest.RepoCore.FixtureImporter do
  @moduledoc """
  Import boundary for official-style repo-core CAR fixtures.

  The importer validates the CAR container, loads the first root as the relevant
  commit object, verifies the commit block CID, and optionally verifies the
  commit signature against a DID document.
  """

  alias Tempest.RepoCore.{Car, Cid, Commit}

  @type result :: %{
          car: Car.t(),
          commit: Commit.t(),
          commit_cid: Cid.t(),
          blocks_by_cid: %{String.t() => binary()}
        }

  @type error ::
          :missing_commit_root
          | :commit_block_missing
          | :commit_cid_mismatch
          | :invalid_commit_signature
          | {:car_error, term()}
          | {:commit_error, term()}

  @spec import_car(binary(), keyword() | map()) :: {:ok, result()} | {:error, error()}
  def import_car(bytes, opts \\ [])

  def import_car(bytes, opts) when is_binary(bytes) do
    opts = opts_map(opts)

    with {:ok, car} <- decode_car(bytes, opts),
         {:ok, commit_cid} <- first_root(car),
         blocks_by_cid = blocks_by_cid(car),
         {:ok, commit_bytes} <- commit_block(blocks_by_cid, commit_cid),
         {:ok, commit} <- decode_commit(commit_bytes),
         :ok <- verify_commit_cid(commit, commit_cid),
         :ok <- maybe_verify_signature(commit, Map.get(opts, :did_document)) do
      {:ok, %{car: car, commit: commit, commit_cid: commit_cid, blocks_by_cid: blocks_by_cid}}
    end
  end

  def import_car(_bytes, _opts), do: {:error, {:car_error, :invalid_car}}

  defp decode_car(bytes, opts) do
    car_opts =
      opts
      |> Map.take([:limits, :verify_cids, :require_roots_present])
      |> Map.put_new(:require_roots_present, true)

    case Car.decode(bytes, car_opts) do
      {:ok, car} -> {:ok, car}
      {:error, reason} -> {:error, {:car_error, reason}}
    end
  end

  defp first_root(%Car{roots: [commit_cid | _rest]}), do: {:ok, commit_cid}
  defp first_root(%Car{}), do: {:error, :missing_commit_root}

  defp blocks_by_cid(%Car{blocks: blocks}) do
    Map.new(blocks, fn %{cid: cid, data: data} ->
      {Cid.to_string(cid), data}
    end)
  end

  defp commit_block(blocks_by_cid, commit_cid) do
    case Map.fetch(blocks_by_cid, Cid.to_string(commit_cid)) do
      {:ok, bytes} -> {:ok, bytes}
      :error -> {:error, :commit_block_missing}
    end
  end

  defp decode_commit(bytes) do
    case Commit.decode(bytes) do
      {:ok, commit} -> {:ok, commit}
      {:error, reason} -> {:error, {:commit_error, reason}}
    end
  end

  defp verify_commit_cid(commit, expected_cid) do
    if Commit.cid!(commit) == expected_cid do
      :ok
    else
      {:error, :commit_cid_mismatch}
    end
  end

  defp maybe_verify_signature(_commit, nil), do: :ok

  defp maybe_verify_signature(commit, did_document) do
    case Commit.verify_with_did_document(commit, did_document) do
      {:ok, true} -> :ok
      {:ok, false} -> {:error, :invalid_commit_signature}
      {:error, reason} -> {:error, {:commit_error, reason}}
    end
  end

  defp opts_map(opts) when is_list(opts), do: Map.new(opts)
  defp opts_map(opts) when is_map(opts), do: opts
end
