defmodule TempestWeb.XrpcControllerTest do
  use TempestWeb.ConnCase

  test "GET describeServer returns protocol metadata as JSON", %{conn: conn} do
    conn = get(conn, ~p"/xrpc/com.atproto.server.describeServer")
    response = json_response(conn, 200)

    assert get_resp_header(conn, "content-type") == ["application/json; charset=utf-8"]
    assert get_resp_header(conn, "access-control-allow-origin") == ["*"]
    assert response["did"] == "did:web:localhost"
    assert response["availableUserDomains"] == [".localhost"]
    assert response["inviteCodeRequired"] == false
    assert response["links"]["privacyPolicy"] == nil
    assert response["links"]["termsOfService"] == nil
  end

  test "XRPC preflight permits browser ATProto client headers", %{conn: conn} do
    conn =
      conn
      |> put_req_header("origin", "https://pdsmoover.com")
      |> put_req_header("access-control-request-method", "GET")
      |> put_req_header(
        "access-control-request-headers",
        "authorization,content-type,dpop,atproto-proxy,atproto-accept-labelers"
      )
      |> options(~p"/xrpc/com.atproto.server.describeServer")

    assert response(conn, 204) == ""
    assert get_resp_header(conn, "access-control-allow-origin") == ["*"]
    assert get_resp_header(conn, "access-control-allow-methods") == ["GET, POST, OPTIONS"]
    assert get_resp_header(conn, "access-control-expose-headers") == ["dpop-nonce"]

    [allow_headers] = get_resp_header(conn, "access-control-allow-headers")
    assert allow_headers =~ "authorization"
    assert allow_headers =~ "content-type"
    assert allow_headers =~ "dpop"
    assert allow_headers =~ "atproto-proxy"
    assert allow_headers =~ "atproto-accept-labelers"
    assert allow_headers =~ "x-atproto-accept-labelers"
  end

  test "GET did.json returns service DID document", %{conn: conn} do
    conn = get(conn, ~p"/.well-known/did.json")
    response = json_response(conn, 200)

    assert response["id"] == "did:web:localhost"

    assert [
             %{
               "id" => "#atproto_pds",
               "type" => "AtprotoPersonalDataServer",
               "serviceEndpoint" => "http://localhost:4002"
             }
           ] = response["service"]
  end

  test "unknown XRPC method returns JSON error", %{conn: conn} do
    conn = get(conn, ~p"/xrpc/com.atproto.unknown.method")
    response = json_response(conn, 404)

    assert get_resp_header(conn, "content-type") == ["application/json; charset=utf-8"]
    assert response["error"] == "UnknownMethod"
    assert response["message"] == "com.atproto.unknown.method is not a supported XRPC method"
  end

  test "POST to query method returns JSON error", %{conn: conn} do
    conn = post(conn, ~p"/xrpc/com.atproto.server.describeServer", %{})
    response = json_response(conn, 400)

    assert get_resp_header(conn, "content-type") == ["application/json; charset=utf-8"]
    assert response["error"] == "InvalidRequest"
    assert response["message"] =~ "must use GET"
  end

  test "GET to procedure method returns JSON error", %{conn: conn} do
    conn = get(conn, ~p"/xrpc/com.atproto.server.createSession")
    response = json_response(conn, 400)

    assert get_resp_header(conn, "content-type") == ["application/json; charset=utf-8"]
    assert response["error"] == "InvalidRequest"
    assert response["message"] =~ "must use POST"
  end

  test "procedure JSON content type is validated before handler execution", %{conn: conn} do
    conn =
      conn
      |> put_req_header("content-type", "text/plain")
      |> post(~p"/xrpc/com.atproto.server.createSession", "not json")

    response = json_response(conn, 400)

    assert get_resp_header(conn, "content-type") == ["application/json; charset=utf-8"]
    assert response["error"] == "InvalidRequest"
    assert response["message"] == "request body must use content-type application/json"
  end

  test "subscription method requires a websocket upgrade", %{conn: conn} do
    conn = get(conn, ~p"/xrpc/com.atproto.sync.subscribeRepos")

    response = json_response(conn, 426)

    assert get_resp_header(conn, "content-type") == ["application/json; charset=utf-8"]
    assert response["error"] == "UpgradeRequired"
  end
end
