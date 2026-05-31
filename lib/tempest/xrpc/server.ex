defmodule Tempest.Xrpc.Server do
  @moduledoc """
  Handlers for `com.atproto.server.*` XRPC methods.
  """

  alias Tempest.Accounts

  def describe_server(_conn, _params, _method) do
    config = Tempest.Config.load!()

    {:ok,
     %{
       availableUserDomains: [available_user_domain(config.hostname)],
       inviteCodeRequired: false,
       links: %{
         privacyPolicy: nil,
         termsOfService: nil
       }
     }}
  end

  def create_account(_conn, params, _method) do
    case Accounts.create_account(params) do
      {:ok, response} ->
        {:ok, response}

      {:error, :validation, %Ecto.Changeset{} = changeset} ->
        {:error, 400, "InvalidRequest", format_changeset_errors(changeset)}

      {:error, :validation, message} ->
        {:error, 400, "InvalidRequest", message}

      {:error, :repo_initialization, reason} ->
        {:error, 500, "InternalServerError", "failed to initialize account repository: #{inspect(reason)}"}

      {:error, :identity_publish, reason} ->
        {:error, 502, "UpstreamFailure", "failed to publish account identity: #{inspect(reason)}"}
    end
  end

  def create_session(_conn, params, _method) do
    identifier = Map.get(params, "identifier")
    password = Map.get(params, "password")

    case Accounts.create_session(identifier, password) do
      {:ok, response} ->
        {:ok, response}

      {:error, :inactive_account} ->
        {:error, 403, "AccountTakedown", "Account is not active"}

      {:error, :invalid_credentials} ->
        {:error, 401, "AuthenticationRequired", "Invalid identifier or password"}

      {:error, :rate_limited} ->
        {:error, 429, "RateLimitExceeded", "Too many authentication attempts"}
    end
  end

  def refresh_session(conn, _params, _method) do
    case Accounts.refresh_session(conn.assigns.auth_context) do
      {:ok, response} -> {:ok, response}
      {:error, :expired_refresh_token} -> {:error, 401, "ExpiredToken", "Refresh token is expired"}
      {:error, :reused_refresh_token} -> {:error, 401, "InvalidToken", "Refresh token has already been used"}
    end
  end

  def delete_session(conn, _params, _method) do
    :ok = Accounts.delete_session(conn.assigns.auth_context)
    {:ok, %{}}
  end

  def get_session(conn, _params, _method) do
    Accounts.get_session(conn.assigns.auth_context)
  end

  def check_account_status(conn, _params, _method) do
    Accounts.check_account_status(conn.assigns.auth_context)
  end

  def get_service_auth(conn, params, _method) do
    case Accounts.get_service_auth(conn.assigns.auth_context, params) do
      {:ok, response} -> {:ok, response}
      {:error, :invalid_audience} -> {:error, 400, "InvalidRequest", "audience is invalid"}
      {:error, :invalid_method} -> {:error, 400, "InvalidRequest", "lxm is invalid"}
    end
  end

  def reserve_signing_key(conn, _params, _method) do
    Accounts.reserve_signing_key(conn.assigns.auth_context)
  end

  def list_app_passwords(conn, _params, _method) do
    Accounts.list_app_passwords(conn.assigns.auth_context)
  end

  def create_app_password(conn, params, _method) do
    case Accounts.create_app_password(conn.assigns.auth_context, params) do
      {:ok, response} -> {:ok, response}
      {:error, :invalid_scope} -> {:error, 400, "InvalidRequest", "invalid app password scope"}
      {:error, :rate_limited} -> {:error, 429, "RateLimitExceeded", "Too many app password requests"}
      {:error, :validation, changeset} -> {:error, 400, "InvalidRequest", format_changeset_errors(changeset)}
    end
  end

  def revoke_app_password(conn, params, _method) do
    case Accounts.revoke_app_password(conn.assigns.auth_context, params) do
      :ok -> {:ok, %{}}
      {:error, :rate_limited} -> {:error, 429, "RateLimitExceeded", "Too many app password requests"}
      {:error, :not_found} -> {:error, 404, "NotFound", "app password not found"}
    end
  end

  defp available_user_domain("." <> _domain = hostname), do: hostname
  defp available_user_domain(hostname), do: "." <> hostname

  defp format_changeset_errors(changeset) do
    changeset
    |> Accounts.changeset_errors()
    |> Enum.map_join(", ", fn {field, messages} ->
      "#{field} #{Enum.join(messages, ", ")}"
    end)
  end
end
