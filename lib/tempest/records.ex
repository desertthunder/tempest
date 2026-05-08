defmodule Tempest.Records do
  @moduledoc """
  Repository record write context.
  """

  alias Tempest.Accounts.AuthContext
  alias Tempest.Accounts.Account
  alias Tempest.Identity
  alias Tempest.Identity.DidDocument
  alias Tempest.Identity.Validators
  alias Tempest.Identity.KeyStore
  alias Tempest.Records.LexiconValidator
  alias Tempest.Repo
  alias Tempest.RepoStorage
  alias Tempest.RepoCore.Tid
  alias Tempest.RepoCore.Tid.Clock

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

  def put_record(%AuthContext{account: account}, params) do
    with {:ok, input} <- LexiconValidator.validate_put_record_input(params),
         :ok <- ensure_repo_owner(account, input.repo),
         {:ok, validation_status} <-
           LexiconValidator.validate_record(input.collection, input.rkey, input.record, input.validate),
         {:ok, signing_key} <- active_signing_key(account),
         {:ok, stored} <-
           RepoStorage.put_record(account, signing_key, %{
             collection: input.collection,
             rkey: input.rkey,
             record: input.record,
             swap_record: input.swap_record,
             swap_commit: input.swap_commit
           }),
         :ok <- insert_sequence_event(account.did, stored, "repo.record.put") do
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

  def delete_record(%AuthContext{account: account}, params) do
    with {:ok, input} <- LexiconValidator.validate_delete_record_input(params),
         :ok <- ensure_repo_owner(account, input.repo),
         {:ok, signing_key} <- active_signing_key(account),
         {:ok, stored} <-
           RepoStorage.delete_record(account, signing_key, %{
             collection: input.collection,
             rkey: input.rkey,
             swap_record: input.swap_record,
             swap_commit: input.swap_commit
           }),
         :ok <- maybe_insert_delete_event(account.did, stored) do
      if stored.deleted? do
        {:ok,
         %{
           commit: %{
             cid: stored.commit_cid,
             rev: stored.rev
           }
         }}
      else
        {:ok, %{}}
      end
    end
  end

  def get_record(params) do
    with {:ok, input} <- LexiconValidator.validate_get_record_input(params),
         {:ok, account} <- resolve_hosted_account(input.repo),
         {:ok, record} <- RepoStorage.get_record(account.did, input.collection, input.rkey, cid: input.cid) do
      {:ok, %{uri: record.uri, cid: record.cid, value: record.value}}
    end
  end

  def list_records(params) do
    with {:ok, input} <- LexiconValidator.validate_list_records_input(params),
         {:ok, account} <- resolve_hosted_account(input.repo),
         {:ok, page} <-
           RepoStorage.list_records(account.did, input.collection,
             limit: input.limit,
             cursor: input.cursor,
             reverse?: input.reverse?
           ) do
      {:ok, page}
    end
  end

  def describe_repo(params) do
    with {:ok, input} <- LexiconValidator.validate_describe_repo_input(params),
         {:ok, account} <- resolve_hosted_account(input.repo),
         {:ok, collections} <- RepoStorage.list_collections(account.did) do
      did_doc = Identity.did_document_for_account(account)

      {:ok,
       %{
         handle: account.handle,
         did: account.did,
         didDoc: did_doc,
         collections: collections,
         handleIsCorrect: handle_correct?(account, did_doc)
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

  defp resolve_hosted_account(repo) when is_binary(repo) do
    cond do
      repo == "" ->
        {:error, :invalid_repo}

      String.starts_with?(repo, "did:") ->
        case Repo.get_by(Account, did: repo) do
          %Account{} = account -> ensure_active_account(account)
          nil -> {:error, :repo_not_found}
        end

      true ->
        handle = Validators.normalize_handle(repo)

        with :ok <- Validators.validate_handle(handle) do
          case Repo.get_by(Account, handle: handle) do
            %Account{} = account -> ensure_active_account(account)
            nil -> {:error, :repo_not_found}
          end
        else
          {:error, _reason} -> {:error, :invalid_repo}
        end
    end
  end

  defp ensure_active_account(%Account{active: true, status: "active"} = account), do: {:ok, account}
  defp ensure_active_account(%Account{}), do: {:error, :repo_not_found}

  defp record_key(nil) do
    tid = Tid.new!(Tid.now_unix_microseconds(), Clock.random_clock_id())
    {:ok, tid.value}
  end

  defp record_key(rkey), do: {:ok, rkey}

  defp active_signing_key(account) do
    case KeyStore.active_key_for_account(account) do
      nil -> {:error, :missing_signing_key}
      signing_key -> {:ok, signing_key}
    end
  end

  defp insert_sequence_event(did, stored, event_type \\ "repo.record.create") do
    Tempest.Sequencer.insert_repo_commit(did, stored.rev, stored.commit_cid, event_type, %{
      "uri" => stored.uri,
      "cid" => stored.record_cid
    })
  end

  defp maybe_insert_delete_event(did, %{deleted?: true} = stored) do
    Tempest.Sequencer.insert_repo_commit(did, stored.rev, stored.commit_cid, "repo.record.delete", %{
      "uri" => stored.uri
    })
  end

  defp maybe_insert_delete_event(_did, %{deleted?: false}), do: :ok

  defp handle_correct?(%Account{} = account, did_doc) do
    did = account.did

    DidDocument.claims_handle?(did_doc, account.handle) and
      match?({:ok, ^did}, Identity.hosted_did_for_handle(account.handle))
  end
end
