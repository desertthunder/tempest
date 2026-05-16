defmodule Tempest.Lexicon.OfficialComAtprotoCompatibilityTest do
  use ExUnit.Case, async: true

  alias Tempest.Lexicon.Document

  @moduledoc false

  @official_com_atproto_subset [
    %{
      "lexicon" => 1,
      "id" => "com.atproto.repo.strongRef",
      "description" => "A URI with a content-hash fingerprint.",
      "defs" => %{
        "main" => %{
          "type" => "object",
          "required" => ["uri", "cid"],
          "properties" => %{
            "uri" => %{"type" => "string", "format" => "at-uri"},
            "cid" => %{"type" => "string", "format" => "cid"}
          }
        }
      }
    },
    %{
      "lexicon" => 1,
      "id" => "com.atproto.repo.defs",
      "defs" => %{
        "commitMeta" => %{
          "type" => "object",
          "required" => ["cid", "rev"],
          "properties" => %{
            "cid" => %{"type" => "string", "format" => "cid"},
            "rev" => %{"type" => "string", "format" => "tid"}
          }
        }
      }
    },
    %{
      "lexicon" => 1,
      "id" => "com.atproto.lexicon.schema",
      "defs" => %{
        "main" => %{
          "type" => "record",
          "description" => "Representation of Lexicon schemas themselves, when published as atproto records.",
          "key" => "nsid",
          "record" => %{
            "type" => "object",
            "required" => ["lexicon"],
            "properties" => %{
              "lexicon" => %{
                "type" => "integer",
                "description" => "Indicates the 'version' of the Lexicon language."
              }
            }
          }
        }
      }
    },
    %{
      "lexicon" => 1,
      "id" => "com.atproto.repo.createRecord",
      "defs" => %{
        "main" => %{
          "type" => "procedure",
          "description" => "Create a single new repository record. Requires auth, implemented by PDS.",
          "input" => %{
            "encoding" => "application/json",
            "schema" => %{
              "type" => "object",
              "required" => ["repo", "collection", "record"],
              "properties" => %{
                "repo" => %{"type" => "string", "format" => "at-identifier"},
                "collection" => %{"type" => "string", "format" => "nsid"},
                "rkey" => %{"type" => "string", "format" => "record-key", "maxLength" => 512},
                "validate" => %{"type" => "boolean"},
                "record" => %{"type" => "unknown"},
                "swapCommit" => %{"type" => "string", "format" => "cid"}
              }
            }
          },
          "output" => %{
            "encoding" => "application/json",
            "schema" => %{
              "type" => "object",
              "required" => ["uri", "cid"],
              "properties" => %{
                "uri" => %{"type" => "string", "format" => "at-uri"},
                "cid" => %{"type" => "string", "format" => "cid"},
                "commit" => %{"type" => "ref", "ref" => "com.atproto.repo.defs#commitMeta"},
                "validationStatus" => %{"type" => "string", "knownValues" => ["valid", "unknown"]}
              }
            }
          },
          "errors" => [%{"name" => "InvalidSwap"}]
        }
      }
    },
    %{
      "lexicon" => 1,
      "id" => "com.atproto.identity.resolveHandle",
      "defs" => %{
        "main" => %{
          "type" => "query",
          "description" => "Resolves an atproto handle (hostname) to a DID.",
          "parameters" => %{
            "type" => "params",
            "required" => ["handle"],
            "properties" => %{"handle" => %{"type" => "string", "format" => "handle"}}
          },
          "output" => %{
            "encoding" => "application/json",
            "schema" => %{
              "type" => "object",
              "required" => ["did"],
              "properties" => %{"did" => %{"type" => "string", "format" => "did"}}
            }
          },
          "errors" => [%{"name" => "HandleNotFound"}]
        }
      }
    },
    %{
      "lexicon" => 1,
      "id" => "com.atproto.sync.getLatestCommit",
      "defs" => %{
        "main" => %{
          "type" => "query",
          "description" => "Get the current commit CID & revision of the specified repo.",
          "parameters" => %{
            "type" => "params",
            "required" => ["did"],
            "properties" => %{"did" => %{"type" => "string", "format" => "did"}}
          },
          "output" => %{
            "encoding" => "application/json",
            "schema" => %{
              "type" => "object",
              "required" => ["cid", "rev"],
              "properties" => %{
                "cid" => %{"type" => "string", "format" => "cid"},
                "rev" => %{"type" => "string", "format" => "tid"}
              }
            }
          },
          "errors" => [
            %{"name" => "RepoNotFound"},
            %{"name" => "RepoTakendown"},
            %{"name" => "RepoSuspended"},
            %{"name" => "RepoDeactivated"}
          ]
        }
      }
    }
  ]

  test "validates official com.atproto Lexicons relevant to Tempest" do
    assert :ok = Document.validate_documents(@official_com_atproto_subset)
  end

  test "compatibility target excludes official app.bsky profile post and follow records" do
    ids = Enum.map(@official_com_atproto_subset, &Map.fetch!(&1, "id"))

    assert Enum.all?(ids, &String.starts_with?(&1, "com.atproto."))
    refute "app.bsky.actor.profile" in ids
    refute "app.bsky.feed.post" in ids
    refute "app.bsky.graph.follow" in ids
  end
end
