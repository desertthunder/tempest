defmodule Tempest.OAuth.ParRequest do
  use Ecto.Schema
  import Ecto.Changeset

  schema "oauth_par_requests" do
    field :request_uri, :string
    field :client_id, :string
    field :redirect_uri, :string
    field :scope, :string
    field :state, :string
    field :code_challenge, :string
    field :code_challenge_method, :string
    field :dpop_jkt, :string
    field :client_auth_method, :string, default: "none"
    field :client_auth_kid, :string
    field :client_auth_alg, :string
    field :client_auth_jkt, :string
    field :expires_at, :utc_datetime
    field :used_at, :utc_datetime

    timestamps(type: :utc_datetime)
  end

  def changeset(request, attrs) do
    request
    |> cast(attrs, [
      :request_uri,
      :client_id,
      :redirect_uri,
      :scope,
      :state,
      :code_challenge,
      :code_challenge_method,
      :dpop_jkt,
      :client_auth_method,
      :client_auth_kid,
      :client_auth_alg,
      :client_auth_jkt,
      :expires_at,
      :used_at
    ])
    |> validate_required([
      :request_uri,
      :client_id,
      :redirect_uri,
      :scope,
      :code_challenge,
      :code_challenge_method,
      :dpop_jkt,
      :client_auth_method,
      :expires_at
    ])
    |> validate_inclusion(:client_auth_method, ["none", "private_key_jwt"])
    |> validate_inclusion(:code_challenge_method, ["S256"])
    |> unique_constraint(:request_uri)
  end
end
