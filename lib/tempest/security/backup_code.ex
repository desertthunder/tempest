defmodule Tempest.Security.BackupCode do
  use Ecto.Schema
  import Ecto.Changeset

  schema "backup_codes" do
    field :code_hash, :string
    field :used_at, :utc_datetime
    belongs_to :account, Tempest.Accounts.Account

    timestamps(type: :utc_datetime)
  end

  def changeset(code, attrs) do
    code
    |> cast(attrs, [:account_id, :code_hash, :used_at])
    |> validate_required([:account_id, :code_hash])
  end
end
