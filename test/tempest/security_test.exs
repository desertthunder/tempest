defmodule Tempest.SecurityTest do
  use Tempest.DataCase, async: false

  alias Tempest.Accounts
  alias Tempest.Accounts.{Session, Tokens}
  alias Tempest.Security
  alias Tempest.Security.{BackupCode, DelegatedAccessGrant, EmailToken, MfaCredential, RateLimiter, SecurityEvent, Totp}

  import Ecto.Query

  setup do
    RateLimiter.reset!()

    {:ok, response} =
      Accounts.create_account(%{
        "handle" => "security-#{System.unique_integer([:positive])}.test",
        "email" => "security-#{System.unique_integer([:positive])}@example.com",
        "password" => "correct horse battery staple"
      })

    account = Tempest.Repo.get_by!(Tempest.Accounts.Account, did: response["did"])
    {:ok, account: account}
  end

  test "email tokens are hashed, single-use, and logged", %{account: account} do
    {:ok, %{token: raw}} = Security.issue_email_token(account, "confirm_email")

    refute Tempest.Repo.get_by(EmailToken, token_hash: raw)
    assert Tempest.Repo.get_by(EmailToken, token_hash: hash(raw))

    assert {:ok, _account} = Security.consume_email_token(raw, "confirm_email")
    assert {:error, :invalid_token} = Security.consume_email_token(raw, "confirm_email")

    assert Tempest.Repo.exists?(from e in SecurityEvent, where: e.account_id == ^account.id)
  end

  test "password reset updates password and revokes sessions", %{account: account} do
    {:ok, login} = Accounts.create_session(account.handle, "correct horse battery staple")
    {:ok, %{token: raw}} = Security.issue_email_token(account, "reset_password")

    assert {:ok, _account} = Security.reset_password(raw, "new correct horse battery staple")
    assert {:error, :invalid_token} = Accounts.authenticate_refresh(login["refreshJwt"])
    assert {:ok, _login} = Accounts.create_session(account.handle, "new correct horse battery staple")
  end

  test "totp enrollment confirms with current code and creates backup codes", %{account: account} do
    {:ok, %{credential: credential, secret: secret, uri: uri}} = Security.start_totp_enrollment(account)

    assert uri =~ "otpauth://totp/"
    assert %MfaCredential{confirmed_at: nil} = Tempest.Repo.get!(MfaCredential, credential.id)

    code = Totp.code(secret)
    assert {:ok, %{backup_codes: backup_codes}} = Security.confirm_totp(account, credential.id, code)
    assert length(backup_codes) == 10
    assert :ok = Security.verify_totp(account, code)

    [backup | _] = backup_codes
    assert :ok = Security.use_backup_code(account, backup)
    assert {:error, :invalid_backup_code} = Security.use_backup_code(account, backup)
    assert Tempest.Repo.aggregate(from(c in BackupCode, where: c.account_id == ^account.id), :count) == 10
  end

  test "session inventory and remote revoke", %{account: account} do
    {:ok, login} = Accounts.create_session(account.handle, "correct horse battery staple")
    sessions = Security.list_sessions(account)
    session = Enum.find(sessions, &(&1.token_hash == Tokens.refresh_token_hash(login["refreshJwt"])))

    assert %Session{} = session
    assert :ok = Security.revoke_session(account, session.id)
    assert {:error, :invalid_token} = Accounts.authenticate_refresh(login["refreshJwt"])
  end

  test "delegated access grants can be revoked", %{account: account} do
    assert {:ok, grant} = Security.create_delegation(account, "did:plc:delegate", "atproto")
    assert %DelegatedAccessGrant{} = Tempest.Repo.get(DelegatedAccessGrant, grant.id)
    assert :ok = Security.revoke_delegation(account, grant.id)
    assert Tempest.Repo.get!(DelegatedAccessGrant, grant.id).revoked_at
  end

  test "rate limiter returns rate_limited after configured attempts" do
    assert :ok = RateLimiter.check(:login, "ratelimit", limit: 1, window_ms: 60_000)
    assert {:error, :rate_limited} = RateLimiter.check(:login, "ratelimit", limit: 1, window_ms: 60_000)
  end

  defp hash(value), do: :crypto.hash(:sha256, value) |> Base.encode16(case: :lower)
end
