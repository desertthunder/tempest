defmodule TempestWeb.XrpcErrorJSON do
  @moduledoc """
  Renders protocol-shaped XRPC JSON errors.
  """

  import Phoenix.Controller
  import Plug.Conn

  def render(conn, status, error, message \\ nil) do
    body =
      %{error: error}
      |> maybe_put_message(message)

    conn
    |> put_status(status)
    |> json(body)
  end

  defp maybe_put_message(body, nil), do: body
  defp maybe_put_message(body, ""), do: body
  defp maybe_put_message(body, message), do: Map.put(body, :message, message)
end
