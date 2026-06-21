defmodule Mix.Tasks.Pds.PersonalBackup.Status do
  @moduledoc """
  Shows personal backup status for a registered external account.

      mix pds.personal_backup.status --did did:plc:...
  """

  use Mix.Task

  @shortdoc "Shows personal backup account status"

  @impl true
  def run(args) do
    Mix.Task.run("app.start")
    {opts, _argv, _invalid} = OptionParser.parse(args, strict: [did: :string])
    did = Keyword.get(opts, :did) || List.first(args)

    unless did, do: Mix.raise("usage: mix pds.personal_backup.status --did DID")

    status =
      did
      |> account_by_did!()
      |> Tempest.PersonalBackups.account_backup_status()

    latest_snapshot = status.latest_snapshot
    latest_run = status.latest_run

    Mix.shell().info(
      "did=#{status.account.did} handle=#{status.account.handle} status=#{status.account.status} credential=#{status.account.credential_state} snapshots=#{status.snapshot_count} storedBlobs=#{status.stored_blob_count}"
    )

    if latest_snapshot do
      Mix.shell().info(
        "latestSnapshotId=#{latest_snapshot.id} snapshotStatus=#{latest_snapshot.status} verification=#{latest_snapshot.verification_status} storageKey=#{latest_snapshot.storage_key}"
      )
    end

    if latest_run do
      Mix.shell().info("latestRunId=#{latest_run.id} runStatus=#{latest_run.status} kind=#{latest_run.kind}")
    end
  end

  defp account_by_did!(did) do
    Tempest.PersonalBackups.get_account_by_did(did) ||
      Mix.raise("unknown personal backup account did=#{did}")
  end
end
