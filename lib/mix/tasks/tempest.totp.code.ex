defmodule Mix.Tasks.Tempest.Totp.Code do
  use Mix.Task

  @shortdoc "Generate a TOTP code for a base32 secret"

  @impl Mix.Task
  def run([secret]) do
    Mix.shell().info(Tempest.Security.Totp.code(secret))
  end

  def run(_args) do
    Mix.raise("usage: mix tempest.totp.code <base32-secret>")
  end
end
