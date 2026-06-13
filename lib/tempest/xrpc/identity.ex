defmodule Tempest.Xrpc.Identity do
  @moduledoc """
  Handlers for `com.atproto.identity.*` XRPC methods.
  """

  alias Tempest.Accounts
  alias Tempest.Identity
  alias Tempest.Security

  def resolve_handle(_conn, params, _method) do
    params
    |> Map.get("handle")
    |> Identity.resolve_handle()
    |> case do
      {:ok, did} -> {:ok, %{did: did}}
      {:error, reason} -> identity_error(reason)
    end
  end

  def update_handle(conn, params, _method) do
    handle = Map.get(params, "handle")

    case Identity.update_handle(conn.assigns.auth_context, handle) do
      {:ok, account} ->
        {:ok, Accounts.account_response(account)}

      {:error, reason} ->
        identity_error(reason)
    end
  end

  def get_recommended_did_credentials(conn, _params, _method) do
    {:ok, Identity.recommended_did_credentials(conn.assigns.auth_context.account)}
  end

  def request_plc_operation_signature(conn, params, _method) do
    account = conn.assigns.auth_context.account

    with password when is_binary(password) and password != "" <- Map.get(params, "password"),
         :ok <- Security.verify_account_password(account, password),
         {:ok, %{token: token}} <- Security.issue_plc_operation_token(account) do
      {:ok, %{"token" => token}}
    else
      nil -> {:error, 400, "InvalidRequest", "password is required"}
      "" -> {:error, 400, "InvalidRequest", "password is required"}
      {:error, :invalid_password} -> {:error, 401, "AuthenticationRequired", "password is invalid"}
      {:error, _reason} -> {:error, 400, "InvalidRequest", "could not create PLC operation signature token"}
    end
  end

  defp identity_error(:invalid_handle_syntax), do: {:error, 400, "InvalidRequest", "handle is invalid"}
  defp identity_error(:invalid_did_syntax), do: {:error, 400, "InvalidRequest", "resolved DID is invalid"}

  defp identity_error(:unsupported_did_method),
    do: {:error, 400, "InvalidRequest", "resolved DID method is unsupported"}

  defp identity_error(:private_ip), do: {:error, 400, "InvalidRequest", "handle resolves to a private or local address"}
  defp identity_error(:unsafe_url), do: {:error, 400, "InvalidRequest", "handle resolver URL is unsafe"}

  defp identity_error(:handle_did_mismatch),
    do: {:error, 400, "InvalidRequest", "handle does not resolve to authenticated DID"}

  defp identity_error(:did_document_mismatch), do: {:error, 400, "InvalidRequest", "DID document does not claim handle"}
  defp identity_error(:resolution_failed), do: {:error, 400, "HandleNotFound", "handle could not be resolved"}
  defp identity_error(:handle_not_found), do: {:error, 400, "HandleNotFound", "handle could not be resolved"}
  defp identity_error(:did_not_found), do: {:error, 400, "InvalidRequest", "DID document could not be resolved"}
  defp identity_error(_reason), do: {:error, 400, "InvalidRequest", "identity verification failed"}
end
