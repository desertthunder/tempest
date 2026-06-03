defmodule Tempest.Security.Email do
  @moduledoc """
  Security email delivery helpers.
  """

  import Swoosh.Email

  alias Tempest.{Mailer, Security}
  alias Tempest.Accounts.Account

  def deliver_confirmation(%Account{} = account) do
    with {:ok, %{token: token}} <- Security.issue_email_token(account, "confirm_email") do
      deliver(account.email, "Confirm your Tempest email", "Use this token to confirm your email: #{token}", %{
        purpose: "confirm_email"
      })
    end
  end

  def deliver_update(%Account{} = account, new_email) do
    with {:ok, %{token: token}} <- Security.issue_email_token(account, "update_email", new_email) do
      deliver(new_email, "Confirm your Tempest email change", "Use this token to confirm your new email: #{token}", %{
        purpose: "update_email"
      })
    end
  end

  def deliver_password_reset(%Account{} = account) do
    with {:ok, %{token: token}} <- Security.issue_email_token(account, "reset_password") do
      deliver(account.email, "Reset your Tempest password", "Use this token to reset your password: #{token}", %{
        purpose: "reset_password"
      })
    end
  end

  defp deliver(to, subject, body, metadata) do
    email =
      new()
      |> from(from_address())
      |> to(to)
      |> subject(subject)
      |> text_body(body)

    case Mailer.deliver(email) do
      {:ok, result} ->
        :telemetry.execute([:tempest, :email, :deliver], %{count: 1}, Map.merge(metadata, %{status: :ok}))
        {:ok, result}

      {:error, reason} ->
        :telemetry.execute([:tempest, :email, :deliver], %{count: 1}, Map.merge(metadata, %{status: :error}))
        {:error, reason}
    end
  end

  defp from_address do
    config = Application.get_env(:tempest, __MODULE__, [])
    name = Keyword.get(config, :from_name, "Tempest")
    address = Keyword.get(config, :from_address, "noreply@localhost")
    {name, address}
  end
end
