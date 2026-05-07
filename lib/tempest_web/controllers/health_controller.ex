defmodule TempestWeb.HealthController do
  use TempestWeb, :controller

  def show(conn, _params) do
    json(conn, %{
      status: "ok",
      version: Tempest.version()
    })
  end
end
