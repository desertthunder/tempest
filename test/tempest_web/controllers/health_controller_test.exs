defmodule TempestWeb.HealthControllerTest do
  use TempestWeb.ConnCase

  test "GET /xrpc/_health returns public JSON without auth", %{conn: conn} do
    conn = get(conn, ~p"/xrpc/_health")
    response = json_response(conn, 200)

    assert get_resp_header(conn, "content-type") == ["application/json; charset=utf-8"]
    assert response["status"] == "ok"
    assert response["version"] =~ ~r/\Av0\.1\.0\.dev\d+\+g[0-9a-f]{7}\z/
    assert response["storage"]["dataDir"] =~ "tempest_test"
    assert response["storage"]["accountDb"] =~ "account.sqlite"
    assert response["storage"]["sequencerDb"] =~ "sequencer.sqlite"
    assert response["storage"]["writable"] == true
  end

  test "GET /xrpc/_stats returns public JSON metrics without auth", %{conn: conn} do
    conn = get(conn, ~p"/xrpc/_stats")
    response = json_response(conn, 200)

    assert get_resp_header(conn, "content-type") == ["application/json; charset=utf-8"]
    assert is_binary(response["status"])
    assert is_binary(response["version"])
    assert is_binary(response["generatedAt"])
    assert is_integer(response["uptimeSeconds"])
    assert is_map(response["metrics"])
    assert is_map(response["health"])
    assert response["health"]["checks"]["storageWritable"] in [true, false]
  end
end
