defmodule Tempest.Identity.SsrfProtection do
  @moduledoc """
  Host and URL checks before identity-derived outbound fetches.
  """

  alias Tempest.Identity.Validators

  def validate_url(url) when is_binary(url) do
    uri = URI.parse(url)

    with :ok <- validate_uri_shape(uri),
         :ok <- Validators.validate_handle(uri.host),
         {:ok, addresses} <- lookup_addresses(uri.host),
         :ok <- validate_addresses(addresses) do
      :ok
    else
      {:error, reason} -> {:error, reason}
      _other -> {:error, :unsafe_url}
    end
  end

  def validate_url(_url), do: {:error, :unsafe_url}

  defp validate_uri_shape(%URI{scheme: scheme, host: host, userinfo: nil})
       when scheme in ["http", "https"] and is_binary(host),
       do: :ok

  defp validate_uri_shape(_uri), do: {:error, :unsafe_url}

  defp lookup_addresses(host) do
    case identity_config(:dns_lookup) do
      nil -> default_lookup_addresses(host)
      fun when is_function(fun, 1) -> fun.(host)
      {module, function, args} -> apply(module, function, [host | args])
    end
  end

  defp default_lookup_addresses(host) do
    ipv4 = host |> String.to_charlist() |> :inet.getaddrs(:inet)
    ipv6 = host |> String.to_charlist() |> :inet.getaddrs(:inet6)

    addresses =
      [ipv4, ipv6]
      |> Enum.flat_map(fn
        {:ok, addresses} -> addresses
        {:error, _reason} -> []
      end)

    case addresses do
      [] -> {:error, :resolution_failed}
      addresses -> {:ok, addresses}
    end
  end

  defp validate_addresses([]), do: {:error, :resolution_failed}

  defp validate_addresses(addresses) do
    if Enum.all?(addresses, &public_address?/1) do
      :ok
    else
      {:error, :private_ip}
    end
  end

  defp public_address?({a, b, _c, _d}) do
    cond do
      a == 0 -> false
      a == 10 -> false
      a == 100 and b in 64..127 -> false
      a == 127 -> false
      a == 169 and b == 254 -> false
      a == 172 and b in 16..31 -> false
      a == 192 and b == 168 -> false
      a >= 224 -> false
      true -> true
    end
  end

  defp public_address?({0, 0, 0, 0, 0, 0, 0, 1}), do: false
  defp public_address?({0, 0, 0, 0, 0, 0, 0, 0}), do: false
  defp public_address?({0xFC00, _, _, _, _, _, _, _}), do: false
  defp public_address?({0xFD00, _, _, _, _, _, _, _}), do: false
  defp public_address?({first, _, _, _, _, _, _, _}) when first in 0xFE80..0xFEBF, do: false
  defp public_address?({_a, _b, _c, _d, _e, _f, _g, _h}), do: true
  defp public_address?(_address), do: false

  defp identity_config(key) do
    :tempest
    |> Application.get_env(Tempest.Identity, [])
    |> Keyword.get(key)
  end
end
