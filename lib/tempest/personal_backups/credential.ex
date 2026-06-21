defmodule Tempest.PersonalBackups.Credential do
  @moduledoc """
  Stored credential metadata for an external backup account.

  Secret material is intentionally opaque here. Templates must never render
  `secret_ciphertext`.
  """

  use Ecto.Schema

  import Ecto.Changeset

  alias Tempest.PersonalBackups.Account

  @modes ~w(none app_password access_token)

  schema "personal_backup_credentials" do
    field :mode, :string, default: "none"
    field :secret_ciphertext, :string
    field :secret_hint, :string
    field :verified_at, :utc_datetime
    field :deleted_at, :utc_datetime

    belongs_to :account, Account

    timestamps(type: :utc_datetime)
  end

  def changeset(credential, attrs) do
    credential
    |> cast(attrs, [:account_id, :mode, :secret_ciphertext, :secret_hint, :verified_at, :deleted_at])
    |> validate_required([:account_id, :mode])
    |> validate_inclusion(:mode, @modes)
    |> unique_constraint(:account_id)
  end

  def public_state(%__MODULE__{} = credential) do
    %{
      mode: credential.mode,
      configured?: configured?(credential),
      secret_hint: credential.secret_hint,
      verified_at: credential.verified_at,
      deleted_at: credential.deleted_at
    }
  end

  def configured?(%__MODULE__{mode: "none"}), do: false
  def configured?(%__MODULE__{secret_ciphertext: secret, deleted_at: nil}), do: is_binary(secret) and secret != ""
  def configured?(%__MODULE__{}), do: false
end
