defmodule Tempest.Identity.PlcOperation do
  @moduledoc """
  Builds PLC operation-shaped maps from the current local account state.
  """

  alias Tempest.Accounts.Account
  alias Tempest.Identity.KeyStore

  def for_account(%Account{} = account) do
    signing_key = KeyStore.active_key_for_account(account)

    %{
      "type" => "plc_operation",
      "prev" => nil,
      "rotationKeys" => [signing_key.public_key_multibase],
      "verificationMethods" => %{"atproto" => signing_key.public_key_multibase},
      "alsoKnownAs" => ["at://#{account.handle}"],
      "services" => %{
        "atproto_pds" => %{
          "type" => "AtprotoPersonalDataServer",
          "endpoint" => pds_service_endpoint()
        }
      }
    }
  end

  defp pds_service_endpoint do
    %{scheme: scheme, host: host, port: port} = URI.parse(Tempest.Config.load!().public_url)
    default_port? = (scheme == "http" and port in [nil, 80]) or (scheme == "https" and port in [nil, 443])

    if default_port?, do: "#{scheme}://#{host}", else: "#{scheme}://#{host}:#{port}"
  end
end
