defmodule Tempest.Xrpc.Actor do
  @moduledoc """
  Handlers for private `app.bsky.actor.*` compatibility XRPC methods.
  """

  alias Tempest.Accounts

  def get_preferences(conn, _params, _method) do
    {:ok, response} = Accounts.get_preferences(conn.assigns.auth_context)
    {:ok, response}
  end

  def put_preferences(conn, params, _method) do
    case Accounts.put_preferences(conn.assigns.auth_context, params) do
      {:ok, response} -> {:ok, response}
      {:error, reason} -> actor_error(reason)
    end
  end

  defp actor_error(:invalid_preferences),
    do: {:error, 400, "InvalidRequest", "preferences must be an array"}

  defp actor_error(_reason), do: {:error, 500, "InternalServerError", "actor preference request failed"}
end
