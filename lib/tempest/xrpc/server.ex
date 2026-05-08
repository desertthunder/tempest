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
