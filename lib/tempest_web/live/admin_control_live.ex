defmodule TempestWeb.AdminControlLive do
  use TempestWeb, :live_view

  alias Tempest.Admin
  alias TempestWeb.AdminHTML

  @impl true
  def mount(_params, _session, socket), do: {:ok, assign(socket, :page_title, "Admin Control Panel")}

  @impl true
  def handle_params(_params, _uri, socket) do
    {:noreply, assign_action_data(socket)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      {render_admin_page(assigns)}
    </Layouts.app>
    """
  end

  defp assign_action_data(%{assigns: %{live_action: :dashboard}} = socket) do
    socket
    |> assign(:status, Admin.status())
    |> assign(:page_title, "Admin Dashboard")
  end

  defp assign_action_data(%{assigns: %{live_action: :invites}} = socket) do
    socket
    |> assign(:status, Admin.status())
    |> assign(:page_title, "Admin Invites")
  end

  defp assign_action_data(%{assigns: %{live_action: :repo}} = socket) do
    socket
    |> assign(:result, nil)
    |> assign(:page_title, "Admin Repo")
  end

  defp assign_action_data(%{assigns: %{live_action: :backups}} = socket) do
    socket
    |> assign(:result, nil)
    |> assign(:page_title, "Admin Backups")
  end

  defp assign_action_data(%{assigns: %{live_action: :storage}} = socket) do
    socket
    |> assign(:status, Admin.status())
    |> assign(:page_title, "Admin Storage")
  end

  defp assign_action_data(%{assigns: %{live_action: :compatibility}} = socket) do
    socket
    |> assign(:status, Admin.compatibility_status())
    |> assign(:page_title, "Admin Compatibility")
  end

  defp render_admin_page(%{live_action: :dashboard} = assigns), do: AdminHTML.dashboard(assigns)
  defp render_admin_page(%{live_action: :invites} = assigns), do: AdminHTML.invites(assigns)
  defp render_admin_page(%{live_action: :repo} = assigns), do: AdminHTML.repo(assigns)
  defp render_admin_page(%{live_action: :backups} = assigns), do: AdminHTML.backups(assigns)
  defp render_admin_page(%{live_action: :storage} = assigns), do: AdminHTML.storage(assigns)
  defp render_admin_page(%{live_action: :compatibility} = assigns), do: AdminHTML.compatibility(assigns)
end
