defmodule Tempest.Identity.KeyStore do
  @moduledoc """
  Boundary for hosted account signing-key generation and encrypted private-key storage.
  """

  alias Plug.Crypto.{KeyGenerator, MessageEncryptor}
  alias Tempest.Accounts.Account
  alias Tempest.Identity.SigningKey
  alias Tempest.Repo

  import Ecto.Query

  @kid "#atproto"
  @salt "tempest identity signing keys"
  @aad "Tempest.Identity.KeyStore.v1"

  def initial_key_changeset(%Account{} = account) do
    {public_key, private_key} = :crypto.generate_key(:ecdh, :secp256k1)

    SigningKey.create_changeset(%SigningKey{}, %{
      account_id: account.id,
      kid: @kid,
      public_key_multibase: multibase64(public_key),
      private_key_ciphertext: encrypt_private_key(private_key),
      active: true
    })
  end

  def create_initial_key(%Account{} = account) do
    account
    |> initial_key_changeset()
    |> Repo.insert()
  end

  def active_key_for_account(%Account{} = account) do
    account
    |> Ecto.assoc(:signing_keys)
    |> where([key], key.active)
    |> order_by([key], asc: key.inserted_at)
    |> first()
    |> Repo.one()
  end

  def decrypt_private_key(%SigningKey{private_key_ciphertext: ciphertext}) do
    MessageEncryptor.decrypt(ciphertext, @aad, encryption_key(), "")
  end

  defp encrypt_private_key(private_key) do
    MessageEncryptor.encrypt(private_key, @aad, encryption_key(), "")
  end

  defp encryption_key do
    :tempest
    |> Application.fetch_env!(TempestWeb.Endpoint)
    |> Keyword.fetch!(:secret_key_base)
    |> KeyGenerator.generate(@salt, length: 32)
  end

  defp multibase64(key), do: "u" <> Base.url_encode64(key, padding: false)
end
