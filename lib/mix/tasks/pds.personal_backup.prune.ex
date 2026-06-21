defmodule Mix.Tasks.Pds.PersonalBackup.Prune do
  @moduledoc """
  Prunes personal backup snapshots according to the account retention policy.

      mix pds.personal_backup.prune --did did:plc:...
  """

  use Mix.Task

  @shortdoc "Prunes personal backup snapshots"

  @impl true
  def run(args) do
    Mix.Task.run("app.start")
    {opts, _argv, _invalid} = OptionParser.parse(args, strict: [did: :string])
    did = Keyword.get(opts, :did) || List.first(args)

    unless did, do: Mix.raise("usage: mix pds.personal_backup.prune --did DID")

    account = account_by_did!(did)

    case Tempest.PersonalBackups.prune_snapshots(account) do
      {:ok, pruned} ->
        Mix.shell().info("prunedSnapshots=#{length(pruned)}")

        Enum.each(pruned, fn snapshot ->
          Mix.shell().info("prunedSnapshotId=#{snapshot.id} storageKey=#{snapshot.storage_key}")
        end)

      {:error, reason} ->
        Mix.raise("personal backup prune failed: #{inspect(reason)}")
    end
  end

  defp account_by_did!(did) do
    Tempest.PersonalBackups.get_account_by_did(did) ||
      Mix.raise("unknown personal backup account did=#{did}")
  end
end
