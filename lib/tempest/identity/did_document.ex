defmodule Tempest.Identity.DidDocument do
  @moduledoc """
  Builds hosted-account DID documents.
  """

  alias Tempest.Accounts.Account
  alias Tempest.Identity.KeyStore

  def build(%Account{} = account) do
    signing_key = KeyStore.active_key_for_account(account)
    verification_id = account.did <> "#atproto"

    %{
      "@context" => ["https://www.w3.org/ns/did/v1"],
      "id" => account.did,
      "alsoKnownAs" => ["at://#{account.handle}"],
      "verificationMethod" => [
        %{
          "id" => verification_id,
          "type" => "Multikey",
          "controller" => account.did,
          "publicKeyMultibase" => signing_key.public_key_multibase
        }
      ],
      "service" => [
        %{
          "id" => "#atproto_pds",
          "type" => "AtprotoPersonalDataServer",
          "serviceEndpoint" => pds_service_endpoint()
        }
      ]
    }
  end

  def claims_handle?(%{"alsoKnownAs" => also_known_as}, handle) when is_list(also_known_as) do
    "at://#{handle}" in also_known_as
  end

  def claims_handle?(_document, _handle), do: false

  defp pds_service_endpoint do
    %{scheme: scheme, host: host, port: port} = URI.parse(Tempest.Config.load!().public_url)
    default_port? = (scheme == "http" and port in [nil, 80]) or (scheme == "https" and port in [nil, 443])

    if default_port? do
      "#{scheme}://#{host}"
    else
      "#{scheme}://#{host}:#{port}"
    end
  end
end
