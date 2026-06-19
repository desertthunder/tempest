defmodule TempestWeb.DocLiveRouteTest do
  use TempestWeb.ConnCase

  test "GET /docs renders the reference index without authentication", %{conn: conn} do
    conn = get(conn, ~p"/docs")
    html = html_response(conn, 200)
    document = LazyHTML.from_fragment(html)

    assert has_selector?(document, "#tempest-docs")
    assert has_selector?(document, "#doc-bookmarks")
    assert has_selector?(document, "#doc-content")
    assert has_selector?(document, ~s(a[href="/docs/architecture"]))
    assert html =~ "Tempest Navigator 4.0 - Reference Documentation"
    assert html =~ "Best viewed in Tempest Navigator"
    assert html =~ "Reference Documentation"
  end

  test "GET /docs/architecture renders the architecture reference document", %{conn: conn} do
    conn = get(conn, ~p"/docs/architecture")
    html = html_response(conn, 200)
    document = LazyHTML.from_fragment(html)

    assert has_selector?(document, "#doc-title")
    assert has_selector?(document, ~s(a[href="/docs/admin-operations"]))
    assert has_selector?(document, ~s(a[href="/docs/blobs"]))
    assert has_selector?(document, "pre code")
    assert has_selector?(document, "table")
    assert html =~ ~s(id="doc-title")
    assert html =~ ">Architecture</h1>"
    assert html =~ "Reference file: architecture.md"
    assert html =~ "Concepts"
  end

  test "unknown slugs return 404", %{conn: conn} do
    conn = get(conn, ~p"/docs/not-a-real-doc")

    assert html_response(conn, 404)
  end

  test "path traversal attempts return 404 and do not read local files", %{conn: conn} do
    conn = get(conn, "/docs/..%2F..%2Fconfig%2Fprod.exs")
    html = html_response(conn, 404)

    refute html =~ "SECRET_KEY_BASE"
    refute html =~ "TempestWeb.Endpoint"
  end

  test "file-like paths outside docs/reference cannot be rendered", %{conn: conn} do
    conn = get(conn, "/docs/CHANGELOG.md")

    assert html_response(conn, 404)
  end

  test "relative links between reference docs resolve to viewer routes", %{conn: conn} do
    conn = get(conn, ~p"/docs")
    html = html_response(conn, 200)
    document = LazyHTML.from_fragment(html)

    assert has_selector?(document, ~s(#doc-content a[href="/docs/architecture"]))
    assert has_selector?(document, ~s(#doc-content a[href="/docs/deployment-observability"]))
    assert has_selector?(document, ~s(#doc-content a[href="/docs/identity-troubleshooting"]))
  end

  defp has_selector?(document, selector) do
    document
    |> LazyHTML.query(selector)
    |> Enum.any?()
  end
end
