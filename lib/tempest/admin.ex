defmodule Tempest.Admin do
  @moduledoc """
  Operator-facing status and maintenance helpers.
  """

  import Ecto.Query

  alias Tempest.Accounts.Account
  alias Tempest.{Blobs, Config, Repo, RepoStorage, Sequencer, Storage}

  @compatibility_methods ~w(
    com.atproto.server.describeServer com.atproto.server.createAccount com.atproto.server.createSession
    com.atproto.server.refreshSession com.atproto.server.deleteSession com.atproto.server.getSession
    com.atproto.server.createAppPassword com.atproto.server.listAppPasswords com.atproto.server.revokeAppPassword
    com.atproto.server.getServiceAuth com.atproto.server.checkAccountStatus com.atproto.server.activateAccount
    com.atproto.server.deactivateAccount com.atproto.server.requestAccountDelete com.atproto.server.deleteAccount
    com.atproto.server.requestPasswordReset com.atproto.server.resetPassword com.atproto.server.confirmEmail
    com.atproto.server.requestEmailConfirmation com.atproto.server.requestEmailUpdate com.atproto.server.updateEmail
    com.atproto.server.reserveSigningKey com.atproto.identity.resolveHandle com.atproto.identity.updateHandle
    com.atproto.identity.getRecommendedDidCredentials com.atproto.identity.requestPlcOperationSignature
    com.atproto.identity.signPlcOperation com.atproto.identity.submitPlcOperation com.atproto.repo.createRecord
    com.atproto.repo.putRecord com.atproto.repo.deleteRecord com.atproto.repo.applyWrites com.atproto.repo.getRecord
    com.atproto.repo.listRecords com.atproto.repo.describeRepo com.atproto.repo.uploadBlob
    com.atproto.repo.listMissingBlobs com.atproto.repo.importRepo com.atproto.sync.getRepo
    com.atproto.sync.getBlocks com.atproto.sync.getRecord com.atproto.sync.getLatestCommit
    com.atproto.sync.getRepoStatus com.atproto.sync.listRepos com.atproto.sync.listBlobs
    com.atproto.sync.getBlob com.atproto.sync.requestCrawl com.atproto.sync.subscribeRepos
    com.atproto.sync.notifyOfUpdate app.bsky.actor.getPreferences app.bsky.actor.putPreferences
  )

  @partial_methods ~w(
    com.atproto.server.requestPasswordReset com.atproto.server.resetPassword com.atproto.server.confirmEmail
    com.atproto.server.requestEmailConfirmation com.atproto.server.requestEmailUpdate com.atproto.server.updateEmail
  )

  @deferred_methods ~w(com.atproto.sync.notifyOfUpdate)

  @doc """
  Returns admin-visible service status.
  """
  def status(%Config{} = config \\ Config.load!()) do
    env = Application.get_env(:tempest, :env, :prod)
    accounts = account_summaries(config)

    %{
      "status" => "ok",
      "version" => Tempest.version(),
      "admin" => admin_status(),
      "storage" => Storage.health(config, env),
      "database" => database_status(config),
      "sequencer" => sequencer_status(),
      "blobStore" => blob_store_status(config, accounts),
      "accounts" => accounts
    }
  end

  defp admin_status do
    {did, method} =
      case Tempest.AdminAuth.auth_method() do
        {:ok, %{did: did, method: method}} -> {did, Atom.to_string(method)}
        {:error, reason} -> {nil, Atom.to_string(reason)}
      end

    %{"did" => did, "authMethod" => method, "tokenConfigured" => Tempest.AdminAuth.configured?()}
  end

  def compatibility_status do
    endpoints = Enum.map(@compatibility_methods, &compatibility_endpoint/1)

    %{
      endpoints: endpoints,
      summary: Enum.frequencies_by(endpoints, & &1.status),
      notes: [
        "Unknown app.bsky.* methods use the configured proxy/fallback policy.",
        "Status is route-based and should be read with the smoke-test matrix."
      ]
    }
  end

  defp compatibility_endpoint(method) do
    %{
      method: method,
      status: compatibility_status_for(method),
      route: if(method == "com.atproto.sync.subscribeRepos", do: "websocket", else: "xrpc")
    }
  end

  defp compatibility_status_for(method) when method in @partial_methods, do: "partial"
  defp compatibility_status_for(method) when method in @deferred_methods, do: "deferred"

  defp compatibility_status_for(method) do
    case Tempest.Xrpc.Registry.fetch(method) do
      {:ok, _method} -> "implemented"
      {:error, _reason} -> "planned"
    end
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
