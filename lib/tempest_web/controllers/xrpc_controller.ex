defmodule TempestWeb.XrpcController do
  use TempestWeb, :controller

  alias Tempest.Xrpc.Registry
  alias TempestWeb.XrpcErrorJSON

  @json "application/json"

  def handle(%{method: "OPTIONS"} = conn, _params) do
    send_resp(conn, :no_content, "")
  end

  def handle(conn, %{"method" => method_nsid} = params) do
    with {:ok, method} <- fetch_method(method_nsid),
         :ok <- validate_verb(conn, method),
         :ok <- validate_content_type(conn, method) do
      dispatch(conn, params, method)
    else
      {:error, status, error, message} ->
        XrpcErrorJSON.render(conn, status, error, message)
    end
  end

  defp fetch_method(method_nsid) do
    case Registry.fetch(method_nsid) do
      {:ok, method} ->
        {:ok, method}

      {:error, :not_found} ->
        {:error, 404, "UnknownMethod", "#{method_nsid} is not a supported XRPC method"}
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

  defp dispatch(conn, params, method) do
    {module, function} = method.handler

    case apply(module, function, [conn, params, method]) do
      {:ok, body} ->
        json(conn, body)

      {:error, status, error, message} ->
        XrpcErrorJSON.render(conn, status, error, message)
    end
  end
end
