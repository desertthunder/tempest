defmodule Tempest.Accounts do
  @moduledoc """
  Local accounts and session lifecycle.
  """

  import Ecto.Query

  alias Tempest.Accounts.{Account, AuthContext, Password, Session, Tokens}
  alias Tempest.Identity
  alias Tempest.Repo

  @public_fields [:did, :handle, :email, :active, :status]

  def create_account(attrs) when is_map(attrs) do
    with {:ok, password} <- fetch_string(attrs, "password"),
         :ok <- Password.validate(password) do
      password_hash = Password.hash(password)
      did = Map.get(attrs, "did") || Identity.generate_hosted_did()

      account_attrs =
        attrs
        |> Map.take(["handle", "email"])
        |> Map.put("did", did)
        |> Map.put("password_hash", password_hash)
        |> Map.put("active", true)
        |> Map.put("status", "active")

      refresh_token = Tokens.new_refresh_token()

      Repo.transaction(fn ->
        with {:ok, account} <- Repo.insert(Account.create_changeset(%Account{}, account_attrs)),
             {:ok, _signing_key} <- Identity.create_initial_signing_key(account),
             {:ok, session} <-
               Repo.insert(new_session_changeset(account, refresh_token, Ecto.UUID.generate())) do
          {account, session}
        else
          {:error, changeset} -> Repo.rollback({:validation, changeset})
        end
      end)
      |> case do
        {:ok, {account, session}} ->
          :ok =
            Tempest.Sequencer.insert_placeholder(account.did, "identity.account.create", %{"handle" => account.handle})

          {:ok, session_response(account, session, refresh_token)}

        {:error, {:validation, changeset}} ->
          {:error, :validation, changeset}
      end
    else
      {:error, reason} -> {:error, :validation, reason}
    end
  end

  def create_session(identifier, password) when is_binary(identifier) and is_binary(password) do
    identifier = normalize_identifier(identifier)

    account =
      Account
      |> where([a], a.handle == ^identifier or a.email == ^identifier or a.did == ^identifier)
      |> Repo.one()

    cond do
      is_nil(account) ->
        Password.verify(password, nil)
        {:error, :invalid_credentials}

      not account.active ->
        {:error, :inactive_account}

      account.status != "active" ->
        {:error, :inactive_account}

      Password.verify(password, account.password_hash) ->
        create_session_for_account(account)

      true ->
        {:error, :invalid_credentials}
    end
  end

  def create_session(_identifier, _password), do: {:error, :invalid_credentials}

  def refresh_session(%AuthContext{token_type: :refresh, account: account, session: session}) do
    now = now()

    Repo.transaction(fn ->
      fresh_session = Repo.get!(Session, session.id)

      cond do
        fresh_session.revoked_at || fresh_session.rotated_at ->
          revoke_session_family!(fresh_session.family_id, now, reuse?: true)
          Repo.rollback(:reused_refresh_token)

        DateTime.compare(fresh_session.expires_at, now) != :gt ->
          revoke_session_family!(fresh_session.family_id, now)
          Repo.rollback(:expired_refresh_token)

        true ->
          refresh_token = Tokens.new_refresh_token()

          fresh_session
          |> Session.rotate_changeset(%{revoked_at: now, rotated_at: now})
          |> Repo.update!()

          new_session =
            %Session{}
            |> Session.create_changeset(%{
              account_id: account.id,
              token_hash: Tokens.refresh_token_hash(refresh_token),
              family_id: fresh_session.family_id,
              expires_at: Tokens.refresh_expires_at(now)
            })
            |> Repo.insert!()

          session_response(account, new_session, refresh_token)
      end
    end)
    |> case do
      {:ok, response} -> {:ok, response}
      {:error, reason} -> {:error, reason}
    end
  end

  def delete_session(%AuthContext{token_type: :refresh, session: session}) do
    now = now()

    Session
    |> where([s], s.family_id == ^session.family_id and is_nil(s.revoked_at))
    |> Repo.update_all(set: [revoked_at: now])

    :ok
  end

  def get_session(%AuthContext{token_type: :access, account: account}) do
    {:ok, account_response(account)}
  end

  def authenticate_access(token) do
    with {:ok, %{"typ" => "access", "account_id" => account_id, "session_id" => session_id} = claims} <-
           Tokens.verify_access_token(token),
         %Account{} = account <- Repo.get(Account, account_id),
         %Session{} = session <- Repo.get(Session, session_id),
         :ok <- ensure_access_session(account, session) do
      {:ok, %AuthContext{account: account, session: session, token_type: :access, access_claims: claims}}
    else
      {:error, reason} -> {:error, reason}
      nil -> {:error, :invalid_token}
      _other -> {:error, :invalid_token}
    end
  end

  def authenticate_refresh(token) when is_binary(token) do
    session =
      Session
      |> where([s], s.token_hash == ^Tokens.refresh_token_hash(token))
      |> preload(:account)
      |> Repo.one()

    now = now()

    cond do
      is_nil(session) ->
        {:error, :invalid_token}

      session.revoked_at || session.rotated_at ->
        revoke_session_family!(session.family_id, now, reuse?: true)
        {:error, :invalid_token}

      DateTime.compare(session.expires_at, now) != :gt ->
        revoke_session_family!(session.family_id, now)
        {:error, :expired_token}

      not session.account.active or session.account.status != "active" ->
        {:error, :inactive_account}

      true ->
        {:ok, %AuthContext{account: session.account, session: session, token_type: :refresh}}
    end
  end

  def authenticate_refresh(_token), do: {:error, :invalid_token}

  def account_response(%Account{} = account) do
    account
    |> Map.take(@public_fields)
    |> Map.new(fn {key, value} -> {Atom.to_string(key), value} end)
  end

  def changeset_errors(%Ecto.Changeset{} = changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {message, opts} ->
      Regex.replace(~r"%{(\w+)}", message, fn _, key ->
        opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
      end)
    end)
  end

  defp create_session_for_account(%Account{} = account) do
    refresh_token = Tokens.new_refresh_token()

    account
    |> new_session_changeset(refresh_token, Ecto.UUID.generate())
    |> Repo.insert()
    |> case do
      {:ok, session} -> {:ok, session_response(account, session, refresh_token)}
      {:error, changeset} -> {:error, :validation, changeset}
    end
  end

  defp new_session_changeset(%Account{} = account, refresh_token, family_id) do
    %Session{}
    |> Session.create_changeset(%{
      account_id: account.id,
      token_hash: Tokens.refresh_token_hash(refresh_token),
      family_id: family_id,
      expires_at: Tokens.refresh_expires_at()
    })
  end

  defp session_response(%Account{} = account, %Session{} = session, refresh_token) do
    account
    |> account_response()
    |> Map.merge(%{
      "accessJwt" => Tokens.sign_access_token(account, session),
      "refreshJwt" => refresh_token,
      "active" => account.active
    })
  end

  defp revoke_session_family!(family_id, now, opts \\ []) do
    attrs =
      if Keyword.get(opts, :reuse?, false) do
        [revoked_at: now, reuse_detected_at: now]
      else
        [revoked_at: now]
      end

    Session
    |> where([s], s.family_id == ^family_id and is_nil(s.revoked_at))
    |> Repo.update_all(set: attrs)
  end

  defp ensure_access_session(%Account{} = account, %Session{} = session) do
    now = now()

    cond do
      session.account_id != account.id ->
        {:error, :invalid_token}

      session.revoked_at ->
        {:error, :invalid_token}

      DateTime.compare(session.expires_at, now) != :gt ->
        {:error, :expired_token}

      not account.active or account.status != "active" ->
        {:error, :inactive_account}

      true ->
        :ok
    end
  end

  defp fetch_string(attrs, key) do
    case Map.get(attrs, key) do
      value when is_binary(value) and value != "" -> {:ok, value}
      _value -> {:error, "#{key} is required"}
    end
  end

  defp normalize_identifier(identifier) do
    identifier
    |> String.trim()
    |> String.downcase()
  end

  defp now do
    DateTime.utc_now()
    |> DateTime.truncate(:second)
  end
end
