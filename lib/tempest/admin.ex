defmodule Tempest.Admin do
  @moduledoc """
  Operator-facing status and maintenance helpers.
  """

  import Ecto.Query

  alias Tempest.Accounts.Account
  alias Tempest.{Blobs, Config, Repo, RepoStorage, Sequencer, Storage}

  @doc """
  Returns admin-visible service status.
  """
  def status(%Config{} = config \\ Config.load!()) do
    env = Application.get_env(:tempest, :env, :prod)
    accounts = account_summaries(config)

    %{
      "status" => "ok",
      "version" => Tempest.version(),
      "admin" => %{"tokenConfigured" => Tempest.AdminAuth.configured?()},
      "storage" => Storage.health(config, env),
      "database" => database_status(config),
      "sequencer" => sequencer_status(),
      "blobStore" => blob_store_status(config, accounts),
      "accounts" => accounts
    }
  end

  defp database_status(config) do
    %{
      "accountDb" => file_status(Config.account_db_path(config)),
      "sequencerDb" => file_status(Config.sequencer_db_path(config)),
      "repoDir" => file_status(Path.join(config.data_dir, "repos")),
      "blobDir" => file_status(Path.join(config.data_dir, "blobs"))
    }
  end

  defp sequencer_status do
    %{
      "currentSeq" => result_or_nil(Sequencer.current_seq()),
      "tornWriteCount" => result_or_nil(Sequencer.torn_write_count())
    }
  end

  defp blob_store_status(config, accounts) do
    counts = Enum.map(accounts, & &1["blobCount"])

    %{
      "adapter" => blob_adapter_name(),
      "path" => Path.join(config.data_dir, "blobs"),
      "accountCount" => length(accounts),
      "publicBlobCount" => Enum.sum(counts)
    }
  end

  defp account_summaries(config) do
    Account
    |> order_by([a], asc: a.did)
    |> Repo.all()
    |> Enum.map(fn account ->
      repo_counts = ok_or_empty(RepoStorage.status_counts(account.did, config))
      blob_counts = ok_or_empty(Blobs.status_counts(account.did, Map.get(repo_counts, :referenced_blob_cids, [])))

      %{
        "did" => account.did,
        "handle" => account.handle,
        "active" => account.active and account.status == "active",
        "status" => account.status,
        "repoCount" => Map.get(repo_counts, :repo_count, 0),
        "recordCount" => Map.get(repo_counts, :record_count, 0),
        "commitCount" => Map.get(repo_counts, :commit_count, Map.get(repo_counts, :repo_count, 0)),
        "blobCount" => Map.get(blob_counts, :blob_count, 0),
        "missingBlobCount" => Map.get(blob_counts, :missing_blob_count, 0)
      }
    end)
  end

  defp file_status(path) do
    %{
      "path" => path,
      "exists" => File.exists?(path),
      "type" => file_type(path),
      "bytes" => file_size(path)
    }
  end

  defp file_type(path) do
    cond do
      File.dir?(path) -> "directory"
      File.regular?(path) -> "file"
      true -> "missing"
    end
  end

  defp file_size(path) do
    case File.stat(path) do
      {:ok, %{size: size}} -> size
      {:error, _reason} -> nil
    end
  end

  defp result_or_nil({:ok, value}), do: value
  defp result_or_nil({:error, reason}), do: inspect(reason)

  defp ok_or_empty({:ok, map}) when is_map(map), do: map
  defp ok_or_empty(_result), do: %{}

  defp blob_adapter_name do
    :tempest
    |> Application.get_env(Blobs, [])
    |> Keyword.get(:storage_adapter, Tempest.Blobs.LocalStorage)
    |> inspect()
  end
end
