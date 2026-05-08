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
end
