defmodule Tempest.Lexicon.RegistryTest do
  use ExUnit.Case, async: false

  alias Tempest.Lexicon.Registry

  test "loads Lexicon documents from configured fixture paths" do
    previous_config = Application.get_env(:tempest, Registry, [])

    Application.put_env(:tempest, Registry, paths: [Path.expand("../../../priv/lexicons/smoke", __DIR__)])

    on_exit(fn ->
      Application.put_env(:tempest, Registry, previous_config)
    end)

    assert {:ok, document} = Registry.fetch("app.bsky.actor.profile")
    assert document["id"] == "app.bsky.actor.profile"

    assert {:ok, _document, %{"type" => "object"}} =
             Registry.fetch_definition("com.atproto.repo.strongRef")
  end
end
