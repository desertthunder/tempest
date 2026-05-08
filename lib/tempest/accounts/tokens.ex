defmodule Tempest.Accounts.Tokens do
  @moduledoc """
  Access token signing and refresh token generation.
  """

  alias Tempest.Accounts.{Account, Session}
  alias TempestWeb.Endpoint

  @access_salt "tempest access token v1"
  @access_max_age_seconds 15 * 60
  @refresh_lifetime_seconds 60 * 60 * 24 * 30
  @refresh_prefix "tempest-refresh-v1."

  def sign_access_token(%Account{} = account, %Session{} = session) do
    Phoenix.Token.sign(Endpoint, @access_salt, %{
      "typ" => "access",
      "account_id" => account.id,
      "session_id" => session.id,
      "did" => account.did
    })
  end

  def verify_access_token(token) when is_binary(token) do
    Phoenix.Token.verify(Endpoint, @access_salt, token, max_age: @access_max_age_seconds)
  end

  def verify_access_token(_token), do: {:error, :invalid}

  def new_refresh_token do
    @refresh_prefix <> random_url_token(48)
  end

  def refresh_token_hash(token) when is_binary(token) do
    :crypto.hash(:sha256, token)
    |> Base.encode16(case: :lower)
  end

  def refresh_expires_at(now \\ DateTime.utc_now()) do
    now
    |> DateTime.add(@refresh_lifetime_seconds, :second)
    |> DateTime.truncate(:second)
  end

  defp random_url_token(bytes) do
    bytes
    |> :crypto.strong_rand_bytes()
    |> Base.url_encode64(padding: false)
  end
end
