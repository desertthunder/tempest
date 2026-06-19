defmodule TempestWeb.Plugs.XrpcAuth do
  @moduledoc """
  Authenticates XRPC bearer tokens when a registered method requires auth.
  """

  import Plug.Conn

  alias Tempest.{Accounts, Permissions}
  alias Tempest.OAuth.Dpop
  alias Tempest.Xrpc.Registry
  alias TempestWeb.XrpcErrorJSON

  @doc false
  def init(opts), do: opts

  @doc """
  Authenticates registered bearer-protected XRPC methods and assigns `:auth_context`.

  Public methods and preflight requests pass through unchanged. OAuth access
  tokens must include a valid DPoP proof for the current request URL.
  """
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
         {:ok, auth_context} <- verify_token(method_nsid, token),
         :ok <- verify_dpop_bound_request(conn, auth_context),
         :ok <- authorize(auth_context, method_nsid, conn.params) do
      assign(conn, :auth_context, auth_context)
    else
      {:error, :missing_token} ->
        reject(conn, 401, "AuthenticationRequired", "Bearer token is required")

      {:error, :expired_token} ->
        reject(conn, 401, "ExpiredToken", "Bearer token is expired")

      {:error, :inactive_account} ->
        reject(conn, 403, "AccountTakedown", "Account is not active")

      {:error, :permission_denied} ->
        reject(conn, 403, "AuthScopeInsufficient", "Bearer token scope is insufficient")

      {:error, :missing_dpop} ->
        reject(conn, 401, "InvalidToken", "DPoP proof is required")

      {:error, :invalid_dpop_nonce} ->
        conn
        |> put_resp_header("dpop-nonce", Dpop.issue_nonce())
        |> reject(401, "UseDpopNonce", "DPoP nonce is required or has expired")

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

  defp verify_token(method_nsid, token)
       when method_nsid in [
              "com.atproto.server.checkAccountStatus",
              "com.atproto.repo.importRepo",
              "com.atproto.repo.listMissingBlobs",
              "com.atproto.repo.uploadBlob",
              "com.atproto.identity.getRecommendedDidCredentials",
              "com.atproto.identity.requestPlcOperationSignature",
              "com.atproto.identity.signPlcOperation",
              "com.atproto.identity.submitPlcOperation",
              "com.atproto.server.activateAccount",
              "com.atproto.server.deactivateAccount",
              "com.atproto.server.requestAccountDelete",
              "com.atproto.server.deleteAccount"
            ],
       do: Accounts.authenticate_access_allow_inactive(token)

  defp verify_token(_method_nsid, token), do: Accounts.authenticate_access(token)

  defp verify_dpop_bound_request(conn, %{token_type: :oauth_access, access_claims: %{"cnf" => %{"jkt" => jkt}}}) do
    dpop = conn |> get_req_header("dpop") |> List.first()
    Dpop.verify_proof(dpop, conn.method, current_request_url(conn), bound_jkt: jkt) |> ok_only()
  end

  defp verify_dpop_bound_request(_conn, _auth_context), do: :ok

  defp authorize(auth_context, method_nsid, params) do
    if Permissions.allowed?(auth_context, method_nsid, params), do: :ok, else: {:error, :permission_denied}
  end

  defp ok_only({:ok, _value}), do: :ok
  defp ok_only({:error, reason}), do: {:error, reason}

  defp current_request_url(conn) do
    query = if conn.query_string == "", do: "", else: "?" <> conn.query_string
    endpoint_url = Phoenix.Controller.endpoint_module(conn).url()
    forwarded_scheme = forwarded_header(conn, "x-forwarded-proto")
    forwarded_host = forwarded_header(conn, "x-forwarded-host")

    base_url =
      if forwarded_scheme || forwarded_host do
        endpoint_uri = URI.parse(endpoint_url)
        scheme = forwarded_scheme || endpoint_uri.scheme || Atom.to_string(conn.scheme)
        host = forwarded_host || host_header(conn) || endpoint_uri.host || conn.host

        scheme <> "://" <> host
      else
        endpoint_url
      end

    base_url <> conn.request_path <> query
  end

  defp forwarded_header(conn, name) do
    conn
    |> get_req_header(name)
    |> List.first()
    |> first_forwarded_value()
  end

  defp first_forwarded_value(nil), do: nil

  defp first_forwarded_value(value) when is_binary(value) do
    value
    |> String.split(",", parts: 2)
    |> List.first()
    |> String.trim()
    |> case do
      "" -> nil
      forwarded -> forwarded
    end
  end

  defp host_header(conn), do: conn |> get_req_header("host") |> List.first()

  defp reject(conn, status, error, message) do
    conn
    |> XrpcErrorJSON.render(status, error, message)
    |> halt()
  end
end
