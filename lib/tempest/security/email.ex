defmodule Tempest.Security.Email do
  @moduledoc """
  Security email delivery helpers.

  Builds plain-text security email (password reset, email confirmation, email
  update) and delivers them through the configured Swoosh mailer.

  Telemetry on `[:tempest, :email, :deliver]` carries `purpose`, `provider`, and `status`.
  """

  import Swoosh.Email

  alias Tempest.{Config, Mailer, Security}
  alias Tempest.Accounts.Account
  alias Tempest.Security.EmailToken

  @doc """
  Sends an email-confirmation token to the account's current email address.
  """
  def deliver_confirmation(%Account{} = account) do
    with {:ok, %{token: token, email_token: email_token}} <-
           Security.issue_email_token(account, "confirm_email") do
      deliver(build_confirmation(account, token, email_token))
    end
  end

  @doc """
  Sends an email-update token to a new email address.
  """
  def deliver_update(%Account{} = account, new_email) do
    with {:ok, %{token: token, email_token: email_token}} <-
           Security.issue_email_token(account, "update_email", new_email) do
      deliver(build_update(account, new_email, token, email_token))
    end
  end

  @doc """
  Sends a password-reset token to the account's current email address.
  """
  def deliver_password_reset(%Account{} = account) do
    with {:ok, %{token: token, email_token: email_token}} <-
           Security.issue_email_token(account, "reset_password") do
      deliver(build_password_reset(account, token, email_token))
    end
  end

  defp build_confirmation(%Account{} = account, token, %EmailToken{expires_at: expires_at}) do
    body = """
    Confirm your email for #{instance_name()}.

    Account: @#{account.handle}

    Use this token to confirm your email:

      #{token}

    #{action_line("confirm_email", token)}

    This token expires at #{format_expiry(expires_at)}.

    If you did not request this email, you can safely ignore it.
    """

    new()
    |> from(from_address())
    |> to(account.email)
    |> subject("Confirm your #{instance_name()} email")
    |> text_body(body)
    |> put_provider_options("confirm_email", token)
  end

  defp build_update(%Account{} = account, new_email, token, %EmailToken{expires_at: expires_at}) do
    body = """
    Confirm your new email for #{instance_name()}.

    Account: @#{account.handle}

    Use this token to confirm your new email address (#{new_email}):

      #{token}

    #{action_line("update_email", token)}

    This token expires at #{format_expiry(expires_at)}.

    If you did not request this email, you can safely ignore it.
    """

    new()
    |> from(from_address())
    |> to(new_email)
    |> subject("Confirm your #{instance_name()} email change")
    |> text_body(body)
    |> put_provider_options("update_email", token)
  end

  defp build_password_reset(%Account{} = account, token, %EmailToken{expires_at: expires_at}) do
    body = """
    Reset your #{instance_name()} password.

    Account: @#{account.handle}

    Use this token to reset your password:

      #{token}

    #{action_line("reset_password", token)}

    This token expires at #{format_expiry(expires_at)}.

    If you did not request a password reset, you can safely ignore this email.
    """

    new()
    |> from(from_address())
    |> to(account.email)
    |> subject("Reset your #{instance_name()} password")
    |> text_body(body)
    |> put_provider_options("reset_password", token)
  end

  defp deliver(%Swoosh.Email{} = email) do
    purpose = email.provider_options[:__purpose__] || "unknown"
    provider = mailer_provider()

    case Mailer.deliver(email) do
      {:ok, result} ->
        :telemetry.execute(
          [:tempest, :email, :deliver],
          %{count: 1},
          %{purpose: purpose, provider: provider, status: :ok}
        )

        {:ok, result}

      {:error, reason} ->
        :telemetry.execute(
          [:tempest, :email, :deliver],
          %{count: 1},
          %{purpose: purpose, provider: provider, status: :error}
        )

        {:error, sanitize_delivery_error(reason)}
    end
  end

  defp put_provider_options(email, purpose, token) do
    email
    |> put_provider_option(:__purpose__, purpose)
    |> put_resend_options(purpose, token)
  end

  defp put_resend_options(email, purpose, token) do
    if mailer_provider() == :resend do
      email
      |> put_provider_option(:tags, [%{name: "purpose", value: purpose}])
      |> put_provider_option(:idempotency_key, idempotency_key(purpose, token))
    else
      email
    end
  end

  defp idempotency_key(purpose, token) do
    "#{purpose}:#{hash_for_key(token)}"
  end

  defp hash_for_key(token) do
    :crypto.hash(:sha256, token) |> Base.url_encode64(padding: false)
  end

  defp from_address do
    config = Application.get_env(:tempest, __MODULE__, [])
    name = Keyword.get(config, :from_name, "Tempest")
    address = Keyword.get(config, :from_address, "noreply@localhost")
    {name, address}
  end

  defp instance_name do
    config = Application.get_env(:tempest, __MODULE__, [])
    Keyword.get(config, :from_name, "Tempest")
  end

  # Builds an action URL line for the email body when a public URL is configured.
  # Falls back to an empty string (plain token copy above suffices) when no
  # public URL is available, e.g. during tests or local dev without a host.
  defp action_line(purpose, token) do
    case action_url(purpose, token) do
      nil -> ""
      url -> "Or follow this link:\n\n  #{url}"
    end
  end

  defp action_url(purpose, token) do
    case public_base_url() do
      nil ->
        nil

      base ->
        path =
          case purpose do
            "confirm_email" -> "/account/email/confirm"
            "update_email" -> "/account/email/update"
            "reset_password" -> "/account/password/reset"
          end

        "#{base}#{path}?token=#{token}"
    end
  end

  defp public_base_url do
    Config.load!().public_url
  rescue
    _ -> nil
  end

  defp format_expiry(%DateTime{} = expires_at) do
    expires_at
    |> DateTime.shift_zone!("Etc/UTC")
    |> Calendar.strftime("%Y-%m-%d %H:%M UTC")
  end

  defp mailer_provider do
    config = Application.get_env(:tempest, Tempest.Mailer, [])
    adapter = Keyword.get(config, :adapter, Swoosh.Adapters.Local)

    case adapter do
      Swoosh.Adapters.Resend -> :resend
      Swoosh.Adapters.SMTP -> :smtp
      _other -> :local
    end
  end

  # Sanitize Swoosh/adapter errors before they reach callers or logs.
  #
  # The Resend adapter returns {:error, {status, body}} on HTTP failures,
  # where `body` may be a decoded provider error map.
  #
  # The SMTP adapter returns{:error, reason} with protocol detail.
  # Collapse all of these into a generic delivery-failure atom so raw tokens,
  # API keys, auth headers, and provider error bodies never reach the XRPC error
  # path or production logs.
  defp sanitize_delivery_error({:error, reason}), do: {:error, sanitize_delivery_error(reason)}

  defp sanitize_delivery_error({status, _body}) when is_integer(status),
    do: :delivery_failed

  defp sanitize_delivery_error({:validation, _}), do: :delivery_failed

  defp sanitize_delivery_error({:unexpected_response, _}), do: :delivery_failed

  defp sanitize_delivery_error(_other), do: :delivery_failed
end
