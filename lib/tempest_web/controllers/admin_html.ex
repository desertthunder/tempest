defmodule TempestWeb.AdminHTML do
  use TempestWeb, :html

  embed_templates "admin_html/*"

  def admin_nav(assigns) do
    ~H"""
    <nav class="resource-strip operator-account__nav" aria-label="Admin tools">
      <a href={~p"/admin"}>Dashboard</a>
      <a href={~p"/admin/invites"}>Invites</a>
      <a href={~p"/admin/repo"}>Repo Ops</a>
      <a href={~p"/admin/backups"}>Backups</a>
      <a href={~p"/admin/storage"}>Storage</a>
      <a href={~p"/admin/compatibility"}>Compatibility</a>
    </nav>
    """
  end

  def present(nil), do: "—"
  def present(value) when is_boolean(value), do: inspect(value)
  def present(value), do: to_string(value)

  def json_pretty(value), do: Jason.encode!(value, pretty: true)
end
