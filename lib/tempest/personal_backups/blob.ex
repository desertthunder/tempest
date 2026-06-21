defmodule Tempest.PersonalBackups.Blob do
  @moduledoc """
  Blob metadata recorded for a personal backup snapshot.
  """

  use Ecto.Schema

  import Ecto.Changeset

  alias Tempest.PersonalBackups.Snapshot

  @statuses ~w(pending stored missing failed)

  schema "personal_backup_blobs" do
    field :cid, :string
    field :path, :string
    field :byte_size, :integer, default: 0
    field :sha256, :string
    field :status, :string, default: "pending"
    field :error_reason, :string

    belongs_to :snapshot, Snapshot

    timestamps(type: :utc_datetime)
  end

  def changeset(blob, attrs) do
    blob
    |> cast(attrs, [:snapshot_id, :cid, :path, :byte_size, :sha256, :status, :error_reason])
    |> validate_required([:snapshot_id, :cid, :status])
    |> validate_number(:byte_size, greater_than_or_equal_to: 0)
    |> validate_inclusion(:status, @statuses)
    |> unique_constraint([:snapshot_id, :cid])
  end
end
