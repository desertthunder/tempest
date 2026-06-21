defmodule Tempest.PersonalBackups.Verifier do
  @moduledoc """
  Verification boundary for personal-backup repository CAR snapshots.
  """

  alias Tempest.RepoCore.{CarVerifier, Cid, Commit}

  def verify_repo_car(bytes, did_document, did) when is_binary(bytes) and is_map(did_document) and is_binary(did) do
    with {:ok, verified} <- CarVerifier.verify_repo_car(bytes, did: did),
         {:ok, true} <- Commit.verify_with_did_document(verified.commit, did_document) do
      {:ok,
       %{
         car: verified.car,
         commit: verified.commit,
         commit_cid: verified.commit_cid,
         commit_cid_string: Cid.to_string(verified.commit_cid),
         rev: verified.commit.rev,
         entries: verified.entries,
         record_count: map_size(verified.entries)
       }}
    else
      {:ok, false} -> {:error, :invalid_commit_signature}
      {:error, reason} -> {:error, reason}
    end
  end
end
