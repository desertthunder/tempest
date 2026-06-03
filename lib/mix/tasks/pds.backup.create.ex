defmodule Mix.Tasks.Pds.Backup.Create do
  @moduledoc """
  Creates a local Tempest backup directory.

      mix pds.backup.create [--output /path/to/backup-dir]
  """

  use Mix.Task

  @shortdoc "Creates a local backup"

  @impl true
  def run(args) do
    Mix.Task.run("app.start")
    {opts, _argv, _invalid} = OptionParser.parse(args, strict: [output: :string])
    path = Keyword.get(opts, :output)

    opts = if path, do: [path: path], else: []

    case Tempest.Admin.Backup.create(opts) do
      {:ok, result} -> Mix.shell().info("backupPath=#{result.path}")
      {:error, reason} -> Mix.raise("backup create failed: #{inspect(reason)}")
    end
  end
end
