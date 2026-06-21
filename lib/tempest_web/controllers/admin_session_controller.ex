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
        create_external_oauth_session(conn, admin_params, params)

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
        |> put_session(:account_session_id, admin_session.session.id)
        |> put_session(:account_session_family_id, admin_session.family_id)
        |> put_session(:account_did, admin_session.did)
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

  defp create_external_oauth_session(conn, admin_params, params) do
    access_token = Map.get(admin_params, "access_token", "")
    return_to = return_to(params)

    case AdminAuth.create_external_oauth_browser_session(access_token) do
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
  defp login_error(:missing_oauth_token), do: "OAuth access token is required for this external admin DID."
  defp login_error(:invalid_oauth_token), do: "OAuth access token is invalid for this admin DID."
  defp login_error(:pds_not_found), do: "The configured admin DID does not advertise an AT Protocol PDS."
  defp login_error(:oauth_metadata_not_found), do: "Admin OAuth metadata could not be discovered."
  defp login_error(:oauth_introspection_failed), do: "Admin OAuth token introspection failed."
  defp login_error(:rate_limited), do: "Too many attempts. Try again later."
  defp login_error(_reason), do: "The username or password is incorrect."

  defp renew_session(conn) do
    conn
    |> configure_session(renew: true)
    |> clear_session()
  end
end
