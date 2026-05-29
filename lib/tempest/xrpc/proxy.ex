defmodule Tempest.Xrpc.Proxy do
  @moduledoc """
  Fallback proxy policy for service XRPC methods intentionally not implemented locally.
  """

  @service_prefixes ["app.bsky.", "chat.bsky."]

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
         upstream when is_binary(upstream) <- upstream_base_url() do
      do_request(conn, upstream, nsid, params)
    else
      _other -> :not_configured
    end
  end

  defp do_request(conn, upstream, nsid, params) do
    options =
      :tempest
      |> Application.get_env(__MODULE__, [])
      |> Keyword.get(:http_req_options, [])

    request =
      options
      |> Keyword.merge(method: conn.method, url: url(upstream, nsid), headers: forwarded_headers(conn), retry: false)
      |> maybe_query(conn, params)
      |> maybe_json(conn, params)

    case Req.request(request) do
      {:ok, response} -> {:ok, response}
      {:error, reason} -> {:error, reason}
    end
  end

  defp url(upstream, nsid), do: String.trim_trailing(upstream, "/") <> "/xrpc/" <> nsid

  defp maybe_query(request, %{method: "GET"}, params) do
    Keyword.put(request, :params, Map.drop(params, ["method"]))
  end

  defp maybe_query(request, _conn, _params), do: request

  defp maybe_json(request, %{method: "POST"}, params) do
    Keyword.put(request, :json, Map.drop(params, ["method"]))
  end

  defp maybe_json(request, _conn, _params), do: request

  defp forwarded_headers(conn) do
    conn.req_headers
    |> Enum.filter(fn {name, _value} -> name in ["authorization", "accept", "content-type"] end)
  end
end
