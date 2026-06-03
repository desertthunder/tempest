defmodule Mix.Tasks.Pds.Backup.Restore do
  @moduledoc """
  Restores a local Tempest backup directory.

      mix pds.backup.restore --input /path/to/backup-dir --target /path/to/data-dir [--force]
  """

  use Mix.Task

  @shortdoc "Restores a local backup"

  @impl true
  def run(args) do
    Mix.Task.run("app.config")
    {opts, _argv, _invalid} = OptionParser.parse(args, strict: [input: :string, target: :string, force: :boolean])
    input = Keyword.get(opts, :input) || List.first(args)
    target = Keyword.get(opts, :target)
    force? = Keyword.get(opts, :force, false)

    unless input, do: Mix.raise("usage: mix pds.backup.restore --input BACKUP_DIR [--target DATA_DIR] [--force]")

    restore_opts = [force?: force?]
    restore_opts = if target, do: Keyword.put(restore_opts, :target, target), else: restore_opts

    case Tempest.Admin.Backup.restore(input, restore_opts) do
      {:ok, result} -> Mix.shell().info("restoredDataDir=#{result.path}")
      {:error, :target_not_empty} -> Mix.raise("backup restore refused to overwrite target without --force")
      {:error, reason} -> Mix.raise("backup restore failed: #{inspect(reason)}")
    end
  end
end
