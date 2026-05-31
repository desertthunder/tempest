defmodule Tempest.Repo.Migrations.CreateSecurityMfaAndDelegation do
  use Ecto.Migration

  def change do
    create table(:security_events) do
      add :account_id, references(:accounts, on_delete: :delete_all), null: false
      add :event_type, :text, null: false
      add :metadata_json, :text, null: false, default: "{}"

      timestamps(type: :utc_datetime, updated_at: false)
    end

    create index(:security_events, [:account_id])
    create index(:security_events, [:event_type])

    create table(:email_tokens) do
      add :account_id, references(:accounts, on_delete: :delete_all), null: false
      add :purpose, :text, null: false
      add :email, :text, null: false
      add :token_hash, :text, null: false
      add :expires_at, :utc_datetime, null: false
      add :used_at, :utc_datetime

      timestamps(type: :utc_datetime)
    end

    create unique_index(:email_tokens, [:token_hash])
    create index(:email_tokens, [:account_id, :purpose])

    create table(:mfa_credentials) do
      add :account_id, references(:accounts, on_delete: :delete_all), null: false
      add :type, :text, null: false
      add :label, :text
      add :secret_ciphertext, :text
      add :confirmed_at, :utc_datetime
      add :disabled_at, :utc_datetime
      add :last_used_at, :utc_datetime

      timestamps(type: :utc_datetime)
    end

    create index(:mfa_credentials, [:account_id, :type])

    create table(:backup_codes) do
      add :account_id, references(:accounts, on_delete: :delete_all), null: false
      add :code_hash, :text, null: false
      add :used_at, :utc_datetime

      timestamps(type: :utc_datetime)
    end

    create unique_index(:backup_codes, [:code_hash])
    create index(:backup_codes, [:account_id])

    create table(:delegated_access_grants) do
      add :owner_account_id, references(:accounts, on_delete: :delete_all), null: false
      add :delegate_did, :text, null: false
      add :scope, :text, null: false
      add :expires_at, :utc_datetime
      add :revoked_at, :utc_datetime

      timestamps(type: :utc_datetime)
    end

    create index(:delegated_access_grants, [:owner_account_id])
    create index(:delegated_access_grants, [:delegate_did])
  end
end
