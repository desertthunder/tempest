defmodule Tempest.Repo.Migrations.CreatePlcOperationTokens do
  use Ecto.Migration

  def change do
    create table(:plc_operation_tokens) do
      add :account_id, references(:accounts, on_delete: :delete_all), null: false
      add :token_hash, :string, null: false
      add :expires_at, :utc_datetime, null: false
      add :used_at, :utc_datetime

      timestamps(type: :utc_datetime)
    end

    create unique_index(:plc_operation_tokens, [:token_hash])
    create index(:plc_operation_tokens, [:account_id])
    create index(:plc_operation_tokens, [:account_id, :used_at])
  end
end
