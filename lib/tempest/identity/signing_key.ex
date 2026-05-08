defmodule Tempest.Identity.SigningKey do
  @moduledoc """
  Encrypted private signing-key material for a hosted account.
  """

  use Ecto.Schema

  import Ecto.Changeset

  schema "signing_keys" do
    field :kid, :string
    field :public_key_multibase, :string
    field :private_key_ciphertext, :string
    field :active, :boolean, default: true

    belongs_to :account, Tempest.Accounts.Account

    timestamps(type: :utc_datetime)
  end

  def create_changeset(signing_key, attrs) do
    signing_key
    |> cast(attrs, [:account_id, :kid, :public_key_multibase, :private_key_ciphertext, :active])
    |> validate_required([:account_id, :kid, :public_key_multibase, :private_key_ciphertext, :active])
    |> validate_format(:kid, ~r/\A#[A-Za-z0-9._:-]+\z/)
    |> validate_format(:public_key_multibase, ~r/\A[a-zA-Z0-9_-]+\z/)
    |> unique_constraint([:account_id, :kid])
    |> assoc_constraint(:account)
  end
end
