defmodule Tempest.Security.ExternalMetadataFetcher do
  @moduledoc """
  Hardened HTTP boundary for untrusted external metadata.

  This module is intended for OAuth client metadata, logos, JWKS URIs, DID
  documents, handle well-known fetches, and any other user-controlled URL fetch.
  It rejects unsafe URL shapes, private/link-local/reserved IP targets after DNS
  resolution, redirects, oversized bodies, slow connections, and non-HTTP(S)
  schemes. Callers should still validate the returned document semantics.
  """

  @default_max_body_bytes 128 * 1024
  @default_receive_timeout 2_000
  @default_connect_timeout 1_000
  @redirect_statuses [301, 302, 303, 307, 308]

  @type fetch_error ::
          :unsafe_url
          | :private_ip
          | :resolution_failed
          | :redirect_rejected
          | :body_too_large
          | :unsupported_content_type
          | :unexpected_status
          | :request_failed
          | :invalid_json

  @doc """
  Fetches a URL as text through the hardened external metadata boundary.
  """
  def fetch_text(url, opts \\ [])

  def fetch_text(url, opts) when is_binary(url) do
    max_body_bytes = Keyword.get(opts, :max_body_bytes, config(:max_body_bytes, @default_max_body_bytes))

    with :ok <- validate_url(url),
         {:ok, body, _headers} <- request(url, max_body_bytes, opts) do
      {:ok, body}
    end
  end

  def fetch_text(_url, _opts), do: {:error, :unsafe_url}

  @doc """
  Fetches and decodes JSON through the hardened external metadata boundary.
  """
  def fetch_json(url, opts \\ []) do
    with {:ok, body} <- fetch_text(url, opts),
         {:ok, json} <- Jason.decode(body) do
      {:ok, json}
    else
      {:error, %Jason.DecodeError{}} -> {:error, :invalid_json}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Validates URL shape and resolved addresses before outbound fetch.
  """
  def validate_url(url) when is_binary(url) do
    uri = URI.parse(url)

    with :ok <- validate_uri_shape(uri),
         :ok <- validate_host(uri.host),
         {:ok, addresses} <- lookup_addresses(uri.host),
         :ok <- validate_addresses(addresses) do
      :ok
    else
      {:error, reason} -> {:error, reason}
      _other -> {:error, :unsafe_url}
    end
  end

  def validate_url(_url), do: {:error, :unsafe_url}

  defp request(url, max_body_bytes, opts) do
    req_opts =
      [
        url: url,
        redirect: false,
        retry: false,
        raw: true,
        receive_timeout: Keyword.get(opts, :receive_timeout, config(:receive_timeout, @default_receive_timeout)),
        connect_options: [
          timeout: Keyword.get(opts, :connect_timeout, config(:connect_timeout, @default_connect_timeout))
        ]
      ]
      |> Keyword.merge(config(:req_options, []))
      |> Keyword.merge(Keyword.get(opts, :req_options, []))

    case Req.get(req_opts) do
      {:ok, %{status: status}} when status in @redirect_statuses ->
        {:error, :redirect_rejected}

      {:ok, %{status: status, body: body, headers: headers}} when status in 200..299 ->
        body = normalize_body(body)

        if byte_size(body) <= max_body_bytes do
          {:ok, body, headers}
        else
          {:error, :body_too_large}
        end

      {:ok, _response} ->
        {:error, :unexpected_status}

      {:error, _reason} ->
        {:error, :request_failed}
    end
  end

  defp normalize_body(body) when is_binary(body), do: body
  defp normalize_body(body), do: Jason.encode!(body)

  defp validate_uri_shape(%URI{scheme: scheme, host: host, userinfo: nil, fragment: nil})
       when scheme in ["http", "https"] and is_binary(host),
       do: :ok

  defp validate_uri_shape(_uri), do: {:error, :unsafe_url}

  defp validate_host(host) do
    cond do
      String.trim(host) == "" -> {:error, :unsafe_url}
      String.contains?(host, ["/", "\\", " ", "\t", "\n", "\r"]) -> {:error, :unsafe_url}
      true -> :ok
    end
  end

  defp lookup_addresses(host) do
    case config(:dns_lookup, nil) do
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
      a == 192 and b == 0 -> false
      a == 192 and b == 168 -> false
      a == 198 and b in [18, 19] -> false
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

  defp config(key, default) do
    :tempest
    |> Application.get_env(__MODULE__, [])
    |> Keyword.get(key, default)
  end
end
