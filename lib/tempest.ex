defmodule Tempest do
  @moduledoc """
  Tempest keeps the contexts that define your domain
  and business logic.

  Contexts are also responsible for managing your data, regardless
  if it comes from the database, an external API or others.
  """

  @version Mix.Project.config()[:version]
  @git_commit_count (case System.cmd("git", ["rev-list", "--count", "HEAD"], stderr_to_stdout: true) do
                       {count, 0} -> String.trim(count)
                       _ -> "0"
                     end)
  @git_short_sha (case System.cmd("git", ["rev-parse", "--short=7", "HEAD"], stderr_to_stdout: true) do
                    {sha, 0} -> String.trim(sha)
                    _ -> "0000000"
                  end)

  @doc """
  Returns the public Tempest application version.
  """
  def version, do: "v#{@version}.dev#{@git_commit_count}+g#{@git_short_sha}"
end
