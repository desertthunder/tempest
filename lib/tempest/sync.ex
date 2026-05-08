defmodule Tempest.Sync do
  @moduledoc """
  Read-side context for `com.atproto.sync.*` XRPC methods.
  """

  import Ecto.Query

  alias Tempest.Accounts.Account
  alias Tempest.Repo
  alias Tempest.RepoCore.{Cid, Did, Nsid, RecordKey}
  alias Tempest.RepoStorage

  def get_repo(params) when is_map(params) do
    with {:ok, did} <- validate_did_param(params),
         {:ok, account} <- fetch_account(did),
         :ok <- ensure_active(account),
         {:ok, export} <- RepoStorage.export_car(account.did) do
      {:ok, export.bytes}
    end
  end

  def get_repo(_params), do: {:error, :invalid_request_body}

  def get_latest_commit(params) when is_map(params) do
    with {:ok, did} <- validate_did_param(params),
         {:ok, account} <- fetch_account(did),
         :ok <- ensure_active(account),
         {:ok, latest} <- RepoStorage.latest_commit(account.did) do
      {:ok, %{cid: latest.cid, rev: latest.rev}}
    end
  end

  def get_latest_commit(_params), do: {:error, :invalid_request_body}

  def get_record(params) when is_map(params) do
    with {:ok, input} <- validate_get_record_params(params),
         {:ok, account} <- fetch_account(input.did),
         :ok <- ensure_active(account),
         {:ok, _record} <- RepoStorage.get_record(account.did, input.collection, input.rkey),
         {:ok, export} <- RepoStorage.export_car(account.did) do
      {:ok, export.bytes}
    end
  end

  def get_record(_params), do: {:error, :invalid_request_body}

  def get_repo_status(params) when is_map(params) do
    with {:ok, did} <- validate_did_param(params),
         {:ok, account} <- fetch_account(did, active_required?: false) do
      repo_status(account)
    end
  end

  def get_repo_status(_params), do: {:error, :invalid_request_body}

  defp validate_get_record_params(params) do
    with {:ok, did} <- validate_did_param(params),
         {:ok, collection} <- validate_collection(Map.get(params, "collection")),
         {:ok, rkey} <- validate_rkey(Map.get(params, "rkey")),
         :ok <- validate_unsupported_commit(Map.get(params, "commit")) do
      {:ok, %{did: did, collection: collection, rkey: rkey}}
    end
  end

  defp validate_did_param(params) do
    case Map.get(params, "did") do
      did when is_binary(did) and did != "" ->
        case Did.parse(did) do
          {:ok, did} -> {:ok, did}
          {:error, _reason} -> {:error, :invalid_did}
        end

      _value ->
        {:error, {:missing_field, "did"}}
    end
  end

  defp validate_collection(collection) do
    case Nsid.parse(collection) do
      {:ok, %Nsid{value: normalized}} -> {:ok, normalized}
      {:error, _reason} -> {:error, :invalid_collection}
    end
  end

  defp validate_rkey(rkey) do
    case RecordKey.parse(rkey) do
      {:ok, rkey} -> {:ok, rkey}
      {:error, _reason} -> {:error, :invalid_rkey}
    end
  end

  defp validate_unsupported_commit(nil), do: :ok

  defp validate_unsupported_commit(commit) do
    case Cid.parse(commit) do
      {:ok, _cid} -> {:error, :commit_not_supported}
      {:error, _reason} -> {:error, :invalid_commit}
    end
  end

  defp fetch_account(did, opts \\ []) do
    active_required? = Keyword.get(opts, :active_required?, true)

    Account
    |> where([account], account.did == ^did)
    |> Repo.one()
    |> case do
      %Account{} = account when active_required? -> ensure_found_active(account)
      %Account{} = account -> {:ok, account}
      nil -> {:error, :repo_not_found}
    end
  end

  defp ensure_found_active(%Account{} = account) do
    case ensure_active(account) do
      :ok -> {:ok, account}
      {:error, reason} -> {:error, reason}
    end
  end

  defp ensure_active(%Account{active: true, status: "active"}), do: :ok
  defp ensure_active(%Account{status: "takendown"}), do: {:error, :repo_takendown}
  defp ensure_active(%Account{status: "suspended"}), do: {:error, :repo_suspended}
  defp ensure_active(%Account{status: "deactivated"}), do: {:error, :repo_deactivated}
  defp ensure_active(%Account{status: "deleted"}), do: {:error, :repo_not_found}
  defp ensure_active(%Account{}), do: {:error, :repo_not_found}

  defp repo_status(%Account{} = account) do
    response = %{did: account.did, active: account.active and account.status == "active"}

    cond do
      response.active ->
        with {:ok, latest} <- RepoStorage.latest_commit(account.did) do
          {:ok, Map.put(response, :rev, latest.rev)}
        end

      account.status in ["active", nil] ->
        {:ok, response}

      true ->
        {:ok, Map.put(response, :status, account.status)}
    end
  end
end
