defmodule Tempest.Identity.PlcClient do
  @moduledoc """
  Boundary for publishing DID PLC operations.

  The client is configurable so tests can use Req.Test or another fake service.
  """

  require Logger

  def fetch_state(did) when is_binary(did) do
    url = plc_directory_url() <> "/" <> URI.encode(did)

    opts =
      [url: url, retry: false]
      |> Keyword.merge(identity_config(:http_req_options) || [])

    case Req.get(opts) do
      {:ok, %{status: 200, body: body}} when is_map(body) -> {:ok, body}
      {:ok, %{status: 200, body: body}} when is_binary(body) -> Jason.decode(body)
      {:ok, %{status: 404}} -> {:ok, nil}
      {:ok, %{status: status}} -> {:error, {:plc_status, status}}
      {:error, reason} -> {:error, {:plc_request_failed, reason}}
    end
  end

  def publish_operation(did, operation) when is_binary(did) and is_map(operation) do
    url = plc_directory_url() <> "/" <> URI.encode(did)
    prev = Map.get(operation, "prev")
    endpoint = get_in(operation, ["services", "atproto_pds", "endpoint"])

    opts =
      [url: url, json: operation, retry: false]
      |> Keyword.merge(identity_config(:http_req_options) || [])

    Logger.info("Publishing PLC operation",
      did: did,
      plc_url: url,
      plc_prev: prev,
      plc_service_endpoint: endpoint,
      has_signature: is_binary(Map.get(operation, "sig"))
    )

    case Req.post(opts) do
      {:ok, %{status: status}} when status in 200..299 ->
        Logger.info("Published PLC operation did=#{did} plc_url=#{url} plc_status=#{status}",
          did: did,
          plc_url: url,
          plc_status: status
        )

        :ok

      {:ok, %{status: status, body: body}} ->
        response_body = response_body_snippet(body)

        Logger.error(
          "PLC directory rejected operation did=#{did} plc_url=#{url} plc_status=#{status} plc_response_body=#{response_body}",
          did: did,
          plc_url: url,
          plc_status: status,
          plc_response_body: response_body
        )

        {:error, {:plc_status, status}}

      {:error, reason} ->
        request_error = inspect(reason)

        Logger.error("PLC directory request failed did=#{did} plc_url=#{url} plc_request_error=#{request_error}",
          did: did,
          plc_url: url,
          plc_request_error: request_error
        )

        {:error, {:plc_request_failed, reason}}
    end
  end

  defp response_body_snippet(body) when is_binary(body) do
    body
    |> String.slice(0, 500)
    |> String.replace(~r/\s+/, " ")
  end

  defp response_body_snippet(body) when is_map(body) do
    body
    |> Jason.encode()
    |> case do
      {:ok, encoded} -> response_body_snippet(encoded)
      {:error, _reason} -> inspect(body, limit: 20, printable_limit: 500)
    end
  end

  defp response_body_snippet(body), do: inspect(body, limit: 20, printable_limit: 500)

  defp plc_directory_url do
    identity_config(:plc_directory_url) || "https://plc.directory"
  end

  defp identity_config(key) do
    :tempest
    |> Application.get_env(Tempest.Identity, [])
    |> Keyword.get(key)
  end
end
