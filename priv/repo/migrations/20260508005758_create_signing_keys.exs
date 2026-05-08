defmodule Tempest.Repo.Migrations.CreateSigningKeys do
  use Ecto.Migration

  def change do
    create table(:signing_keys) do
      add :account_id, references(:accounts, on_delete: :delete_all), null: false
      add :kid, :text, null: false
      add :public_key_multibase, :text, null: false
      add :private_key_ciphertext, :text, null: false
      add :active, :boolean, null: false, default: true

      timestamps(type: :utc_datetime)
    end

    create index(:signing_keys, [:account_id])
    create unique_index(:signing_keys, [:account_id, :kid])
  end
end
