defmodule Tempest.OAuth.AuthorizationCode do
  use Ecto.Schema
  import Ecto.Changeset

  schema "oauth_authorization_codes" do
    field :code_hash, :string
    field :client_id, :string
    field :redirect_uri, :string
    field :scope, :string
    field :code_challenge, :string
    field :dpop_jkt, :string
    field :expires_at, :utc_datetime
    field :used_at, :utc_datetime
    field :revoked_at, :utc_datetime

    belongs_to :account, Tempest.Accounts.Account
    belongs_to :par_request, Tempest.OAuth.ParRequest

    timestamps(type: :utc_datetime)
  end

  def changeset(code, attrs) do
    code
    |> cast(attrs, [
      :code_hash,
      :account_id,
      :par_request_id,
      :client_id,
      :redirect_uri,
      :scope,
      :code_challenge,
      :dpop_jkt,
      :expires_at,
      :used_at,
      :revoked_at
    ])
    |> validate_required([
      :code_hash,
      :account_id,
      :par_request_id,
      :client_id,
      :redirect_uri,
      :scope,
      :code_challenge,
      :dpop_jkt,
      :expires_at
    ])
    |> unique_constraint(:code_hash)
  end
end
