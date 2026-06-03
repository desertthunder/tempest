defmodule Tempest.Security do
  @moduledoc """
  Account security helpers for email tokens, MFA, delegated access, and audit events.
  """

  import Ecto.Query

  alias Tempest.Accounts.{Account, Password, Session}
  alias Tempest.Security.{BackupCode, DelegatedAccessGrant, EmailToken, MfaCredential, RateLimiter, SecurityEvent, Totp}
  alias Tempest.Repo

  @email_token_ttl_seconds 30 * 60

  def log_event(%Account{} = account, event_type, metadata \\ %{}) do
    attrs = %{
      account_id: account.id,
      event_type: event_type,
      metadata_json: Jason.encode!(metadata)
    }

    %SecurityEvent{} |> SecurityEvent.changeset(attrs) |> Repo.insert()
  end

  def issue_email_token(%Account{} = account, purpose, email \\ nil) do
    raw = random_token(32)
    email = email || account.email
    now = now()

    attrs = %{
      account_id: account.id,
      purpose: purpose,
      email: email,
      token_hash: hash(raw),
      expires_at: DateTime.add(now, @email_token_ttl_seconds, :second)
    }

    with {:ok, token} <- %EmailToken{} |> EmailToken.changeset(attrs) |> Repo.insert(),
         {:ok, _event} <- log_event(account, "email_token.issued", %{purpose: purpose, email: email}) do
      {:ok, %{token: raw, email_token: token}}
    end
  end

  def consume_email_token(raw, purpose) when is_binary(raw) do
    now = now()

    Repo.transaction(fn ->
      token =
        EmailToken
        |> where([t], t.token_hash == ^hash(raw) and t.purpose == ^purpose)
        |> where([t], is_nil(t.used_at) and t.expires_at > ^now)
        |> preload(:account)
        |> Repo.one()

      case token do
        nil ->
          Repo.rollback(:invalid_token)

        %EmailToken{} = token ->
          token |> Ecto.Changeset.change(%{used_at: now}) |> Repo.update!()

          case purpose do
            "update_email" ->
              token.account |> Ecto.Changeset.change(%{email: token.email}) |> Repo.update!()

            "reset_password" ->
              revoke_sessions!(token.account)

            _other ->
              :ok
          end

          log_event(token.account, "email_token.consumed", %{purpose: purpose})
          token.account
      end
    end)
  end

  def consume_email_token(_raw, _purpose), do: {:error, :invalid_token}

  def start_totp_enrollment(%Account{} = account, label \\ nil) do
    secret = Totp.new_secret()
    label = label || account.handle

    attrs = %{
      account_id: account.id,
      type: "totp",
      label: label,
      secret_ciphertext: secret
    }

    with {:ok, credential} <- %MfaCredential{} |> MfaCredential.changeset(attrs) |> Repo.insert(),
         {:ok, _event} <- log_event(account, "mfa.totp.enrollment_started", %{}) do
      {:ok,
       %{
         credential: credential,
         secret: secret,
         uri: Totp.otpauth_uri(secret, "Tempest", label)
       }}
    end
  end

  def confirm_totp(%Account{} = account, credential_id, code) do
    with %MfaCredential{} = credential <- Repo.get_by(MfaCredential, id: credential_id, account_id: account.id),
         true <- is_nil(credential.disabled_at),
         true <- Totp.valid?(credential.secret_ciphertext, code),
         {:ok, credential} <- credential |> Ecto.Changeset.change(%{confirmed_at: now()}) |> Repo.update(),
         {:ok, backup_codes} <- rotate_backup_codes(account),
         {:ok, _event} <- log_event(account, "mfa.totp.confirmed", %{}) do
      {:ok, %{credential: credential, backup_codes: backup_codes}}
    else
      _error -> {:error, :invalid_totp}
    end
  end

  def verify_totp(%Account{} = account, code) do
    if RateLimiter.check(:totp, account.did) == :ok and valid_totp_for_account?(account, code) do
      log_event(account, "mfa.totp.verified", %{})
      :ok
    else
      {:error, :invalid_totp}
    end
  end

  def use_backup_code(%Account{} = account, code) do
    now = now()

    {count, _rows} =
      BackupCode
      |> where([c], c.account_id == ^account.id and c.code_hash == ^hash(code) and is_nil(c.used_at))
      |> Repo.update_all(set: [used_at: now])

    if count == 1 do
      log_event(account, "mfa.backup_code.used", %{})
      :ok
    else
      {:error, :invalid_backup_code}
    end
  end

  def list_sessions(%Account{} = account) do
    Session
    |> where([s], s.account_id == ^account.id)
    |> order_by([s], desc: s.inserted_at)
    |> Repo.all()
  end

  def revoke_session(%Account{} = account, session_id) do
    now = now()

    {count, _rows} =
      Session
      |> where([s], s.account_id == ^account.id and s.id == ^session_id and is_nil(s.revoked_at))
      |> Repo.update_all(set: [revoked_at: now])

    if count == 1 do
      log_event(account, "session.revoked", %{session_id: session_id})
      :ok
    else
      {:error, :not_found}
    end
  end

  def create_delegation(%Account{} = owner, delegate_did, scope, opts \\ []) do
    attrs = %{
      owner_account_id: owner.id,
      delegate_did: delegate_did,
      scope: scope,
      expires_at: Keyword.get(opts, :expires_at)
    }

    with {:ok, grant} <- %DelegatedAccessGrant{} |> DelegatedAccessGrant.changeset(attrs) |> Repo.insert(),
         {:ok, _event} <- log_event(owner, "delegated_access.created", %{delegate_did: delegate_did, scope: scope}) do
      {:ok, grant}
    end
  end

  def revoke_delegation(%Account{} = owner, grant_id) do
    now = now()

    {count, _rows} =
      DelegatedAccessGrant
      |> where([g], g.owner_account_id == ^owner.id and g.id == ^grant_id and is_nil(g.revoked_at))
      |> Repo.update_all(set: [revoked_at: now])

    if count == 1 do
      log_event(owner, "delegated_access.revoked", %{grant_id: grant_id})
      :ok
    else
      {:error, :not_found}
    end
  end

  def request_password_reset(identifier) do
    identifier = identifier |> to_string() |> String.trim() |> String.downcase()

    case Repo.get_by(Account, email: identifier) || Repo.get_by(Account, handle: identifier) ||
           Repo.get_by(Account, did: identifier) do
      %Account{} = account -> Tempest.Security.Email.deliver_password_reset(account)
      nil -> {:ok, :accepted}
    end
  end

  def request_email_confirmation(%Account{} = account), do: Tempest.Security.Email.deliver_confirmation(account)

  def confirm_email(raw_token), do: consume_email_token(raw_token, "confirm_email")

  def request_email_update(%Account{} = account, new_email) when is_binary(new_email) do
    Tempest.Security.Email.deliver_update(account, new_email)
  end

  def update_email(raw_token), do: consume_email_token(raw_token, "update_email")

  def reset_password(raw_token, new_password) do
    with :ok <- Password.validate(new_password),
         {:ok, account} <- consume_email_token(raw_token, "reset_password") do
      account
      |> Ecto.Changeset.change(%{password_hash: Password.hash(new_password)})
      |> Repo.update()
    end
  end

  defp valid_totp_for_account?(%Account{} = account, code) do
    MfaCredential
    |> where([c], c.account_id == ^account.id and c.type == "totp")
    |> where([c], not is_nil(c.confirmed_at) and is_nil(c.disabled_at))
    |> Repo.all()
    |> Enum.any?(&Totp.valid?(&1.secret_ciphertext, code))
  end

  defp rotate_backup_codes(%Account{} = account) do
    Repo.delete_all(from c in BackupCode, where: c.account_id == ^account.id and is_nil(c.used_at))

    codes = for _ <- 1..10, do: backup_code()

    Enum.each(codes, fn code ->
      %BackupCode{}
      |> BackupCode.changeset(%{account_id: account.id, code_hash: hash(code)})
      |> Repo.insert!()
    end)

    {:ok, codes}
  end

  defp revoke_sessions!(%Account{} = account) do
    Session
    |> where([s], s.account_id == ^account.id and is_nil(s.revoked_at))
    |> Repo.update_all(set: [revoked_at: now()])
  end

  defp backup_code do
    10 |> :crypto.strong_rand_bytes() |> Base.encode32(case: :lower, padding: false)
  end

  defp random_token(bytes), do: bytes |> :crypto.strong_rand_bytes() |> Base.url_encode64(padding: false)
  defp hash(value), do: :crypto.hash(:sha256, value) |> Base.encode16(case: :lower)
  defp now, do: DateTime.utc_now() |> DateTime.truncate(:second)
end
