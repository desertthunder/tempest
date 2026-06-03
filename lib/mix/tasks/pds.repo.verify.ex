defmodule Mix.Tasks.Pds.Repo.Verify do
  @moduledoc """
  Verifies a hosted repository CAR export.

      mix pds.repo.verify --did did:plc:...
  """

  use Mix.Task

  @shortdoc "Verifies a hosted repository"

  @impl true
  def run(args) do
    Mix.Task.run("app.start")
    {opts, _argv, _invalid} = OptionParser.parse(args, strict: [did: :string])
    did = Keyword.get(opts, :did) || List.first(args)

    unless did, do: Mix.raise("usage: mix pds.repo.verify --did DID")

    case Tempest.Admin.RepoOps.verify(did) do
      {:ok, result} ->
        Mix.shell().info(
          "repo ok did=#{result.did} root=#{result.root} rev=#{result.rev} records=#{result.record_count} blocks=#{result.block_count}"
        )

      {:error, reason} ->
        Mix.raise("repo verify failed: #{inspect(reason)}")
    end
  end
end
