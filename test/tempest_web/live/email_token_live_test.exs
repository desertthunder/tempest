defmodule TempestWeb.EmailTokenLiveTest do
  use TempestWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

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

  describe "password reset page" do
    test "renders the reset form with stable element IDs", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/account/password/reset")

      assert has_element?(view, "#password-reset-form")
      assert has_element?(view, "#password-reset-form button[type='submit']")
    end

    test "pre-fills token from query param", %{conn: conn} do
      {:ok, _view, html} =
        conn
        |> live(~p"/account/password/reset?token=prefilled-token")

      assert html =~ "prefilled-token"
    end

    test "submits a valid reset token and redirects to login", %{conn: conn} do
      account = create_account!("reset-live.test", "reset-live@example.com")
      {:ok, %{token: token}} = Tempest.Security.issue_email_token(account, "reset_password")

      {:ok, view, _html} = live(conn, ~p"/account/password/reset?token=#{token}")

      view
      |> form("#password-reset-form", %{
        "password_reset" => %{"token" => token, "password" => "new correct horse battery staple"}
      })
      |> render_submit()

      assert_redirected(view, ~p"/account/login")

      assert {:ok, _session} =
               Accounts.create_session(account.handle, "new correct horse battery staple")
    end

    test "shows an error for an invalid token", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/account/password/reset")

      view
      |> form("#password-reset-form", %{
        "password_reset" => %{"token" => "invalid-token", "password" => "new correct horse battery staple"}
      })
      |> render_submit()

      assert render(view) =~ "Token is invalid or expired"
    end

    test "shows an error for a weak password", %{conn: conn} do
      account = create_account!("reset-weak.test", "reset-weak@example.com")
      {:ok, %{token: token}} = Tempest.Security.issue_email_token(account, "reset_password")

      {:ok, view, _html} = live(conn, ~p"/account/password/reset?token=#{token}")

      view
      |> form("#password-reset-form", %{"password_reset" => %{"token" => token, "password" => "short"}})
      |> render_submit()

      assert render(view) =~ "password must be"
    end
  end

  describe "email confirmation page" do
    test "renders the confirm form with stable element IDs", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/account/email/confirm")

      assert has_element?(view, "#confirm-email-form")
      assert has_element?(view, "#confirm-email-form button[type='submit']")
    end

    test "submits a valid confirmation token", %{conn: conn} do
      account = create_account!("confirm-live.test", "confirm-live@example.com")
      {:ok, %{token: token}} = Tempest.Security.issue_email_token(account, "confirm_email")

      {:ok, view, _html} = live(conn, ~p"/account/email/confirm?token=#{token}")

      view
      |> form("#confirm-email-form", %{"confirm_email" => %{"token" => token}})
      |> render_submit()

      assert_redirected(view, ~p"/")
    end

    test "submits with {email, token} and succeeds when email matches", %{conn: conn} do
      account = create_account!("confirm-shape-live.test", "confirm-shape-live@example.com")
      {:ok, %{token: token}} = Tempest.Security.issue_email_token(account, "confirm_email")

      {:ok, view, _html} = live(conn, ~p"/account/email/confirm?token=#{token}")

      view
      |> form("#confirm-email-form", %{
        "confirm_email" => %{"token" => token, "email" => account.email}
      })
      |> render_submit()

      assert_redirected(view, ~p"/")
    end

    test "shows an error for an invalid token", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/account/email/confirm")

      view
      |> form("#confirm-email-form", %{"confirm_email" => %{"token" => "invalid-token"}})
      |> render_submit()

      assert render(view) =~ "Token is invalid or expired"
    end
  end

  describe "email update page" do
    test "renders the update form with stable element IDs", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/account/email/update")

      assert has_element?(view, "#update-email-form")
      assert has_element?(view, "#update-email-form button[type='submit']")
    end

    test "submits a valid update token with matching email", %{conn: conn} do
      account = create_account!("update-live.test", "update-live@example.com")
      target_email = "new-update-live@example.com"

      {:ok, %{token: token}} =
        Tempest.Security.issue_email_token(account, "update_email", target_email)

      {:ok, view, _html} = live(conn, ~p"/account/email/update?token=#{token}")

      view
      |> form("#update-email-form", %{"update_email" => %{"token" => token, "email" => target_email}})
      |> render_submit()

      assert_redirected(view, ~p"/")
      assert Repo.get_by!(Account, did: account.did).email == target_email
    end

    test "shows an error when email does not match token target", %{conn: conn} do
      account = create_account!("update-mismatch.test", "update-mismatch@example.com")

      {:ok, %{token: token}} =
        Tempest.Security.issue_email_token(account, "update_email", "correct-target@example.com")

      {:ok, view, _html} = live(conn, ~p"/account/email/update?token=#{token}")

      view
      |> form("#update-email-form", %{
        "update_email" => %{"token" => token, "email" => "wrong-target@example.com"}
      })
      |> render_submit()

      assert render(view) =~ "Token is invalid or expired"
      assert Repo.get_by!(Account, did: account.did).email == "update-mismatch@example.com"
    end
  end

  defp create_account!(handle, email) do
    {:ok, session} = Accounts.create_account(%{"handle" => handle, "email" => email, "password" => @password})
    Repo.get_by!(Account, did: session["did"])
  end
end
