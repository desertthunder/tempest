defmodule Tempest.Lexicon.BundledManifestTest do
  use ExUnit.Case, async: true

  alias Tempest.Lexicon.Bundled
  alias Tempest.Xrpc.Registry

  test "bundled Lexicons record official atproto source metadata" do
    manifest = Bundled.manifest()

    assert manifest["source_repo"] == "https://github.com/bluesky-social/atproto"
    assert manifest["source_commit"] =~ ~r/^[0-9a-f]{40}$/
    assert manifest["document_count"] == length(Bundled.documents())
    assert "app.bsky.feed.post" in manifest["document_ids"]
    assert "com.atproto.repo.applyWrites" in manifest["document_ids"]
    assert "com.atproto.sync.getBlocks" in manifest["document_ids"]
    assert "com.atproto.sync.requestCrawl" in manifest["document_ids"]
  end

  test "every locally implemented XRPC method has a bundled Lexicon document" do
    document_ids = MapSet.new(Bundled.manifest()["document_ids"])

    missing =
      Registry.all()
      |> Enum.map(& &1.nsid)
      |> Enum.reject(&MapSet.member?(document_ids, &1))

    assert missing == []
  end
end
