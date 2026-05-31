defmodule Tempest.Security.EmailToken do
  use Ecto.Schema
  import Ecto.Changeset

  @purposes ~w(confirm_email update_email reset_password)

  schema "email_tokens" do
    field :purpose, :string
    field :email, :string
    field :token_hash, :string
    field :expires_at, :utc_datetime
    field :used_at, :utc_datetime
    belongs_to :account, Tempest.Accounts.Account

    timestamps(type: :utc_datetime)
  end

  def changeset(token, attrs) do
    token
    |> cast(attrs, [:account_id, :purpose, :email, :token_hash, :expires_at, :used_at])
    |> validate_required([:account_id, :purpose, :email, :token_hash, :expires_at])
    |> validate_inclusion(:purpose, @purposes)
  end
end
