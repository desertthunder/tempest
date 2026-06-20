defmodule TempestWeb.AdminSessionController do
  use TempestWeb, :controller

  alias Tempest.AdminAuth

  def new(conn, params) do
    render_login(conn, params, nil)
  end

  def create(conn, %{"admin" => admin_params} = params) do
    case AdminAuth.auth_method() do
      {:ok, %{method: :local_account}} ->
        create_local_session(conn, admin_params, params)

      {:ok, %{method: :oauth}} ->
        conn
        |> put_status(:not_implemented)
        |> render_login(params, "This admin DID is hosted externally and requires AT Protocol OAuth.")

      {:error, reason} ->
        conn
        |> put_status(:service_unavailable)
        |> render_login(params, login_error(reason))
    end
  end

  def create(conn, params), do: create(conn, Map.put(params, "admin", %{}))

  def delete(conn, params) do
    AdminAuth.revoke_browser_session(
      get_session(conn, :admin_session_id),
      get_session(conn, :admin_session_family_id),
      get_session(conn, :admin_did)
    )

    conn
    |> renew_session()
    |> redirect(to: safe_return_to(return_to(params), ~p"/"))
  end

  defp create_local_session(conn, admin_params, params) do
    identifier = Map.get(admin_params, "identifier", "")
    password = Map.get(admin_params, "password", "")
    return_to = return_to(params)

    case AdminAuth.create_local_browser_session(identifier, password) do
      {:ok, admin_session} ->
        conn
        |> renew_session()
        |> put_session(:admin_session_id, admin_session.session.id)
        |> put_session(:admin_session_family_id, admin_session.family_id)
        |> put_session(:admin_did, admin_session.did)
        |> redirect(to: safe_return_to(return_to, ~p"/admin"))

      {:error, reason} ->
        conn
        |> put_status(:unauthorized)
        |> render_login(params, login_error(reason))
    end
  end

  defp render_login(conn, params, error) do
    auth_method =
      case AdminAuth.auth_method() do
        {:ok, info} -> info.method
        {:error, reason} -> reason
      end

    render(conn, :new,
      form: Phoenix.Component.to_form(%{}, as: :admin),
      return_to: safe_return_to(return_to(params), ~p"/"),
      error: error,
      auth_method: auth_method,
      admin_did: configured_admin_did()
    )
  end

  defp configured_admin_did do
    case AdminAuth.configured_did() do
      {:ok, did} -> did
      {:error, _reason} -> nil
    end
  end

  defp return_to(params), do: Map.get(params, "return_to")

  defp safe_return_to(path, fallback) when is_binary(path) do
    cond do
      path == "" -> fallback
      String.starts_with?(path, "//") -> fallback
      String.contains?(path, ["\r", "\n"]) -> fallback
      String.starts_with?(path, "/") -> path
      true -> fallback
    end
  end

  defp safe_return_to(_path, fallback), do: fallback

  defp login_error(:admin_did_not_configured), do: "TEMPEST_ADMIN_DID is not configured."
  defp login_error(:admin_did_not_found), do: "The configured admin DID could not be resolved."
  defp login_error(:not_admin_account), do: "This account is not the configured admin DID."
  defp login_error(:inactive_account), do: "This account is not active."
  defp login_error(:rate_limited), do: "Too many attempts. Try again later."
  defp login_error(_reason), do: "The user name or password is incorrect."

  defp renew_session(conn) do
    conn
    |> configure_session(renew: true)
    |> clear_session()
  end
end
