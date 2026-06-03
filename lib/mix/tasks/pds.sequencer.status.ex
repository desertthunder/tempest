defmodule Mix.Tasks.Pds.Sequencer.Status do
  @moduledoc """
  Prints durable sequencer status.

      mix pds.sequencer.status
  """

  use Mix.Task

  @shortdoc "Prints sequencer status"

  @impl true
  def run(_args) do
    Mix.Task.run("app.start")

    with {:ok, current_seq} <- Tempest.Sequencer.current_seq(),
         {:ok, torn_write_count} <- Tempest.Sequencer.torn_write_count() do
      Mix.shell().info("currentSeq=#{current_seq} tornWriteCount=#{torn_write_count}")
    else
      {:error, reason} -> Mix.raise("sequencer status failed: #{inspect(reason)}")
    end
  end
end
