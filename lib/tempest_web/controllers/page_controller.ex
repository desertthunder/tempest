defmodule TempestWeb.PageController do
  use TempestWeb, :controller

  def home(conn, _params) do
    render(conn, :home,
      host: conn.host,
      app_version: Application.spec(:tempest, :vsn),
      rendered_at: rendered_at()
    )
  end

  defp rendered_at do
    DateTime.utc_now()
    |> Calendar.strftime("%Y-%m-%d %H:%M:%SZ")
  end
end
