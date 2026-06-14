defmodule TempestWeb.PageController do
  use TempestWeb, :controller

  alias Tempest.PublicStats

  def home(conn, _params) do
    render(conn, :home,
      host: conn.host,
      app_version: Application.spec(:tempest, :vsn),
      rendered_at: rendered_at()
    )
  end

  def stats(conn, _params) do
    summary = PublicStats.summary()
    health_status = summary["health"]["status"] || "unknown"

    render(conn, :stats,
      summary: summary,
      metrics: summary["metrics"],
      health: summary["health"],
      checks: summary["health"]["checks"],
      health_status: health_status,
      rendered_at: rendered_at()
    )
  end

  defp rendered_at do
    DateTime.utc_now()
    |> Calendar.strftime("%Y-%m-%d %H:%M:%SZ")
  end
end
