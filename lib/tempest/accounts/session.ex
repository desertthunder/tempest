defmodule Tempest.Accounts.Session do
  @moduledoc """
  Hashed refresh token storage for account sessions.
  """

  use Ecto.Schema

  import Ecto.Changeset

  schema "sessions" do
    field :token_hash, :string
    field :family_id, :string
    field :expires_at, :utc_datetime
    field :revoked_at, :utc_datetime
    field :rotated_at, :utc_datetime
    field :reuse_detected_at, :utc_datetime

    belongs_to :account, Tempest.Accounts.Account

    timestamps(type: :utc_datetime)
  end

  def create_changeset(session, attrs) do
    session
    |> cast(attrs, [:account_id, :token_hash, :family_id, :expires_at])
    |> validate_required([:account_id, :token_hash, :family_id, :expires_at])
    |> foreign_key_constraint(:account_id)
    |> unique_constraint(:token_hash)
  end

  def rotate_changeset(session, attrs) do
    session
    |> cast(attrs, [:rotated_at, :revoked_at])
    |> validate_required([:rotated_at, :revoked_at])
  end

  def revoke_changeset(session, attrs) do
    session
    |> cast(attrs, [:revoked_at])
    |> validate_required([:revoked_at])
  end

  def reuse_changeset(session, attrs) do
    session
    |> cast(attrs, [:reuse_detected_at, :revoked_at])
    |> validate_required([:reuse_detected_at, :revoked_at])
  end
end
