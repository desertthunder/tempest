defmodule Tempest.PersonalBackups.Run do
  @moduledoc """
  Persisted execution state for an external account backup attempt.
  """

  use Ecto.Schema

  import Ecto.Changeset

  alias Tempest.PersonalBackups.Account

  @statuses ~w(pending running succeeded failed warning)
  @kinds ~w(manual scheduled verification prune export)

  schema "personal_backup_runs" do
    field :snapshot_id, :integer
    field :status, :string, default: "pending"
    field :kind, :string, default: "manual"
    field :started_at, :utc_datetime
    field :finished_at, :utc_datetime
    field :error_reason, :string
    field :metadata, :map, default: %{}

    belongs_to :account, Account

    timestamps(type: :utc_datetime)
  end

  def changeset(run, attrs) do
    run
    |> cast(attrs, [:account_id, :snapshot_id, :status, :kind, :started_at, :finished_at, :error_reason, :metadata])
    |> validate_required([:account_id, :status, :kind, :metadata])
    |> validate_inclusion(:status, @statuses)
    |> validate_inclusion(:kind, @kinds)
  end
end
