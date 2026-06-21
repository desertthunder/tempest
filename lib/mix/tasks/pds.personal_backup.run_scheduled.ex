defmodule Mix.Tasks.Pds.PersonalBackup.RunScheduled do
  @moduledoc """
  Runs at most one due scheduled personal backup.

      mix pds.personal_backup.run_scheduled
  """

  use Mix.Task

  @shortdoc "Runs one due scheduled personal backup"

  @impl true
  def run(_args) do
    Mix.Task.run("app.start")

    case Tempest.PersonalBackups.run_due_scheduled_backups() do
      {:ok, :none_due} ->
        Mix.shell().info("scheduledBackup=none_due")

      {:ok, %{account: account, snapshot: snapshot, run: run}} ->
        Mix.shell().info(
          "scheduledBackup=ran did=#{account.did} runId=#{run.id} snapshotId=#{snapshot.id} nextAt=#{account.next_scheduled_backup_at}"
        )

      {:error, reason} ->
        Mix.raise("scheduled personal backup failed: #{inspect(reason)}")
    end
  end
end
