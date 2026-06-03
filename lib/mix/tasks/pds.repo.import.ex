defmodule Mix.Tasks.Pds.Repo.Import do
  @moduledoc """
  Imports a verified repository CAR for an existing account.

      mix pds.repo.import --did did:plc:... --input /tmp/repo.car
  """

  use Mix.Task

  @shortdoc "Imports a repository CAR for an account"

  @impl true
  def run(args) do
    Mix.Task.run("app.start")
    {opts, _argv, _invalid} = OptionParser.parse(args, strict: [did: :string, input: :string])
    did = Keyword.get(opts, :did) || List.first(args)
    input = Keyword.get(opts, :input) || Enum.at(args, 1)

    unless did && input, do: Mix.raise("usage: mix pds.repo.import --did DID --input PATH")

    case Tempest.Admin.RepoOps.import(did, input) do
      {:ok, result} ->
        Mix.shell().info(
          "imported did=#{did} cid=#{result["cid"]} rev=#{result["rev"]} records=#{result["recordCount"]}"
        )

      {:error, reason} ->
        Mix.raise("repo import failed: #{inspect(reason)}")
    end
  end
end
