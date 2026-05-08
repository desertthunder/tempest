defmodule Tempest.Lexicon.ValidatorTest do
  use ExUnit.Case, async: false

  alias Tempest.Lexicon.Validator
  alias Tempest.RepoCore.Cid

  setup context do
    Tempest.LexiconFixtures.install!(context)
  end

  test "validates a record from configured Lexicon documents" do
    cid = Cid.for_drisl("post block") |> Cid.to_string()

    record = %{
      "$type" => "app.bsky.actor.profile",
      "displayName" => "Alice",
      "pinnedPost" => %{
        "uri" => "at://did:plc:abcdefghijklmnopqrstuvwx/app.bsky.feed.post/abc",
        "cid" => cid
      },
      "labels" => %{
        "$type" => "com.atproto.label.defs#selfLabels",
        "values" => [%{"val" => "example"}]
      }
    }

    assert {:ok, :valid} = Validator.validate_record("app.bsky.actor.profile", "self", record)
  end

  test "rejects schema violations through refs" do
    record = %{
      "$type" => "app.bsky.actor.profile",
      "pinnedPost" => %{
        "uri" => "at://did:plc:abcdefghijklmnopqrstuvwx/app.bsky.feed.post/abc",
        "cid" => "not-a-cid"
      }
    }

    assert {:error, {:invalid_field, "app.bsky.actor.profile.pinnedPost.cid"}} =
             Validator.validate_record("app.bsky.actor.profile", "self", record)
  end

  test "enforces record key types from the Lexicon definition" do
    record = %{"$type" => "app.bsky.actor.profile"}

    assert {:error, {:invalid_record_key, "literal:self"}} =
             Validator.validate_record("app.bsky.actor.profile", "not-self", record)
  end

  test "accepts unknown Lexicons unless schema validation is required" do
    record = %{"$type" => "example.app.record"}

    assert {:ok, :unknown} = Validator.validate_record("example.app.record", "abc", record)

    assert {:error, :unknown_lexicon} =
             Validator.validate_record("example.app.record", "abc", record, require_schema?: true)
  end
end
