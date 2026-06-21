defmodule Mix.Tasks.Pds.PersonalBackup.Export do
  @moduledoc """
  Exports a personal backup snapshot as a portable zip bundle.

      mix pds.personal_backup.export --snapshot-id 123 --output /path/to/snapshot.zip
  """

  use Mix.Task

  @shortdoc "Exports a personal backup snapshot bundle"

  @impl true
  def run(args) do
    Mix.Task.run("app.start")
    {opts, _argv, _invalid} = OptionParser.parse(args, strict: [snapshot_id: :integer, output: :string])
    snapshot_id = Keyword.get(opts, :snapshot_id)

    unless snapshot_id, do: Mix.raise("usage: mix pds.personal_backup.export --snapshot-id ID [--output PATH]")

    snapshot = Tempest.PersonalBackups.get_snapshot!(snapshot_id)
    export_opts = if output = Keyword.get(opts, :output), do: [path: output], else: []

    case Tempest.PersonalBackups.export_snapshot_bundle(snapshot, export_opts) do
      {:ok, result} ->
        Mix.shell().info("exportPath=#{result.path} bytes=#{result.byte_size}")

      {:error, reason} ->
        Mix.raise("personal backup export failed: #{inspect(reason)}")
    end
  end
end
