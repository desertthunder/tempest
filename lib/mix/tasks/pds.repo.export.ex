defmodule Mix.Tasks.Pds.Repo.Export do
  @moduledoc """
  Exports a hosted repository to a CAR file.

      mix pds.repo.export --did did:plc:... --output /tmp/repo.car
  """

  use Mix.Task

  @shortdoc "Exports a hosted repository CAR"

  @impl true
  def run(args) do
    Mix.Task.run("app.start")
    {opts, _argv, _invalid} = OptionParser.parse(args, strict: [did: :string, output: :string])
    did = Keyword.get(opts, :did) || List.first(args)
    output = Keyword.get(opts, :output) || Enum.at(args, 1)

    unless did && output, do: Mix.raise("usage: mix pds.repo.export --did DID --output PATH")

    case Tempest.Admin.RepoOps.export(did, output) do
      {:ok, result} ->
        Mix.shell().info("exported did=#{result.did} root=#{result.root} path=#{result.path} bytes=#{result.bytes}")

      {:error, reason} ->
        Mix.raise("repo export failed: #{inspect(reason)}")
    end
  end
end
