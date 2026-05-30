defmodule Tempest.Repo.Migrations.CreateOauthAndAppPasswords do
  use Ecto.Migration

  def change do
    create table(:oauth_dpop_nonces) do
      add :nonce_hash, :text, null: false
      add :expires_at, :utc_datetime, null: false
      add :used_at, :utc_datetime

      timestamps(type: :utc_datetime)
    end

    create unique_index(:oauth_dpop_nonces, [:nonce_hash])
    create index(:oauth_dpop_nonces, [:expires_at])

    create table(:oauth_par_requests) do
      add :request_uri, :text, null: false
      add :client_id, :text, null: false
      add :redirect_uri, :text, null: false
      add :scope, :text, null: false
      add :state, :text
      add :code_challenge, :text, null: false
      add :code_challenge_method, :text, null: false
      add :dpop_jkt, :text, null: false
      add :expires_at, :utc_datetime, null: false
      add :used_at, :utc_datetime

      timestamps(type: :utc_datetime)
    end

    create unique_index(:oauth_par_requests, [:request_uri])
    create index(:oauth_par_requests, [:client_id])

    create table(:oauth_authorization_codes) do
      add :code_hash, :text, null: false
      add :account_id, references(:accounts, on_delete: :delete_all), null: false
      add :par_request_id, references(:oauth_par_requests, on_delete: :delete_all), null: false
      add :client_id, :text, null: false
      add :redirect_uri, :text, null: false
      add :scope, :text, null: false
      add :code_challenge, :text, null: false
      add :dpop_jkt, :text, null: false
      add :expires_at, :utc_datetime, null: false
      add :used_at, :utc_datetime
      add :revoked_at, :utc_datetime

      timestamps(type: :utc_datetime)
    end

    create unique_index(:oauth_authorization_codes, [:code_hash])
    create index(:oauth_authorization_codes, [:account_id])

    create table(:oauth_tokens) do
      add :access_token_hash, :text, null: false
      add :refresh_token_hash, :text
      add :account_id, references(:accounts, on_delete: :delete_all), null: false
      add :client_id, :text, null: false
      add :scope, :text, null: false
      add :dpop_jkt, :text, null: false
      add :expires_at, :utc_datetime, null: false
      add :revoked_at, :utc_datetime
      add :rotated_at, :utc_datetime

      timestamps(type: :utc_datetime)
    end

    create unique_index(:oauth_tokens, [:access_token_hash])
    create unique_index(:oauth_tokens, [:refresh_token_hash])
    create index(:oauth_tokens, [:account_id])

    create table(:app_passwords) do
      add :account_id, references(:accounts, on_delete: :delete_all), null: false
      add :name, :text, null: false
      add :token_hash, :text, null: false
      add :scope, :text, null: false
      add :last_used_at, :utc_datetime
      add :revoked_at, :utc_datetime

      timestamps(type: :utc_datetime)
    end

    create unique_index(:app_passwords, [:token_hash])
    create index(:app_passwords, [:account_id])
  end
end
