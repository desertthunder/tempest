defmodule Tempest.DocsTest do
  use ExUnit.Case, async: false

  alias Tempest.Docs

  describe "list_documents/0" do
    test "uses a fixed manifest covering every reference markdown file" do
      manifest_paths =
        Docs.list_documents()
        |> Enum.map(& &1.path)
        |> Enum.sort()

      reference_paths =
        "docs/reference/*.md"
        |> Path.wildcard()
        |> Enum.map(&Path.basename/1)
        |> Enum.sort()

      assert manifest_paths == reference_paths
      assert Enum.map(Docs.list_documents(), & &1.slug) == Enum.uniq(Enum.map(Docs.list_documents(), & &1.slug))
    end
  end

  describe "fetch_document/1" do
    test "fetches a known document by slug" do
      assert {:ok, document} = Docs.fetch_document("architecture")

      assert document.slug == "architecture"
      assert document.path == "architecture.md"
      assert document.title == "Architecture"
      assert document.updated == "2026-06-03"
      assert document.markdown =~ "## Concepts"
    end

    test "fetches a known document when runtime cwd does not contain docs/reference" do
      original_cwd = File.cwd!()

      try do
        File.cd!(System.tmp_dir!())

        assert {:ok, document} = Docs.fetch_document("architecture")
        assert document.title == "Architecture"
        assert document.html =~ "<h2>Concepts</h2>"
      after
        File.cd!(original_cwd)
      end
    end

    test "rejects unknown slugs and path traversal attempts" do
      assert Docs.fetch_document("missing") == {:error, :not_found}
      assert Docs.fetch_document("../config/prod.exs") == {:error, :not_found}
      assert Docs.fetch_document("..%2F..%2Fconfig%2Fprod.exs") == {:error, :not_found}
      assert Docs.fetch_document("architecture.md") == {:error, :not_found}
    end

    test "uses frontmatter metadata when present" do
      assert {:ok, document} = Docs.fetch_document("car-drisl")

      assert document.title == "CAR and DRISL"
      assert document.updated == "2026-06-13"
      refute document.markdown =~ "---"
    end

    test "renders trusted local markdown to html with headings, code blocks, tables, and escaped raw html" do
      assert {:ok, document} = Docs.fetch_document("architecture")

      assert document.html =~ "<h2>Concepts</h2>"
      assert document.html =~ "<pre><code class=\"language-text\">"
      assert document.html =~ "<table>"

      assert {:ok, security} = Docs.fetch_document("security-oauth")
      refute security.html =~ "<script>"
    end

    test "rewrites relative links between known reference documents" do
      assert {:ok, document} = Docs.fetch_document("reference")

      assert document.markdown =~ "[Architecture](/docs/architecture)"
      assert document.html =~ ~s(<a href="/docs/architecture">Architecture</a>)
      assert document.markdown =~ "[Identity Troubleshooting](/docs/identity-troubleshooting)"

      assert {:ok, interop} = Docs.fetch_document("interop-testing")

      assert interop.markdown =~
               "[`deployment-observability`](/docs/deployment-observability#relay-and-appview-crawl-verification)"
    end
  end

  describe "fetch_desktop_document/1" do
    test "fetches the changelog from a fixed desktop document manifest" do
      assert {:ok, document} = Docs.fetch_desktop_document("changelog")

      assert document.slug == "changelog"
      assert document.path == "CHANGELOG.md"
      assert document.title == "Changelog"
      assert document.markdown =~ "## v0.1.0"
      assert document.html =~ "<h2>v0.1.0</h2>"
    end

    test "rejects unknown desktop documents and path traversal attempts" do
      assert Docs.fetch_desktop_document("missing") == {:error, :not_found}
      assert Docs.fetch_desktop_document("../config/prod.exs") == {:error, :not_found}
      assert Docs.fetch_desktop_document("..%2F..%2Fconfig%2Fprod.exs") == {:error, :not_found}
      assert Docs.fetch_desktop_document("CHANGELOG.md") == {:error, :not_found}
      assert Docs.fetch_desktop_document("architecture") == {:error, :not_found}
    end
  end

  describe "document_path/1" do
    test "uses /docs for the reference index and /docs/:slug for other docs" do
      assert Docs.document_path("reference") == "/docs"
      assert Docs.document_path("architecture") == "/docs/architecture"
    end
  end

  describe "desktop_document_path/1" do
    test "uses /changelog for the changelog desktop document" do
      assert Docs.desktop_document_path("changelog") == "/changelog"
    end
  end
end
