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

  test "unknown service endpoints return UnknownMethod when no upstream is configured", %{conn: conn} do
    Application.put_env(:tempest, Tempest.Xrpc.Proxy, [])

    unknown_conn = get(conn, ~p"/xrpc/app.bsky.feed.getTimeline")

    assert %{"error" => "UnknownMethod"} = json_response(unknown_conn, 404)
  end

  test "unknown PDS endpoints are not proxied", %{conn: conn} do
    Application.put_env(:tempest, Tempest.Xrpc.Proxy, upstream_base_url: "https://appview.example")

    unknown_conn = get(conn, ~p"/xrpc/com.atproto.server.requestPasswordReset")

    assert %{"error" => "UnknownMethod"} = json_response(unknown_conn, 404)
  end
end
