defmodule Tempest.LexiconFixtures do
  @moduledoc false

  def install!(test_context) do
    previous_config = Application.get_env(:tempest, Tempest.Lexicon.Registry, [])

    Application.put_env(:tempest, Tempest.Lexicon.Registry, bundled?: false, documents: documents())

    ExUnit.Callbacks.on_exit(test_context, fn ->
      Application.put_env(:tempest, Tempest.Lexicon.Registry, previous_config)
    end)

    :ok
  end

  def documents do
    smoke_fixture_paths()
    |> Enum.map(fn path ->
      path
      |> File.read!()
      |> Jason.decode!()
    end)
  end

  def profile do
    read_fixture!("app/bsky/actor/profile.json")
  end

  def strong_ref do
    read_fixture!("com/atproto/repo/strongRef.json")
  end

  def label_defs do
    read_fixture!("com/atproto/label/defs.json")
  end

  defp smoke_fixture_paths do
    Path.wildcard(Path.join(fixture_root(), "**/*.json"))
  end

  defp read_fixture!(relative_path) do
    fixture_root()
    |> Path.join(relative_path)
    |> File.read!()
    |> Jason.decode!()
  end

  defp fixture_root do
    Path.expand("../../priv/lexicons/smoke", __DIR__)
  end
end
