defmodule Tempest.Xrpc.Proxy do
  @moduledoc """
  Fallback proxy policy for service XRPC methods intentionally not implemented locally.
  """

  alias Tempest.{Accounts, Identity}
  alias Tempest.Accounts.Tokens

  @service_prefixes ["app.bsky.", "chat.bsky."]
  @default_http_options [receive_timeout: 60_000, connect_options: [timeout: 5_000]]

  def proxyable?(nsid) when is_binary(nsid) do
    Enum.any?(@service_prefixes, &String.starts_with?(nsid, &1))
  end

  def proxyable?(_nsid), do: false

  def upstream_base_url do
    :tempest
    |> Application.get_env(__MODULE__, [])
    |> Keyword.get(:upstream_base_url)
  end

  def request(conn, nsid, params) do
    with true <- proxyable?(nsid),
         {:ok, target} <- proxy_target(conn) do
      do_request(conn, target, nsid, params)
    else
      :not_configured -> :not_configured
      {:error, reason} -> {:error, reason}
      _other -> :not_configured
    end
  end

  defp do_request(conn, target, nsid, params) do
    options =
      :tempest
      |> Application.get_env(__MODULE__, [])
      |> Keyword.get(:http_req_options, [])

    request =
      @default_http_options
      |> Keyword.merge(options)
      |> Keyword.merge(
        method: conn.method,
        url: url(target.base_url, nsid),
        headers: forwarded_headers(conn, target, nsid),
        retry: false
      )
      |> maybe_query(conn, params)
      |> maybe_json(conn, params)

    case Req.request(request) do
      {:ok, response} -> {:ok, response}
      {:error, reason} -> {:error, reason}
    end
  end

  defp url(upstream, nsid), do: String.trim_trailing(upstream, "/") <> "/xrpc/" <> nsid

  defp proxy_target(conn) do
    case atproto_proxy_header(conn) do
      {:ok, proxy_to} -> proxy_target_from_header(proxy_to)
      :error -> proxy_target_from_config()
    end
  end

  defp proxy_target_from_header(proxy_to) do
    with {:ok, did, service_id} <- parse_proxy_to(proxy_to),
         {:ok, document} <- Identity.external_did_document_for_did(did),
         {:ok, endpoint} <- service_endpoint(document, service_id) do
      {:ok, %{base_url: endpoint, audience: did}}
    end
  end

  defp proxy_target_from_config do
    case upstream_base_url() do
      upstream when is_binary(upstream) ->
        with {:ok, audience} <- service_audience_from_url(upstream) do
          {:ok, %{base_url: upstream, audience: audience}}
        end

      _other ->
        :not_configured
    end
  end

  defp atproto_proxy_header(conn) do
    conn.req_headers
    |> Enum.find_value(fn
      {"atproto-proxy", value} when is_binary(value) and value != "" -> {:ok, value}
      _header -> nil
    end)
    |> case do
      {:ok, value} -> {:ok, value}
      nil -> :error
    end
  end

  defp parse_proxy_to(proxy_to) do
    case String.split(proxy_to, "#", parts: 2) do
      ["did:" <> _rest = did, service_id] when service_id != "" -> {:ok, did, "#" <> service_id}
      _parts -> {:error, :invalid_proxy_header}
    end
  end

  defp service_endpoint(%{"service" => services}, service_id) when is_list(services) do
    services
    |> Enum.find_value(fn
      %{"id" => ^service_id, "serviceEndpoint" => endpoint} when is_binary(endpoint) -> endpoint
      _service -> nil
    end)
    |> case do
      nil -> {:error, :proxy_service_not_found}
      endpoint -> {:ok, endpoint}
    end
  end

  defp service_endpoint(_document, _service_id), do: {:error, :proxy_service_not_found}

  defp maybe_query(request, %{method: "GET"}, params) do
    Keyword.put(request, :params, Map.drop(params, ["method"]))
  end

  defp maybe_query(request, _conn, _params), do: request

  defp maybe_json(request, %{method: "POST"}, params) do
    Keyword.put(request, :json, Map.drop(params, ["method"]))
  end

  defp maybe_json(request, _conn, _params), do: request

  defp forwarded_headers(conn, target, nsid) do
    conn.req_headers
    |> Enum.filter(fn {name, _value} ->
      name in [
        "accept",
        "accept-language",
        "content-type",
        "atproto-accept-labelers",
        "atproto-content-labelers",
        "x-atproto-accept-labelers",
        "x-bsky-topics"
      ]
    end)
    |> maybe_put_service_auth(conn, target, nsid)
  end

  defp maybe_put_service_auth(headers, conn, target, nsid) do
    with {:ok, token} <- bearer_token(conn),
         {:ok, auth_context} <- Accounts.authenticate_access(token),
         true <- Tempest.Permissions.allowed?(auth_context, nsid, %{}) do
      [{"authorization", "Bearer #{Tokens.sign_service_auth(auth_context.account, target.audience, nsid)}"} | headers]
    else
      _other -> headers
    end
  end

  defp bearer_token(conn) do
    conn.req_headers
    |> Enum.find_value(fn
      {"authorization", "Bearer " <> token} when token != "" -> {:ok, token}
      {"authorization", "bearer " <> token} when token != "" -> {:ok, token}
      _header -> nil
    end)
    |> case do
      {:ok, token} -> {:ok, token}
      nil -> :error
    end
  end

  defp service_audience_from_url(upstream) do
    case URI.parse(upstream) do
      %{host: host} when is_binary(host) and host != "" -> {:ok, "did:web:#{host}"}
      _uri -> {:error, :invalid_upstream}
    end
  end
end
