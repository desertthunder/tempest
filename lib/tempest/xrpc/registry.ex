defmodule Tempest.Xrpc.Registry do
  @moduledoc """
  Registry for the XRPC methods exposed by Tempest.
  """

  alias Tempest.Xrpc.Method

  @json "application/json"
  @car "application/vnd.ipld.car"
  @blob "application/octet-stream"

  @methods [
    %Method{
      nsid: "com.atproto.server.describeServer",
      kind: :query,
      auth: :none,
      input: nil,
      output: @json,
      handler: {Tempest.Xrpc.Server, :describe_server},
      errors: []
    },
    %Method{
      nsid: "com.atproto.server.createAccount",
      kind: :procedure,
      auth: :none,
      input: @json,
      output: @json,
      handler: {Tempest.Xrpc.Server, :create_account},
      errors: ["InvalidInviteCode", "HandleNotAvailable"]
    },
    %Method{
      nsid: "com.atproto.server.createSession",
      kind: :procedure,
      auth: :none,
      input: @json,
      output: @json,
      handler: {Tempest.Xrpc.Server, :create_session},
      errors: ["AuthenticationRequired", "AccountTakedown"]
    },
    %Method{
      nsid: "com.atproto.server.refreshSession",
      kind: :procedure,
      auth: :bearer,
      input: nil,
      output: @json,
      handler: {Tempest.Xrpc.Server, :refresh_session},
      errors: ["ExpiredToken", "InvalidToken"]
    },
    %Method{
      nsid: "com.atproto.server.deleteSession",
      kind: :procedure,
      auth: :bearer,
      input: nil,
      output: @json,
      handler: {Tempest.Xrpc.Server, :delete_session},
      errors: ["ExpiredToken", "InvalidToken"]
    },
    %Method{
      nsid: "com.atproto.server.getSession",
      kind: :query,
      auth: :bearer,
      input: nil,
      output: @json,
      handler: {Tempest.Xrpc.Server, :get_session},
      errors: ["ExpiredToken", "InvalidToken"]
    },
    %Method{
      nsid: "com.atproto.identity.resolveHandle",
      kind: :query,
      auth: :none,
      input: nil,
      output: @json,
      handler: {Tempest.Xrpc.Identity, :resolve_handle},
      errors: ["HandleNotFound"]
    },
    %Method{
      nsid: "com.atproto.identity.updateHandle",
      kind: :procedure,
      auth: :bearer,
      input: @json,
      output: @json,
      handler: {Tempest.Xrpc.Identity, :update_handle},
      errors: ["HandleNotFound", "InvalidRequest"]
    },
    %Method{
      nsid: "com.atproto.repo.createRecord",
      kind: :procedure,
      auth: :bearer,
      input: @json,
      output: @json,
      handler: {Tempest.Xrpc.Repo, :create_record},
      errors: ["InvalidSwap"]
    },
    %Method{
      nsid: "com.atproto.repo.putRecord",
      kind: :procedure,
      auth: :bearer,
      input: @json,
      output: @json,
      handler: {Tempest.Xrpc.Repo, :put_record},
      errors: ["InvalidSwap"]
    },
    %Method{
      nsid: "com.atproto.repo.deleteRecord",
      kind: :procedure,
      auth: :bearer,
      input: @json,
      output: @json,
      handler: {Tempest.Xrpc.Repo, :delete_record},
      errors: ["InvalidSwap"]
    },
    %Method{
      nsid: "com.atproto.repo.getRecord",
      kind: :query,
      auth: :none,
      input: nil,
      output: @json,
      handler: {Tempest.Xrpc.Repo, :get_record},
      errors: ["RecordNotFound"]
    },
    %Method{
      nsid: "com.atproto.repo.listRecords",
      kind: :query,
      auth: :none,
      input: nil,
      output: @json,
      handler: {Tempest.Xrpc.Repo, :list_records},
      errors: []
    },
    %Method{
      nsid: "com.atproto.repo.describeRepo",
      kind: :query,
      auth: :none,
      input: nil,
      output: @json,
      handler: {Tempest.Xrpc.Repo, :describe_repo},
      errors: []
    },
    %Method{
      nsid: "com.atproto.repo.uploadBlob",
      kind: :procedure,
      auth: :bearer,
      input: @blob,
      output: @json,
      handler: {Tempest.Xrpc.NotImplemented, :handle},
      errors: ["BlobTooLarge"]
    },
    %Method{
      nsid: "com.atproto.sync.getRepo",
      kind: :query,
      auth: :none,
      input: nil,
      output: @car,
      handler: {Tempest.Xrpc.Sync, :get_repo},
      errors: ["RepoNotFound"]
    },
    %Method{
      nsid: "com.atproto.sync.getLatestCommit",
      kind: :query,
      auth: :none,
      input: nil,
      output: @json,
      handler: {Tempest.Xrpc.Sync, :get_latest_commit},
      errors: ["RepoNotFound"]
    },
    %Method{
      nsid: "com.atproto.sync.getBlocks",
      kind: :query,
      auth: :none,
      input: nil,
      output: @car,
      handler: {Tempest.Xrpc.Sync, :get_blocks},
      errors: ["RepoNotFound", "BlockNotFound"]
    },
    %Method{
      nsid: "com.atproto.sync.getRecord",
      kind: :query,
      auth: :none,
      input: nil,
      output: @car,
      handler: {Tempest.Xrpc.Sync, :get_record},
      errors: ["RecordNotFound", "RepoNotFound"]
    },
    %Method{
      nsid: "com.atproto.sync.listRepos",
      kind: :query,
      auth: :none,
      input: nil,
      output: @json,
      handler: {Tempest.Xrpc.Sync, :list_repos},
      errors: []
    },
    %Method{
      nsid: "com.atproto.sync.getRepoStatus",
      kind: :query,
      auth: :none,
      input: nil,
      output: @json,
      handler: {Tempest.Xrpc.Sync, :get_repo_status},
      errors: ["RepoNotFound"]
    },
    %Method{
      nsid: "com.atproto.sync.listBlobs",
      kind: :query,
      auth: :none,
      input: nil,
      output: @json,
      handler: {Tempest.Xrpc.Sync, :list_blobs},
      errors: ["RepoNotFound"]
    },
    %Method{
      nsid: "com.atproto.sync.requestCrawl",
      kind: :procedure,
      auth: :none,
      input: @json,
      output: @json,
      handler: {Tempest.Xrpc.Sync, :request_crawl},
      errors: []
    },
    %Method{
      nsid: "com.atproto.sync.subscribeRepos",
      kind: :subscription,
      auth: :none,
      input: nil,
      output: "application/vnd.atproto.eventstream",
      handler: {TempestWeb.FirehoseController, :subscribe_repos},
      errors: []
    }
  ]

  @methods_by_nsid Map.new(@methods, &{&1.nsid, &1})

  @doc """
  Returns all registered XRPC methods.
  """
  def all, do: @methods

  @doc """
  Fetches a registered XRPC method by NSID.
  """
  def fetch(nsid) when is_binary(nsid) do
    case Map.fetch(@methods_by_nsid, nsid) do
      {:ok, method} -> {:ok, method}
      :error -> {:error, :not_found}
    end
  end
end
