defmodule Tempest.Xrpc.Sync do
  @moduledoc """
  Handlers for `com.atproto.sync.*` XRPC methods.
  """

  alias Tempest.Sync

  def get_repo(_conn, params, _method) do
    case Sync.get_repo(params) do
      {:ok, bytes} -> {:ok, bytes}
      {:error, reason} -> sync_error(reason)
    end
  end

  def get_latest_commit(_conn, params, _method) do
    case Sync.get_latest_commit(params) do
      {:ok, response} -> {:ok, response}
      {:error, reason} -> sync_error(reason)
    end
  end

  def get_record(_conn, params, _method) do
    case Sync.get_record(params) do
      {:ok, bytes} -> {:ok, bytes}
      {:error, reason} -> sync_error(reason)
    end
  end

  def get_blocks(_conn, params, _method) do
    case Sync.get_blocks(params) do
      {:ok, bytes} -> {:ok, bytes}
      {:error, reason} -> sync_error(reason)
    end
  end

  def get_repo_status(_conn, params, _method) do
    case Sync.get_repo_status(params) do
      {:ok, response} -> {:ok, response}
      {:error, reason} -> sync_error(reason)
    end
  end

  def list_repos(_conn, params, _method) do
    case Sync.list_repos(params) do
      {:ok, response} -> {:ok, response}
      {:error, reason} -> sync_error(reason)
    end
  end

  def list_blobs(_conn, params, _method) do
    case Sync.list_blobs(params) do
      {:ok, response} -> {:ok, response}
      {:error, reason} -> sync_error(reason)
    end
  end

  def get_blob(_conn, params, _method) do
    case Sync.get_blob(params) do
      {:ok, response} -> {:ok, response}
      {:error, reason} -> sync_error(reason)
    end
  end

  def request_crawl(_conn, params, _method) do
    case Sync.request_crawl(params) do
      {:ok, response} -> {:ok, response}
      {:error, reason} -> sync_error(reason)
    end
  end

  defp sync_error(:repo_not_found), do: {:error, 400, "RepoNotFound", "repository could not be found"}
  defp sync_error(:repo_takendown), do: {:error, 400, "RepoTakendown", "repository is taken down"}
  defp sync_error(:repo_suspended), do: {:error, 400, "RepoSuspended", "repository is suspended"}
  defp sync_error(:repo_deactivated), do: {:error, 400, "RepoDeactivated", "repository is deactivated"}
  defp sync_error(:record_not_found), do: {:error, 400, "RecordNotFound", "record could not be found"}
  defp sync_error(:block_not_found), do: {:error, 400, "BlockNotFound", "block could not be found"}
  defp sync_error(:blob_not_found), do: {:error, 400, "BlobNotFound", "blob could not be found"}
  defp sync_error(:commit_not_found), do: {:error, 400, "InvalidRequest", "commit could not be found"}
  defp sync_error(:invalid_did), do: {:error, 400, "InvalidRequest", "did is invalid"}
  defp sync_error(:invalid_collection), do: {:error, 400, "InvalidRequest", "collection is invalid"}
  defp sync_error(:invalid_rkey), do: {:error, 400, "InvalidRequest", "rkey is invalid"}
  defp sync_error(:invalid_commit), do: {:error, 400, "InvalidRequest", "commit is invalid"}
  defp sync_error(:invalid_cids), do: {:error, 400, "InvalidRequest", "cids must include 1 to 100 valid CIDs"}
  defp sync_error(:invalid_cid), do: {:error, 400, "InvalidRequest", "cid is invalid"}
  defp sync_error(:invalid_limit), do: {:error, 400, "InvalidRequest", "limit must be between 1 and 1000"}
  defp sync_error(:invalid_cursor), do: {:error, 400, "InvalidRequest", "cursor is invalid"}
  defp sync_error(:invalid_hostname), do: {:error, 400, "InvalidRequest", "hostname is invalid"}
  defp sync_error(:rate_limited), do: {:error, 429, "RateLimitExceeded", "requestCrawl is rate limited"}
  defp sync_error({:relay_status, _status}), do: {:error, 502, "UpstreamFailure", "relay request failed"}
  defp sync_error({:relay_request_failed, _reason}), do: {:error, 502, "UpstreamFailure", "relay request failed"}

  defp sync_error({:missing_field, field}), do: {:error, 400, "InvalidRequest", "#{field} is required"}
  defp sync_error(_reason), do: {:error, 500, "InternalServerError", "sync read failed"}
end
