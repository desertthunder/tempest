defmodule Tempest.Lexicon.SyncTaskTest do
  use ExUnit.Case, async: false

  alias Mix.Tasks.Tempest.Lexicon.Sync

  test "syncs configured official Lexicon paths from a pinned raw base URL" do
    source = tmp_dir!("source")
    output = tmp_dir!("output")
    paths_file = Path.join(tmp_dir!("paths"), "paths.txt")

    write_json!(Path.join(source, "com/atproto/example.json"), %{"lexicon" => 1, "id" => "com.atproto.example"})
    File.write!(paths_file, "com/atproto/example.json\n")

    Sync.run([
      "--commit",
      "abc123",
      "--base-url",
      "file://#{source}",
      "--paths",
      paths_file,
      "--out",
      output
    ])

    assert output
           |> Path.join("com/atproto/example.json")
           |> File.read!()
           |> Jason.decode!() == %{"lexicon" => 1, "id" => "com.atproto.example"}
  end

  defp tmp_dir!(name) do
    path = Path.join(System.tmp_dir!(), "tempest-sync-#{name}-#{System.unique_integer([:positive])}")
    File.mkdir_p!(path)
    path
  end

  defp write_json!(path, data) do
    File.mkdir_p!(Path.dirname(path))
    File.write!(path, Jason.encode!(data))
  end
end
