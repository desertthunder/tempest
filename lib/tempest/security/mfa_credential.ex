defmodule Tempest.Security.MfaCredential do
  use Ecto.Schema
  import Ecto.Changeset

  @types ~w(totp passkey webauthn backup_codes trusted_device)

  schema "mfa_credentials" do
    field :type, :string
    field :label, :string
    field :secret_ciphertext, :string
    field :confirmed_at, :utc_datetime
    field :disabled_at, :utc_datetime
    field :last_used_at, :utc_datetime
    belongs_to :account, Tempest.Accounts.Account

    timestamps(type: :utc_datetime)
  end

  def changeset(credential, attrs) do
    credential
    |> cast(attrs, [:account_id, :type, :label, :secret_ciphertext, :confirmed_at, :disabled_at, :last_used_at])
    |> validate_required([:account_id, :type])
    |> validate_inclusion(:type, @types)
  end
end
