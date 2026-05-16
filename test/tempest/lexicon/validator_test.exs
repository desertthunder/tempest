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

  test "preserves record write validation modes" do
    assert {:ok, :valid} =
             Validator.validate_record("app.bsky.actor.profile", "self", %{
               "$type" => "app.bsky.actor.profile",
               "displayName" => "Alice"
             })

    assert {:ok, :unknown} =
             Validator.validate_record("example.app.record", "abc", %{"$type" => "example.app.record"})

    assert {:error, :unknown_lexicon} =
             Validator.validate_record("example.app.record", "abc", %{"$type" => "example.app.record"},
               require_schema?: true
             )

    assert {:ok, :unknown} =
             Validator.validate_record(
               "app.bsky.actor.profile",
               "not-self",
               %{"$type" => "app.bsky.actor.profile", "displayName" => 123},
               validate_schema?: false
             )
  end

  test "external resolver failures preserve optimistic unknown and strict unknown failure" do
    previous_config = Application.get_env(:tempest, Tempest.Lexicon.Registry, [])

    Application.put_env(:tempest, Tempest.Lexicon.Registry,
      bundled?: false,
      paths: [],
      external_resolver: [
        enabled?: true,
        resolver: Tempest.Lexicon.ValidatorTest.FailingResolver
      ]
    )

    on_exit(fn ->
      Application.put_env(:tempest, Tempest.Lexicon.Registry, previous_config)
    end)

    record = %{"$type" => "example.app.record"}

    assert {:ok, :unknown} = Validator.validate_record("example.app.record", "abc", record)

    assert {:error, :unknown_lexicon} =
             Validator.validate_record("example.app.record", "abc", record, require_schema?: true)
  end
end

defmodule Tempest.Lexicon.ValidatorTest.FailingResolver do
  @moduledoc false

  @behaviour Tempest.Lexicon.ExternalResolver

  @impl true
  def resolve(_id, _opts), do: {:error, :private_ip}
end
