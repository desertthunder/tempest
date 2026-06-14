defmodule Tempest.Lexicon.RegistryTest do
  use ExUnit.Case, async: false

  alias Tempest.Lexicon.Document
  alias Tempest.Lexicon.Registry

  setup do
    previous_config = Application.get_env(:tempest, Registry, [])

    on_exit(fn ->
      Application.put_env(:tempest, Registry, previous_config)
    end)

    :ok
  end

  test "loads bundled generated Lexicon documents by default" do
    Application.put_env(:tempest, Registry, bundled?: true, paths: [])

    assert :ok = Registry.validate_startup!()
    assert {:ok, document} = Registry.fetch("app.bsky.actor.profile")
    assert document["id"] == "app.bsky.actor.profile"

    assert {:ok, [manifest]} = Registry.manifest()
    assert manifest["source_repo"] == "https://github.com/bluesky-social/atproto"
    assert manifest["source_commit"] =~ ~r/^[0-9a-f]{40}$/
    assert manifest["document_count"] == length(manifest["document_ids"])

    assert "app.bsky.actor.profile" in manifest["document_ids"]
    assert "com.atproto.label.defs" in manifest["document_ids"]
    assert "com.atproto.lexicon.schema" in manifest["document_ids"]
    assert "com.atproto.repo.applyWrites" in manifest["document_ids"]
    assert "com.atproto.repo.strongRef" in manifest["document_ids"]
  end

  test "loads Lexicon documents from configured fixture paths" do
    Application.put_env(:tempest, Registry,
      bundled?: false,
      paths: [Path.expand("../../../priv/lexicons/smoke", __DIR__)]
    )

    assert {:ok, document} = Registry.fetch("app.bsky.actor.profile")
    assert document["id"] == "app.bsky.actor.profile"

    assert {:ok, _document, %{"type" => "object"}} =
             Registry.fetch_definition("com.atproto.repo.strongRef")
  end

  test "loads repository namespaces from a lexicons directory" do
    directory = tmp_dir!("namespace-lexicons")
    write_json!(Path.join([directory, "example", "app", "post.json"]), custom_record("example.app.post"))
    write_json!(Path.join([directory, "example", "app", "like.json"]), custom_record("example.app.like"))
    write_json!(Path.join([directory, "other", "app", "post.json"]), custom_record("other.app.post"))

    Application.put_env(:tempest, Registry,
      bundled?: false,
      repositories: [[path: directory, namespaces: ["example.app"]]]
    )

    assert :ok = Registry.validate_startup!()
    assert {:ok, _document, %{"type" => "record"}} = Registry.fetch_record("example.app.post")
    assert {:ok, _document, %{"type" => "record"}} = Registry.fetch_record("example.app.like")
    assert {:error, :unknown_lexicon} = Registry.fetch_record("other.app.post")
  end

  test "loads repository namespaces from a git checkout root" do
    checkout = tmp_dir!("namespace-repo")
    lexicons = Path.join(checkout, "lexicons")
    write_json!(Path.join([lexicons, "example", "feed", "post.json"]), custom_record("example.feed.post"))

    Application.put_env(:tempest, Registry,
      bundled?: false,
      repositories: [[path: checkout, namespaces: ["example.feed"]]]
    )

    assert :ok = Registry.validate_startup!()
    assert {:ok, _document, %{"type" => "record"}} = Registry.fetch_record("example.feed.post")
  end

  test "configured local documents are validated and can add custom record schemas" do
    directory = tmp_dir!("custom-lexicons")

    custom =
      lexicon("example.app.note", %{
        "main" => %{
          "type" => "record",
          "key" => "any",
          "record" => %{
            "type" => "object",
            "required" => ["text"],
            "properties" => %{"text" => %{"type" => "string", "maxLength" => 64}}
          }
        }
      })

    write_json!(Path.join(directory, "example.app.note.json"), custom)

    Application.put_env(:tempest, Registry, bundled?: false, paths: [directory])

    assert :ok = Registry.validate_startup!()
    assert {:ok, _document, %{"type" => "record"}} = Registry.fetch_record("example.app.note")
  end

  test "duplicate document ids fail validation" do
    document = lexicon("example.app.duplicate", %{"main" => %{"type" => "object"}})

    assert {:error, {:duplicate_document_ids, ["example.app.duplicate"]}} =
             Document.validate_documents([document, document])
  end

  test "duplicate union refs fail validation" do
    document =
      lexicon("example.app.union", %{
        "main" => %{
          "type" => "object",
          "properties" => %{
            "subject" => %{
              "type" => "union",
              "refs" => ["#item", "example.app.union#item"]
            }
          }
        },
        "item" => %{"type" => "object"}
      })

    assert {:error, {:duplicate_refs, "example.app.union#main.properties.subject", ["example.app.union#item"]}} =
             Document.validate_document(document)
  end

  test "loader limits fail configured local directories" do
    directory = tmp_dir!("limited-lexicons")
    write_json!(Path.join(directory, "one.json"), lexicon("example.app.one", %{"main" => %{"type" => "object"}}))
    write_json!(Path.join(directory, "two.json"), lexicon("example.app.two", %{"main" => %{"type" => "object"}}))

    assert {:error, {:loader_limit_exceeded, :max_files}} =
             Registry.validate_config(bundled?: false, paths: [directory], limits: [max_files: 1])
  end

  test "unresolved refs fail startup validation" do
    document =
      lexicon("example.app.unresolved", %{
        "main" => %{
          "type" => "object",
          "properties" => %{"missing" => %{"type" => "ref", "ref" => "example.app.missing"}}
        }
      })

    assert {:error, {:unresolved_definition_refs, ["example.app.missing#main"]}} =
             Registry.validate_config(bundled?: false, documents: [document])
  end

  test "ref cycles are accepted as recursive Lexicon graphs" do
    document =
      lexicon("example.app.cycle", %{
        "main" => %{"type" => "object", "properties" => %{"next" => %{"type" => "ref", "ref" => "#node"}}},
        "node" => %{"type" => "object", "properties" => %{"next" => %{"type" => "ref", "ref" => "#node"}}}
      })

    assert :ok = Document.validate_documents([document])
  end

  test "deep refs fail document set validation when they exceed loader limits" do
    defs =
      0..4
      |> Enum.map(fn index ->
        name = "node#{index}"
        next = "node#{index + 1}"

        definition =
          if index == 4 do
            %{"type" => "object"}
          else
            %{"type" => "object", "properties" => %{"next" => %{"type" => "ref", "ref" => "##{next}"}}}
          end

        {name, definition}
      end)
      |> Map.new()

    document = lexicon("example.app.deep", defs)

    assert {:error, {:loader_limit_exceeded, :max_ref_depth, path}} =
             Document.validate_documents([document], max_ref_depth: 2)

    assert "example.app.deep#node3" in path
  end

  test "oversized local schemas fail loader validation" do
    directory = tmp_dir!("oversized-lexicons")
    path = Path.join(directory, "large.json")

    write_json!(
      path,
      lexicon("example.app.large", %{
        "main" => %{"type" => "object", "description" => String.duplicate("x", 128)}
      })
    )

    assert {:error, {:loader_limit_exceeded, :max_file_bytes, ^path}} =
             Registry.validate_config(bundled?: false, paths: [directory], limits: [max_file_bytes: 32])
  end

  test "external resolver is disabled by default" do
    Application.put_env(:tempest, Registry,
      bundled?: false,
      paths: [],
      external_resolver: [
        resolver: Tempest.Lexicon.RegistryTest.Resolver,
        opts: [caller: self(), document: custom_record("example.app.external")]
      ]
    )

    assert {:error, :unknown_lexicon} = Registry.fetch_record("example.app.external")
    refute_received {:resolved, "example.app.external"}
  end

  test "external resolver can resolve unknown schemas when explicitly enabled" do
    Application.put_env(:tempest, Registry,
      bundled?: false,
      paths: [],
      external_resolver: [
        enabled?: true,
        resolver: Tempest.Lexicon.RegistryTest.Resolver,
        opts: [caller: self(), document: custom_record("example.app.external")]
      ]
    )

    assert {:ok, _document, %{"type" => "record"}} = Registry.fetch_record("example.app.external")
    assert_received {:resolved, "example.app.external"}
  end

  test "external resolver cannot override bundled or local sources" do
    Application.put_env(:tempest, Registry,
      bundled?: true,
      paths: [],
      external_resolver: [
        enabled?: true,
        resolver: Tempest.Lexicon.RegistryTest.Resolver,
        opts: [caller: self(), document: custom_record("app.bsky.actor.profile")]
      ]
    )

    assert {:ok, document, _definition} = Registry.fetch_record("app.bsky.actor.profile")
    assert document["defs"]["main"]["key"] == "literal:self"
    refute_received {:resolved, "app.bsky.actor.profile"}
  end

  defp lexicon(id, defs), do: %{"lexicon" => 1, "id" => id, "defs" => defs}

  defp custom_record(id) do
    lexicon(id, %{
      "main" => %{
        "type" => "record",
        "key" => "any",
        "record" => %{"type" => "object", "properties" => %{"text" => %{"type" => "string"}}}
      }
    })
  end

  defp tmp_dir!(name) do
    path = Path.join(System.tmp_dir!(), "tempest-#{name}-#{System.unique_integer([:positive])}")
    File.mkdir_p!(path)
    path
  end

  defp write_json!(path, data) do
    File.mkdir_p!(Path.dirname(path))
    File.write!(path, Jason.encode!(data))
  end
end

defmodule Tempest.Lexicon.RegistryTest.Resolver do
  @moduledoc false

  @behaviour Tempest.Lexicon.ExternalResolver

  @impl true
  def resolve(id, opts) do
    send(Keyword.fetch!(opts, :caller), {:resolved, id})

    case Keyword.fetch!(opts, :document) do
      %{"id" => ^id} = document -> {:ok, document}
      _document -> {:error, :not_found}
    end
  end
end
