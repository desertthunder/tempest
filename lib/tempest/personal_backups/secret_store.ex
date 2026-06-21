defmodule Tempest.PersonalBackups.SecretStore do
  @moduledoc false

  alias Plug.Crypto.{KeyGenerator, MessageEncryptor}

  @salt "tempest personal backup credentials"
  @aad "Tempest.PersonalBackups.Credential.v1"

  def encrypt(secret) when is_binary(secret) and secret != "" do
    {:ok, MessageEncryptor.encrypt(secret, @aad, encryption_key(), "")}
  end

  def encrypt(_secret), do: {:error, :missing_secret}

  def decrypt(ciphertext) when is_binary(ciphertext) and ciphertext != "" do
    MessageEncryptor.decrypt(ciphertext, @aad, encryption_key(), "")
  end

  def decrypt(_ciphertext), do: {:error, :missing_secret}

  def hint(secret) when is_binary(secret) do
    suffix = String.slice(secret, -4, 4)

    if suffix == "", do: nil, else: "..." <> suffix
  end

  def hint(_secret), do: nil

  defp encryption_key do
    :tempest
    |> Application.fetch_env!(TempestWeb.Endpoint)
    |> Keyword.fetch!(:secret_key_base)
    |> KeyGenerator.generate(@salt, length: 32)
  end
end
