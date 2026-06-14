defmodule TempestWeb.WellKnownController do
  use TempestWeb, :controller

  alias Tempest.Identity

  def did_json(conn, _params) do
    config = Tempest.Config.load!()

    json(conn, %{
      "@context" => ["https://www.w3.org/ns/did/v1"],
      "id" => "did:web:#{config.hostname}",
      "service" => [
        %{
          "id" => "#atproto_pds",
          "type" => "AtprotoPersonalDataServer",
          "serviceEndpoint" => service_endpoint(config)
        }
      ]
    })
  end

  def atproto_did(conn, _params) do
    case Identity.hosted_did_for_handle(conn.host) do
      {:ok, did} ->
        conn
        |> put_resp_content_type("text/plain")
        |> send_resp(200, did)

      {:error, :handle_not_found} ->
        send_resp(conn, 404, "handle not found")
    end
  end

  defp service_endpoint(config) do
    %{scheme: scheme, host: host, port: port} = URI.parse(config.public_url)
    default_port? = (scheme == "http" and port in [nil, 80]) or (scheme == "https" and port in [nil, 443])

    if default_port?, do: "#{scheme}://#{host}", else: "#{scheme}://#{host}:#{port}"
  end
end
