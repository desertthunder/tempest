defmodule Tempest.Lexicon.GenerateTaskTest do
  use ExUnit.Case, async: false

  alias Mix.Tasks.Tempest.Lexicon.Generate

  test "generates deterministic bundled module with manifest and ref dependencies" do
    source = tmp_dir!("source")
    output = Path.join(tmp_dir!("output"), "bundled.ex")

    write_json!(
      Path.join(source, "example.app.note.json"),
      lexicon("example.app.note", %{
        "main" => %{
          "type" => "record",
          "key" => "any",
          "record" => %{
            "type" => "object",
            "properties" => %{"subject" => %{"type" => "ref", "ref" => "example.app.subject"}}
          }
        }
      })
    )

    write_json!(
      Path.join(source, "example.app.subject.json"),
      lexicon("example.app.subject", %{
        "main" => %{
          "type" => "object",
          "required" => ["name"],
          "properties" => %{"name" => %{"type" => "string"}}
        }
      })
    )

    Generate.run([
      "--source",
      source,
      "--commit",
      "abc123",
      "--source-repo",
      "example",
      "--generated-at",
      "2026-05-16T12:00:00Z",
      "--include",
      "example.app.note",
      "--out",
      output
    ])

    generated = File.read!(output)

    assert generated =~ ~s("source_repo" => "example")
    assert generated =~ ~s("source_commit" => "abc123")
    assert generated =~ ~s("generated_at" => "2026-05-16T12:00:00Z")
    assert generated =~ ~s("document_count" => 2)
    assert generated =~ ~s("example.app.note")
    assert generated =~ ~s("example.app.subject")
  end

  test "generates bundled module from namespace prefixes with dependencies" do
    source = tmp_dir!("namespace-source")
    output = Path.join(tmp_dir!("namespace-output"), "bundled.ex")

    write_json!(
      Path.join(source, "example.app.note.json"),
      lexicon("example.app.note", %{
        "main" => %{
          "type" => "record",
          "key" => "any",
          "record" => %{
            "type" => "object",
            "properties" => %{"subject" => %{"type" => "ref", "ref" => "com.example.subject"}}
          }
        }
      })
    )

    write_json!(
      Path.join(source, "example.app.profile.json"),
      lexicon("example.app.profile", %{"main" => %{"type" => "object"}})
    )

    write_json!(
      Path.join(source, "com.example.subject.json"),
      lexicon("com.example.subject", %{"main" => %{"type" => "object"}})
    )

    write_json!(
      Path.join(source, "other.app.note.json"),
      lexicon("other.app.note", %{"main" => %{"type" => "object"}})
    )

    Generate.run([
      "--source",
      source,
      "--commit",
      "abc123",
      "--namespace",
      "example.app",
      "--out",
      output
    ])

    generated = File.read!(output)

    assert generated =~ ~s("document_count" => 3)
    assert generated =~ ~s("example.app.note")
    assert generated =~ ~s("example.app.profile")
    assert generated =~ ~s("com.example.subject")
    refute generated =~ ~s("other.app.note")
  end

  defp lexicon(id, defs), do: %{"lexicon" => 1, "id" => id, "defs" => defs}

  defp tmp_dir!(name) do
    path = Path.join(System.tmp_dir!(), "tempest-generate-#{name}-#{System.unique_integer([:positive])}")
    File.mkdir_p!(path)
    path
  end

  defp write_json!(path, data) do
    File.mkdir_p!(Path.dirname(path))
    File.write!(path, Jason.encode!(data))
  end
end
