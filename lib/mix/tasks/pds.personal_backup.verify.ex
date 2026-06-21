defmodule Mix.Tasks.Pds.PersonalBackup.Verify do
  @moduledoc """
  Verifies a personal backup snapshot offline.

      mix pds.personal_backup.verify --snapshot-id 123
      mix pds.personal_backup.verify --path /path/to/snapshot-dir
  """

  use Mix.Task

  @shortdoc "Verifies a personal backup snapshot offline"

  @impl true
  def run(args) do
    Mix.Task.run("app.start")
    {opts, _argv, _invalid} = OptionParser.parse(args, strict: [snapshot_id: :integer, path: :string])

    target =
      cond do
        snapshot_id = Keyword.get(opts, :snapshot_id) -> Tempest.PersonalBackups.get_snapshot!(snapshot_id)
        path = Keyword.get(opts, :path) -> path
        true -> Mix.raise("usage: mix pds.personal_backup.verify --snapshot-id ID | --path DIR")
      end

    case Tempest.PersonalBackups.verify_snapshot_offline(target) do
      {:ok, result} ->
        account = get_in(result.manifest, ["account", "did"])
        repo = get_in(result.manifest, ["repo", "commit"])
        Mix.shell().info("verification=#{result.status} did=#{account} commit=#{repo}")

      {:error, reason} ->
        Mix.raise("personal backup verify failed: #{inspect(reason)}")
    end
  end
end
