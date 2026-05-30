defmodule Tempest.Accounts.AppPassword do
  use Ecto.Schema
  import Ecto.Changeset

  schema "app_passwords" do
    field :name, :string
    field :token_hash, :string
    field :scope, :string
    field :last_used_at, :utc_datetime
    field :revoked_at, :utc_datetime

    belongs_to :account, Tempest.Accounts.Account

    timestamps(type: :utc_datetime)
  end

  def changeset(app_password, attrs) do
    app_password
    |> cast(attrs, [:account_id, :name, :token_hash, :scope, :last_used_at, :revoked_at])
    |> validate_required([:account_id, :name, :token_hash, :scope])
    |> validate_length(:name, min: 1, max: 80)
    |> unique_constraint(:token_hash)
  end
end
