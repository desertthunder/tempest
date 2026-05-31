defmodule Tempest.Security.Email do
  @moduledoc """
  Security email delivery helpers.
  """

  import Swoosh.Email

  alias Tempest.{Mailer, Security}
  alias Tempest.Accounts.Account

  def deliver_confirmation(%Account{} = account) do
    with {:ok, %{token: token}} <- Security.issue_email_token(account, "confirm_email") do
      deliver(account.email, "Confirm your Tempest email", "Use this token to confirm your email: #{token}")
    end
  end

  def deliver_update(%Account{} = account, new_email) do
    with {:ok, %{token: token}} <- Security.issue_email_token(account, "update_email", new_email) do
      deliver(new_email, "Confirm your Tempest email change", "Use this token to confirm your new email: #{token}")
    end
  end

  def deliver_password_reset(%Account{} = account) do
    with {:ok, %{token: token}} <- Security.issue_email_token(account, "reset_password") do
      deliver(account.email, "Reset your Tempest password", "Use this token to reset your password: #{token}")
    end
  end

  defp deliver(to, subject, body) do
    new()
    |> from({"Tempest", "noreply@localhost"})
    |> to(to)
    |> subject(subject)
    |> text_body(body)
    |> Mailer.deliver()
  end
end
