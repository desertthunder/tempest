defmodule Tempest.Security.PlcOperationToken do
  @moduledoc """
  Short-lived, single-use authorization tokens for PLC operation signing.
  """

  use Ecto.Schema
  import Ecto.Changeset

  alias Tempest.Accounts.Account

  schema "plc_operation_tokens" do
    belongs_to :account, Account
    field :token_hash, :string
    field :expires_at, :utc_datetime
    field :used_at, :utc_datetime

    timestamps(type: :utc_datetime)
  end

  def changeset(token, attrs) do
    token
    |> cast(attrs, [:account_id, :token_hash, :expires_at, :used_at])
    |> validate_required([:account_id, :token_hash, :expires_at])
    |> foreign_key_constraint(:account_id)
    |> unique_constraint(:token_hash)
  end
end
