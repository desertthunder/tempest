defmodule Mix.Tasks.Tempest.Storage.Setup do
  @moduledoc """
  Creates Tempest's SQLite data directory layout.
  """

  use Mix.Task

  @shortdoc "Creates Tempest SQLite storage files and directories"

  @impl true
  def run(_args) do
    Mix.Task.run("app.config")

    Tempest.Config.load!()
    |> Tempest.Storage.bootstrap!()
  end
end
