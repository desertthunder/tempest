defmodule TempestWeb.Xrpc.ProxyFallbackTest do
  use TempestWeb.ConnCase, async: false

  setup context do
    Req.Test.set_req_test_from_context(context)
    Req.Test.verify_on_exit!(context)

    old_config = Application.get_env(:tempest, Tempest.Xrpc.Proxy, [])

    on_exit(fn -> Application.put_env(:tempest, Tempest.Xrpc.Proxy, old_config) end)
  end

  test "unknown service endpoints proxy to configured AppView", %{conn: conn} do
    Application.put_env(:tempest, Tempest.Xrpc.Proxy,
      upstream_base_url: "https://appview.example",
      http_req_options: [plug: {Req.Test, __MODULE__}]
    )

    Req.Test.expect(__MODULE__, fn conn ->
      assert conn.request_path == "/xrpc/app.bsky.feed.getTimeline"
      assert conn.query_string == "limit=1"
      Req.Test.json(conn, %{"feed" => []})
    end)

    proxy_conn =
      conn
      |> get(~p"/xrpc/app.bsky.feed.getTimeline", %{"limit" => "1"})

    assert json_response(proxy_conn, 200) == %{"feed" => []}
  end

  test "unknown app.bsky procedures proxy JSON bodies and bearer headers to configured AppView", %{conn: conn} do
    Application.put_env(:tempest, Tempest.Xrpc.Proxy,
      upstream_base_url: "https://appview.example",
      http_req_options: [plug: {Req.Test, __MODULE__}]
    )

    Req.Test.expect(__MODULE__, fn req_conn ->
      assert req_conn.method == "POST"
      assert req_conn.request_path == "/xrpc/app.bsky.feed.sendInteractions"
      assert Plug.Conn.get_req_header(req_conn, "authorization") == ["Bearer appview-token"]
      {:ok, body, req_conn} = Plug.Conn.read_body(req_conn)
      assert Jason.decode!(body) == %{"interactions" => []}

      req_conn
      |> Plug.Conn.put_resp_content_type("application/json")
      |> Plug.Conn.send_resp(
        403,
        Jason.encode!(%{"error" => "UpstreamPolicy", "message" => "AppView rejected request"})
      )
    end)

    proxy_conn =
      conn
      |> put_req_header("authorization", "Bearer appview-token")
      |> put_req_header("content-type", "application/json")
      |> post(~p"/xrpc/app.bsky.feed.sendInteractions", %{"interactions" => []})

    assert %{"error" => "UpstreamPolicy"} = json_response(proxy_conn, 403)
  end

  test "unknown service endpoints return UnknownMethod when no upstream is configured", %{conn: conn} do
    Application.put_env(:tempest, Tempest.Xrpc.Proxy, [])

    unknown_conn = get(conn, ~p"/xrpc/app.bsky.feed.getTimeline")

    assert %{"error" => "UnknownMethod"} = json_response(unknown_conn, 404)
  end

  test "unknown PDS endpoints are not proxied", %{conn: conn} do
    Application.put_env(:tempest, Tempest.Xrpc.Proxy, upstream_base_url: "https://appview.example")

    unknown_conn = get(conn, ~p"/xrpc/com.atproto.server.unknownMethod")

    assert %{"error" => "UnknownMethod"} = json_response(unknown_conn, 404)
  end
end
