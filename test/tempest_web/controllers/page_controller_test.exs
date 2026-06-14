defmodule TempestWeb.PageControllerTest do
  use TempestWeb.ConnCase

  test "GET /", %{conn: conn} do
    conn = get(conn, ~p"/")
    html = html_response(conn, 200)

    assert html =~ ~s(id="tempest-home")
    assert html =~ "Personal Data Server"
    assert html =~ ~s(id="api-endpoints")
    assert html =~ "Coming soon"
  end

  test "GET /stats renders a public aggregate dashboard", %{conn: conn} do
    conn = get(conn, ~p"/stats")
    html = html_response(conn, 200)

    assert html =~ ~s(id="tempest-stats")
    assert html =~ "Tempest Public Stats"
    assert html =~ "Hosted Accounts"
    assert html =~ "Total Accounts"
    assert html =~ "Commit"
    assert html =~ "Health"
    assert html =~ "Stats scan errors"
  end
end
