defmodule Tempest.AdminAuth do
  @moduledoc """
  Admin bearer-token verification.

  Admin tokens are separate from account bearer tokens. Operators configure an
  Argon2 hash in `:tempest, :admin_token_hash` or `TEMPEST_ADMIN_TOKEN_HASH`.
  """

  import Ecto.Query

  alias Tempest.Accounts.{Account, Password}
  alias Tempest.Identity.SsrfProtection
  alias Tempest.{Accounts, Config, Identity, Repo}

  @external_session_ttl_seconds 60 * 60 * 12

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

  def create_external_oauth_browser_session(access_token) when is_binary(access_token) and access_token != "" do
    with {:ok, admin_did} <- configured_did(),
         {:ok, document} <- Identity.external_did_document_for_did(admin_did),
         {:ok, pds_url} <- atproto_pds_url(document),
         {:ok, introspection_endpoint} <- discover_introspection_endpoint(pds_url),
         {:ok, %{"active" => true, "sub" => ^admin_did}} <- introspect_token(introspection_endpoint, access_token) do
      create_external_session(admin_did)
    else
      {:error, reason} -> {:error, reason}
      _other -> {:error, :invalid_oauth_token}
    end
  end

  def create_external_oauth_browser_session(_access_token), do: {:error, :missing_oauth_token}

  def authenticate_browser_session(session_id, family_id, did) when is_binary(family_id) and is_binary(did) do
    case authenticate_local_browser_session(session_id, family_id, did) do
      {:ok, auth} -> {:ok, auth}
      {:error, _reason} -> authenticate_external_browser_session(session_id, family_id, did)
    end
  end

  def authenticate_browser_session(_session_id, _family_id, _did), do: {:error, :invalid_admin_session}

  def revoke_browser_session(session_id, family_id, did) do
    case authenticate_local_browser_session(session_id, family_id, did) do
      {:ok, _auth} ->
        Accounts.revoke_browser_session(session_id, family_id)

      {:error, _reason} ->
        revoke_external_session(session_id, family_id, did)
    end
  end

  @doc """
  Returns true when an admin token hash is configured.
  """
  def configured?, do: is_binary(configured_hash()) and configured_hash() != ""

  defp authenticate_local_browser_session(session_id, family_id, did) do
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

  defp authenticate_external_browser_session(session_id, family_id, did)
       when is_binary(session_id) and is_binary(family_id) and is_binary(did) do
    with {:ok, admin_did} <- configured_did(),
         ^admin_did <- did,
         {:ok, session} <- fetch_external_session(session_id, family_id, did) do
      {:ok, %{did: admin_did, session: session, token_type: :admin_external_oauth_session}}
    else
      {:error, reason} -> {:error, reason}
      _other -> {:error, :invalid_admin_session}
    end
  end

  defp authenticate_external_browser_session(_session_id, _family_id, _did), do: {:error, :invalid_admin_session}

  defp atproto_pds_url(%{"service" => services}) when is_list(services) do
    services
    |> Enum.find(fn
      %{"id" => "#atproto_pds", "serviceEndpoint" => endpoint} when is_binary(endpoint) -> true
      %{"type" => "AtprotoPersonalDataServer", "serviceEndpoint" => endpoint} when is_binary(endpoint) -> true
      _service -> false
    end)
    |> case do
      %{"serviceEndpoint" => endpoint} ->
        endpoint = String.trim_trailing(endpoint, "/")

        with :ok <- SsrfProtection.validate_url(endpoint) do
          {:ok, endpoint}
        end

      _missing ->
        {:error, :pds_not_found}
    end
  end

  defp atproto_pds_url(_document), do: {:error, :pds_not_found}

  defp discover_introspection_endpoint(pds_url) do
    protected_resource_url = pds_url <> "/.well-known/oauth-protected-resource"

    with {:ok, %{"authorization_servers" => [authorization_server | _]}} <- get_json(protected_resource_url),
         :ok <- SsrfProtection.validate_url(authorization_server),
         {:ok, %{"introspection_endpoint" => introspection_endpoint}} <-
           get_json(String.trim_trailing(authorization_server, "/") <> "/.well-known/oauth-authorization-server"),
         :ok <- SsrfProtection.validate_url(introspection_endpoint) do
      {:ok, introspection_endpoint}
    else
      {:error, reason} -> {:error, reason}
      _other -> {:error, :oauth_metadata_not_found}
    end
  end

  defp introspect_token(introspection_endpoint, access_token) do
    opts =
      [
        url: introspection_endpoint,
        form: %{"client_id" => Config.load!().public_url <> "/admin/oauth-client", "token" => access_token},
        redirect: false,
        retry: false,
        receive_timeout: 2_000,
        connect_options: [timeout: 1_000]
      ]
      |> Keyword.merge(oauth_req_options())

    case Req.post(opts) do
      {:ok, %{status: 200, body: body}} when is_map(body) -> {:ok, body}
      {:ok, %{status: 200, body: body}} when is_binary(body) -> Jason.decode(body)
      {:ok, _response} -> {:error, :invalid_oauth_token}
      {:error, _reason} -> {:error, :oauth_introspection_failed}
    end
  end

  defp get_json(url) do
    opts =
      [
        url: url,
        redirect: false,
        retry: false,
        receive_timeout: 2_000,
        connect_options: [timeout: 1_000]
      ]
      |> Keyword.merge(oauth_req_options())

    case Req.get(opts) do
      {:ok, %{status: 200, body: body}} when is_map(body) -> {:ok, body}
      {:ok, %{status: 200, body: body}} when is_binary(body) -> Jason.decode(body)
      {:ok, _response} -> {:error, :oauth_metadata_not_found}
      {:error, _reason} -> {:error, :oauth_metadata_not_found}
    end
  end

  defp create_external_session(did) do
    table = external_session_table()
    now = System.system_time(:second)
    id = random_token(32)
    family_id = Ecto.UUID.generate()
    expires_at = now + @external_session_ttl_seconds
    session = %{id: id, family_id: family_id, did: did, expires_at: expires_at}

    :ets.insert(table, {{id, family_id, did}, session})
    {:ok, %{did: did, session: session, family_id: family_id}}
  end

  defp fetch_external_session(session_id, family_id, did) do
    case :ets.lookup(external_session_table(), {session_id, family_id, did}) do
      [{_key, %{expires_at: expires_at} = session}] ->
        if expires_at > System.system_time(:second), do: {:ok, session}, else: {:error, :expired_admin_session}

      [] ->
        {:error, :invalid_admin_session}
    end
  end

  defp revoke_external_session(session_id, family_id, did) do
    :ets.delete(external_session_table(), {session_id, family_id, did})
    :ok
  end

  defp external_session_table do
    case :ets.whereis(__MODULE__.ExternalSessions) do
      :undefined -> :ets.new(__MODULE__.ExternalSessions, [:named_table, :public, read_concurrency: true])
      table -> table
    end
  end

  defp oauth_req_options do
    :tempest
    |> Application.get_env(__MODULE__, [])
    |> Keyword.get(:oauth_req_options, [])
  end

  defp random_token(bytes), do: bytes |> :crypto.strong_rand_bytes() |> Base.url_encode64(padding: false)

  defp local_admin_account?(did) do
    Account
    |> where([account], account.did == ^did and account.active and account.status == "active")
    |> Repo.exists?()
  end

  defp configured_hash do
    Application.get_env(:tempest, :admin_token_hash) || System.get_env("TEMPEST_ADMIN_TOKEN_HASH")
  end
end
