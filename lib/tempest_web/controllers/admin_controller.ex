defmodule TempestWeb.AdminController do
  use TempestWeb, :controller

  alias Tempest.AdminAuth
  alias TempestWeb.XrpcErrorJSON

  def status(conn, _params) do
    case AdminAuth.verify_authorization_header(conn.req_headers) do
      :ok ->
        json(conn, Tempest.Admin.status())

      {:error, :missing_admin_token} ->
        reject(conn, 401, "AuthenticationRequired", "Admin bearer token is required")

      {:error, :admin_token_not_configured} ->
        reject(conn, 503, "AdminAuthNotConfigured", "Admin token hash is not configured")

      {:error, _reason} ->
        reject(conn, 401, "InvalidToken", "Admin bearer token is invalid")
    end
  end

  defp reject(conn, status, error, message) do
    XrpcErrorJSON.render(conn, status, error, message)
  end
end
