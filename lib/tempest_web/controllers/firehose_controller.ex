defmodule TempestWeb.FirehoseController do
  use TempestWeb, :controller

  alias TempestWeb.FirehoseSocket
  alias TempestWeb.XrpcErrorJSON

  def subscribe_repos(conn, params) do
    with {:ok, cursor} <- parse_cursor(Map.get(params, "cursor")) do
      conn
      |> WebSockAdapter.upgrade(FirehoseSocket, %{cursor: cursor}, timeout: :infinity, max_frame_size: 5_000_000)
      |> halt()
    else
      {:error, :invalid_cursor} ->
        XrpcErrorJSON.render(conn, 400, "InvalidRequest", "cursor must be a non-negative integer")
    end
  rescue
    e in WebSockAdapter.UpgradeError ->
      XrpcErrorJSON.render(conn, 426, "UpgradeRequired", e.message)
  end

  defp parse_cursor(nil), do: {:ok, nil}

  defp parse_cursor(cursor) when is_binary(cursor) do
    case Integer.parse(cursor) do
      {value, ""} when value >= 0 -> {:ok, value}
      _other -> {:error, :invalid_cursor}
    end
  end
end
