defmodule TempestWeb.Plugs.XrpcAuth do
  @moduledoc """
  Authenticates XRPC bearer tokens when a registered method requires auth.
  """

  import Plug.Conn

  alias Tempest.Accounts
  alias Tempest.Xrpc.Registry
  alias TempestWeb.XrpcErrorJSON

  def init(opts), do: opts

  def call(%{method: "OPTIONS"} = conn, _opts), do: conn

  def call(%{path_params: %{"method" => method_nsid}} = conn, _opts) do
    with {:ok, method} <- Registry.fetch(method_nsid),
         true <- method.auth == :bearer do
      authenticate(conn, method_nsid)
    else
      _other -> conn
    end
  end

  def call(conn, _opts), do: conn

  defp authenticate(conn, method_nsid) do
    with {:ok, token} <- bearer_token(conn),
         {:ok, auth_context} <- verify_token(method_nsid, token) do
      assign(conn, :auth_context, auth_context)
    else
      {:error, :missing_token} ->
        reject(conn, 401, "AuthenticationRequired", "Bearer token is required")

      {:error, :expired_token} ->
        reject(conn, 401, "ExpiredToken", "Bearer token is expired")

      {:error, :inactive_account} ->
        reject(conn, 403, "AccountTakedown", "Account is not active")

      {:error, _reason} ->
        reject(conn, 401, "InvalidToken", "Bearer token is invalid")
    end
  end

  defp bearer_token(conn) do
    conn
    |> get_req_header("authorization")
    |> case do
      ["Bearer " <> token] when token != "" -> {:ok, token}
      ["bearer " <> token] when token != "" -> {:ok, token}
      _headers -> {:error, :missing_token}
    end
  end

  defp verify_token(method_nsid, token)
       when method_nsid in [
              "com.atproto.server.refreshSession",
              "com.atproto.server.deleteSession"
            ] do
    Accounts.authenticate_refresh(token)
  end

  defp verify_token(_method_nsid, token), do: Accounts.authenticate_access(token)

  defp reject(conn, status, error, message) do
    conn
    |> XrpcErrorJSON.render(status, error, message)
    |> halt()
  end
end
