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

  def get_repo_status(_conn, params, _method) do
    case Sync.get_repo_status(params) do
      {:ok, response} -> {:ok, response}
      {:error, reason} -> sync_error(reason)
    end
  end

  defp sync_error(:repo_not_found), do: {:error, 400, "RepoNotFound", "repository could not be found"}
  defp sync_error(:repo_takendown), do: {:error, 400, "RepoTakendown", "repository is taken down"}
  defp sync_error(:repo_suspended), do: {:error, 400, "RepoSuspended", "repository is suspended"}
  defp sync_error(:repo_deactivated), do: {:error, 400, "RepoDeactivated", "repository is deactivated"}
  defp sync_error(:record_not_found), do: {:error, 400, "RecordNotFound", "record could not be found"}
  defp sync_error(:invalid_did), do: {:error, 400, "InvalidRequest", "did is invalid"}
  defp sync_error(:invalid_collection), do: {:error, 400, "InvalidRequest", "collection is invalid"}
  defp sync_error(:invalid_rkey), do: {:error, 400, "InvalidRequest", "rkey is invalid"}
  defp sync_error(:invalid_commit), do: {:error, 400, "InvalidRequest", "commit is invalid"}

  defp sync_error(:commit_not_supported),
    do: {:error, 400, "InvalidRequest", "historical commit reads are not supported"}

  defp sync_error({:missing_field, field}), do: {:error, 400, "InvalidRequest", "#{field} is required"}
  defp sync_error(_reason), do: {:error, 500, "InternalServerError", "sync read failed"}
end
