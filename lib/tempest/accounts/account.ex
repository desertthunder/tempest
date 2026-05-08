defmodule Tempest.Accounts.Account do
  @moduledoc """
  Local hosted account state.
  """

  use Ecto.Schema

  import Ecto.Changeset

  @statuses ~w(active deactivated deleted takendown suspended desynchronized throttled)

  schema "accounts" do
    field :did, :string
    field :handle, :string
    field :email, :string
    field :password_hash, :string
    field :active, :boolean, default: true
    field :status, :string, default: "active"

    has_many :sessions, Tempest.Accounts.Session

    timestamps(type: :utc_datetime)
  end

  def create_changeset(account, attrs) do
    account
    |> cast(attrs, [:did, :handle, :email, :password_hash, :active, :status])
    |> update_change(:handle, &normalize_handle/1)
    |> update_change(:email, &normalize_email/1)
    |> validate_required([:did, :handle, :email, :password_hash, :active, :status])
    |> validate_format(:did, ~r/\Adid:[a-z0-9]+:[A-Za-z0-9._:%-]+\z/)
    |> validate_format(:handle, ~r/\A[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?(?:\.[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?)+\z/)
    |> validate_length(:handle, max: 253)
    |> validate_format(:email, ~r/\A[^@\s]+@[^@\s]+\.[^@\s]+\z/)
    |> validate_length(:email, max: 320)
    |> validate_inclusion(:status, @statuses)
    |> unique_constraint(:did)
    |> unique_constraint(:handle)
    |> unique_constraint(:email)
  end

  defp normalize_handle(handle) when is_binary(handle) do
    handle
    |> String.trim()
    |> String.downcase()
  end

  defp normalize_handle(handle), do: handle

  defp normalize_email(email) when is_binary(email) do
    email
    |> String.trim()
    |> String.downcase()
  end

  defp normalize_email(email), do: email
end
