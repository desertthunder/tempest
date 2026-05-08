defmodule Tempest.RepoCore.AtUriTest do
  use ExUnit.Case, async: true

  alias Tempest.RepoCore.AtUri

  describe "parse/1" do
    test "parses repository, collection, and record references" do
      assert {:ok, repo_uri} = AtUri.parse("at://did:plc:vwzwgnygau7ed7b7wt5ux7y2")
      assert repo_uri.authority == "did:plc:vwzwgnygau7ed7b7wt5ux7y2"
      assert repo_uri.authority_type == :did
      refute AtUri.record?(repo_uri)

      assert {:ok, collection_uri} = AtUri.parse("at://retr0.id/app.bsky.feed.post")
      assert collection_uri.authority == "retr0.id"
      assert collection_uri.authority_type == :handle
      assert collection_uri.collection == "app.bsky.feed.post"
      assert collection_uri.rkey == nil

      assert {:ok, record_uri} =
               AtUri.parse("at://did:plc:vwzwgnygau7ed7b7wt5ux7y2/app.bsky.feed.post/3k5nobkf2w72g")

      assert record_uri.collection == "app.bsky.feed.post"
      assert record_uri.rkey == "3k5nobkf2w72g"
      assert AtUri.record?(record_uri)
      assert AtUri.repo_path(record_uri) == {:ok, "app.bsky.feed.post/3k5nobkf2w72g"}
    end

    test "accepts syntactically valid unsupported DID methods in the authority" do
      assert {:ok, uri} = AtUri.parse("at://did:method:val:two/com.example.foo/self")
      assert uri.authority_type == :did
      assert uri.authority == "did:method:val:two"
    end

    test "preserves case-sensitive record keys" do
      assert {:ok, uri} = AtUri.parse("at://foo.com/com.example.foo/Self:Post_1~A")
      assert uri.rkey == "Self:Post_1~A"
      assert AtUri.to_string(uri) == "at://foo.com/com.example.foo/Self:Post_1~A"
    end

    test "rejects unsupported URI parts and invalid structure" do
      assert AtUri.parse("https://foo.com/com.example.foo/123") == {:error, :invalid_scheme}
      assert AtUri.parse("AT://foo.com/com.example.foo/123") == {:error, :invalid_scheme}
      assert AtUri.parse("at://") == {:error, :missing_authority}
      assert AtUri.parse("at://foo.com/") == {:error, :trailing_slash}
      assert AtUri.parse("at://foo.com/com.example.foo/123?x=1") == {:error, :unsupported_query_or_fragment}
      assert AtUri.parse("at://foo.com/com.example.foo/123#frag") == {:error, :unsupported_query_or_fragment}
      assert AtUri.parse("at://foo.com/com.example.foo/alpha/beta") == {:error, :too_many_path_segments}
    end

    test "rejects invalid authorities, collections, and record keys" do
      assert AtUri.parse("at://user:pass@foo.com") == {:error, :unsupported_userinfo}
      assert AtUri.parse("at://example.com:3000") == {:error, {:invalid_authority, :invalid_handle_syntax}}
      assert AtUri.parse("at://computer") == {:error, {:invalid_authority, :invalid_handle_syntax}}
      assert AtUri.parse("at://foo.com/example/123") == {:error, {:invalid_collection, :invalid_nsid_syntax}}

      assert AtUri.parse("at://foo.com/com.example.foo/any+space") ==
               {:error, {:invalid_record_key, :invalid_record_key_syntax}}
    end

    test "enforces normalized handle and collection segments for AT URI values" do
      assert AtUri.parse("at://Foo.com/com.example.foo/123") == {:error, {:not_normalized, :authority}}
      assert AtUri.parse("at://foo.com/COM.example.foo/123") == {:error, {:not_normalized, :collection}}
    end
  end
end
