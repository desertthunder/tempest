defmodule Tempest.Accounts.Tokens do
  @moduledoc """
  Access token signing and refresh token generation.
  """

  alias Tempest.Accounts.{Account, Session}
  alias TempestWeb.Endpoint

  @access_salt "tempest access token v1"
  @access_max_age_seconds 15 * 60
  @service_auth_salt "tempest service auth token v1"
  @service_auth_max_age_seconds 10 * 60
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

  def sign_service_auth(%Account{} = account, audience, method_nsid)
      when is_binary(audience) and is_binary(method_nsid) do
    Phoenix.Token.sign(Endpoint, @service_auth_salt, %{
      "typ" => "service-auth",
      "iss" => account.did,
      "sub" => account.did,
      "aud" => audience,
      "lxm" => method_nsid
    })
  end

  def verify_service_auth(token) when is_binary(token) do
    Phoenix.Token.verify(Endpoint, @service_auth_salt, token, max_age: @service_auth_max_age_seconds)
  end

  def verify_service_auth(_token), do: {:error, :invalid}

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
