defmodule Tempest.Lexicon.Bundled do
  @moduledoc """
  Bundled generated Lexicon documents.

  Regenerate with:

      mix tempest.lexicon.generate --source priv/lexicons/smoke --commit smoke-fixture
  """

  @behaviour Tempest.Lexicon.Provider

  @manifest %{
    "source_repo" => "atproto",
    "source_commit" => "smoke-fixture",
    "generated_at" => "2026-05-16T00:00:00Z",
    "document_count" => 4,
    "document_ids" => [
      "app.bsky.actor.profile",
      "com.atproto.label.defs",
      "com.atproto.lexicon.schema",
      "com.atproto.repo.strongRef"
    ]
  }

  @documents [
    %{
      "defs" => %{
        "main" => %{
          "key" => "literal:self",
          "record" => %{
            "properties" => %{
              "avatar" => %{"accept" => ["image/png", "image/jpeg"], "maxSize" => 1_000_000, "type" => "blob"},
              "banner" => %{"accept" => ["image/png", "image/jpeg"], "maxSize" => 1_000_000, "type" => "blob"},
              "createdAt" => %{"format" => "datetime", "type" => "string"},
              "description" => %{"maxGraphemes" => 256, "maxLength" => 2_560, "type" => "string"},
              "displayName" => %{"maxGraphemes" => 64, "maxLength" => 640, "type" => "string"},
              "joinedViaStarterPack" => %{"ref" => "com.atproto.repo.strongRef", "type" => "ref"},
              "labels" => %{"refs" => ["com.atproto.label.defs#selfLabels"], "type" => "union"},
              "pinnedPost" => %{"ref" => "com.atproto.repo.strongRef", "type" => "ref"},
              "pronouns" => %{"maxGraphemes" => 20, "maxLength" => 200, "type" => "string"},
              "website" => %{"format" => "uri", "type" => "string"}
            },
            "type" => "object"
          },
          "type" => "record"
        }
      },
      "id" => "app.bsky.actor.profile",
      "lexicon" => 1
    },
    %{
      "defs" => %{
        "main" => %{
          "description" => "Representation of Lexicon schemas themselves, when published as atproto records.",
          "key" => "nsid",
          "record" => %{
            "properties" => %{
              "lexicon" => %{
                "description" => "Indicates the 'version' of the Lexicon language.",
                "type" => "integer"
              }
            },
            "required" => ["lexicon"],
            "type" => "object"
          },
          "type" => "record"
        }
      },
      "id" => "com.atproto.lexicon.schema",
      "lexicon" => 1
    },
    %{
      "defs" => %{
        "selfLabel" => %{
          "properties" => %{"val" => %{"maxLength" => 128, "type" => "string"}},
          "required" => ["val"],
          "type" => "object"
        },
        "selfLabels" => %{
          "properties" => %{
            "values" => %{
              "items" => %{"ref" => "#selfLabel", "type" => "ref"},
              "maxLength" => 10,
              "type" => "array"
            }
          },
          "required" => ["values"],
          "type" => "object"
        }
      },
      "id" => "com.atproto.label.defs",
      "lexicon" => 1
    },
    %{
      "defs" => %{
        "main" => %{
          "properties" => %{
            "cid" => %{"format" => "cid", "type" => "string"},
            "uri" => %{"format" => "at-uri", "type" => "string"}
          },
          "required" => ["uri", "cid"],
          "type" => "object"
        }
      },
      "id" => "com.atproto.repo.strongRef",
      "lexicon" => 1
    }
  ]

  @impl true
  def load(_opts), do: {:ok, @documents, @manifest}

  def documents, do: @documents
  def manifest, do: @manifest
end
