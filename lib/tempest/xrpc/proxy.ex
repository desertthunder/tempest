defmodule Tempest.Xrpc.Proxy do
  @moduledoc """
  Fallback proxy policy for service XRPC methods intentionally not implemented locally.
  """

  alias Tempest.Accounts
  alias Tempest.Accounts.Tokens

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
      |> Keyword.merge(
        method: conn.method,
        url: url(upstream, nsid),
        headers: forwarded_headers(conn, upstream, nsid),
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

  defp maybe_query(request, %{method: "GET"}, params) do
    Keyword.put(request, :params, Map.drop(params, ["method"]))
  end

  defp maybe_query(request, _conn, _params), do: request

  defp maybe_json(request, %{method: "POST"}, params) do
    Keyword.put(request, :json, Map.drop(params, ["method"]))
  end

  defp maybe_json(request, _conn, _params), do: request

  defp forwarded_headers(conn, upstream, nsid) do
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
    |> maybe_put_service_auth(conn, upstream, nsid)
  end

  defp maybe_put_service_auth(headers, conn, upstream, nsid) do
    with {:ok, token} <- bearer_token(conn),
         {:ok, auth_context} <- Accounts.authenticate_access(token),
         {:ok, audience} <- service_audience(conn, upstream) do
      [{"authorization", "Bearer #{Tokens.sign_service_auth(auth_context.account, audience, nsid)}"} | headers]
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

  defp service_audience(conn, upstream) do
    conn.req_headers
    |> Enum.find_value(fn
      {"atproto-proxy", value} when is_binary(value) -> value
      _header -> nil
    end)
    |> case do
      nil -> service_audience_from_url(upstream)
      proxy -> proxy |> String.split("#", parts: 2) |> List.first() |> validate_did_audience()
    end
  end

  defp service_audience_from_url(upstream) do
    case URI.parse(upstream) do
      %{host: host} when is_binary(host) and host != "" -> {:ok, "did:web:#{host}"}
      _uri -> {:error, :invalid_upstream}
    end
  end

  defp validate_did_audience("did:" <> _rest = did), do: {:ok, did}
  defp validate_did_audience(_audience), do: {:error, :invalid_audience}
end
