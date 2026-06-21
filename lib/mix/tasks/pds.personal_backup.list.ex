defmodule Mix.Tasks.Pds.PersonalBackup.List do
  @moduledoc """
  Lists personal backup snapshots.

      mix pds.personal_backup.list [--did did:plc:...]
  """

  use Mix.Task

  @shortdoc "Lists personal backup snapshots"

  @impl true
  def run(args) do
    Mix.Task.run("app.start")
    {opts, _argv, _invalid} = OptionParser.parse(args, strict: [did: :string])

    opts
    |> Keyword.take([:did])
    |> Tempest.PersonalBackups.list_snapshots()
    |> Enum.each(fn snapshot ->
      completed_at = snapshot.completed_at && DateTime.to_iso8601(snapshot.completed_at)

      Mix.shell().info(
        "snapshotId=#{snapshot.id} did=#{snapshot.did} status=#{snapshot.status} verification=#{snapshot.verification_status} completedAt=#{completed_at} storageKey=#{snapshot.storage_key}"
      )
    end)
  end
end
