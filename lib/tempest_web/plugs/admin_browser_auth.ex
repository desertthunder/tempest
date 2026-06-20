defmodule TempestWeb.Plugs.AdminBrowserAuth do
  @moduledoc """
  Authenticates admin Control Panel requests from bearer tokens or browser sessions.
  """

  import Phoenix.Controller
  import Plug.Conn

  alias Tempest.AdminAuth
  alias TempestWeb.XrpcErrorJSON

  use TempestWeb, :verified_routes

  def init(opts), do: opts

  def call(conn, _opts) do
    case authenticate(conn) do
      {:ok, auth} ->
        assign(conn, :admin_auth, auth)

      {:error, :missing_admin_token} ->
        redirect_to_login(conn)

      {:error, :bearer_not_allowed} ->
        reject(conn, 401, "AutomationOnly", "Admin bearer tokens are only accepted on automation endpoints")

      {:error, _reason} ->
        reject(conn, 401, "InvalidToken", "Admin session is invalid")
    end
  end

  defp authenticate(conn) do
    if authorization_header?(conn) do
      {:error, :bearer_not_allowed}
    else
      authenticate_session(conn)
    end
  end

  defp authorization_header?(conn), do: conn |> get_req_header("authorization") |> Enum.any?()

  defp authenticate_session(conn) do
    session_id = get_session(conn, :admin_session_id)
    family_id = get_session(conn, :admin_session_family_id)
    did = get_session(conn, :admin_did)

    case AdminAuth.authenticate_browser_session(session_id, family_id, did) do
      {:ok, auth} ->
        {:ok, auth}

      {:error, _reason} = error when not is_nil(session_id) or not is_nil(family_id) or not is_nil(did) ->
        error

      {:error, _reason} ->
        {:error, :missing_admin_token}
    end
  end

  defp redirect_to_login(conn) do
    return_to = current_path(conn)

    conn
    |> redirect(to: ~p"/admin/login?#{[return_to: return_to]}")
    |> halt()
  end

  defp reject(conn, status, error, message) do
    conn
    |> clear_session()
    |> XrpcErrorJSON.render(status, error, message)
    |> halt()
  end
end
