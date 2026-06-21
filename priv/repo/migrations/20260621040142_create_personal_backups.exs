defmodule Tempest.Repo.Migrations.CreatePersonalBackups do
  use Ecto.Migration

  def change do
    create table(:personal_backup_accounts) do
      add :label, :text, null: false
      add :did, :text, null: false
      add :handle, :text, null: false
      add :source_pds_url, :text, null: false
      add :pinned_source_pds_url, :text
      add :credential_state, :text, null: false, default: "none"
      add :last_checked_at, :utc_datetime
      add :last_success_at, :utc_datetime
      add :last_snapshot_id, :integer
      add :status, :text, null: false, default: "pending"
      add :status_reason, :text

      timestamps(type: :utc_datetime)
    end

    create unique_index(:personal_backup_accounts, [:did])
    create index(:personal_backup_accounts, [:handle])
    create index(:personal_backup_accounts, [:status])

    create table(:personal_backup_credentials) do
      add :account_id, references(:personal_backup_accounts, on_delete: :delete_all), null: false
      add :mode, :text, null: false, default: "none"
      add :secret_ciphertext, :text
      add :secret_hint, :text
      add :verified_at, :utc_datetime
      add :deleted_at, :utc_datetime

      timestamps(type: :utc_datetime)
    end

    create unique_index(:personal_backup_credentials, [:account_id])
    create index(:personal_backup_credentials, [:mode])

    create table(:personal_backup_retention_settings) do
      add :account_id, references(:personal_backup_accounts, on_delete: :delete_all), null: false
      add :policy, :text, null: false, default: "keep_last_n"
      add :keep_last, :integer, null: false, default: 3
      add :keep_days, :integer

      timestamps(type: :utc_datetime)
    end

    create unique_index(:personal_backup_retention_settings, [:account_id])

    create table(:personal_backup_runs) do
      add :account_id, references(:personal_backup_accounts, on_delete: :delete_all), null: false
      add :snapshot_id, :integer
      add :status, :text, null: false, default: "pending"
      add :kind, :text, null: false, default: "manual"
      add :started_at, :utc_datetime
      add :finished_at, :utc_datetime
      add :error_reason, :text
      add :metadata, :map, null: false, default: %{}

      timestamps(type: :utc_datetime)
    end

    create index(:personal_backup_runs, [:account_id])
    create index(:personal_backup_runs, [:status])

    create table(:personal_backup_snapshots) do
      add :account_id, references(:personal_backup_accounts, on_delete: :delete_all), null: false
      add :run_id, references(:personal_backup_runs, on_delete: :nilify_all)
      add :status, :text, null: false, default: "pending"
      add :storage_key, :text, null: false
      add :manifest_path, :text
      add :repo_car_path, :text
      add :commit_cid, :text
      add :rev, :text
      add :source_pds_url, :text, null: false
      add :handle, :text, null: false
      add :did, :text, null: false
      add :byte_size, :integer, null: false, default: 0
      add :sha256, :text
      add :pinned, :boolean, null: false, default: false
      add :completed_at, :utc_datetime
      add :verification_status, :text, null: false, default: "pending"
      add :verification_report_path, :text

      timestamps(type: :utc_datetime)
    end

    create index(:personal_backup_snapshots, [:account_id])
    create index(:personal_backup_snapshots, [:status])
    create unique_index(:personal_backup_snapshots, [:storage_key])

    create table(:personal_backup_blobs) do
      add :snapshot_id, references(:personal_backup_snapshots, on_delete: :delete_all),
        null: false

      add :cid, :text, null: false
      add :path, :text
      add :byte_size, :integer, null: false, default: 0
      add :sha256, :text
      add :status, :text, null: false, default: "pending"
      add :error_reason, :text

      timestamps(type: :utc_datetime)
    end

    create unique_index(:personal_backup_blobs, [:snapshot_id, :cid])
    create index(:personal_backup_blobs, [:status])
  end
end
