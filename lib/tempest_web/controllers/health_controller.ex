defmodule TempestWeb.HealthController do
  use TempestWeb, :controller

  def show(conn, _params) do
    config = Tempest.Config.load!()
    env = Application.get_env(:tempest, :env, :prod)

    json(conn, %{
      status: "ok",
      version: Tempest.version(),
      storage: Tempest.Storage.health(config, env)
    })
  end
end
