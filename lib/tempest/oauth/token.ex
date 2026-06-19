defmodule Tempest.OAuth.Token do
  use Ecto.Schema
  import Ecto.Changeset

  schema "oauth_tokens" do
    field :access_token_hash, :string
    field :refresh_token_hash, :string
    field :client_id, :string
    field :scope, :string
    field :dpop_jkt, :string
    field :client_auth_method, :string, default: "none"
    field :client_auth_kid, :string
    field :client_auth_alg, :string
    field :client_auth_jkt, :string
    field :expires_at, :utc_datetime
    field :revoked_at, :utc_datetime
    field :rotated_at, :utc_datetime

    belongs_to :account, Tempest.Accounts.Account

    timestamps(type: :utc_datetime)
  end

  def changeset(token, attrs) do
    token
    |> cast(attrs, [
      :access_token_hash,
      :refresh_token_hash,
      :account_id,
      :client_id,
      :scope,
      :dpop_jkt,
      :client_auth_method,
      :client_auth_kid,
      :client_auth_alg,
      :client_auth_jkt,
      :expires_at,
      :revoked_at,
      :rotated_at
    ])
    |> validate_required([
      :access_token_hash,
      :account_id,
      :client_id,
      :scope,
      :dpop_jkt,
      :client_auth_method,
      :expires_at
    ])
    |> validate_inclusion(:client_auth_method, ["none", "private_key_jwt"])
    |> unique_constraint(:access_token_hash)
    |> unique_constraint(:refresh_token_hash)
  end
end
