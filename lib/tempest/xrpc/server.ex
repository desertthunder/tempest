defmodule Tempest.Xrpc.Server do
  @moduledoc """
  Handlers for `com.atproto.server.*` XRPC methods.
  """

  def describe_server(_conn, _params, _method) do
    config = Tempest.Config.load!()

    {:ok,
     %{
       availableUserDomains: [available_user_domain(config.hostname)],
       inviteCodeRequired: false,
       links: %{
         privacyPolicy: nil,
         termsOfService: nil
       }
     }}
  end

  defp available_user_domain("." <> _domain = hostname), do: hostname
  defp available_user_domain(hostname), do: "." <> hostname
end
