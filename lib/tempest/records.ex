defmodule Tempest.Records do
  @moduledoc """
  Repository record write context.
  """

  alias Tempest.Accounts.AuthContext
  alias Tempest.Accounts.Account
  alias Tempest.Blobs
  alias Tempest.Blobs.LocalStorage
  alias Tempest.Config
  alias Tempest.Identity
  alias Tempest.Identity.DidDocument
  alias Tempest.Identity.Validators
  alias Tempest.Identity.KeyStore
  alias Tempest.Records.LexiconValidator
  alias Tempest.Repo
  alias Tempest.RepoStorage
  alias Tempest.RepoCore.{CarVerifier, Commit, Drisl}
  alias Tempest.RepoCore.Tid
  alias Tempest.RepoCore.Tid.Clock

  def import_repo(%AuthContext{account: account}, car_bytes) when is_binary(car_bytes) do
    with {:ok, did_document} <- Identity.did_document_for_did(account.did),
         {:ok, verified} <- CarVerifier.verify_repo_car(car_bytes, did: account.did),
         :ok <- verify_import_signature(verified.commit, did_document),
         {:ok, imported} <- RepoStorage.import_verified_car(account, verified) do
      {:ok, %{"cid" => imported.cid, "rev" => imported.rev, "recordCount" => imported.record_count}}
    end
  end

  def import_repo(%AuthContext{}, _car_bytes), do: {:error, :invalid_request_body}

  def list_missing_blobs(%AuthContext{account: account}, params) when is_map(params) do
    with {:ok, limit} <- validate_limit(Map.get(params, "limit"), 500, 1000),
         {:ok, cursor} <- validate_optional_cursor(Map.get(params, "cursor")),
         {:ok, referenced} <- all_referenced_blob_cids(account.did),
         {:ok, missing} <- Blobs.missing_cids(account.did, referenced) do
      page = missing |> Enum.drop_while(fn cid -> cursor && cid <= cursor end) |> Enum.take(limit + 1)
      visible = Enum.take(page, limit)
      blobs = Enum.map(visible, &%{"cid" => &1})
      response = %{"blobs" => blobs}

      if length(page) > limit do
        {:ok, Map.put(response, "cursor", List.last(visible))}
      else
        {:ok, response}
      end
    end
  end

  def list_missing_blobs(%AuthContext{}, _params), do: {:error, :invalid_request_body}

  def create_record(%AuthContext{account: account}, params) do
    with {:ok, input} <- LexiconValidator.validate_create_record_input(params),
         :ok <- ensure_repo_owner(account, input.repo),
         {:ok, rkey} <- record_key(input.rkey),
         {:ok, validation_status} <-
           LexiconValidator.validate_record(input.collection, rkey, input.record, input.validate),
         blob_cids = Blobs.referenced_cids(input.record),
         :ok <- Blobs.ensure_present(account.did, blob_cids),
         {:ok, signing_key} <- active_signing_key(account),
         {:ok, stored} <-
           RepoStorage.create_record(account, signing_key, %{
             collection: input.collection,
             rkey: rkey,
             record: input.record,
             swap_commit: input.swap_commit
           }),
         :ok <- promote_blobs(account.did, blob_cids),
         {:ok, _event} <- insert_sequence_event(account.did, stored, "create", input.collection, rkey) do
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
         blob_cids = Blobs.referenced_cids(input.record),
         :ok <- Blobs.ensure_present(account.did, blob_cids),
         {:ok, old_blob_cids} <- current_record_blob_cids(account.did, input.collection, input.rkey),
         {:ok, signing_key} <- active_signing_key(account),
         {:ok, stored} <-
           RepoStorage.put_record(account, signing_key, %{
             collection: input.collection,
             rkey: input.rkey,
             record: input.record,
             swap_record: input.swap_record,
             swap_commit: input.swap_commit
           }),
         :ok <- promote_blobs(account.did, blob_cids),
         :ok <- delete_unreferenced_blobs(account.did, old_blob_cids),
         {:ok, _event} <- insert_sequence_event(account.did, stored, "update", input.collection, input.rkey) do
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
         {:ok, old_blob_cids} <- current_record_blob_cids(account.did, input.collection, input.rkey),
         {:ok, signing_key} <- active_signing_key(account),
         {:ok, stored} <-
           RepoStorage.delete_record(account, signing_key, %{
             collection: input.collection,
             rkey: input.rkey,
             swap_record: input.swap_record,
             swap_commit: input.swap_commit
           }),
         :ok <- maybe_delete_unreferenced_blobs(account.did, old_blob_cids, stored),
         {:ok, _event} <- maybe_insert_delete_event(account.did, stored, input.collection, input.rkey) do
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

  def apply_writes(%AuthContext{account: account}, params) do
    with {:ok, input} <- LexiconValidator.validate_apply_writes_input(params),
         :ok <- ensure_repo_owner(account, input.repo),
         {:ok, prepared_writes} <- prepare_apply_writes(account, input.writes, input.validate),
         new_blob_cids = apply_writes_new_blob_cids(prepared_writes),
         :ok <- Blobs.ensure_present(account.did, new_blob_cids),
         {:ok, old_blob_cids} <- apply_writes_old_blob_cids(account.did, prepared_writes),
         {:ok, signing_key} <- active_signing_key(account),
         {:ok, stored} <-
           RepoStorage.apply_writes(account, signing_key, %{
             swap_commit: input.swap_commit,
             writes: prepared_writes
           }),
         :ok <- promote_blobs(account.did, new_blob_cids),
         :ok <- delete_unreferenced_blobs(account.did, old_blob_cids),
         {:ok, _event} <- insert_apply_writes_event(account.did, stored) do
      {:ok,
       %{
         commit: %{cid: stored.commit_cid, rev: stored.rev},
         results: Enum.map(stored.results, &apply_write_result/1)
       }}
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

  defp prepare_apply_writes(account, writes, validate) do
    writes
    |> Enum.reduce_while({:ok, []}, fn write, {:ok, acc} ->
      case prepare_apply_write(account, write, validate) do
        {:ok, prepared} -> {:cont, {:ok, [prepared | acc]}}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
    |> case do
      {:ok, writes} -> {:ok, Enum.reverse(writes)}
      {:error, reason} -> {:error, reason}
    end
  end

  defp prepare_apply_write(_account, %{action: :delete} = write, _validate), do: {:ok, write}

  defp prepare_apply_write(_account, write, validate) do
    rkey = write.rkey || generated_record_key()

    with {:ok, validation_status} <- LexiconValidator.validate_record(write.collection, rkey, write.value, validate) do
      {:ok,
       write
       |> Map.put(:rkey, rkey)
       |> Map.put(:record, write.value)
       |> Map.put(:validation_status, validation_status)}
    end
  end

  defp generated_record_key do
    Tid.new!(Tid.now_unix_microseconds(), Clock.random_clock_id()).value
  end

  defp apply_writes_new_blob_cids(writes) do
    writes
    |> Enum.filter(&(&1.action in [:create, :update]))
    |> Enum.flat_map(&Blobs.referenced_cids(&1.record))
    |> Enum.uniq()
  end

  defp apply_writes_old_blob_cids(did, writes) do
    writes
    |> Enum.filter(&(&1.action in [:update, :delete]))
    |> Enum.reduce_while({:ok, []}, fn write, {:ok, acc} ->
      case current_record_blob_cids(did, write.collection, write.rkey) do
        {:ok, cids} -> {:cont, {:ok, acc ++ cids}}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
    |> case do
      {:ok, cids} -> {:ok, Enum.uniq(cids)}
      {:error, reason} -> {:error, reason}
    end
  end

  defp apply_write_result(%{action: :create} = result) do
    %{
      "$type" => "com.atproto.repo.applyWrites#createResult",
      uri: result.uri,
      cid: result.cid,
      validationStatus: result.validationStatus
    }
  end

  defp apply_write_result(%{action: :update} = result) do
    %{
      "$type" => "com.atproto.repo.applyWrites#updateResult",
      uri: result.uri,
      cid: result.cid,
      validationStatus: result.validationStatus
    }
  end

  defp apply_write_result(%{action: :delete}) do
    %{"$type" => "com.atproto.repo.applyWrites#deleteResult"}
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

  defp validate_limit(nil, default, _max), do: {:ok, default}

  defp validate_limit(value, _default, max) when is_integer(value) and value >= 1 and value <= max, do: {:ok, value}

  defp validate_limit(value, _default, max) when is_binary(value) do
    case Integer.parse(value) do
      {limit, ""} when limit >= 1 and limit <= max -> {:ok, limit}
      _other -> {:error, :invalid_limit}
    end
  end

  defp validate_limit(_value, _default, _max), do: {:error, :invalid_limit}

  defp validate_optional_cursor(nil), do: {:ok, nil}
  defp validate_optional_cursor(cursor) when is_binary(cursor), do: {:ok, cursor}
  defp validate_optional_cursor(_cursor), do: {:error, :invalid_cursor}

  defp verify_import_signature(commit, did_document) do
    case Commit.verify_with_did_document(commit, did_document) do
      {:ok, true} -> :ok
      {:ok, false} -> {:error, :invalid_commit_signature}
      {:error, reason} -> {:error, {:commit_error, reason}}
    end
  end

  defp active_signing_key(account) do
    case KeyStore.active_key_for_account(account) do
      nil -> {:error, :missing_signing_key}
      signing_key -> {:ok, signing_key}
    end
  end

  defp promote_blobs(_did, []), do: :ok

  defp promote_blobs(did, blob_cids) do
    config = Config.load!()

    Enum.reduce_while(blob_cids, :ok, fn cid, :ok ->
      with {:ok, _path} <- LocalStorage.promote_blob(config, did, cid),
           :ok <- Blobs.mark_public(did, [cid]) do
        {:cont, :ok}
      else
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
  end

  defp current_record_blob_cids(did, collection, rkey) do
    case RepoStorage.get_record(did, collection, rkey) do
      {:ok, %{value: record}} -> {:ok, Blobs.referenced_cids(record)}
      {:error, :record_not_found} -> {:ok, []}
      {:error, reason} -> {:error, reason}
    end
  end

  defp maybe_delete_unreferenced_blobs(did, old_blob_cids, %{deleted?: true}) do
    delete_unreferenced_blobs(did, old_blob_cids)
  end

  defp maybe_delete_unreferenced_blobs(_did, _old_blob_cids, %{deleted?: false}), do: :ok

  defp delete_unreferenced_blobs(_did, []), do: :ok

  defp delete_unreferenced_blobs(did, old_blob_cids) do
    config = Config.load!()

    with {:ok, current_blob_cids} <- all_current_blob_cids(did) do
      old_blob_cids
      |> Enum.reject(&(&1 in current_blob_cids))
      |> Enum.reduce_while(:ok, fn cid, :ok ->
        with :ok <- LocalStorage.delete_blob(config, did, cid),
             :ok <- Blobs.delete_metadata(did, [cid]) do
          {:cont, :ok}
        else
          {:error, reason} -> {:halt, {:error, reason}}
        end
      end)
    end
  end

  defp all_referenced_blob_cids(did, cursor \\ nil, acc \\ []) do
    with {:ok, page} <- RepoStorage.list_referenced_blobs(did, limit: 1000, cursor: cursor) do
      cids = acc ++ Map.get(page, :cids, [])

      case Map.get(page, :cursor) do
        nil -> {:ok, cids}
        cursor -> all_referenced_blob_cids(did, cursor, cids)
      end
    end
  end

  defp all_current_blob_cids(did, cursor \\ nil, acc \\ []) do
    with {:ok, page} <- RepoStorage.list_referenced_blobs(did, limit: 1000, cursor: cursor) do
      cids = acc ++ page.cids

      case Map.get(page, :cursor) do
        nil -> {:ok, cids}
        cursor -> all_current_blob_cids(did, cursor, cids)
      end
    end
  end

  defp insert_sequence_event(did, stored, action, collection, rkey) do
    path = collection <> "/" <> rkey

    op =
      %{
        "action" => action,
        "path" => path,
        "cid" => stored.record_cid
      }
      |> maybe_put("prev", Map.get(stored, :prev_record_cid))

    with {:ok, payload} <- commit_payload(did, stored, [path], [op]) do
      Tempest.Sequencer.insert_repo_commit(did, stored.rev, stored.commit_cid, action, payload)
    end
  end

  defp insert_apply_writes_event(did, stored) do
    with {:ok, payload} <- commit_payload(did, stored, stored.paths, stored.ops) do
      Tempest.Sequencer.insert_repo_commit(did, stored.rev, stored.commit_cid, "applyWrites", payload)
    end
  end

  defp maybe_insert_delete_event(did, %{deleted?: true} = stored, collection, rkey) do
    path = collection <> "/" <> rkey
    op = %{"action" => "delete", "path" => path, "cid" => nil, "prev" => stored.prev_record_cid}

    with {:ok, payload} <- commit_payload(did, stored, [path], [op]) do
      Tempest.Sequencer.insert_repo_commit(did, stored.rev, stored.commit_cid, "delete", payload)
    end
  end

  defp maybe_insert_delete_event(_did, %{deleted?: false}, _collection, _rkey), do: {:ok, nil}

  defp commit_payload(did, stored, paths, ops) do
    base = %{
      "ops" => ops,
      "blobs" => [],
      "tooBig" => false
    }

    with {:ok, car_slice} <- RepoStorage.export_commit_car_slice(did, stored.commit_cid, paths: paths) do
      payload =
        base
        |> put_common_commit_fields(stored)
        |> Map.put("blocks", Drisl.bytes(car_slice.bytes))

      case CarVerifier.verify_commit_event(
             Map.merge(payload, %{"did" => did, "commit" => stored.commit_cid, "rev" => stored.rev})
           ) do
        :ok ->
          {:ok, payload}

        {:error, reason}
        when reason in [:firehose_car_too_large, :firehose_record_too_large, :firehose_frame_too_large] ->
          too_big_commit_payload(did, stored, ops)

        {:error, reason} ->
          {:error, {:invalid_commit_event, reason}}
      end
    end
  end

  defp too_big_commit_payload(did, stored, ops) do
    with {:ok, car_slice} <- RepoStorage.export_commit_car_slice(did, stored.commit_cid, paths: []) do
      payload =
        %{
          "blocks" => Drisl.bytes(car_slice.bytes),
          "ops" => ops,
          "blobs" => [],
          "tooBig" => true
        }
        |> put_common_commit_fields(stored)

      case CarVerifier.verify_commit_event(
             Map.merge(payload, %{"did" => did, "commit" => stored.commit_cid, "rev" => stored.rev})
           ) do
        :ok -> {:ok, payload}
        {:error, reason} -> {:error, {:invalid_commit_event, reason}}
      end
    end
  end

  defp put_common_commit_fields(payload, stored) do
    payload
    |> maybe_put("since", Map.get(stored, :prev_rev))
    |> maybe_put("prevData", Map.get(stored, :prev_data))
  end

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)

  defp handle_correct?(%Account{} = account, did_doc) do
    did = account.did

    DidDocument.claims_handle?(did_doc, account.handle) and
      match?({:ok, ^did}, Identity.hosted_did_for_handle(account.handle))
  end
end
