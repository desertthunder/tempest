defmodule TempestWeb.Xrpc.ProxyFallbackTest do
  use TempestWeb.ConnCase, async: false

  alias Tempest.Accounts.Tokens

  setup context do
    Req.Test.set_req_test_from_context(context)
    Req.Test.verify_on_exit!(context)

    old_config = Application.get_env(:tempest, Tempest.Xrpc.Proxy, [])
    old_identity_config = Application.get_env(:tempest, Tempest.Identity, [])

    on_exit(fn -> Application.put_env(:tempest, Tempest.Xrpc.Proxy, old_config) end)
    on_exit(fn -> Application.put_env(:tempest, Tempest.Identity, old_identity_config) end)
  end

  test "unknown service endpoints proxy to configured AppView", %{conn: conn} do
    Application.put_env(:tempest, Tempest.Xrpc.Proxy,
      upstream_base_url: "https://appview.example",
      http_req_options: [plug: {Req.Test, __MODULE__}]
    )

    Req.Test.expect(__MODULE__, fn conn ->
      assert conn.request_path == "/xrpc/app.bsky.feed.getTimeline"
      assert conn.query_string == "limit=1"
      assert Plug.Conn.get_req_header(conn, "x-bsky-topics") == ["science,news"]
      assert Plug.Conn.get_req_header(conn, "accept-language") == ["en-US"]
      assert Plug.Conn.get_req_header(conn, "atproto-content-labelers") == ["did:plc:labeler"]
      Req.Test.json(conn, %{"feed" => []})
    end)

    proxy_conn =
      conn
      |> put_req_header("x-bsky-topics", "science,news")
      |> put_req_header("accept-language", "en-US")
      |> put_req_header("atproto-content-labelers", "did:plc:labeler")
      |> get(~p"/xrpc/app.bsky.feed.getTimeline", %{"limit" => "1"})

    assert json_response(proxy_conn, 200) == %{"feed" => []}
  end

  test "unknown service queries preserve repeated parameters", %{conn: conn} do
    Application.put_env(:tempest, Tempest.Xrpc.Proxy,
      upstream_base_url: "https://appview.example",
      http_req_options: [plug: {Req.Test, __MODULE__}]
    )

    Req.Test.expect(__MODULE__, fn req_conn ->
      assert req_conn.request_path == "/xrpc/app.bsky.feed.getFeedGenerators"

      assert req_conn.query_string ==
               "feeds=at%3A%2F%2Fdid%3Aplc%3Aone%2Fapp.bsky.feed.generator%2Falpha&feeds=at%3A%2F%2Fdid%3Aplc%3Atwo%2Fapp.bsky.feed.generator%2Fbeta&actors=did%3Aplc%3Aone&actors=did%3Aplc%3Atwo"

      Req.Test.json(req_conn, %{"feeds" => []})
    end)

    proxy_conn =
      get(
        conn,
        "/xrpc/app.bsky.feed.getFeedGenerators?feeds=at%3A%2F%2Fdid%3Aplc%3Aone%2Fapp.bsky.feed.generator%2Falpha&feeds=at%3A%2F%2Fdid%3Aplc%3Atwo%2Fapp.bsky.feed.generator%2Fbeta&actors=did%3Aplc%3Aone&actors=did%3Aplc%3Atwo"
      )

    assert json_response(proxy_conn, 200) == %{"feeds" => []}
  end

  test "unknown app.bsky procedures proxy JSON bodies and service auth to configured AppView", %{conn: conn} do
    Application.put_env(:tempest, Tempest.Xrpc.Proxy,
      upstream_base_url: "https://appview.example",
      http_req_options: [plug: {Req.Test, __MODULE__}]
    )

    account =
      conn
      |> put_req_header("content-type", "application/json")
      |> post(~p"/xrpc/com.atproto.server.createAccount", %{
        "handle" => "proxy-auth.test",
        "email" => "proxy-auth@example.com",
        "password" => "correct horse battery staple"
      })
      |> json_response(200)

    Req.Test.expect(__MODULE__, fn req_conn ->
      assert req_conn.method == "POST"
      assert req_conn.request_path == "/xrpc/app.bsky.feed.sendInteractions"
      assert ["Bearer " <> service_auth] = Plug.Conn.get_req_header(req_conn, "authorization")
      assert {:ok, claims} = Tokens.verify_service_auth(service_auth)
      assert claims["iss"] == account["did"]
      assert claims["aud"] == "did:web:appview.example"
      assert claims["lxm"] == "app.bsky.feed.sendInteractions"

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
      |> recycle()
      |> put_req_header("authorization", "Bearer #{account["accessJwt"]}")
      |> put_req_header("content-type", "application/json")
      |> post(~p"/xrpc/app.bsky.feed.sendInteractions", %{"interactions" => []})

    assert %{"error" => "UpstreamPolicy"} = json_response(proxy_conn, 403)
  end

  test "unknown chat endpoints proxy to the atproto-proxy service endpoint", %{conn: conn} do
    Application.put_env(:tempest, Tempest.Identity,
      http_req_options: [
        plug: fn conn ->
          assert conn.method == "GET"
          assert conn.request_path == "/.well-known/did.json"

          Req.Test.json(conn, %{
            "id" => "did:web:api.bsky.chat",
            "service" => [
              %{
                "id" => "#bsky_chat",
                "type" => "BskyChat",
                "serviceEndpoint" => "https://api.bsky.chat"
              }
            ]
          })
        end
      ]
    )

    Application.put_env(:tempest, Tempest.Xrpc.Proxy, http_req_options: [plug: {Req.Test, __MODULE__}])

    account =
      conn
      |> put_req_header("content-type", "application/json")
      |> post(~p"/xrpc/com.atproto.server.createAccount", %{
        "handle" => "proxy-chat.test",
        "email" => "proxy-chat@example.com",
        "password" => "correct horse battery staple"
      })
      |> json_response(200)

    Req.Test.expect(__MODULE__, fn req_conn ->
      assert req_conn.method == "GET"
      assert req_conn.host == "api.bsky.chat"
      assert req_conn.request_path == "/xrpc/chat.bsky.convo.listConvos"
      assert req_conn.query_string == "limit=20"

      assert ["Bearer " <> service_auth] = Plug.Conn.get_req_header(req_conn, "authorization")
      assert {:ok, claims} = Tokens.verify_service_auth(service_auth)
      assert claims["iss"] == account["did"]
      assert claims["aud"] == "did:web:api.bsky.chat"
      assert claims["lxm"] == "chat.bsky.convo.listConvos"

      Req.Test.json(req_conn, %{"convos" => []})
    end)

    proxy_conn =
      conn
      |> recycle()
      |> put_req_header("authorization", "Bearer #{account["accessJwt"]}")
      |> put_req_header("atproto-proxy", "did:web:api.bsky.chat#bsky_chat")
      |> get(~p"/xrpc/chat.bsky.convo.listConvos", %{"limit" => "20"})

    assert json_response(proxy_conn, 200) == %{"convos" => []}
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
