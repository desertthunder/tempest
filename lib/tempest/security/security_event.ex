defmodule Tempest.Security.SecurityEvent do
  use Ecto.Schema
  import Ecto.Changeset

  schema "security_events" do
    field :event_type, :string
    field :metadata_json, :string, default: "{}"
    belongs_to :account, Tempest.Accounts.Account

    timestamps(type: :utc_datetime, updated_at: false)
  end

  def changeset(event, attrs) do
    event
    |> cast(attrs, [:account_id, :event_type, :metadata_json])
    |> validate_required([:account_id, :event_type, :metadata_json])
  end
end
