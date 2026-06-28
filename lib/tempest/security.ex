defmodule Tempest.Security do
  @moduledoc """
  Account security helpers for email tokens, MFA, delegated access, and audit events.
  """

  import Ecto.Query

  alias Tempest.Accounts.{Account, AppPassword, Password, Session}
  alias Tempest.OAuth.Token

  alias Tempest.Security.{
    BackupCode,
    DelegatedAccessGrant,
    EmailToken,
    MfaCredential,
    PlcOperationToken,
    RateLimiter,
    SecurityEvent,
    Totp
  }

  alias Tempest.Repo

  @email_token_ttl_seconds 30 * 60
  @plc_operation_token_ttl_seconds 10 * 60

  @doc """
  Records a security audit event for an account.
  """
  def log_event(%Account{} = account, event_type, metadata \\ %{}) do
    attrs = %{
      account_id: account.id,
      event_type: event_type,
      metadata_json: Jason.encode!(metadata)
    }

    %SecurityEvent{} |> SecurityEvent.changeset(attrs) |> Repo.insert()
  end

  @doc """
  Issues a short-lived email token for confirmation, email update, or password reset flows.
  """
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

  @doc """
  Consumes a valid email token for the expected purpose.

  Some purposes have side effects: `update_email` updates the account email and
  `reset_password` revokes existing sessions before the caller stores the new
  password hash.

  When `expected_email` is given, the token's stored email must match it before
  consumption.

  This supports the ATProto-shaped `{email, token}` calls used by `confirmEmail`
  and `updateEmail` so a token issued for one address cannot be replayed against
  a different one.
  """
  def consume_email_token(raw, purpose, expected_email \\ nil)

  def consume_email_token(raw, purpose, expected_email) when is_binary(raw) do
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
          if email_matches?(token, expected_email) do
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
          else
            Repo.rollback(:invalid_token)
          end
      end
    end)
  end

  def consume_email_token(_raw, _purpose, _expected_email), do: {:error, :invalid_token}

  @doc """
  Starts TOTP enrollment and returns the plaintext secret plus an otpauth URI.
  """
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

  @doc """
  Confirms a pending TOTP credential and rotates backup codes.
  """
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

  @doc """
  Verifies a confirmed TOTP code for an account with rate limiting.
  """
  def verify_totp(%Account{} = account, code) do
    if RateLimiter.check(:totp, account.did) == :ok and valid_totp_for_account?(account, code) do
      log_event(account, "mfa.totp.verified", %{})
      :ok
    else
      {:error, :invalid_totp}
    end
  end

  @doc """
  Marks one backup code as used if it matches an unused stored hash.
  """
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

  @doc """
  Lists account sessions newest first.
  """
  def list_sessions(%Account{} = account) do
    Session
    |> where([s], s.account_id == ^account.id)
    |> order_by([s], desc: s.inserted_at)
    |> Repo.all()
  end

  @doc """
  Revokes one active account session.
  """
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

  @doc """
  Creates a delegated-access grant from an owner account to another DID.
  """
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

  @doc """
  Revokes an active delegated-access grant owned by the account.
  """
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

  @doc """
  Returns all security-control records shown by the operator account security UI.
  """
  def account_security_inventory(%Account{} = account) do
    %{
      sessions: list_sessions(account),
      oauth_grants: list_oauth_grants(account),
      app_passwords: list_app_password_records(account),
      delegated_access: list_delegations(account),
      mfa_credentials: list_mfa_credentials(account),
      backup_codes: list_backup_code_summaries(account),
      security_events: list_security_events(account, limit: 50)
    }
  end

  @doc """
  Lists OAuth grants issued to the account.
  """
  def list_oauth_grants(%Account{} = account) do
    Token
    |> where([t], t.account_id == ^account.id)
    |> order_by([t], desc: t.inserted_at)
    |> Repo.all()
  end

  @doc """
  Lists app-password records for the account.
  """
  def list_app_password_records(%Account{} = account) do
    AppPassword
    |> where([p], p.account_id == ^account.id)
    |> order_by([p], desc: p.inserted_at)
    |> Repo.all()
  end

  @doc """
  Lists delegated-access grants owned by the account.
  """
  def list_delegations(%Account{} = account) do
    DelegatedAccessGrant
    |> where([g], g.owner_account_id == ^account.id)
    |> order_by([g], desc: g.inserted_at)
    |> Repo.all()
  end

  @doc """
  Lists MFA credentials for the account.
  """
  def list_mfa_credentials(%Account{} = account) do
    MfaCredential
    |> where([c], c.account_id == ^account.id)
    |> order_by([c], desc: c.inserted_at)
    |> Repo.all()
  end

  @doc """
  Lists backup-code metadata without exposing backup-code plaintext.
  """
  def list_backup_code_summaries(%Account{} = account) do
    BackupCode
    |> where([c], c.account_id == ^account.id)
    |> order_by([c], asc: c.id)
    |> Repo.all()
    |> Enum.map(fn code ->
      %{
        id: code.id,
        used?: not is_nil(code.used_at),
        used_at: code.used_at,
        inserted_at: code.inserted_at
      }
    end)
  end

  @doc """
  Lists recent security events for the account.
  """
  def list_security_events(%Account{} = account, opts \\ []) do
    limit = Keyword.get(opts, :limit, 50)

    SecurityEvent
    |> where([e], e.account_id == ^account.id)
    |> order_by([e], desc: e.inserted_at)
    |> limit(^limit)
    |> Repo.all()
  end

  @doc """
  Verifies an account password using the same constant-time fallback behavior as login.
  """
  def verify_account_password(%Account{} = account, password) when is_binary(password) do
    if Password.verify(password, account.password_hash), do: :ok, else: {:error, :invalid_password}
  end

  def verify_account_password(%Account{} = account, _password) do
    Password.verify(nil, account.password_hash)
    {:error, :invalid_password}
  end

  @doc """
  Issues a short-lived token that authorizes one PLC operation signature.
  """
  def issue_plc_operation_token(%Account{} = account) do
    raw = random_token(32)

    attrs = %{
      account_id: account.id,
      token_hash: hash(raw),
      expires_at: DateTime.add(now(), @plc_operation_token_ttl_seconds, :second)
    }

    with {:ok, token} <- %PlcOperationToken{} |> PlcOperationToken.changeset(attrs) |> Repo.insert(),
         {:ok, _event} <- log_event(account, "plc_operation_signature.requested", %{token_id: token.id}) do
      {:ok, %{token: raw, plc_operation_token: token}}
    end
  end

  @doc """
  Consumes a valid PLC operation token for the account.
  """
  def consume_plc_operation_token(%Account{} = account, raw) when is_binary(raw) do
    now = now()

    Repo.transaction(fn ->
      token =
        PlcOperationToken
        |> where([t], t.account_id == ^account.id and t.token_hash == ^hash(raw))
        |> where([t], is_nil(t.used_at) and t.expires_at > ^now)
        |> Repo.one()

      case token do
        nil ->
          Repo.rollback(:invalid_token)

        %PlcOperationToken{} = token ->
          token |> Ecto.Changeset.change(%{used_at: now}) |> Repo.update!()
          log_event(account, "plc_operation_signature.token_consumed", %{token_id: token.id})
          token
      end
    end)
  end

  def consume_plc_operation_token(%Account{} = _account, _raw), do: {:error, :invalid_token}

  @doc """
  Starts a password reset email flow without revealing whether the identifier exists.
  """
  def request_password_reset(identifier) do
    identifier = identifier |> to_string() |> String.trim() |> String.downcase()

    case Repo.get_by(Account, email: identifier) || Repo.get_by(Account, handle: identifier) ||
           Repo.get_by(Account, did: identifier) do
      %Account{} = account -> Tempest.Security.Email.deliver_password_reset(account)
      nil -> {:ok, :accepted}
    end
  end

  @doc """
  Sends an email-confirmation token to the account's current email address.
  """
  def request_email_confirmation(%Account{} = account), do: Tempest.Security.Email.deliver_confirmation(account)

  @doc """
  Confirms the account email associated with an email-confirmation token.

  Accepts both token-only calls and ATProto-shaped `{email, token}` calls. When
  `email` is given, it must match the account email associated with the token.
  """
  def confirm_email(raw_token, email \\ nil),
    do: consume_email_token(raw_token, "confirm_email", email)

  @doc """
  Sends an email-update token to a new email address.
  """
  def request_email_update(%Account{} = account, new_email) when is_binary(new_email) do
    Tempest.Security.Email.deliver_update(account, new_email)
  end

  @doc """
  Applies a pending email update token.

  Accepts `{email, token}`: the token must be an `update_email` token whose
  stored target email matches the requested email.
  """
  def update_email(raw_token, email \\ nil),
    do: consume_email_token(raw_token, "update_email", email)

  @doc """
  Resets an account password through a valid reset token.
  """
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

  # When expected_email is nil, no email match is required (token-only calls).
  # When given, compare case-insensitively against the token's stored email so
  # ATProto-shaped {email, token} calls reject tokens issued for a different
  # target address.
  defp email_matches?(_token, nil), do: true

  defp email_matches?(%EmailToken{email: token_email}, expected_email) do
    String.downcase(token_email) == String.downcase(expected_email)
  end
end
