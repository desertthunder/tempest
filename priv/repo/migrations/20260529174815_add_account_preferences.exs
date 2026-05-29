defmodule Tempest.Repo.Migrations.AddAccountPreferences do
  use Ecto.Migration

  def change do
    alter table(:accounts) do
      add :preferences_json, :text, null: false, default: "[]"
    end
  end
end
