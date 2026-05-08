defmodule Tempest.RepoCore.MstTest do
  use ExUnit.Case, async: true

  alias Tempest.RepoCore.{Cid, Mst}
  alias Tempest.RepoCore.Drisl.Bytes

  describe "depth/1" do
    test "matches official atproto repository examples" do
      assert Mst.depth("2653ae71") == 0
      assert Mst.depth("blue") == 1
      assert Mst.depth("app.bsky.feed.post/454397e440ec") == 4
      assert Mst.depth("app.bsky.feed.post/9adeb165882c") == 8
    end
  end

  describe "insert/get/delete" do
    test "inserts and gets values by key" do
      first = cid("first")
      second = cid("second")

      assert {:ok, mst} =
               Mst.new()
               |> Mst.insert("app.bsky.feed.post/3jui7kd54zh2y", first)

      assert {:ok, mst} = Mst.insert(mst, "app.bsky.feed.post/3jui7kd54zh2z", second)
      assert Mst.get(mst, "app.bsky.feed.post/3jui7kd54zh2y") == {:ok, first}
      assert Mst.get(mst, "app.bsky.feed.post/3jui7kd54zh2z") == {:ok, second}
      assert Mst.get(mst, "app.bsky.feed.post/missing") == {:error, :not_found}
    end

    test "rejects duplicate inserts and supports explicit replacement" do
      original = cid("original")
      updated = cid("updated")

      assert {:ok, mst} = Mst.insert(Mst.new(), "app.bsky.feed.post/self", original)
      assert Mst.insert(mst, "app.bsky.feed.post/self", updated) == {:error, :duplicate_key}
      assert {:ok, mst} = Mst.put(mst, "app.bsky.feed.post/self", updated)
      assert Mst.get(mst, "app.bsky.feed.post/self") == {:ok, updated}
    end

    test "deletes values and reports missing keys" do
      value = cid("value")

      assert {:ok, mst} = Mst.insert(Mst.new(), "app.bsky.feed.post/self", value)
      assert {:ok, mst} = Mst.delete(mst, "app.bsky.feed.post/self")
      assert Mst.get(mst, "app.bsky.feed.post/self") == {:error, :not_found}
      assert Mst.delete(mst, "app.bsky.feed.post/self") == {:error, :not_found}
      assert Mst.count(mst) == 0
    end

    test "rejects invalid keys and values" do
      assert Mst.insert(Mst.new(), "", cid("value")) == {:error, :invalid_key}
      assert Mst.insert(Mst.new(), String.duplicate("a", 1_025), cid("value")) == {:error, :invalid_key}
      assert Mst.insert(Mst.new(), "app.bsky.feed.post/self", "not-a-cid") == {:error, :invalid_value}
    end
  end

  describe "range/2" do
    test "scans sorted ranges with exclusive bounds and limits" do
      mst =
        Mst.from_entries!([
          {"app.bsky.feed.post/a", cid("a")},
          {"app.bsky.feed.post/b", cid("b")},
          {"app.bsky.feed.post/c", cid("c")},
          {"app.bsky.graph.follow/a", cid("follow")}
        ])

      assert keys(Mst.range(mst)) ==
               [
                 "app.bsky.feed.post/a",
                 "app.bsky.feed.post/b",
                 "app.bsky.feed.post/c",
                 "app.bsky.graph.follow/a"
               ]
               |> Enum.sort()

      assert keys(Mst.range(mst, after: "app.bsky.feed.post/a", before: "app.bsky.feed.post/c")) ==
               ["app.bsky.feed.post/b"]

      assert keys(Mst.range(mst, prefix: "app.bsky.feed.post/")) == [
               "app.bsky.feed.post/a",
               "app.bsky.feed.post/b",
               "app.bsky.feed.post/c"
             ]

      assert keys(Mst.range(mst, prefix: "app.bsky.feed.post/", limit: 2)) == [
               "app.bsky.feed.post/a",
               "app.bsky.feed.post/b"
             ]
    end
  end

  describe "serialization" do
    test "represents an empty repository as a single empty MST node" do
      assert {:ok, %{root: root, blocks: [{block_root, bytes}], node: node}} = Mst.serialize(Mst.new())
      assert block_root == root
      assert node == %{"l" => nil, "e" => []}
      assert root == Cid.for_drisl(bytes)
    end

    test "compresses keys within a node using previous-key prefixes" do
      first = cid("first")
      second = cid("second")

      mst =
        Mst.from_entries!([
          {"bsky/posts/abcdefg", first},
          {"bsky/posts/abcdehi", second}
        ])

      assert {:ok, %{node: %{"l" => nil, "e" => entries}}} = Mst.serialize(mst)

      assert [
               %{"p" => 0, "k" => %Bytes{bytes: "bsky/posts/abcdefg"}, "v" => ^first, "t" => nil},
               %{"p" => 16, "k" => %Bytes{bytes: "hi"}, "v" => ^second, "t" => nil}
             ] = entries
    end

    test "is independent of insertion order and restores root after delete and reinsert" do
      entries = [
        {"a/a", cid("a/a")},
        {"app/a", cid("app/a")},
        {"app/b", cid("app/b")},
        {"z/z", cid("z/z")}
      ]

      forward = Mst.from_entries!(entries)
      reverse = Mst.from_entries!(Enum.reverse(entries))

      assert {:ok, forward_root} = Mst.root_cid(forward)
      assert {:ok, ^forward_root} = Mst.root_cid(reverse)

      assert {:ok, deleted} = Mst.delete(forward, "app/b")
      refute Mst.root_cid(deleted) == {:ok, forward_root}
      assert {:ok, restored} = Mst.insert(deleted, "app/b", cid("app/b"))
      assert Mst.root_cid(restored) == {:ok, forward_root}
    end
  end

  defp cid(value), do: Cid.for_raw(value)
  defp keys(entries), do: Enum.map(entries, & &1.key)
end
