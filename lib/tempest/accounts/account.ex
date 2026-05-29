defmodule Tempest.Accounts.Account do
  @moduledoc """
  Local hosted account state.
  """

  use Ecto.Schema

  import Ecto.Changeset

  alias Tempest.Identity.Validators

  @statuses ~w(active deactivated deleted takendown suspended desynchronized throttled)

  schema "accounts" do
    field :did, :string
    field :handle, :string
    field :email, :string
    field :password_hash, :string
    field :active, :boolean, default: true
    field :status, :string, default: "active"
    field :preferences_json, :string, default: "[]"

    has_many :sessions, Tempest.Accounts.Session
    has_many :signing_keys, Tempest.Identity.SigningKey

    timestamps(type: :utc_datetime)
  end

  def create_changeset(account, attrs) do
    account
    |> cast(attrs, [:did, :handle, :email, :password_hash, :active, :status, :preferences_json])
    |> update_change(:handle, &normalize_handle/1)
    |> update_change(:email, &normalize_email/1)
    |> validate_required([:did, :handle, :email, :password_hash, :active, :status])
    |> validate_identity_did()
    |> validate_identity_handle()
    |> validate_format(:email, ~r/\A[^@\s]+@[^@\s]+\.[^@\s]+\z/)
    |> validate_length(:email, max: 320)
    |> validate_inclusion(:status, @statuses)
    |> unique_constraint(:did)
    |> unique_constraint(:handle)
    |> unique_constraint(:email)
  end

  def update_handle_changeset(account, attrs) do
    account
    |> cast(attrs, [:handle])
    |> update_change(:handle, &normalize_handle/1)
    |> validate_required([:handle])
    |> validate_identity_handle()
    |> unique_constraint(:handle)
  end

  defp normalize_handle(handle) when is_binary(handle) do
    Validators.normalize_handle(handle)
  end

  defp normalize_handle(handle), do: handle

  defp normalize_email(email) when is_binary(email) do
    email
    |> String.trim()
    |> String.downcase()
  end

  defp normalize_email(email), do: email

  defp validate_identity_did(changeset) do
    validate_change(changeset, :did, fn :did, did ->
      case Validators.validate_did(did) do
        :ok -> []
        {:error, :unsupported_did_method} -> [did: "uses an unsupported DID method"]
        {:error, :invalid_did_syntax} -> [did: "has invalid syntax"]
      end
    end)
  end

  defp validate_identity_handle(changeset) do
    validate_change(changeset, :handle, fn :handle, handle ->
      case Validators.validate_handle(handle) do
        :ok -> []
        {:error, :invalid_handle_syntax} -> [handle: "has invalid syntax"]
      end
    end)
  end
end
