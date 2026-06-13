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
      nsid: "com.atproto.server.checkAccountStatus",
      kind: :query,
      auth: :bearer,
      input: nil,
      output: @json,
      handler: {Tempest.Xrpc.Server, :check_account_status},
      errors: ["ExpiredToken", "InvalidToken"]
    },
    %Method{
      nsid: "com.atproto.server.getServiceAuth",
      kind: :query,
      auth: :bearer,
      input: nil,
      output: @json,
      handler: {Tempest.Xrpc.Server, :get_service_auth},
      errors: ["ExpiredToken", "InvalidToken", "InvalidRequest"]
    },
    %Method{
      nsid: "com.atproto.server.reserveSigningKey",
      kind: :procedure,
      auth: :bearer,
      input: @json,
      output: @json,
      handler: {Tempest.Xrpc.Server, :reserve_signing_key},
      errors: ["ExpiredToken", "InvalidToken"]
    },
    %Method{
      nsid: "com.atproto.server.activateAccount",
      kind: :procedure,
      auth: :bearer,
      input: @json,
      output: @json,
      handler: {Tempest.Xrpc.Server, :activate_account},
      errors: ["ExpiredToken", "InvalidToken", "InvalidRequest"]
    },
    %Method{
      nsid: "com.atproto.server.deactivateAccount",
      kind: :procedure,
      auth: :bearer,
      input: @json,
      output: @json,
      handler: {Tempest.Xrpc.Server, :deactivate_account},
      errors: ["ExpiredToken", "InvalidToken"]
    },
    %Method{
      nsid: "com.atproto.server.requestAccountDelete",
      kind: :procedure,
      auth: :bearer,
      input: @json,
      output: @json,
      handler: {Tempest.Xrpc.Server, :request_account_delete},
      errors: ["ExpiredToken", "InvalidToken"]
    },
    %Method{
      nsid: "com.atproto.server.deleteAccount",
      kind: :procedure,
      auth: :bearer,
      input: @json,
      output: @json,
      handler: {Tempest.Xrpc.Server, :delete_account},
      errors: ["ExpiredToken", "InvalidToken"]
    },
    %Method{
      nsid: "com.atproto.server.listAppPasswords",
      kind: :query,
      auth: :bearer,
      input: nil,
      output: @json,
      handler: {Tempest.Xrpc.Server, :list_app_passwords},
      errors: ["ExpiredToken", "InvalidToken"]
    },
    %Method{
      nsid: "com.atproto.server.createAppPassword",
      kind: :procedure,
      auth: :bearer,
      input: @json,
      output: @json,
      handler: {Tempest.Xrpc.Server, :create_app_password},
      errors: ["ExpiredToken", "InvalidToken"]
    },
    %Method{
      nsid: "com.atproto.server.revokeAppPassword",
      kind: :procedure,
      auth: :bearer,
      input: @json,
      output: @json,
      handler: {Tempest.Xrpc.Server, :revoke_app_password},
      errors: ["ExpiredToken", "InvalidToken"]
    },
    %Method{
      nsid: "com.atproto.server.requestPasswordReset",
      kind: :procedure,
      auth: :none,
      input: @json,
      output: @json,
      handler: {Tempest.Xrpc.Server, :request_password_reset},
      errors: ["InvalidRequest"]
    },
    %Method{
      nsid: "com.atproto.server.resetPassword",
      kind: :procedure,
      auth: :none,
      input: @json,
      output: @json,
      handler: {Tempest.Xrpc.Server, :reset_password},
      errors: ["InvalidRequest"]
    },
    %Method{
      nsid: "com.atproto.server.requestEmailConfirmation",
      kind: :procedure,
      auth: :bearer,
      input: @json,
      output: @json,
      handler: {Tempest.Xrpc.Server, :request_email_confirmation},
      errors: ["ExpiredToken", "InvalidToken"]
    },
    %Method{
      nsid: "com.atproto.server.confirmEmail",
      kind: :procedure,
      auth: :none,
      input: @json,
      output: @json,
      handler: {Tempest.Xrpc.Server, :confirm_email},
      errors: ["InvalidRequest"]
    },
    %Method{
      nsid: "com.atproto.server.requestEmailUpdate",
      kind: :procedure,
      auth: :bearer,
      input: @json,
      output: @json,
      handler: {Tempest.Xrpc.Server, :request_email_update},
      errors: ["ExpiredToken", "InvalidToken", "InvalidRequest"]
    },
    %Method{
      nsid: "com.atproto.server.updateEmail",
      kind: :procedure,
      auth: :none,
      input: @json,
      output: @json,
      handler: {Tempest.Xrpc.Server, :update_email},
      errors: ["InvalidRequest"]
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
      nsid: "com.atproto.identity.getRecommendedDidCredentials",
      kind: :query,
      auth: :bearer,
      input: nil,
      output: @json,
      handler: {Tempest.Xrpc.Identity, :get_recommended_did_credentials},
      errors: ["InvalidRequest"]
    },
    %Method{
      nsid: "com.atproto.identity.requestPlcOperationSignature",
      kind: :procedure,
      auth: :bearer,
      input: @json,
      output: @json,
      handler: {Tempest.Xrpc.Identity, :request_plc_operation_signature},
      errors: ["AuthenticationRequired", "InvalidRequest"]
    },
    %Method{
      nsid: "com.atproto.identity.signPlcOperation",
      kind: :procedure,
      auth: :bearer,
      input: @json,
      output: @json,
      handler: {Tempest.Xrpc.Identity, :sign_plc_operation},
      errors: ["AuthenticationRequired", "InvalidRequest"]
    },
    %Method{
      nsid: "com.atproto.identity.submitPlcOperation",
      kind: :procedure,
      auth: :bearer,
      input: @json,
      output: @json,
      handler: {Tempest.Xrpc.Identity, :submit_plc_operation},
      errors: ["InvalidRequest", "UpstreamFailure"]
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
      nsid: "com.atproto.repo.applyWrites",
      kind: :procedure,
      auth: :bearer,
      input: @json,
      output: @json,
      handler: {Tempest.Xrpc.Repo, :apply_writes},
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
      nsid: "com.atproto.repo.listMissingBlobs",
      kind: :query,
      auth: :bearer,
      input: nil,
      output: @json,
      handler: {Tempest.Xrpc.Repo, :list_missing_blobs},
      errors: ["ExpiredToken", "InvalidToken"]
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
      handler: {Tempest.Xrpc.Repo, :upload_blob},
      errors: ["BlobTooLarge"]
    },
    %Method{
      nsid: "com.atproto.repo.importRepo",
      kind: :procedure,
      auth: :bearer,
      input: @car,
      output: @json,
      handler: {Tempest.Xrpc.Repo, :import_repo},
      errors: ["InvalidRequest"]
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
      nsid: "com.atproto.sync.getBlob",
      kind: :query,
      auth: :none,
      input: nil,
      output: @blob,
      handler: {Tempest.Xrpc.Sync, :get_blob},
      errors: ["RepoNotFound", "BlobNotFound"]
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
    },
    %Method{
      nsid: "app.bsky.actor.getPreferences",
      kind: :query,
      auth: :bearer,
      input: nil,
      output: @json,
      handler: {Tempest.Xrpc.Actor, :get_preferences},
      errors: []
    },
    %Method{
      nsid: "app.bsky.actor.putPreferences",
      kind: :procedure,
      auth: :bearer,
      input: @json,
      output: @json,
      handler: {Tempest.Xrpc.Actor, :put_preferences},
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
