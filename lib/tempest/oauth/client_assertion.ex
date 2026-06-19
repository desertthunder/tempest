defmodule Tempest.OAuth.ClientAssertion do
  use Ecto.Schema
  import Ecto.Changeset

  schema "oauth_client_assertions" do
    field :client_id, :string
    field :jti_hash, :string
    field :expires_at, :utc_datetime

    timestamps(type: :utc_datetime)
  end

  def changeset(assertion, attrs) do
    assertion
    |> cast(attrs, [:client_id, :jti_hash, :expires_at])
    |> validate_required([:client_id, :jti_hash, :expires_at])
    |> unique_constraint([:client_id, :jti_hash])
  end
end
