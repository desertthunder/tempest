defmodule TempestWeb.HomeLiveRouteTest do
  use TempestWeb.ConnCase

  test "GET /", %{conn: conn} do
    conn = get(conn, ~p"/")
    html = html_response(conn, 200)

    assert html =~ ~s(id="tempest-home")
    assert html =~ "Personal Data Server"
    assert html =~ "WELCOME.EXE"
    assert html =~ ~s(id="home-status-cards")
    assert html =~ ~s(href="/changelog")
    assert html =~ ~s(src="/images/icons/page.svg")
    assert html =~ "Changelog"
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

  test "GET /changelog renders the public changelog document", %{conn: conn} do
    conn = get(conn, ~p"/changelog")
    html = html_response(conn, 200)
    document = LazyHTML.from_fragment(html)

    assert has_selector?(document, "#tempest-changelog")
    assert has_selector?(document, "#changelog-document")
    assert has_selector?(document, "#changelog-source")
    assert has_selector?(document, ~s(a[href="/changelog"] img[src="/images/icons/page.svg"]))
    assert LazyHTML.text(LazyHTML.filter(document, "title")) =~ "Changelog"
    assert html =~ ~s(id="changelog-title")
    assert html =~ "Tempest Write - CHANGELOG.md"
    assert html =~ "v0.1.0"
  end

  test "GET /changelog does not expose arbitrary document paths", %{conn: conn} do
    conn = get(conn, "/changelog/CHANGELOG.md")
    assert html_response(conn, 404)

    conn = conn |> recycle() |> get("/changelog/../config/prod.exs")
    assert html_response(conn, 404)
  end

  defp has_selector?(document, selector) do
    document
    |> LazyHTML.query(selector)
    |> Enum.any?()
  end
end
