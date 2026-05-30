defmodule Tempest.OAuth do
  @moduledoc """
  OAuth authorization-code, PAR, token, refresh, and revocation boundary.
  """

  import Ecto.Query

  alias Tempest.Accounts.{Account, Password}
  alias Tempest.OAuth.{AuthorizationCode, Dpop, ParRequest, Token}
  alias Tempest.Repo
  alias TempestWeb.Endpoint

  @par_lifetime_seconds 10 * 60
  @code_lifetime_seconds 5 * 60
  @access_lifetime_seconds 15 * 60
  @access_salt "tempest oauth access token v1"

  @supported_scopes ~w(atproto transition:generic transition:chat.bsky transition:email blob:*/* rpc:*)

  def supported_scopes, do: @supported_scopes

  def create_par(params, dpop_proof, public_url) do
    with :ok <- require_param(params, "client_id"),
         :ok <- require_param(params, "redirect_uri"),
         :ok <- require_param(params, "scope"),
         :ok <- require_param(params, "code_challenge"),
         "S256" <- Map.get(params, "code_challenge_method"),
         :ok <- validate_scope_string(params["scope"]),
         {:ok, proof} <- Dpop.verify_proof(dpop_proof, "POST", public_url <> "/oauth/par") do
      request_uri = "urn:ietf:params:oauth:request_uri:" <> random_token(32)
      now = now()

      attrs = %{
        request_uri: request_uri,
        client_id: params["client_id"],
        redirect_uri: params["redirect_uri"],
        scope: params["scope"],
        state: Map.get(params, "state"),
        code_challenge: params["code_challenge"],
        code_challenge_method: "S256",
        dpop_jkt: proof.jkt,
        expires_at: DateTime.add(now, @par_lifetime_seconds, :second)
      }

      case %ParRequest{} |> ParRequest.changeset(attrs) |> Repo.insert() do
        {:ok, par} -> {:ok, par}
        {:error, changeset} -> {:error, {:validation, changeset}}
      end
    else
      nil -> {:error, :invalid_request}
      other when is_binary(other) -> {:error, :invalid_request}
      {:error, reason} -> {:error, reason}
    end
  end

  def get_valid_par(request_uri) when is_binary(request_uri) do
    now = now()

    ParRequest
    |> where([p], p.request_uri == ^request_uri)
    |> where([p], is_nil(p.used_at))
    |> where([p], p.expires_at > ^now)
    |> Repo.one()
    |> case do
      nil -> {:error, :invalid_request_uri}
      par -> {:ok, par}
    end
  end

  def get_valid_par(_request_uri), do: {:error, :invalid_request_uri}

  def authorize(params) do
    with {:ok, par} <- get_valid_par(Map.get(params, "request_uri")),
         {:ok, account} <- authenticate_account(Map.get(params, "identifier"), Map.get(params, "password")) do
      code = random_token(32)
      now = now()

      Repo.transaction(fn ->
        fresh_par = Repo.get!(ParRequest, par.id)

        if fresh_par.used_at do
          Repo.rollback(:invalid_request_uri)
        else
          fresh_par
          |> ParRequest.changeset(%{used_at: now})
          |> Repo.update!()

          %AuthorizationCode{}
          |> AuthorizationCode.changeset(%{
            code_hash: hash(code),
            account_id: account.id,
            par_request_id: par.id,
            client_id: par.client_id,
            redirect_uri: par.redirect_uri,
            scope: par.scope,
            code_challenge: par.code_challenge,
            dpop_jkt: par.dpop_jkt,
            expires_at: DateTime.add(now, @code_lifetime_seconds, :second)
          })
          |> Repo.insert!()

          redirect = append_query(par.redirect_uri, %{"code" => code, "state" => par.state})
          %{redirect: redirect, code: code}
        end
      end)
    end
  end

  def exchange_authorization_code(params, dpop_proof, public_url) do
    with :ok <- require_param(params, "code"),
         :ok <- require_param(params, "code_verifier"),
         {:ok, code} <- fetch_code(params["code"]),
         :ok <- verify_redirect_uri(code, Map.get(params, "redirect_uri")),
         :ok <- verify_pkce(code.code_challenge, params["code_verifier"]),
         {:ok, proof} <- Dpop.verify_proof(dpop_proof, "POST", public_url <> "/oauth/token", bound_jkt: code.dpop_jkt) do
      issue_tokens_from_code(code, proof)
    end
  end

  def refresh(params, dpop_proof, public_url) do
    with :ok <- require_param(params, "refresh_token"),
         {:ok, token} <- fetch_refresh_token(params["refresh_token"]),
         {:ok, proof} <- Dpop.verify_proof(dpop_proof, "POST", public_url <> "/oauth/token", bound_jkt: token.dpop_jkt) do
      rotate_refresh_token(token, proof)
    end
  end

  def revoke(token_string) when is_binary(token_string) do
    now = now()
    access_hash = hash(token_string)
    refresh_hash = hash(token_string)

    Token
    |> where([t], t.access_token_hash == ^access_hash or t.refresh_token_hash == ^refresh_hash)
    |> Repo.update_all(set: [revoked_at: now])

    :ok
  end

  def sign_access_token(%Account{} = account, %Token{} = token) do
    Phoenix.Token.sign(Endpoint, @access_salt, %{
      "typ" => "oauth_access",
      "account_id" => account.id,
      "token_id" => token.id,
      "did" => account.did,
      "client_id" => token.client_id,
      "scope" => token.scope,
      "cnf" => %{"jkt" => token.dpop_jkt}
    })
  end

  def verify_access_token(token) when is_binary(token) do
    with {:ok, %{"typ" => "oauth_access", "account_id" => account_id, "token_id" => token_id} = claims} <-
           Phoenix.Token.verify(Endpoint, @access_salt, token, max_age: @access_lifetime_seconds),
         %Token{} = oauth_token <- Repo.get(Token, token_id),
         %Account{} = account <- Repo.get(Account, account_id),
         :ok <- ensure_token_valid(oauth_token, account, token) do
      {:ok, account, oauth_token, claims}
    else
      {:error, reason} -> {:error, reason}
      nil -> {:error, :invalid_token}
      _other -> {:error, :invalid_token}
    end
  end

  def verify_access_token(_token), do: {:error, :invalid_token}

  defp issue_tokens_from_code(%AuthorizationCode{} = code, proof) do
    now = now()

    Repo.transaction(fn ->
      fresh_code = Repo.get!(AuthorizationCode, code.id)

      cond do
        fresh_code.used_at || fresh_code.revoked_at ->
          Repo.rollback(:invalid_grant)

        expired?(fresh_code.expires_at, now) ->
          Repo.rollback(:invalid_grant)

        true ->
          fresh_code
          |> AuthorizationCode.changeset(%{used_at: now})
          |> Repo.update!()

          account = Repo.get!(Account, fresh_code.account_id)
          refresh_token = "tempest-oauth-refresh-v1." <> random_token(48)

          token =
            %Token{}
            |> Token.changeset(%{
              access_token_hash: "pending-#{random_token(8)}",
              refresh_token_hash: hash(refresh_token),
              account_id: account.id,
              client_id: fresh_code.client_id,
              scope: fresh_code.scope,
              dpop_jkt: proof.jkt,
              expires_at: DateTime.add(now, @access_lifetime_seconds, :second)
            })
            |> Repo.insert!()

          access_token = sign_access_token(account, token)

          token
          |> Token.changeset(%{access_token_hash: hash(access_token)})
          |> Repo.update!()

          token_response(access_token, refresh_token, account.did, fresh_code.scope)
      end
    end)
  end

  defp rotate_refresh_token(%Token{} = token, proof) do
    now = now()

    Repo.transaction(fn ->
      fresh_token = Repo.get!(Token, token.id)

      cond do
        fresh_token.revoked_at || fresh_token.rotated_at ->
          Repo.rollback(:invalid_grant)

        true ->
          fresh_token
          |> Token.changeset(%{rotated_at: now, revoked_at: now})
          |> Repo.update!()

          account = Repo.get!(Account, fresh_token.account_id)
          refresh_token = "tempest-oauth-refresh-v1." <> random_token(48)

          new_token =
            %Token{}
            |> Token.changeset(%{
              access_token_hash: "pending-#{random_token(8)}",
              refresh_token_hash: hash(refresh_token),
              account_id: account.id,
              client_id: fresh_token.client_id,
              scope: fresh_token.scope,
              dpop_jkt: proof.jkt,
              expires_at: DateTime.add(now, @access_lifetime_seconds, :second)
            })
            |> Repo.insert!()

          access_token = sign_access_token(account, new_token)

          new_token
          |> Token.changeset(%{access_token_hash: hash(access_token)})
          |> Repo.update!()

          token_response(access_token, refresh_token, account.did, fresh_token.scope)
      end
    end)
  end

  defp token_response(access_token, refresh_token, did, scope) do
    %{
      "access_token" => access_token,
      "refresh_token" => refresh_token,
      "token_type" => "DPoP",
      "expires_in" => @access_lifetime_seconds,
      "scope" => scope,
      "sub" => did
    }
  end

  defp fetch_code(code) do
    now = now()

    AuthorizationCode
    |> where([c], c.code_hash == ^hash(code))
    |> where([c], is_nil(c.used_at))
    |> where([c], is_nil(c.revoked_at))
    |> where([c], c.expires_at > ^now)
    |> Repo.one()
    |> case do
      nil -> {:error, :invalid_grant}
      code -> {:ok, code}
    end
  end

  defp fetch_refresh_token(refresh_token) do
    Token
    |> where([t], t.refresh_token_hash == ^hash(refresh_token))
    |> where([t], is_nil(t.revoked_at))
    |> where([t], is_nil(t.rotated_at))
    |> Repo.one()
    |> case do
      nil -> {:error, :invalid_grant}
      token -> {:ok, token}
    end
  end

  defp ensure_token_valid(%Token{} = token, %Account{} = account, access_token) do
    now = now()

    cond do
      token.account_id != account.id -> {:error, :invalid_token}
      token.revoked_at -> {:error, :invalid_token}
      token.access_token_hash != hash(access_token) -> {:error, :invalid_token}
      expired?(token.expires_at, now) -> {:error, :expired_token}
      not account.active or account.status != "active" -> {:error, :inactive_account}
      true -> :ok
    end
  end

  defp authenticate_account(identifier, password) when is_binary(identifier) and is_binary(password) do
    normalized = identifier |> String.trim() |> String.downcase()

    account =
      Account
      |> where([a], a.handle == ^normalized or a.email == ^normalized or a.did == ^normalized)
      |> Repo.one()

    cond do
      is_nil(account) ->
        Password.verify(password, nil)
        {:error, :invalid_credentials}

      not account.active or account.status != "active" ->
        {:error, :inactive_account}

      Password.verify(password, account.password_hash) ->
        {:ok, account}

      true ->
        {:error, :invalid_credentials}
    end
  end

  defp authenticate_account(_identifier, _password), do: {:error, :invalid_credentials}

  defp verify_redirect_uri(_code, nil), do: :ok
  defp verify_redirect_uri(%AuthorizationCode{redirect_uri: redirect_uri}, redirect_uri), do: :ok
  defp verify_redirect_uri(_code, _redirect_uri), do: {:error, :invalid_grant}

  defp verify_pkce(code_challenge, verifier) when is_binary(code_challenge) and is_binary(verifier) do
    challenge = verifier |> sha256() |> Base.url_encode64(padding: false)
    if challenge == code_challenge, do: :ok, else: {:error, :invalid_grant}
  end

  defp verify_pkce(_code_challenge, _verifier), do: {:error, :invalid_grant}

  defp require_param(params, key) do
    case Map.get(params, key) do
      value when is_binary(value) and value != "" -> :ok
      _value -> {:error, :invalid_request}
    end
  end

  defp validate_scope_string(scope) when is_binary(scope) do
    scopes = String.split(scope, " ", trim: true)

    if scopes != [] and Enum.all?(scopes, &valid_scope?/1) do
      :ok
    else
      {:error, :invalid_scope}
    end
  end

  defp validate_scope_string(_scope), do: {:error, :invalid_scope}

  defp valid_scope?("rpc:" <> nsid),
    do: nsid == "*" or String.match?(nsid, ~r/^[a-zA-Z0-9.*?-]+(?:\.[a-zA-Z0-9*?-]+)*(?:\?aud=did:[^\s]+)?$/)

  defp valid_scope?(scope), do: scope in @supported_scopes

  defp append_query(url, params) when is_binary(url) do
    params = params |> Enum.reject(fn {_key, value} -> is_nil(value) end) |> Map.new()
    separator = if String.contains?(url, "?"), do: "&", else: "?"
    url <> separator <> URI.encode_query(params)
  end

  defp append_query(_url, _params), do: ""

  defp expired?(%DateTime{} = expires_at, %DateTime{} = now), do: DateTime.compare(expires_at, now) != :gt
  defp expired?(_expires_at, _now), do: true

  defp hash(value) when is_binary(value), do: value |> sha256() |> Base.encode16(case: :lower)
  defp sha256(value) when is_binary(value), do: :crypto.hash(:sha256, value)
  defp random_token(bytes), do: bytes |> :crypto.strong_rand_bytes() |> Base.url_encode64(padding: false)
  defp now, do: DateTime.utc_now() |> DateTime.truncate(:second)
end
