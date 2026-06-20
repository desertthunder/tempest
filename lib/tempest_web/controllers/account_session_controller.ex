defmodule TempestWeb.AccountSessionController do
  use TempestWeb, :controller

  alias Tempest.Accounts

  def new(conn, params) do
    render_login(conn, params, nil)
  end

  def create(conn, %{"account" => account_params} = params) do
    identifier = Map.get(account_params, "identifier", "")
    password = Map.get(account_params, "password", "")
    return_to = return_to(params)

    case Accounts.create_browser_session(identifier, password) do
      {:ok, browser_session} ->
        conn
        |> renew_session()
        |> put_session(:account_session_id, browser_session.session.id)
        |> put_session(:account_session_family_id, browser_session.family_id)
        |> put_session(:account_did, browser_session.account.did)
        |> redirect(to: safe_return_to(return_to, ~p"/account"))

      {:error, reason} ->
        conn
        |> put_status(:unauthorized)
        |> render_login(params, login_error(reason))
    end
  end

  def create(conn, params), do: create(conn, Map.put(params, "account", %{}))

  def delete(conn, params) do
    Accounts.revoke_browser_session(
      get_session(conn, :account_session_id),
      get_session(conn, :account_session_family_id)
    )

    conn
    |> renew_session()
    |> redirect(to: safe_return_to(return_to(params), ~p"/"))
  end

  defp render_login(conn, params, error) do
    render(conn, :new,
      form: Phoenix.Component.to_form(%{}, as: :account),
      return_to: safe_return_to(return_to(params), ~p"/"),
      error: error
    )
  end

  defp return_to(params), do: Map.get(params, "return_to")

  defp safe_return_to(path, fallback) when is_binary(path) do
    cond do
      path == "" -> fallback
      String.starts_with?(path, "//") -> fallback
      String.contains?(path, ["\r", "\n"]) -> fallback
      String.starts_with?(path, "/") -> path
      true -> fallback
    end
  end

  defp safe_return_to(_path, fallback), do: fallback

  defp login_error(:inactive_account), do: "This account is not active."
  defp login_error(:rate_limited), do: "Too many attempts. Try again later."
  defp login_error(_reason), do: "The user name or password is incorrect."

  defp renew_session(conn) do
    conn
    |> configure_session(renew: true)
    |> clear_session()
  end
end
