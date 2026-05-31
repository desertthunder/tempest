defmodule Tempest.Security.DelegatedAccessGrant do
  use Ecto.Schema
  import Ecto.Changeset

  schema "delegated_access_grants" do
    field :delegate_did, :string
    field :scope, :string
    field :expires_at, :utc_datetime
    field :revoked_at, :utc_datetime
    belongs_to :owner_account, Tempest.Accounts.Account

    timestamps(type: :utc_datetime)
  end

  def changeset(grant, attrs) do
    grant
    |> cast(attrs, [:owner_account_id, :delegate_did, :scope, :expires_at, :revoked_at])
    |> validate_required([:owner_account_id, :delegate_did, :scope])
  end
end
