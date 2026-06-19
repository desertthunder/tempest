defmodule Tempest.AdminAuth do
  @moduledoc """
  Admin bearer-token verification.

  Admin tokens are separate from account bearer tokens. Operators configure an
  Argon2 hash in `:tempest, :admin_token_hash` or `TEMPEST_ADMIN_TOKEN_HASH`.
  """

  alias Tempest.Accounts.Password

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

  @doc """
  Returns true when an admin token hash is configured.
  """
  def configured?, do: is_binary(configured_hash()) and configured_hash() != ""

  defp configured_hash do
    Application.get_env(:tempest, :admin_token_hash) || System.get_env("TEMPEST_ADMIN_TOKEN_HASH")
  end
end
