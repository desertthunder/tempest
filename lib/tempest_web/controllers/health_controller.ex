defmodule TempestWeb.HealthController do
  use TempestWeb, :controller

  alias Tempest.PublicStats

  def show(conn, _params) do
    config = Tempest.Config.load!()
    env = Application.get_env(:tempest, :env, :prod)

    json(conn, %{
      status: "ok",
      version: Tempest.version(),
      storage: Tempest.Storage.health(config, env)
    })
  end

  def stats(conn, _params) do
    json(conn, PublicStats.summary())
  end
end
