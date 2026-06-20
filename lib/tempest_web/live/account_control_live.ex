defmodule TempestWeb.AccountControlLive do
  use TempestWeb, :live_view

  alias Tempest.{Accounts, Blobs, RepoStorage, Security, Sequencer}
  alias TempestWeb.OperatorAccountHTML

  @page_limit 50

  @impl true
  def mount(_params, _session, socket), do: {:ok, assign(socket, :page_title, "Account Control Panel")}

  @impl true
  def handle_params(params, uri, socket) do
    auth = socket.assigns.account_auth

    socket =
      socket
      |> assign(:current_uri, uri)
      |> assign(:account, auth.account)
      |> assign_action_data(params)

    {:noreply, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      {render_account_page(assigns)}
    </Layouts.app>
    """
  end

  defp assign_action_data(%{assigns: %{live_action: :dashboard, account_auth: auth}} = socket, _params) do
    {:ok, status} = Accounts.check_account_status(auth)

    socket
    |> assign(:status, status)
    |> assign(:page_title, "Account Dashboard")
  end

  defp assign_action_data(%{assigns: %{live_action: :repo, account: account}} = socket, params) do
    {:ok, collections} = RepoStorage.list_collections(account.did)
    {:ok, latest} = RepoStorage.latest_commit(account.did)
    {:ok, records} = RepoStorage.list_recent_records(account.did, limit: @page_limit)

    socket
    |> assign(:collections, collections)
    |> assign(:latest, latest)
    |> assign(:records, records)
    |> assign(:selected_collection, Map.get(params, "collection"))
    |> assign(:page_title, "Account Repo")
  end

  defp assign_action_data(%{assigns: %{live_action: :blobs, account: account}} = socket, _params) do
    {:ok, blobs} = Blobs.list_all(account.did, limit: @page_limit)

    socket
    |> assign(:blobs, blobs)
    |> assign(:page_title, "Account Blobs")
  end

  defp assign_action_data(%{assigns: %{live_action: :access, account: account}} = socket, _params) do
    socket
    |> assign(:inventory, Security.account_security_inventory(account))
    |> assign(:page_title, "Account Access")
  end

  defp assign_action_data(%{assigns: %{live_action: :security, account: account}} = socket, _params) do
    socket
    |> assign(:inventory, Security.account_security_inventory(account))
    |> assign(:page_title, "Account Security")
  end

  defp assign_action_data(%{assigns: %{live_action: :migration, account_auth: auth}} = socket, _params) do
    {:ok, status} = Accounts.check_account_status(auth)

    socket
    |> assign(:status, status)
    |> assign(:page_title, "Account Migration")
  end

  defp assign_action_data(%{assigns: %{live_action: :sequencer}} = socket, params) do
    cursor = parse_cursor!(Map.get(params, "cursor"))

    {:ok, events} =
      Sequencer.list_after(cursor, limit: @page_limit, did: Map.get(params, "did"), type: Map.get(params, "type"))

    socket
    |> assign(:events, events)
    |> assign(:cursor, cursor)
    |> assign(:did_filter, Map.get(params, "did"))
    |> assign(:type_filter, Map.get(params, "type"))
    |> assign(:page_title, "Account Sequencer")
  end

  defp assign_action_data(%{assigns: %{live_action: :firehose, account: account}} = socket, _params) do
    {:ok, events} = Sequencer.list_after(0, limit: 20, did: account.did)

    socket
    |> assign(:events, events)
    |> assign(:websocket_url, websocket_url())
    |> assign(:page_title, "Account Firehose")
  end

  defp render_account_page(%{live_action: :dashboard} = assigns), do: OperatorAccountHTML.dashboard(assigns)
  defp render_account_page(%{live_action: :repo} = assigns), do: OperatorAccountHTML.repo(assigns)
  defp render_account_page(%{live_action: :blobs} = assigns), do: OperatorAccountHTML.blobs(assigns)
  defp render_account_page(%{live_action: :access} = assigns), do: OperatorAccountHTML.access(assigns)
  defp render_account_page(%{live_action: :security} = assigns), do: OperatorAccountHTML.security(assigns)
  defp render_account_page(%{live_action: :migration} = assigns), do: OperatorAccountHTML.migration(assigns)
  defp render_account_page(%{live_action: :sequencer} = assigns), do: OperatorAccountHTML.sequencer(assigns)
  defp render_account_page(%{live_action: :firehose} = assigns), do: OperatorAccountHTML.firehose(assigns)

  defp parse_cursor!(nil), do: 0

  defp parse_cursor!(cursor) do
    case Integer.parse(cursor) do
      {value, ""} when value >= 0 -> value
      _other -> 0
    end
  end

  defp websocket_url do
    config = Tempest.Config.load!()
    uri = URI.parse(config.public_url)
    scheme = if uri.scheme == "https", do: "wss", else: "ws"
    scheme <> "://" <> uri.authority <> "/xrpc/com.atproto.sync.subscribeRepos?cursor=0"
  end
end
