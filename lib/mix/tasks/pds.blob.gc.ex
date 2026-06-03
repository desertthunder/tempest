defmodule Mix.Tasks.Pds.Blob.Gc do
  @moduledoc """
  Removes expired temporary blobs.

      mix pds.blob.gc
  """

  use Mix.Task

  @shortdoc "Runs one blob garbage-collection pass"

  @impl true
  def run(_args) do
    Mix.Task.run("app.start")

    case Tempest.Blobs.GarbageCollector.run_once() do
      {:ok, count} -> Mix.shell().info("deletedExpiredTempBlobs=#{count}")
      {:error, reason} -> Mix.raise("blob gc failed: #{inspect(reason)}")
    end
  end
end
