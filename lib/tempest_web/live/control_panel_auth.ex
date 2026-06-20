defmodule TempestWeb.ControlPanelAuth do
  @moduledoc """
  LiveView auth hooks and session helpers for account and admin control panels.
  """

  import Phoenix.LiveView
  import Phoenix.Component, only: [assign: 3]

  alias Tempest.{Accounts, AdminAuth}

  def account_session(conn) do
    case conn.assigns[:account_auth] do
      %{session: %{id: session_id, family_id: family_id}} ->
        %{"account_session_id" => session_id, "account_session_family_id" => family_id}

      _auth ->
        %{}
    end
  end

  def admin_session(conn) do
    case conn.assigns[:admin_auth] do
      %{session: %{id: session_id, family_id: family_id}, did: did} ->
        %{"admin_session_id" => session_id, "admin_session_family_id" => family_id, "admin_did" => did}

      _auth ->
        %{}
    end
  end

  def on_mount(:account, _params, session, socket) do
    session_id = session_value(session, "account_session_id", :account_session_id)
    family_id = session_value(session, "account_session_family_id", :account_session_family_id)

    case Accounts.authenticate_browser_session(session_id, family_id) do
      {:ok, auth} ->
        {:cont,
         socket
         |> assign(:account_auth, auth)
         |> assign(:current_scope, %{kind: :account, did: auth.account.did})}

      {:error, _reason} ->
        {:halt, redirect(socket, to: "/account/login")}
    end
  end

  def on_mount(:admin, _params, session, socket) do
    session_id = session_value(session, "admin_session_id", :admin_session_id)
    family_id = session_value(session, "admin_session_family_id", :admin_session_family_id)
    did = session_value(session, "admin_did", :admin_did)

    case AdminAuth.authenticate_browser_session(session_id, family_id, did) do
      {:ok, auth} ->
        {:cont,
         socket
         |> assign(:admin_auth, auth)
         |> assign(:current_scope, %{kind: :admin, did: did})}

      {:error, _reason} ->
        {:halt, redirect(socket, to: "/admin/login")}
    end
  end

  defp session_value(session, string_key, atom_key) do
    Map.get(session, string_key) || Map.get(session, atom_key)
  end
end
