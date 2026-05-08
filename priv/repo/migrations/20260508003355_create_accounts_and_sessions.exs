defmodule Tempest.Repo.Migrations.CreateAccountsAndSessions do
  use Ecto.Migration

  def change do
    create table(:accounts) do
      add :did, :text, null: false
      add :handle, :text, null: false
      add :email, :text, null: false
      add :password_hash, :text, null: false
      add :active, :boolean, null: false, default: true
      add :status, :text, null: false, default: "active"

      timestamps(type: :utc_datetime)
    end

    create unique_index(:accounts, [:did])
    create unique_index(:accounts, [:handle])
    create unique_index(:accounts, [:email])

    create table(:sessions) do
      add :account_id, references(:accounts, on_delete: :delete_all), null: false
      add :token_hash, :text, null: false
      add :family_id, :text, null: false
      add :expires_at, :utc_datetime, null: false
      add :revoked_at, :utc_datetime
      add :rotated_at, :utc_datetime
      add :reuse_detected_at, :utc_datetime

      timestamps(type: :utc_datetime)
    end

    create unique_index(:sessions, [:token_hash])
    create index(:sessions, [:account_id])
    create index(:sessions, [:family_id])
  end
end
