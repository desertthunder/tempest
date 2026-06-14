defmodule TempestWeb.PageControllerTest do
  use TempestWeb.ConnCase

  test "GET /", %{conn: conn} do
    conn = get(conn, ~p"/")
    html = html_response(conn, 200)

    assert html =~ ~s(id="tempest-home")
    assert html =~ "Personal Data Server"
    assert html =~ "Live Status"
    assert html =~ "Public Metrics"
    assert html =~ ~s(id="api-endpoints")
    assert html =~ "Endpoint Surface"
  end

  test "GET /stats renders a public aggregate dashboard", %{conn: conn} do
    conn = get(conn, ~p"/stats")
    html = html_response(conn, 200)

    assert html =~ ~s(id="tempest-home")
    assert html =~ "Tempest Public Stats"
    assert html =~ "Hosted Accounts"
    assert html =~ "Total Accounts"
    assert html =~ "Commits"
    assert html =~ "Health"
    assert html =~ "Stats scan errors"
  end
end
