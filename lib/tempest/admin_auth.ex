defmodule Tempest.AdminAuth do
  @moduledoc """
  Admin bearer-token verification.

  Admin tokens are separate from account bearer tokens. Operators configure an
  Argon2 hash in `:tempest, :admin_token_hash` or `TEMPEST_ADMIN_TOKEN_HASH`.
  """

  import Ecto.Query

  alias Tempest.Accounts.{Account, Password}
  alias Tempest.{Accounts, Config, Identity, Repo}

  @doc """
  Hashes a plaintext admin token for configuration.
  """
  def hash_token(token) when is_binary(token), do: Password.hash(token)

  @doc """
  Verifies a plaintext admin token against the configured hash.
  """
  def verify_token(token) when is_binary(token) do
    case configured_hash() do
      hash when is_binary(hash) and hash != "" ->
        if Password.verify(token, hash), do: :ok, else: {:error, :invalid_admin_token}

      _missing ->
        Password.verify(token, nil)
        {:error, :admin_token_not_configured}
    end
  end

  def verify_token(_token) do
    Password.verify(nil, nil)
    {:error, :invalid_admin_token}
  end

  @doc """
  Extracts and verifies a bearer token from request headers.
  """
  def verify_authorization_header(headers) when is_list(headers) do
    headers
    |> Enum.find_value(fn
      {"authorization", "Bearer " <> token} when token != "" -> token
      {"authorization", "bearer " <> token} when token != "" -> token
      _header -> nil
    end)
    |> case do
      nil -> {:error, :missing_admin_token}
      token -> verify_token(token)
    end
  end

  def configured_did do
    case Config.load!().admin_did || System.get_env("TEMPEST_ADMIN_DID") do
      did when is_binary(did) and did != "" -> {:ok, did}
      _missing -> {:error, :admin_did_not_configured}
    end
  end

  def auth_method do
    with {:ok, did} <- configured_did() do
      cond do
        local_admin_account?(did) ->
          {:ok, %{did: did, method: :local_account}}

        match?({:ok, _document}, Identity.did_document_for_did(did)) ->
          {:ok, %{did: did, method: :oauth}}

        true ->
          {:error, :admin_did_not_found}
      end
    end
  end

  def create_local_browser_session(identifier, password) do
    with {:ok, admin_did} <- configured_did(),
         {:ok, browser_session} <- Accounts.create_browser_session(identifier, password),
         ^admin_did <- browser_session.account.did do
      {:ok, %{did: admin_did, session: browser_session.session, family_id: browser_session.family_id}}
    else
      {:error, reason} -> {:error, reason}
      _other -> {:error, :not_admin_account}
    end
  end

  def authenticate_browser_session(session_id, family_id, did) when is_binary(family_id) and is_binary(did) do
    with {:ok, admin_did} <- configured_did(),
         ^admin_did <- did,
         {:ok, auth} <- Accounts.authenticate_browser_session(session_id, family_id),
         ^admin_did <- auth.account.did do
      {:ok, %{did: admin_did, account: auth.account, session: auth.session, token_type: :admin_browser_session}}
    else
      {:error, reason} -> {:error, reason}
      _other -> {:error, :invalid_admin_session}
    end
  end

  def authenticate_browser_session(_session_id, _family_id, _did), do: {:error, :invalid_admin_session}

  def revoke_browser_session(session_id, family_id, did) do
    with {:ok, _auth} <- authenticate_browser_session(session_id, family_id, did) do
      Accounts.revoke_browser_session(session_id, family_id)
    else
      {:error, _reason} -> :ok
    end
  end

  @doc """
  Returns true when an admin token hash is configured.
  """
  def configured?, do: is_binary(configured_hash()) and configured_hash() != ""

  defp local_admin_account?(did) do
    Account
    |> where([account], account.did == ^did and account.active and account.status == "active")
    |> Repo.exists?()
  end

  defp configured_hash do
    Application.get_env(:tempest, :admin_token_hash) || System.get_env("TEMPEST_ADMIN_TOKEN_HASH")
  end
end
