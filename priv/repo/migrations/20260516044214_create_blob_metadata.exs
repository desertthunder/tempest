defmodule Tempest.Repo.Migrations.CreateBlobMetadata do
  use Ecto.Migration

  def change do
    execute(
      """
      CREATE TABLE IF NOT EXISTS blob_metadata (
        did TEXT NOT NULL,
        cid TEXT NOT NULL,
        mime_type TEXT NOT NULL,
        size INTEGER NOT NULL CHECK (size >= 0),
        state TEXT NOT NULL CHECK (state IN ('temp', 'public')),
        inserted_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        temp_expires_at TEXT,
        referenced_at TEXT,
        PRIMARY KEY (did, cid)
      )
      """,
      "DROP TABLE IF EXISTS blob_metadata"
    )

    create_if_not_exists index(:blob_metadata, [:did, :state, :cid])
    create_if_not_exists index(:blob_metadata, [:state, :temp_expires_at])
  end
end
