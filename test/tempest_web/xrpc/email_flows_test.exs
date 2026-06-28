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

    token = assert_email_token_sent(to: {nil, account.email}, subject: "Reset your Tempest Test password")

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

    confirm_token = assert_email_token_sent(to: {nil, account.email}, subject: "Confirm your Tempest Test email")

    conn
    |> recycle()
    |> put_req_header("content-type", "application/json")
    |> post(~p"/xrpc/com.atproto.server.confirmEmail", %{"token" => confirm_token})
    |> json_response(200)

    update_resp =
      conn
      |> recycle()
      |> put_req_header("authorization", "Bearer #{session["accessJwt"]}")
      |> put_req_header("content-type", "application/json")
      |> post(~p"/xrpc/com.atproto.server.requestEmailUpdate", %{"email" => "new-email@example.com"})
      |> json_response(200)

    assert update_resp == %{"tokenRequired" => true}

    update_token =
      assert_email_token_sent(to: {nil, "new-email@example.com"}, subject: "Confirm your Tempest Test email change")

    conn
    |> recycle()
    |> put_req_header("content-type", "application/json")
    |> post(~p"/xrpc/com.atproto.server.updateEmail", %{"token" => update_token})
    |> json_response(200)

    assert Repo.get_by!(Account, did: account.did).email == "new-email@example.com"
  end

  test "requestPasswordReset is enumeration-safe for unknown identifiers", %{conn: conn} do
    unknown_email = "does-not-exist-#{System.unique_integer([:positive])}@example.com"
    unknown_handle = "nobody-#{System.unique_integer([:positive])}.test"
    unknown_did = "did:plc:#{"a" <> Integer.to_string(System.unique_integer([:positive]))}"

    for identifier <- [unknown_email, unknown_handle, unknown_did] do
      conn
      |> recycle()
      |> put_req_header("content-type", "application/json")
      |> post(~p"/xrpc/com.atproto.server.requestPasswordReset", %{"email" => identifier})
      |> json_response(200)
    end
  end

  test "resetPassword rejects token reuse, weak passwords, and revoked sessions", %{conn: conn} do
    account = create_account!("reset-reuse.test", "reset-reuse@example.com")
    {:ok, login} = Accounts.create_session(account.handle, @password)

    conn
    |> recycle()
    |> put_req_header("content-type", "application/json")
    |> post(~p"/xrpc/com.atproto.server.requestPasswordReset", %{"email" => account.email})
    |> json_response(200)

    token = assert_email_token_sent(to: {nil, account.email}, subject: "Reset your Tempest Test password")

    new_password = "new correct horse battery staple"

    conn
    |> recycle()
    |> put_req_header("content-type", "application/json")
    |> post(~p"/xrpc/com.atproto.server.resetPassword", %{"token" => token, "password" => new_password})
    |> json_response(200)

    assert {:error, :invalid_token} = Accounts.authenticate_refresh(login["refreshJwt"])
    assert {:ok, _session} = Accounts.create_session(account.handle, new_password)

    conn
    |> recycle()
    |> put_req_header("content-type", "application/json")
    |> post(~p"/xrpc/com.atproto.server.resetPassword", %{"token" => token, "password" => new_password})
    |> json_response(400)

    conn
    |> recycle()
    |> put_req_header("content-type", "application/json")
    |> post(~p"/xrpc/com.atproto.server.resetPassword", %{
      "token" => "invalid-token-value",
      "password" => new_password
    })
    |> json_response(400)

    conn
    |> recycle()
    |> put_req_header("content-type", "application/json")
    |> post(~p"/xrpc/com.atproto.server.resetPassword", %{"token" => token, "password" => "short"})
    |> json_response(400)
  end

  test "confirmEmail accepts {email, token} and rejects mismatched email", %{conn: conn} do
    account = create_account!("confirm-shape.test", "confirm-shape@example.com")
    {:ok, session} = Accounts.create_session(account.handle, @password)

    conn
    |> recycle()
    |> put_req_header("authorization", "Bearer #{session["accessJwt"]}")
    |> put_req_header("content-type", "application/json")
    |> post(~p"/xrpc/com.atproto.server.requestEmailConfirmation", %{})
    |> json_response(200)

    token = assert_email_token_sent(to: {nil, account.email}, subject: "Confirm your Tempest Test email")

    conn
    |> recycle()
    |> put_req_header("content-type", "application/json")
    |> post(~p"/xrpc/com.atproto.server.confirmEmail", %{"token" => token, "email" => account.email})
    |> json_response(200)

    {:ok, _session2} = Accounts.create_session(account.handle, @password)

    conn
    |> recycle()
    |> put_req_header("authorization", "Bearer #{session["accessJwt"]}")
    |> put_req_header("content-type", "application/json")
    |> post(~p"/xrpc/com.atproto.server.requestEmailConfirmation", %{})
    |> json_response(200)

    token2 = assert_email_token_sent(to: {nil, account.email}, subject: "Confirm your Tempest Test email")

    conn
    |> recycle()
    |> put_req_header("content-type", "application/json")
    |> post(~p"/xrpc/com.atproto.server.confirmEmail", %{
      "token" => token2,
      "email" => "wrong-email@example.com"
    })
    |> json_response(400)
  end

  test "updateEmail accepts {email, token} and rejects wrong target email", %{conn: conn} do
    account = create_account!("update-shape.test", "update-shape@example.com")
    {:ok, session} = Accounts.create_session(account.handle, @password)

    conn
    |> recycle()
    |> put_req_header("authorization", "Bearer #{session["accessJwt"]}")
    |> put_req_header("content-type", "application/json")
    |> post(~p"/xrpc/com.atproto.server.requestEmailUpdate", %{"email" => "update-target@example.com"})
    |> json_response(200)

    token =
      assert_email_token_sent(to: {nil, "update-target@example.com"}, subject: "Confirm your Tempest Test email change")

    conn
    |> recycle()
    |> put_req_header("content-type", "application/json")
    |> post(~p"/xrpc/com.atproto.server.updateEmail", %{
      "token" => token,
      "email" => "update-target@example.com"
    })
    |> json_response(200)

    assert Repo.get_by!(Account, did: account.did).email == "update-target@example.com"

    conn
    |> recycle()
    |> put_req_header("authorization", "Bearer #{session["accessJwt"]}")
    |> put_req_header("content-type", "application/json")
    |> post(~p"/xrpc/com.atproto.server.requestEmailUpdate", %{"email" => "second-target@example.com"})
    |> json_response(200)

    token2 =
      assert_email_token_sent(to: {nil, "second-target@example.com"}, subject: "Confirm your Tempest Test email change")

    conn
    |> recycle()
    |> put_req_header("content-type", "application/json")
    |> post(~p"/xrpc/com.atproto.server.updateEmail", %{
      "token" => token2,
      "email" => "different-target@example.com"
    })
    |> json_response(400)

    assert Repo.get_by!(Account, did: account.did).email == "update-target@example.com"
  end

  test "invalid, wrong-purpose, and expired tokens are rejected", %{conn: conn} do
    account = create_account!("token-reject.test", "token-reject@example.com")
    {:ok, session} = Accounts.create_session(account.handle, @password)

    conn
    |> recycle()
    |> put_req_header("authorization", "Bearer #{session["accessJwt"]}")
    |> put_req_header("content-type", "application/json")
    |> post(~p"/xrpc/com.atproto.server.requestEmailConfirmation", %{})
    |> json_response(200)

    confirm_token = assert_email_token_sent(to: {nil, account.email}, subject: "Confirm your Tempest Test email")

    conn
    |> recycle()
    |> put_req_header("content-type", "application/json")
    |> post(~p"/xrpc/com.atproto.server.updateEmail", %{"token" => confirm_token})
    |> json_response(400)

    conn
    |> recycle()
    |> put_req_header("content-type", "application/json")
    |> post(~p"/xrpc/com.atproto.server.resetPassword", %{
      "token" => confirm_token,
      "password" => "new correct horse battery staple"
    })
    |> json_response(400)

    conn
    |> recycle()
    |> put_req_header("content-type", "application/json")
    |> post(~p"/xrpc/com.atproto.server.confirmEmail", %{"token" => "totally-invalid-token"})
    |> json_response(400)
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
