defmodule TempestWeb.WellKnownController do
  use TempestWeb, :controller

  alias Tempest.Identity

  def atproto_did(conn, _params) do
    case Identity.hosted_did_for_handle(conn.host) do
      {:ok, did} ->
        conn
        |> put_resp_content_type("text/plain")
        |> send_resp(200, did)

      {:error, :handle_not_found} ->
        send_resp(conn, 404, "handle not found")
    end
  end
end
