defmodule Mix.Tasks.Pds.Backup.Create do
  @moduledoc """
  Creates a local Tempest backup directory.

      mix pds.backup.create [--output /path/to/backup-dir] [--upload-s3]
  """

  use Mix.Task

  @shortdoc "Creates a local backup"

  @impl true
  def run(args) do
    Mix.Task.run("app.start")
    {opts, _argv, _invalid} = OptionParser.parse(args, strict: [output: :string, upload_s3: :boolean])
    path = Keyword.get(opts, :output)
    upload? = Keyword.get(opts, :upload_s3, false)

    create_opts = [upload?: upload?]
    create_opts = if path, do: Keyword.put(create_opts, :path, path), else: create_opts

    case Tempest.Admin.Backup.create(create_opts) do
      {:ok, result} ->
        Mix.shell().info("backupPath=#{result.path}")
        if result.upload, do: Mix.shell().info("backupUploadKey=#{result.upload.key} bytes=#{result.upload.bytes}")

      {:error, reason} ->
        Mix.raise("backup create failed: #{inspect(reason)}")
    end
  end
end
