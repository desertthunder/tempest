defmodule TempestWeb.PageControllerTest do
  use TempestWeb.ConnCase

  test "GET /", %{conn: conn} do
    conn = get(conn, ~p"/")
    html = html_response(conn, 200)

    assert html =~ ~s(id="tempest-home")
    assert html =~ "Personal Data Server"
    assert html =~ "WELCOME.EXE"
    assert html =~ ~s(id="home-status-cards")
    assert html =~ "Protocol Surface"
    refute html =~ "Public Stats"
    refute html =~ "Endpoint Surface"
  end

  test "GET /stats renders a public aggregate dashboard", %{conn: conn} do
    conn = get(conn, ~p"/stats")
    html = html_response(conn, 200)

    assert html =~ ~s(id="tempest-home")
    assert html =~ "Tempest Public Stats"
    assert html =~ "Public Stats"
    assert html =~ "Hosted Accounts"
    assert html =~ "Commits"
    assert html =~ "Collections"
    assert html =~ "Records"
    assert html =~ "Last Indexed"
    assert html =~ "Uptime"
    assert html =~ "Health"
    assert html =~ "Stats scan errors"
    refute html =~ "Endpoint Surface"
  end
end
