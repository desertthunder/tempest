defmodule Tempest.OAuth.DpopNonce do
  use Ecto.Schema
  import Ecto.Changeset

  schema "oauth_dpop_nonces" do
    field :nonce_hash, :string
    field :expires_at, :utc_datetime
    field :used_at, :utc_datetime

    timestamps(type: :utc_datetime)
  end

  def changeset(nonce, attrs) do
    nonce
    |> cast(attrs, [:nonce_hash, :expires_at, :used_at])
    |> validate_required([:nonce_hash, :expires_at])
    |> unique_constraint(:nonce_hash)
  end
end
