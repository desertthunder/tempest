defmodule Tempest.Records do
  @moduledoc """
  Repository record write context.
  """

  alias Tempest.Accounts.AuthContext
  alias Tempest.Identity.KeyStore
  alias Tempest.Records.LexiconValidator
  alias Tempest.RepoStorage
  alias Tempest.RepoCore.Tid

  def create_record(%AuthContext{account: account}, params) do
    with {:ok, input} <- LexiconValidator.validate_create_record_input(params),
         :ok <- ensure_repo_owner(account, input.repo),
         {:ok, rkey} <- record_key(input.rkey),
         {:ok, validation_status} <-
           LexiconValidator.validate_record(input.collection, rkey, input.record, input.validate),
         {:ok, signing_key} <- active_signing_key(account),
         {:ok, stored} <-
           RepoStorage.create_record(account, signing_key, %{
             collection: input.collection,
             rkey: rkey,
             record: input.record,
             swap_commit: input.swap_commit
           }),
         :ok <- insert_sequence_event(account.did, stored) do
      {:ok,
       %{
         uri: stored.uri,
         cid: stored.record_cid,
         commit: %{
           cid: stored.commit_cid,
           rev: stored.rev
         },
         validationStatus: validation_status
       }}
    end
  end

  defp ensure_repo_owner(account, repo) do
    normalized_handle = Tempest.Identity.Validators.normalize_handle(repo)

    cond do
      repo == account.did -> :ok
      normalized_handle == account.handle -> :ok
      true -> {:error, :repo_mismatch}
    end
  end

  defp record_key(nil) do
    tid = Tid.new!(Tid.now_unix_microseconds(), random_clock_id())
    {:ok, tid.value}
  end

  defp record_key(rkey), do: {:ok, rkey}

  defp active_signing_key(account) do
    case KeyStore.active_key_for_account(account) do
      nil -> {:error, :missing_signing_key}
      signing_key -> {:ok, signing_key}
    end
  end

  defp insert_sequence_event(did, stored) do
    Tempest.Sequencer.insert_repo_commit(did, stored.rev, stored.commit_cid, "repo.record.create", %{
      "uri" => stored.uri,
      "cid" => stored.record_cid
    })
  end

  defp random_clock_id do
    <<value::16>> = :crypto.strong_rand_bytes(2)
    rem(value, Tid.max_clock_id() + 1)
  end
end
