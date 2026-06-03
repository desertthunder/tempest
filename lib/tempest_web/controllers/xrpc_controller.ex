defmodule TempestWeb.XrpcController do
  use TempestWeb, :controller

  alias Tempest.Xrpc.{Proxy, Registry}
  alias TempestWeb.XrpcErrorJSON

  @json "application/json"

  def handle(%{method: "OPTIONS"} = conn, _params) do
    send_resp(conn, :no_content, "")
  end

  def handle(conn, %{"method" => method_nsid} = params) do
    case fetch_method(method_nsid) do
      {:ok, method} ->
        with :ok <- validate_verb(conn, method),
             :ok <- validate_content_type(conn, method) do
          dispatch(conn, params, method)
        else
          {:error, status, error, message} ->
            XrpcErrorJSON.render(conn, status, error, message)
        end

      {:proxy, ^method_nsid} ->
        proxy_or_unknown(conn, params, method_nsid)
    end
  end

  defp fetch_method(method_nsid) do
    case Registry.fetch(method_nsid) do
      {:ok, method} ->
        {:ok, method}

      {:error, :not_found} ->
        {:proxy, method_nsid}
    end
  end

  defp validate_verb(%{method: "GET"}, %{kind: :query}), do: :ok
  defp validate_verb(%{method: "POST"}, %{kind: :procedure}), do: :ok
  defp validate_verb(%{method: "GET"}, %{kind: :subscription}), do: :ok

  defp validate_verb(conn, method) do
    expected = expected_verb(method.kind)

    {:error, 400, "InvalidRequest",
     "#{method.nsid} is a #{method.kind} method and must use #{expected}, not #{conn.method}"}
  end

  defp expected_verb(:query), do: "GET"
  defp expected_verb(:procedure), do: "POST"
  defp expected_verb(:subscription), do: "GET"

  defp validate_content_type(%{method: "POST"} = conn, %{input: @json}) do
    if json_content_type?(conn) do
      :ok
    else
      {:error, 400, "InvalidRequest", "request body must use content-type application/json"}
    end
  end

  defp validate_content_type(%{method: "POST"} = conn, %{nsid: "com.atproto.repo.uploadBlob"}) do
    if conn |> get_req_header("content-type") |> Enum.any?() do
      :ok
    else
      {:error, 400, "InvalidRequest", "request body must include a content-type"}
    end
  end

  defp validate_content_type(%{method: "POST"} = conn, %{input: input}) when is_binary(input) do
    if content_type?(conn, input) do
      :ok
    else
      {:error, 400, "InvalidRequest", "request body must use content-type #{input}"}
    end
  end

  defp validate_content_type(_conn, _method), do: :ok

  defp json_content_type?(conn), do: content_type?(conn, @json)

  defp content_type?(conn, expected) do
    conn
    |> get_req_header("content-type")
    |> Enum.any?(fn content_type ->
      content_type
      |> String.split(";", parts: 2)
      |> List.first()
      |> String.trim()
      |> String.downcase() == expected
    end)
  end

  defp proxy_or_unknown(conn, params, method_nsid) do
    case Proxy.request(conn, method_nsid, params) do
      {:ok, response} ->
        proxy_response(conn, response)

      :not_configured ->
        XrpcErrorJSON.render(conn, 404, "UnknownMethod", "#{method_nsid} is not a supported XRPC method")

      {:error, _reason} ->
        XrpcErrorJSON.render(conn, 502, "UpstreamFailure", "proxied XRPC request failed")
    end
  end

  defp dispatch(conn, params, method) do
    result =
      Tempest.Telemetry.timed([:xrpc, :request], %{nsid: method.nsid, method: conn.method}, fn ->
        {module, function} = method.handler
        apply(module, function, [conn, params, method])
      end)

    case result do
      {:ok, body} ->
        respond(conn, method, body)

      {:error, status, error, message} ->
        XrpcErrorJSON.render(conn, status, error, message)
    end
  end

  defp proxy_response(conn, response) do
    content_type = response.headers |> Map.get("content-type", [@json]) |> List.first()

    conn
    |> put_resp_content_type(content_type)
    |> send_resp(response.status, proxy_body(response.body))
  end

  defp proxy_body(nil), do: ""
  defp proxy_body(body) when is_binary(body), do: body
  defp proxy_body(body), do: Jason.encode!(body)

  defp respond(conn, %{output: @json}, body), do: json(conn, body)

  defp respond(conn, %{nsid: "com.atproto.sync.getBlob"}, %{redirect: url}) do
    conn
    |> put_resp_header("location", url)
    |> put_resp_header("content-security-policy", "default-src 'none'; sandbox")
    |> put_resp_header("x-content-type-options", "nosniff")
    |> send_resp(302, "")
  end

  defp respond(conn, %{nsid: "com.atproto.sync.getBlob"}, %{bytes: bytes} = blob) do
    conn
    |> put_resp_content_type(blob.mime_type, nil)
    |> put_resp_header("content-length", Integer.to_string(blob.content_length))
    |> put_resp_header("content-security-policy", "default-src 'none'; sandbox")
    |> put_resp_header("x-content-type-options", "nosniff")
    |> send_resp(200, bytes)
  end

  defp respond(conn, %{output: content_type}, body) when is_binary(content_type) and is_binary(body) do
    conn
    |> put_resp_content_type(content_type)
    |> send_resp(200, body)
  end
end
