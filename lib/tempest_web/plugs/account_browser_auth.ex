defmodule TempestWeb.Plugs.AccountBrowserAuth do
  @moduledoc """
  Authenticates account Control Panel requests from bearer tokens or browser sessions.
  """

  import Phoenix.Controller
  import Plug.Conn

  alias Tempest.Accounts
  alias Tempest.Accounts.AuthContext
  alias Tempest.AdminAuth
  alias TempestWeb.XrpcErrorJSON

  use TempestWeb, :verified_routes

  def init(opts), do: opts

  def call(conn, _opts) do
    case authenticate(conn) do
      {:ok, auth} ->
        assign(conn, :account_auth, auth)

      {:error, :missing_token} ->
        redirect_to_login(conn)

      {:error, :expired_token} ->
        reject(conn, 401, "ExpiredToken", "Account session is expired")

      {:error, :inactive_account} ->
        reject(conn, 403, "AccountTakedown", "Account is not active")

      {:error, _reason} ->
        reject(conn, 401, "InvalidToken", "Account session is invalid")
    end
  end

  defp authenticate(conn) do
    with {:error, :missing_token} <- authenticate_bearer(conn) do
      authenticate_session(conn)
    end
  end

  defp authenticate_bearer(conn) do
    conn
    |> get_req_header("authorization")
    |> case do
      ["Bearer " <> token] when token != "" -> Accounts.authenticate_access(token)
      ["bearer " <> token] when token != "" -> Accounts.authenticate_access(token)
      _headers -> {:error, :missing_token}
    end
  end

  defp authenticate_session(conn) do
    session_id = get_session(conn, :account_session_id)
    family_id = get_session(conn, :account_session_family_id)

    case Accounts.authenticate_browser_session(session_id, family_id) do
      {:ok, auth} ->
        {:ok, auth}

      {:error, _reason} = error when not is_nil(session_id) or not is_nil(family_id) ->
        error

      {:error, _reason} ->
        authenticate_admin_session(conn)
    end
  end

  defp authenticate_admin_session(conn) do
    session_id = get_session(conn, :admin_session_id)
    family_id = get_session(conn, :admin_session_family_id)
    did = get_session(conn, :admin_did)

    case AdminAuth.authenticate_browser_session(session_id, family_id, did) do
      {:ok, %{account: account, session: session}} ->
        {:ok, %AuthContext{account: account, session: session, token_type: :browser_session}}

      {:ok, _external_admin_session} ->
        {:error, :missing_token}

      {:error, _reason} = error when not is_nil(session_id) or not is_nil(family_id) or not is_nil(did) ->
        error

      {:error, _reason} ->
        {:error, :missing_token}
    end
  end

  defp redirect_to_login(conn) do
    return_to = current_path(conn)

    conn
    |> redirect(to: ~p"/account/login?#{[return_to: return_to]}")
    |> halt()
  end

  defp reject(conn, status, error, message) do
    conn
    |> clear_session()
    |> XrpcErrorJSON.render(status, error, message)
    |> halt()
  end
end
