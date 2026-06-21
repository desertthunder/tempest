defmodule Tempest.PersonalBackups.Snapshot do
  @moduledoc """
  Immutable snapshot metadata for an external account backup.
  """

  use Ecto.Schema

  import Ecto.Changeset

  alias Tempest.PersonalBackups.{Account, Blob, Run}

  @statuses ~w(pending complete incomplete failed)
  @verification_statuses ~w(pending ok warning failed)

  schema "personal_backup_snapshots" do
    field :status, :string, default: "pending"
    field :storage_key, :string
    field :manifest_path, :string
    field :repo_car_path, :string
    field :commit_cid, :string
    field :rev, :string
    field :source_pds_url, :string
    field :handle, :string
    field :did, :string
    field :byte_size, :integer, default: 0
    field :sha256, :string
    field :pinned, :boolean, default: false
    field :completed_at, :utc_datetime
    field :verification_status, :string, default: "pending"
    field :verification_report_path, :string

    belongs_to :account, Account
    belongs_to :run, Run
    has_many :blobs, Blob

    timestamps(type: :utc_datetime)
  end

  def changeset(snapshot, attrs) do
    snapshot
    |> cast(attrs, [
      :account_id,
      :run_id,
      :status,
      :storage_key,
      :manifest_path,
      :repo_car_path,
      :commit_cid,
      :rev,
      :source_pds_url,
      :handle,
      :did,
      :byte_size,
      :sha256,
      :pinned,
      :completed_at,
      :verification_status,
      :verification_report_path
    ])
    |> validate_required([:account_id, :status, :storage_key, :source_pds_url, :handle, :did, :verification_status])
    |> validate_number(:byte_size, greater_than_or_equal_to: 0)
    |> validate_inclusion(:status, @statuses)
    |> validate_inclusion(:verification_status, @verification_statuses)
    |> unique_constraint(:storage_key)
  end

  def pin_changeset(snapshot, attrs) do
    snapshot
    |> cast(attrs, [:pinned])
    |> validate_required([:pinned])
  end
end
