defmodule Tempest.Repo.Migrations.AddOauthPrivateKeyJwtClientAuth do
  use Ecto.Migration

  def change do
    alter table(:oauth_par_requests) do
      add :client_auth_method, :text, null: false, default: "none"
      add :client_auth_kid, :text
      add :client_auth_alg, :text
      add :client_auth_jkt, :text
    end

    alter table(:oauth_authorization_codes) do
      add :client_auth_method, :text, null: false, default: "none"
      add :client_auth_kid, :text
      add :client_auth_alg, :text
      add :client_auth_jkt, :text
    end

    alter table(:oauth_tokens) do
      add :client_auth_method, :text, null: false, default: "none"
      add :client_auth_kid, :text
      add :client_auth_alg, :text
      add :client_auth_jkt, :text
    end

    create table(:oauth_client_assertions) do
      add :client_id, :text, null: false
      add :jti_hash, :text, null: false
      add :expires_at, :utc_datetime, null: false

      timestamps(type: :utc_datetime)
    end

    create unique_index(:oauth_client_assertions, [:client_id, :jti_hash])
    create index(:oauth_client_assertions, [:expires_at])
  end
end
