defmodule Tempest.Security.EmailDeliveryConfigTest do
  use ExUnit.Case, async: true

  alias Tempest.Security.EmailConfig

  describe "provider selection" do
    test "resend provider selects Swoosh.Adapters.Resend without a network call" do
      env = valid_resend_env()

      config = EmailConfig.resolve(env, env: :prod)

      assert config.provider == :resend
      assert config.mailer_config[:adapter] == Swoosh.Adapters.Resend
      assert config.mailer_config[:api_key] == "re_test_key"
      assert config.email_config[:from_name] == "Tempest"
      assert config.email_config[:from_address] == "no-reply@example.com"
    end

    test "smtp provider still selects Swoosh.Adapters.SMTP" do
      env = %{
        "TEMPEST_EMAIL_PROVIDER" => "smtp",
        "TEMPEST_SMTP_HOST" => "smtp.resend.com",
        "TEMPEST_SMTP_PORT" => "587",
        "TEMPEST_SMTP_USERNAME" => "resend",
        "TEMPEST_SMTP_PASSWORD" => "re_test_key",
        "TEMPEST_EMAIL_FROM_NAME" => "Tempest",
        "TEMPEST_EMAIL_FROM_ADDRESS" => "no-reply@example.com"
      }

      config = EmailConfig.resolve(env, env: :prod)

      assert config.provider == :smtp
      assert config.mailer_config[:adapter] == Swoosh.Adapters.SMTP
      assert config.mailer_config[:relay] == "smtp.resend.com"
      assert config.mailer_config[:port] == 587
      assert config.mailer_config[:tls] == :if_available
    end

    test "local provider is the default when nothing is set" do
      config = EmailConfig.resolve(%{}, env: :prod)

      assert config.provider == :local
      assert config.mailer_config[:adapter] == Swoosh.Adapters.Local
    end

    test "legacy TEMPEST_SMTP_ENABLED selects smtp when provider is unset" do
      env = %{
        "TEMPEST_SMTP_ENABLED" => "true",
        "TEMPEST_SMTP_HOST" => "smtp.resend.com",
        "TEMPEST_EMAIL_FROM_ADDRESS" => "no-reply@example.com"
      }

      config = EmailConfig.resolve(env, env: :prod)

      assert config.provider == :smtp
    end

    test "legacy TEMPEST_SMTP_FROM_* aliases map to shared from config" do
      env = %{
        "TEMPEST_SMTP_ENABLED" => "true",
        "TEMPEST_SMTP_HOST" => "smtp.resend.com",
        "TEMPEST_SMTP_FROM_NAME" => "Legacy Tempest",
        "TEMPEST_SMTP_FROM_ADDRESS" => "legacy@example.com"
      }

      config = EmailConfig.resolve(env, env: :dev)

      assert config.provider == :smtp
      assert config.email_config[:from_name] == "Legacy Tempest"
      assert config.email_config[:from_address] == "legacy@example.com"
    end

    test "shared TEMPEST_EMAIL_FROM_* takes precedence over legacy aliases" do
      env = %{
        "TEMPEST_EMAIL_PROVIDER" => "smtp",
        "TEMPEST_SMTP_HOST" => "smtp.resend.com",
        "TEMPEST_EMAIL_FROM_NAME" => "New Tempest",
        "TEMPEST_EMAIL_FROM_ADDRESS" => "new@example.com",
        "TEMPEST_SMTP_FROM_NAME" => "Legacy Tempest",
        "TEMPEST_SMTP_FROM_ADDRESS" => "legacy@example.com"
      }

      config = EmailConfig.resolve(env, env: :dev)

      assert config.email_config[:from_name] == "New Tempest"
      assert config.email_config[:from_address] == "new@example.com"
    end
  end

  describe "production fail-closed" do
    test "resend without API key raises in production" do
      env = Map.delete(valid_resend_env(), "TEMPEST_RESEND_API_KEY")

      assert_raise RuntimeError, ~r/TEMPEST_RESEND_API_KEY/, fn ->
        EmailConfig.resolve(env, env: :prod)
      end
    end

    test "resend without from address raises in production" do
      env = Map.delete(valid_resend_env(), "TEMPEST_EMAIL_FROM_ADDRESS")

      assert_raise RuntimeError, ~r/from address/, fn ->
        EmailConfig.resolve(env, env: :prod)
      end
    end

    test "smtp without host raises in production" do
      env = %{
        "TEMPEST_EMAIL_PROVIDER" => "smtp",
        "TEMPEST_EMAIL_FROM_ADDRESS" => "no-reply@example.com"
      }

      assert_raise RuntimeError, ~r/TEMPEST_SMTP_HOST/, fn ->
        EmailConfig.resolve(env, env: :prod)
      end
    end

    test "smtp without from address raises in production" do
      env = %{
        "TEMPEST_EMAIL_PROVIDER" => "smtp",
        "TEMPEST_SMTP_HOST" => "smtp.resend.com"
      }

      assert_raise RuntimeError, ~r/from address/, fn ->
        EmailConfig.resolve(env, env: :prod)
      end
    end
  end

  describe "non-production fallback" do
    test "resend missing API key does not raise outside production" do
      env = Map.delete(valid_resend_env(), "TEMPEST_RESEND_API_KEY")

      config = EmailConfig.resolve(env, env: :dev)

      assert config.provider == :resend
      assert config.mailer_config[:adapter] == Swoosh.Adapters.Resend
      assert config.mailer_config[:api_key] == nil
    end

    test "invalid provider value raises ArgumentError" do
      assert_raise ArgumentError, ~r/invalid TEMPEST_EMAIL_PROVIDER/, fn ->
        EmailConfig.resolve(%{"TEMPEST_EMAIL_PROVIDER" => "mailgun"}, env: :dev)
      end
    end
  end

  defp valid_resend_env do
    %{
      "TEMPEST_EMAIL_PROVIDER" => "resend",
      "TEMPEST_RESEND_API_KEY" => "re_test_key",
      "TEMPEST_EMAIL_FROM_NAME" => "Tempest",
      "TEMPEST_EMAIL_FROM_ADDRESS" => "no-reply@example.com"
    }
  end
end
