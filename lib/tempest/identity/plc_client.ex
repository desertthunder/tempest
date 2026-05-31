defmodule Tempest.Identity.PlcClient do
  @moduledoc """
  Boundary for publishing DID PLC operations.

  The client is configurable so tests can use Req.Test or another fake service.
  """

  def publish_operation(did, operation) when is_binary(did) and is_map(operation) do
    url = plc_directory_url() <> "/" <> URI.encode(did)

    opts =
      [url: url, json: operation, retry: false]
      |> Keyword.merge(identity_config(:http_req_options) || [])

    case Req.post(opts) do
      {:ok, %{status: status}} when status in 200..299 -> :ok
      {:ok, %{status: status}} -> {:error, {:plc_status, status}}
      {:error, reason} -> {:error, {:plc_request_failed, reason}}
    end
  end

  defp plc_directory_url do
    identity_config(:plc_directory_url) || "https://plc.directory"
  end

  defp identity_config(key) do
    :tempest
    |> Application.get_env(Tempest.Identity, [])
    |> Keyword.get(key)
  end
end
