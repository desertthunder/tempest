defmodule TempestWeb.Xrpc.EmailFlowsTest do
  use TempestWeb.ConnCase

  import Swoosh.TestAssertions

  alias Tempest.{Accounts, Repo}
  alias Tempest.Accounts.Account

  @password "correct horse battery staple"

  setup do
    old_config = Application.get_env(:tempest, Tempest.Security.Email)

    Application.put_env(:tempest, Tempest.Security.Email,
      from_name: "Tempest Test",
      from_address: "noreply@example.com"
    )

    on_exit(fn ->
      if old_config do
        Application.put_env(:tempest, Tempest.Security.Email, old_config)
      else
        Application.delete_env(:tempest, Tempest.Security.Email)
      end
    end)

    :ok
  end

  test "requestPasswordReset sends reset email and resetPassword consumes token", %{conn: conn} do
    account = create_account!("email-reset.test", "email-reset@example.com")

    conn
    |> put_req_header("content-type", "application/json")
    |> post(~p"/xrpc/com.atproto.server.requestPasswordReset", %{"email" => account.email})
    |> json_response(200)

    token = assert_email_token_sent(to: {nil, account.email}, subject: "Reset your Tempest password")

    conn
    |> recycle()
    |> put_req_header("content-type", "application/json")
    |> post(~p"/xrpc/com.atproto.server.resetPassword", %{
      "token" => token,
      "password" => "new correct horse battery staple"
    })
    |> json_response(200)

    assert {:ok, session} = Accounts.create_session(account.handle, "new correct horse battery staple")
    assert session["did"] == account.did
  end

  test "email confirmation and update flows send account emails", %{conn: conn} do
    account = create_account!("email-update.test", "email-update@example.com")
    {:ok, session} = Accounts.create_session(account.handle, @password)

    conn
    |> put_req_header("authorization", "Bearer #{session["accessJwt"]}")
    |> put_req_header("content-type", "application/json")
    |> post(~p"/xrpc/com.atproto.server.requestEmailConfirmation", %{})
    |> json_response(200)

    confirm_token = assert_email_token_sent(to: {nil, account.email}, subject: "Confirm your Tempest email")

    conn
    |> recycle()
    |> put_req_header("content-type", "application/json")
    |> post(~p"/xrpc/com.atproto.server.confirmEmail", %{"token" => confirm_token})
    |> json_response(200)

    conn
    |> recycle()
    |> put_req_header("authorization", "Bearer #{session["accessJwt"]}")
    |> put_req_header("content-type", "application/json")
    |> post(~p"/xrpc/com.atproto.server.requestEmailUpdate", %{"email" => "new-email@example.com"})
    |> json_response(200)

    update_token =
      assert_email_token_sent(to: {nil, "new-email@example.com"}, subject: "Confirm your Tempest email change")

    conn
    |> recycle()
    |> put_req_header("content-type", "application/json")
    |> post(~p"/xrpc/com.atproto.server.updateEmail", %{"token" => update_token})
    |> json_response(200)

    assert Repo.get_by!(Account, did: account.did).email == "new-email@example.com"
  end

  defp create_account!(handle, email) do
    {:ok, session} = Accounts.create_account(%{"handle" => handle, "email" => email, "password" => @password})
    Repo.get_by!(Account, did: session["did"])
  end

  defp assert_email_token_sent(assertions) do
    assert_email_sent(fn email ->
      Enum.each(assertions, fn
        {:to, to} -> assert Swoosh.Email.Recipient.format(to) in email.to
        {:subject, subject} -> assert email.subject == subject
      end)

      [token] = Regex.run(~r/[A-Za-z0-9_-]{40,}/, email.text_body)
      send(self(), {:email_token, token})
      true
    end)

    assert_received {:email_token, token}
    token
  end
end
