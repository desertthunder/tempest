defmodule Tempest.Repo.Migrations.AddPersonalBackupOperations do
  use Ecto.Migration

  def change do
    alter table(:personal_backup_accounts) do
      add :manual_lock_token, :text
      add :manual_lock_taken_at, :utc_datetime
      add :manual_lock_expires_at, :utc_datetime
      add :scheduled_backup_enabled, :boolean, null: false, default: false
      add :scheduled_backup_interval_hours, :integer, null: false, default: 24
      add :next_scheduled_backup_at, :utc_datetime
      add :last_scheduled_backup_at, :utc_datetime
    end

    create index(:personal_backup_accounts, [:manual_lock_expires_at])

    create index(:personal_backup_accounts, [:scheduled_backup_enabled, :next_scheduled_backup_at])
  end
end
