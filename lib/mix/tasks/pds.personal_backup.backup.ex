defmodule Mix.Tasks.Pds.PersonalBackup.Backup do
  @moduledoc """
  Creates a personal backup snapshot for a registered external account.

      mix pds.personal_backup.backup --did did:plc:...
  """

  use Mix.Task

  @shortdoc "Creates a personal backup snapshot"

  @impl true
  def run(args) do
    Mix.Task.run("app.start")
    {opts, _argv, _invalid} = OptionParser.parse(args, strict: [did: :string])
    did = Keyword.get(opts, :did) || List.first(args)

    unless did, do: Mix.raise("usage: mix pds.personal_backup.backup --did DID")

    account = account_by_did!(did)

    case Tempest.PersonalBackups.run_manual_backup(account) do
      {:ok, %{snapshot: snapshot, run: run}} ->
        Mix.shell().info(
          "snapshotId=#{snapshot.id} runId=#{run.id} did=#{snapshot.did} status=#{snapshot.status} verification=#{snapshot.verification_status} storageKey=#{snapshot.storage_key}"
        )

      {:error, reason} ->
        Mix.raise("personal backup failed: #{inspect(reason)}")
    end
  end

  defp account_by_did!(did) do
    Tempest.PersonalBackups.get_account_by_did(did) ||
      Mix.raise("unknown personal backup account did=#{did}")
  end
end
