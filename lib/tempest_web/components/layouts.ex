defmodule TempestWeb.Layouts do
  @moduledoc """
  This module holds layouts and related functionality used by the application.
  """
  use TempestWeb, :html

  embed_templates "layouts/*"

  @site_name "Tempest PDS"
  @site_description "Tempest is an AT Protocol Personal Data Server built with Elixir and Phoenix."

  def site_name, do: @site_name

  def site_description, do: @site_description

  def site_title(assigns) when is_map(assigns) do
    case assigns[:page_title] do
      title when is_binary(title) and title != "" -> "#{title} · AT Protocol"
      _title -> @site_name
    end
  end

  def public_url(path \\ "") when is_binary(path) do
    base_url =
      Tempest.Config.load!()
      |> Map.fetch!(:public_url)
      |> String.trim_trailing("/")

    base_url <> path
  end

  attr :flash, :map, required: true, doc: "the map of flash messages"

  attr :current_scope, :map,
    default: nil,
    doc: "the current [scope](https://hexdocs.pm/phoenix/scopes.html)"

  attr :chrome, :atom, default: :app, values: [:app, :desktop]

  slot :inner_block, required: true

  def app(assigns) do
    ~H"""
    <div class="app-shell">
      <%= if @chrome == :desktop do %>
        {render_slot(@inner_block)}
      <% else %>
        <header class="app-header">
          <a href="/" class="app-header__brand">
            <img src={~p"/images/logo.svg"} width="32" height="32" alt="" />
            <span>Tempest PDS</span>
            <span>v{Application.spec(:tempest, :vsn)}</span>
          </a>
          <nav aria-label="Project links">
            <ul class="app-header__nav">
              <li><a href={~p"/docs"} class="button">Docs</a></li>
              <li><a href="https://github.com/owais/tempest" class="button">GitHub</a></li>
              <li><a href="https://atproto.com/" class="button button--primary">AT Protocol</a></li>
            </ul>
          </nav>
        </header>

        <main class="app-main">
          <div class="app-stack">
            {render_slot(@inner_block)}
          </div>
        </main>
      <% end %>

      <.flash_group flash={@flash} />
    </div>
    """
  end

  @doc """
  Shows the flash group with standard titles and content.
  """
  attr :flash, :map, required: true, doc: "the map of flash messages"
  attr :id, :string, default: "flash-group", doc: "the optional id of flash container"

  def flash_group(assigns) do
    ~H"""
    <div id={@id} class="flash-stack" aria-live="polite">
      <.flash kind={:info} flash={@flash} />
      <.flash kind={:error} flash={@flash} />

      <.flash
        id="client-error"
        kind={:error}
        title={gettext("We can't find the internet")}
        phx-disconnected={show(".phx-client-error #client-error") |> JS.remove_attribute("hidden")}
        phx-connected={hide("#client-error") |> JS.set_attribute({"hidden", ""})}
        hidden
      >
        {gettext("Attempting to reconnect")}
        <.icon name="refresh" class="is-spinning" />
      </.flash>

      <.flash
        id="server-error"
        kind={:error}
        title={gettext("Something went wrong!")}
        phx-disconnected={show(".phx-server-error #server-error") |> JS.remove_attribute("hidden")}
        phx-connected={hide("#server-error") |> JS.set_attribute({"hidden", ""})}
        hidden
      >
        {gettext("Attempting to reconnect")}
        <.icon name="refresh" class="is-spinning" />
      </.flash>
    </div>
    """
  end
end
