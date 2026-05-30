defmodule Tempest.Lexicon.Bundled do
  @moduledoc """
  Bundled generated Lexicon documents.

  Regenerate with:

      mix tempest.lexicon.generate --source <path-to-lexicons> --commit <commit>
  """

  @behaviour Tempest.Lexicon.Provider

  @manifest %{
    "document_count" => 36,
    "document_ids" => [
      "app.bsky.actor.getPreferences",
      "app.bsky.actor.profile",
      "app.bsky.actor.putPreferences",
      "com.atproto.identity.resolveHandle",
      "com.atproto.identity.updateHandle",
      "com.atproto.label.defs",
      "com.atproto.lexicon.schema",
      "com.atproto.repo.applyWrites",
      "com.atproto.repo.createRecord",
      "com.atproto.repo.defs",
      "com.atproto.repo.deleteRecord",
      "com.atproto.repo.describeRepo",
      "com.atproto.repo.getRecord",
      "com.atproto.repo.listRecords",
      "com.atproto.repo.putRecord",
      "com.atproto.repo.strongRef",
      "com.atproto.repo.uploadBlob",
      "com.atproto.server.createAccount",
      "com.atproto.server.createSession",
      "com.atproto.server.deleteSession",
      "com.atproto.server.describeServer",
      "com.atproto.server.getSession",
      "com.atproto.server.refreshSession",
      "com.atproto.server.listAppPasswords",
      "com.atproto.server.createAppPassword",
      "com.atproto.server.revokeAppPassword",
      "com.atproto.sync.getBlob",
      "com.atproto.sync.getBlocks",
      "com.atproto.sync.getLatestCommit",
      "com.atproto.sync.getRecord",
      "com.atproto.sync.getRepo",
      "com.atproto.sync.getRepoStatus",
      "com.atproto.sync.listBlobs",
      "com.atproto.sync.listRepos",
      "com.atproto.sync.requestCrawl",
      "com.atproto.sync.subscribeRepos"
    ],
    "generated_at" => "2026-05-29T00:00:00Z",
    "source_commit" => "22de65eea4c5573480b3a3755db1ece3db75ae18",
    "source_repo" => "https://github.com/bluesky-social/atproto"
  }

  @documents [
    %{
      "defs" => %{
        "main" => %{
          "description" => "Get private preferences attached to the current account.",
          "output" => %{
            "encoding" => "application/json",
            "schema" => %{
              "properties" => %{"preferences" => %{"items" => %{"type" => "unknown"}, "type" => "array"}},
              "required" => ["preferences"],
              "type" => "object"
            }
          },
          "parameters" => %{"properties" => %{}, "type" => "params"},
          "type" => "query"
        }
      },
      "id" => "app.bsky.actor.getPreferences",
      "lexicon" => 1
    },
    %{
      "defs" => %{
        "main" => %{
          "description" => "Set the private preferences attached to the account.",
          "input" => %{
            "encoding" => "application/json",
            "schema" => %{
              "properties" => %{"preferences" => %{"items" => %{"type" => "unknown"}, "type" => "array"}},
              "required" => ["preferences"],
              "type" => "object"
            }
          },
          "type" => "procedure"
        }
      },
      "id" => "app.bsky.actor.putPreferences",
      "lexicon" => 1
    },
    %{
      "defs" => %{
        "main" => %{
          "description" => "A declaration of a Bluesky account profile.",
          "key" => "literal:self",
          "record" => %{
            "properties" => %{
              "avatar" => %{
                "accept" => ["image/png", "image/jpeg"],
                "description" => "Small image to be displayed next to posts from account. AKA, 'profile picture'",
                "maxSize" => 1_000_000,
                "type" => "blob"
              },
              "banner" => %{
                "accept" => ["image/png", "image/jpeg"],
                "description" => "Larger horizontal image to display behind profile view.",
                "maxSize" => 1_000_000,
                "type" => "blob"
              },
              "createdAt" => %{"format" => "datetime", "type" => "string"},
              "description" => %{
                "description" => "Free-form profile description text.",
                "maxGraphemes" => 256,
                "maxLength" => 2560,
                "type" => "string"
              },
              "displayName" => %{
                "maxGraphemes" => 64,
                "maxLength" => 640,
                "type" => "string"
              },
              "joinedViaStarterPack" => %{
                "ref" => "com.atproto.repo.strongRef",
                "type" => "ref"
              },
              "labels" => %{
                "description" => "Self-label values, specific to the Bluesky application, on the overall account.",
                "refs" => ["com.atproto.label.defs#selfLabels"],
                "type" => "union"
              },
              "pinnedPost" => %{
                "ref" => "com.atproto.repo.strongRef",
                "type" => "ref"
              },
              "pronouns" => %{
                "description" => "Free-form pronouns text.",
                "maxGraphemes" => 20,
                "maxLength" => 200,
                "type" => "string"
              },
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
          "description" =>
            "Resolves an atproto handle (hostname) to a DID. Does not necessarily bi-directionally verify against the the DID document.",
          "errors" => [
            %{
              "description" => "The resolution process confirmed that the handle does not resolve to any DID.",
              "name" => "HandleNotFound"
            }
          ],
          "output" => %{
            "encoding" => "application/json",
            "schema" => %{
              "properties" => %{"did" => %{"format" => "did", "type" => "string"}},
              "required" => ["did"],
              "type" => "object"
            }
          },
          "parameters" => %{
            "properties" => %{
              "handle" => %{
                "description" => "The handle to resolve.",
                "format" => "handle",
                "type" => "string"
              }
            },
            "required" => ["handle"],
            "type" => "params"
          },
          "type" => "query"
        }
      },
      "id" => "com.atproto.identity.resolveHandle",
      "lexicon" => 1
    },
    %{
      "defs" => %{
        "main" => %{
          "description" =>
            "Updates the current account's handle. Verifies handle validity, and updates did:plc document if necessary. Implemented by PDS, and requires auth.",
          "input" => %{
            "encoding" => "application/json",
            "schema" => %{
              "properties" => %{
                "handle" => %{
                  "description" => "The new handle.",
                  "format" => "handle",
                  "type" => "string"
                }
              },
              "required" => ["handle"],
              "type" => "object"
            }
          },
          "type" => "procedure"
        }
      },
      "id" => "com.atproto.identity.updateHandle",
      "lexicon" => 1
    },
    %{
      "defs" => %{
        "label" => %{
          "description" => "Metadata tag on an atproto resource (eg, repo or record).",
          "properties" => %{
            "cid" => %{
              "description" =>
                "Optionally, CID specifying the specific version of 'uri' resource this label applies to.",
              "format" => "cid",
              "type" => "string"
            },
            "cts" => %{
              "description" => "Timestamp when this label was created.",
              "format" => "datetime",
              "type" => "string"
            },
            "exp" => %{
              "description" => "Timestamp at which this label expires (no longer applies).",
              "format" => "datetime",
              "type" => "string"
            },
            "neg" => %{
              "description" => "If true, this is a negation label, overwriting a previous label.",
              "type" => "boolean"
            },
            "sig" => %{
              "description" => "Signature of dag-cbor encoded label.",
              "type" => "bytes"
            },
            "src" => %{
              "description" => "DID of the actor who created this label.",
              "format" => "did",
              "type" => "string"
            },
            "uri" => %{
              "description" =>
                "AT URI of the record, repository (account), or other resource that this label applies to.",
              "format" => "uri",
              "type" => "string"
            },
            "val" => %{
              "description" => "The short string name of the value or type of this label.",
              "maxLength" => 128,
              "type" => "string"
            },
            "ver" => %{
              "description" => "The AT Protocol version of the label object.",
              "type" => "integer"
            }
          },
          "required" => ["src", "uri", "val", "cts"],
          "type" => "object"
        },
        "labelValue" => %{
          "knownValues" => ["!hide", "!warn", "!no-unauthenticated", "porn", "sexual", "nudity", "graphic-media", "bot"],
          "type" => "string"
        },
        "labelValueDefinition" => %{
          "description" => "Declares a label value and its expected interpretations and behaviors.",
          "properties" => %{
            "adultOnly" => %{
              "description" => "Does the user need to have adult content enabled in order to configure this label?",
              "type" => "boolean"
            },
            "blurs" => %{
              "description" =>
                "What should this label hide in the UI, if applied? 'content' hides all of the target; 'media' hides the images/video/audio; 'none' hides nothing.",
              "knownValues" => ["content", "media", "none"],
              "type" => "string"
            },
            "defaultSetting" => %{
              "default" => "warn",
              "description" => "The default setting for this label.",
              "knownValues" => ["ignore", "warn", "hide"],
              "type" => "string"
            },
            "identifier" => %{
              "description" =>
                "The value of the label being defined. Must only include lowercase ascii and the '-' character ([a-z-]+).",
              "maxGraphemes" => 100,
              "maxLength" => 100,
              "type" => "string"
            },
            "locales" => %{
              "items" => %{
                "ref" => "#labelValueDefinitionStrings",
                "type" => "ref"
              },
              "type" => "array"
            },
            "severity" => %{
              "description" =>
                "How should a client visually convey this label? 'inform' means neutral and informational; 'alert' means negative and warning; 'none' means show nothing.",
              "knownValues" => ["inform", "alert", "none"],
              "type" => "string"
            }
          },
          "required" => ["identifier", "severity", "blurs", "locales"],
          "type" => "object"
        },
        "labelValueDefinitionStrings" => %{
          "description" => "Strings which describe the label in the UI, localized into a specific language.",
          "properties" => %{
            "description" => %{
              "description" => "A longer description of what the label means and why it might be applied.",
              "maxGraphemes" => 10000,
              "maxLength" => 100_000,
              "type" => "string"
            },
            "lang" => %{
              "description" => "The code of the language these strings are written in.",
              "format" => "language",
              "type" => "string"
            },
            "name" => %{
              "description" => "A short human-readable name for the label.",
              "maxGraphemes" => 64,
              "maxLength" => 640,
              "type" => "string"
            }
          },
          "required" => ["lang", "name", "description"],
          "type" => "object"
        },
        "selfLabel" => %{
          "description" =>
            "Metadata tag on an atproto record, published by the author within the record. Note that schemas should use #selfLabels, not #selfLabel.",
          "properties" => %{
            "val" => %{
              "description" => "The short string name of the value or type of this label.",
              "maxLength" => 128,
              "type" => "string"
            }
          },
          "required" => ["val"],
          "type" => "object"
        },
        "selfLabels" => %{
          "description" => "Metadata tags on an atproto record, published by the author within the record.",
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
          "description" =>
            "Representation of Lexicon schemas themselves, when published as atproto records. Note that the schema language is not defined in Lexicon; this meta schema currently only includes a single version field ('lexicon'). See the atproto specifications for description of the other expected top-level fields ('id', 'defs', etc).",
          "key" => "nsid",
          "record" => %{
            "properties" => %{
              "lexicon" => %{
                "description" =>
                  "Indicates the 'version' of the Lexicon language. Must be '1' for the current atproto/Lexicon schema system.",
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
        "create" => %{
          "description" => "Operation which creates a new record.",
          "properties" => %{
            "collection" => %{"format" => "nsid", "type" => "string"},
            "rkey" => %{
              "description" =>
                "NOTE: maxLength is redundant with record-key format. Keeping it temporarily to ensure backwards compatibility.",
              "format" => "record-key",
              "maxLength" => 512,
              "type" => "string"
            },
            "value" => %{"type" => "unknown"}
          },
          "required" => ["collection", "value"],
          "type" => "object"
        },
        "createResult" => %{
          "properties" => %{
            "cid" => %{"format" => "cid", "type" => "string"},
            "uri" => %{"format" => "at-uri", "type" => "string"},
            "validationStatus" => %{
              "knownValues" => ["valid", "unknown"],
              "type" => "string"
            }
          },
          "required" => ["uri", "cid"],
          "type" => "object"
        },
        "delete" => %{
          "description" => "Operation which deletes an existing record.",
          "properties" => %{
            "collection" => %{"format" => "nsid", "type" => "string"},
            "rkey" => %{"format" => "record-key", "type" => "string"}
          },
          "required" => ["collection", "rkey"],
          "type" => "object"
        },
        "deleteResult" => %{
          "properties" => %{},
          "required" => [],
          "type" => "object"
        },
        "main" => %{
          "description" =>
            "Apply a batch transaction of repository creates, updates, and deletes. Requires auth, implemented by PDS.",
          "errors" => [
            %{
              "description" => "Indicates that the 'swapCommit' parameter did not match current commit.",
              "name" => "InvalidSwap"
            }
          ],
          "input" => %{
            "encoding" => "application/json",
            "schema" => %{
              "properties" => %{
                "repo" => %{
                  "description" => "The handle or DID of the repo (aka, current account).",
                  "format" => "at-identifier",
                  "type" => "string"
                },
                "swapCommit" => %{
                  "description" =>
                    "If provided, the entire operation will fail if the current repo commit CID does not match this value. Used to prevent conflicting repo mutations.",
                  "format" => "cid",
                  "type" => "string"
                },
                "validate" => %{
                  "description" =>
                    "Can be set to 'false' to skip Lexicon schema validation of record data across all operations, 'true' to require it, or leave unset to validate only for known Lexicons.",
                  "type" => "boolean"
                },
                "writes" => %{
                  "items" => %{
                    "closed" => true,
                    "refs" => ["#create", "#update", "#delete"],
                    "type" => "union"
                  },
                  "type" => "array"
                }
              },
              "required" => ["repo", "writes"],
              "type" => "object"
            }
          },
          "output" => %{
            "encoding" => "application/json",
            "schema" => %{
              "properties" => %{
                "commit" => %{
                  "ref" => "com.atproto.repo.defs#commitMeta",
                  "type" => "ref"
                },
                "results" => %{
                  "items" => %{
                    "closed" => true,
                    "refs" => ["#createResult", "#updateResult", "#deleteResult"],
                    "type" => "union"
                  },
                  "type" => "array"
                }
              },
              "required" => [],
              "type" => "object"
            }
          },
          "type" => "procedure"
        },
        "update" => %{
          "description" => "Operation which updates an existing record.",
          "properties" => %{
            "collection" => %{"format" => "nsid", "type" => "string"},
            "rkey" => %{"format" => "record-key", "type" => "string"},
            "value" => %{"type" => "unknown"}
          },
          "required" => ["collection", "rkey", "value"],
          "type" => "object"
        },
        "updateResult" => %{
          "properties" => %{
            "cid" => %{"format" => "cid", "type" => "string"},
            "uri" => %{"format" => "at-uri", "type" => "string"},
            "validationStatus" => %{
              "knownValues" => ["valid", "unknown"],
              "type" => "string"
            }
          },
          "required" => ["uri", "cid"],
          "type" => "object"
        }
      },
      "id" => "com.atproto.repo.applyWrites",
      "lexicon" => 1
    },
    %{
      "defs" => %{
        "main" => %{
          "description" => "Create a single new repository record. Requires auth, implemented by PDS.",
          "errors" => [
            %{
              "description" => "Indicates that 'swapCommit' didn't match current repo commit.",
              "name" => "InvalidSwap"
            }
          ],
          "input" => %{
            "encoding" => "application/json",
            "schema" => %{
              "properties" => %{
                "collection" => %{
                  "description" => "The NSID of the record collection.",
                  "format" => "nsid",
                  "type" => "string"
                },
                "record" => %{
                  "description" => "The record itself. Must contain a $type field.",
                  "type" => "unknown"
                },
                "repo" => %{
                  "description" => "The handle or DID of the repo (aka, current account).",
                  "format" => "at-identifier",
                  "type" => "string"
                },
                "rkey" => %{
                  "description" => "The Record Key.",
                  "format" => "record-key",
                  "maxLength" => 512,
                  "type" => "string"
                },
                "swapCommit" => %{
                  "description" => "Compare and swap with the previous commit by CID.",
                  "format" => "cid",
                  "type" => "string"
                },
                "validate" => %{
                  "description" =>
                    "Can be set to 'false' to skip Lexicon schema validation of record data, 'true' to require it, or leave unset to validate only for known Lexicons.",
                  "type" => "boolean"
                }
              },
              "required" => ["repo", "collection", "record"],
              "type" => "object"
            }
          },
          "output" => %{
            "encoding" => "application/json",
            "schema" => %{
              "properties" => %{
                "cid" => %{"format" => "cid", "type" => "string"},
                "commit" => %{
                  "ref" => "com.atproto.repo.defs#commitMeta",
                  "type" => "ref"
                },
                "uri" => %{"format" => "at-uri", "type" => "string"},
                "validationStatus" => %{
                  "knownValues" => ["valid", "unknown"],
                  "type" => "string"
                }
              },
              "required" => ["uri", "cid"],
              "type" => "object"
            }
          },
          "type" => "procedure"
        }
      },
      "id" => "com.atproto.repo.createRecord",
      "lexicon" => 1
    },
    %{
      "defs" => %{
        "commitMeta" => %{
          "properties" => %{
            "cid" => %{"format" => "cid", "type" => "string"},
            "rev" => %{"format" => "tid", "type" => "string"}
          },
          "required" => ["cid", "rev"],
          "type" => "object"
        }
      },
      "id" => "com.atproto.repo.defs",
      "lexicon" => 1
    },
    %{
      "defs" => %{
        "main" => %{
          "description" => "Delete a repository record, or ensure it doesn't exist. Requires auth, implemented by PDS.",
          "errors" => [%{"name" => "InvalidSwap"}],
          "input" => %{
            "encoding" => "application/json",
            "schema" => %{
              "properties" => %{
                "collection" => %{
                  "description" => "The NSID of the record collection.",
                  "format" => "nsid",
                  "type" => "string"
                },
                "repo" => %{
                  "description" => "The handle or DID of the repo (aka, current account).",
                  "format" => "at-identifier",
                  "type" => "string"
                },
                "rkey" => %{
                  "description" => "The Record Key.",
                  "format" => "record-key",
                  "type" => "string"
                },
                "swapCommit" => %{
                  "description" => "Compare and swap with the previous commit by CID.",
                  "format" => "cid",
                  "type" => "string"
                },
                "swapRecord" => %{
                  "description" => "Compare and swap with the previous record by CID.",
                  "format" => "cid",
                  "type" => "string"
                }
              },
              "required" => ["repo", "collection", "rkey"],
              "type" => "object"
            }
          },
          "output" => %{
            "encoding" => "application/json",
            "schema" => %{
              "properties" => %{
                "commit" => %{
                  "ref" => "com.atproto.repo.defs#commitMeta",
                  "type" => "ref"
                }
              },
              "type" => "object"
            }
          },
          "type" => "procedure"
        }
      },
      "id" => "com.atproto.repo.deleteRecord",
      "lexicon" => 1
    },
    %{
      "defs" => %{
        "main" => %{
          "description" =>
            "Get information about an account and repository, including the list of collections. Does not require auth.",
          "output" => %{
            "encoding" => "application/json",
            "schema" => %{
              "properties" => %{
                "collections" => %{
                  "description" =>
                    "List of all the collections (NSIDs) for which this repo contains at least one record.",
                  "items" => %{"format" => "nsid", "type" => "string"},
                  "type" => "array"
                },
                "did" => %{"format" => "did", "type" => "string"},
                "didDoc" => %{
                  "description" => "The complete DID document for this account.",
                  "type" => "unknown"
                },
                "handle" => %{"format" => "handle", "type" => "string"},
                "handleIsCorrect" => %{
                  "description" => "Indicates if handle is currently valid (resolves bi-directionally)",
                  "type" => "boolean"
                }
              },
              "required" => ["handle", "did", "didDoc", "collections", "handleIsCorrect"],
              "type" => "object"
            }
          },
          "parameters" => %{
            "properties" => %{
              "repo" => %{
                "description" => "The handle or DID of the repo.",
                "format" => "at-identifier",
                "type" => "string"
              }
            },
            "required" => ["repo"],
            "type" => "params"
          },
          "type" => "query"
        }
      },
      "id" => "com.atproto.repo.describeRepo",
      "lexicon" => 1
    },
    %{
      "defs" => %{
        "main" => %{
          "description" => "Get a single record from a repository. Does not require auth.",
          "errors" => [%{"name" => "RecordNotFound"}],
          "output" => %{
            "encoding" => "application/json",
            "schema" => %{
              "properties" => %{
                "cid" => %{"format" => "cid", "type" => "string"},
                "uri" => %{"format" => "at-uri", "type" => "string"},
                "value" => %{"type" => "unknown"}
              },
              "required" => ["uri", "value"],
              "type" => "object"
            }
          },
          "parameters" => %{
            "properties" => %{
              "cid" => %{
                "description" =>
                  "The CID of the version of the record. If not specified, then return the most recent version.",
                "format" => "cid",
                "type" => "string"
              },
              "collection" => %{
                "description" => "The NSID of the record collection.",
                "format" => "nsid",
                "type" => "string"
              },
              "repo" => %{
                "description" => "The handle or DID of the repo.",
                "format" => "at-identifier",
                "type" => "string"
              },
              "rkey" => %{
                "description" => "The Record Key.",
                "format" => "record-key",
                "type" => "string"
              }
            },
            "required" => ["repo", "collection", "rkey"],
            "type" => "params"
          },
          "type" => "query"
        }
      },
      "id" => "com.atproto.repo.getRecord",
      "lexicon" => 1
    },
    %{
      "defs" => %{
        "main" => %{
          "description" =>
            "List a range of records in a repository, matching a specific collection. Does not require auth.",
          "output" => %{
            "encoding" => "application/json",
            "schema" => %{
              "properties" => %{
                "cursor" => %{"type" => "string"},
                "records" => %{
                  "items" => %{"ref" => "#record", "type" => "ref"},
                  "type" => "array"
                }
              },
              "required" => ["records"],
              "type" => "object"
            }
          },
          "parameters" => %{
            "properties" => %{
              "collection" => %{
                "description" => "The NSID of the record type.",
                "format" => "nsid",
                "type" => "string"
              },
              "cursor" => %{"type" => "string"},
              "limit" => %{
                "default" => 50,
                "description" => "The number of records to return.",
                "maximum" => 100,
                "minimum" => 1,
                "type" => "integer"
              },
              "repo" => %{
                "description" => "The handle or DID of the repo.",
                "format" => "at-identifier",
                "type" => "string"
              },
              "reverse" => %{
                "description" => "Flag to reverse the order of the returned records.",
                "type" => "boolean"
              }
            },
            "required" => ["repo", "collection"],
            "type" => "params"
          },
          "type" => "query"
        },
        "record" => %{
          "properties" => %{
            "cid" => %{"format" => "cid", "type" => "string"},
            "uri" => %{"format" => "at-uri", "type" => "string"},
            "value" => %{"type" => "unknown"}
          },
          "required" => ["uri", "cid", "value"],
          "type" => "object"
        }
      },
      "id" => "com.atproto.repo.listRecords",
      "lexicon" => 1
    },
    %{
      "defs" => %{
        "main" => %{
          "description" =>
            "Write a repository record, creating or updating it as needed. Requires auth, implemented by PDS.",
          "errors" => [%{"name" => "InvalidSwap"}],
          "input" => %{
            "encoding" => "application/json",
            "schema" => %{
              "nullable" => ["swapRecord"],
              "properties" => %{
                "collection" => %{
                  "description" => "The NSID of the record collection.",
                  "format" => "nsid",
                  "type" => "string"
                },
                "record" => %{
                  "description" => "The record to write.",
                  "type" => "unknown"
                },
                "repo" => %{
                  "description" => "The handle or DID of the repo (aka, current account).",
                  "format" => "at-identifier",
                  "type" => "string"
                },
                "rkey" => %{
                  "description" => "The Record Key.",
                  "format" => "record-key",
                  "maxLength" => 512,
                  "type" => "string"
                },
                "swapCommit" => %{
                  "description" => "Compare and swap with the previous commit by CID.",
                  "format" => "cid",
                  "type" => "string"
                },
                "swapRecord" => %{
                  "description" =>
                    "Compare and swap with the previous record by CID. WARNING: nullable and optional field; may cause problems with golang implementation",
                  "format" => "cid",
                  "type" => "string"
                },
                "validate" => %{
                  "description" =>
                    "Can be set to 'false' to skip Lexicon schema validation of record data, 'true' to require it, or leave unset to validate only for known Lexicons.",
                  "type" => "boolean"
                }
              },
              "required" => ["repo", "collection", "rkey", "record"],
              "type" => "object"
            }
          },
          "output" => %{
            "encoding" => "application/json",
            "schema" => %{
              "properties" => %{
                "cid" => %{"format" => "cid", "type" => "string"},
                "commit" => %{
                  "ref" => "com.atproto.repo.defs#commitMeta",
                  "type" => "ref"
                },
                "uri" => %{"format" => "at-uri", "type" => "string"},
                "validationStatus" => %{
                  "knownValues" => ["valid", "unknown"],
                  "type" => "string"
                }
              },
              "required" => ["uri", "cid"],
              "type" => "object"
            }
          },
          "type" => "procedure"
        }
      },
      "id" => "com.atproto.repo.putRecord",
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
      "description" => "A URI with a content-hash fingerprint.",
      "id" => "com.atproto.repo.strongRef",
      "lexicon" => 1
    },
    %{
      "defs" => %{
        "main" => %{
          "description" =>
            "Upload a new blob, to be referenced from a repository record. The blob will be deleted if it is not referenced within a time window (eg, minutes). Blob restrictions (mimetype, size, etc) are enforced when the reference is created. Requires auth, implemented by PDS.",
          "input" => %{"encoding" => "*/*"},
          "output" => %{
            "encoding" => "application/json",
            "schema" => %{
              "properties" => %{"blob" => %{"type" => "blob"}},
              "required" => ["blob"],
              "type" => "object"
            }
          },
          "type" => "procedure"
        }
      },
      "id" => "com.atproto.repo.uploadBlob",
      "lexicon" => 1
    },
    %{
      "defs" => %{
        "main" => %{
          "description" => "Create an account. Implemented by PDS.",
          "errors" => [
            %{"name" => "InvalidHandle"},
            %{"name" => "InvalidPassword"},
            %{"name" => "InvalidInviteCode"},
            %{"name" => "HandleNotAvailable"},
            %{"name" => "UnsupportedDomain"},
            %{"name" => "UnresolvableDid"},
            %{"name" => "IncompatibleDidDoc"}
          ],
          "input" => %{
            "encoding" => "application/json",
            "schema" => %{
              "properties" => %{
                "did" => %{
                  "description" => "Pre-existing atproto DID, being imported to a new account.",
                  "format" => "did",
                  "type" => "string"
                },
                "email" => %{"type" => "string"},
                "handle" => %{
                  "description" => "Requested handle for the account.",
                  "format" => "handle",
                  "type" => "string"
                },
                "inviteCode" => %{"type" => "string"},
                "password" => %{
                  "description" =>
                    "Initial account password. May need to meet instance-specific password strength requirements.",
                  "type" => "string"
                },
                "plcOp" => %{
                  "description" =>
                    "A signed DID PLC operation to be submitted as part of importing an existing account to this instance. NOTE: this optional field may be updated when full account migration is implemented.",
                  "type" => "unknown"
                },
                "recoveryKey" => %{
                  "description" => "DID PLC rotation key (aka, recovery key) to be included in PLC creation operation.",
                  "type" => "string"
                },
                "verificationCode" => %{"type" => "string"},
                "verificationPhone" => %{"type" => "string"}
              },
              "required" => ["handle"],
              "type" => "object"
            }
          },
          "output" => %{
            "encoding" => "application/json",
            "schema" => %{
              "description" => "Account login session returned on successful account creation.",
              "properties" => %{
                "accessJwt" => %{"type" => "string"},
                "did" => %{
                  "description" => "The DID of the new account.",
                  "format" => "did",
                  "type" => "string"
                },
                "didDoc" => %{
                  "description" => "Complete DID document.",
                  "type" => "unknown"
                },
                "handle" => %{"format" => "handle", "type" => "string"},
                "refreshJwt" => %{"type" => "string"}
              },
              "required" => ["accessJwt", "refreshJwt", "handle", "did"],
              "type" => "object"
            }
          },
          "type" => "procedure"
        }
      },
      "id" => "com.atproto.server.createAccount",
      "lexicon" => 1
    },
    %{
      "defs" => %{
        "main" => %{
          "description" => "Create an authentication session.",
          "errors" => [
            %{"name" => "AccountTakedown"},
            %{"name" => "AuthFactorTokenRequired"}
          ],
          "input" => %{
            "encoding" => "application/json",
            "schema" => %{
              "properties" => %{
                "allowTakendown" => %{
                  "description" =>
                    "When true, instead of throwing error for takendown accounts, a valid response with a narrow scoped token will be returned",
                  "type" => "boolean"
                },
                "authFactorToken" => %{"type" => "string"},
                "identifier" => %{
                  "description" => "Handle or other identifier supported by the server for the authenticating user.",
                  "type" => "string"
                },
                "password" => %{"type" => "string"}
              },
              "required" => ["identifier", "password"],
              "type" => "object"
            }
          },
          "output" => %{
            "encoding" => "application/json",
            "schema" => %{
              "properties" => %{
                "accessJwt" => %{"type" => "string"},
                "active" => %{"type" => "boolean"},
                "did" => %{"format" => "did", "type" => "string"},
                "didDoc" => %{"type" => "unknown"},
                "email" => %{"type" => "string"},
                "emailAuthFactor" => %{"type" => "boolean"},
                "emailConfirmed" => %{"type" => "boolean"},
                "handle" => %{"format" => "handle", "type" => "string"},
                "refreshJwt" => %{"type" => "string"},
                "status" => %{
                  "description" =>
                    "If active=false, this optional field indicates a possible reason for why the account is not active. If active=false and no status is supplied, then the host makes no claim for why the repository is no longer being hosted.",
                  "knownValues" => ["takendown", "suspended", "deactivated"],
                  "type" => "string"
                }
              },
              "required" => ["accessJwt", "refreshJwt", "handle", "did"],
              "type" => "object"
            }
          },
          "type" => "procedure"
        }
      },
      "id" => "com.atproto.server.createSession",
      "lexicon" => 1
    },
    %{
      "defs" => %{
        "main" => %{
          "description" => "Delete the current session. Requires auth using the 'refreshJwt' (not the 'accessJwt').",
          "errors" => [%{"name" => "InvalidToken"}, %{"name" => "ExpiredToken"}],
          "type" => "procedure"
        }
      },
      "id" => "com.atproto.server.deleteSession",
      "lexicon" => 1
    },
    %{
      "defs" => %{
        "contact" => %{
          "properties" => %{"email" => %{"type" => "string"}},
          "type" => "object"
        },
        "links" => %{
          "properties" => %{
            "privacyPolicy" => %{"format" => "uri", "type" => "string"},
            "termsOfService" => %{"format" => "uri", "type" => "string"}
          },
          "type" => "object"
        },
        "main" => %{
          "description" => "Describes the server's account creation requirements and capabilities. Implemented by PDS.",
          "output" => %{
            "encoding" => "application/json",
            "schema" => %{
              "properties" => %{
                "availableUserDomains" => %{
                  "description" => "List of domain suffixes that can be used in account handles.",
                  "items" => %{"type" => "string"},
                  "type" => "array"
                },
                "contact" => %{
                  "description" => "Contact information",
                  "ref" => "#contact",
                  "type" => "ref"
                },
                "did" => %{"format" => "did", "type" => "string"},
                "inviteCodeRequired" => %{
                  "description" => "If true, an invite code must be supplied to create an account on this instance.",
                  "type" => "boolean"
                },
                "links" => %{
                  "description" => "URLs of service policy documents.",
                  "ref" => "#links",
                  "type" => "ref"
                },
                "phoneVerificationRequired" => %{
                  "description" =>
                    "If true, a phone verification token must be supplied to create an account on this instance.",
                  "type" => "boolean"
                }
              },
              "required" => ["did", "availableUserDomains"],
              "type" => "object"
            }
          },
          "type" => "query"
        }
      },
      "id" => "com.atproto.server.describeServer",
      "lexicon" => 1
    },
    %{
      "defs" => %{
        "main" => %{
          "description" => "Get information about the current auth session. Requires auth.",
          "output" => %{
            "encoding" => "application/json",
            "schema" => %{
              "properties" => %{
                "active" => %{"type" => "boolean"},
                "did" => %{"format" => "did", "type" => "string"},
                "didDoc" => %{"type" => "unknown"},
                "email" => %{"type" => "string"},
                "emailAuthFactor" => %{"type" => "boolean"},
                "emailConfirmed" => %{"type" => "boolean"},
                "handle" => %{"format" => "handle", "type" => "string"},
                "status" => %{
                  "description" =>
                    "If active=false, this optional field indicates a possible reason for why the account is not active. If active=false and no status is supplied, then the host makes no claim for why the repository is no longer being hosted.",
                  "knownValues" => ["takendown", "suspended", "deactivated"],
                  "type" => "string"
                }
              },
              "required" => ["handle", "did"],
              "type" => "object"
            }
          },
          "type" => "query"
        }
      },
      "id" => "com.atproto.server.getSession",
      "lexicon" => 1
    },
    %{
      "defs" => %{
        "main" => %{
          "description" =>
            "Refresh an authentication session. Requires auth using the 'refreshJwt' (not the 'accessJwt').",
          "errors" => [
            %{"name" => "AccountTakedown"},
            %{"name" => "InvalidToken"},
            %{"name" => "ExpiredToken"}
          ],
          "output" => %{
            "encoding" => "application/json",
            "schema" => %{
              "properties" => %{
                "accessJwt" => %{"type" => "string"},
                "active" => %{"type" => "boolean"},
                "did" => %{"format" => "did", "type" => "string"},
                "didDoc" => %{"type" => "unknown"},
                "email" => %{"type" => "string"},
                "emailAuthFactor" => %{"type" => "boolean"},
                "emailConfirmed" => %{"type" => "boolean"},
                "handle" => %{"format" => "handle", "type" => "string"},
                "refreshJwt" => %{"type" => "string"},
                "status" => %{
                  "description" => "Hosting status of the account. If not specified, then assume 'active'.",
                  "knownValues" => ["takendown", "suspended", "deactivated"],
                  "type" => "string"
                }
              },
              "required" => ["accessJwt", "refreshJwt", "handle", "did"],
              "type" => "object"
            }
          },
          "type" => "procedure"
        }
      },
      "id" => "com.atproto.server.refreshSession",
      "lexicon" => 1
    },
    %{
      "defs" => %{
        "main" => %{
          "description" =>
            "Get a blob associated with a given account. Returns the full blob as originally uploaded. Does not require auth; implemented by PDS.",
          "errors" => [
            %{"name" => "BlobNotFound"},
            %{"name" => "RepoNotFound"},
            %{"name" => "RepoTakendown"},
            %{"name" => "RepoSuspended"},
            %{"name" => "RepoDeactivated"}
          ],
          "output" => %{"encoding" => "*/*"},
          "parameters" => %{
            "properties" => %{
              "cid" => %{
                "description" => "The CID of the blob to fetch",
                "format" => "cid",
                "type" => "string"
              },
              "did" => %{
                "description" => "The DID of the account.",
                "format" => "did",
                "type" => "string"
              }
            },
            "required" => ["did", "cid"],
            "type" => "params"
          },
          "type" => "query"
        }
      },
      "id" => "com.atproto.sync.getBlob",
      "lexicon" => 1
    },
    %{
      "defs" => %{
        "main" => %{
          "description" =>
            "Get data blocks from a given repo, by CID. For example, intermediate MST nodes, or records. Does not require auth; implemented by PDS.",
          "errors" => [
            %{"name" => "BlockNotFound"},
            %{"name" => "RepoNotFound"},
            %{"name" => "RepoTakendown"},
            %{"name" => "RepoSuspended"},
            %{"name" => "RepoDeactivated"}
          ],
          "output" => %{"encoding" => "application/vnd.ipld.car"},
          "parameters" => %{
            "properties" => %{
              "cids" => %{
                "items" => %{"format" => "cid", "type" => "string"},
                "type" => "array"
              },
              "did" => %{
                "description" => "The DID of the repo.",
                "format" => "did",
                "type" => "string"
              }
            },
            "required" => ["did", "cids"],
            "type" => "params"
          },
          "type" => "query"
        }
      },
      "id" => "com.atproto.sync.getBlocks",
      "lexicon" => 1
    },
    %{
      "defs" => %{
        "main" => %{
          "description" => "Get the current commit CID & revision of the specified repo. Does not require auth.",
          "errors" => [
            %{"name" => "RepoNotFound"},
            %{"name" => "RepoTakendown"},
            %{"name" => "RepoSuspended"},
            %{"name" => "RepoDeactivated"}
          ],
          "output" => %{
            "encoding" => "application/json",
            "schema" => %{
              "properties" => %{
                "cid" => %{"format" => "cid", "type" => "string"},
                "rev" => %{"format" => "tid", "type" => "string"}
              },
              "required" => ["cid", "rev"],
              "type" => "object"
            }
          },
          "parameters" => %{
            "properties" => %{
              "did" => %{
                "description" => "The DID of the repo.",
                "format" => "did",
                "type" => "string"
              }
            },
            "required" => ["did"],
            "type" => "params"
          },
          "type" => "query"
        }
      },
      "id" => "com.atproto.sync.getLatestCommit",
      "lexicon" => 1
    },
    %{
      "defs" => %{
        "main" => %{
          "description" =>
            "Get data blocks needed to prove the existence or non-existence of record in the current version of repo. Does not require auth.",
          "errors" => [
            %{"name" => "RecordNotFound"},
            %{"name" => "RepoNotFound"},
            %{"name" => "RepoTakendown"},
            %{"name" => "RepoSuspended"},
            %{"name" => "RepoDeactivated"}
          ],
          "output" => %{"encoding" => "application/vnd.ipld.car"},
          "parameters" => %{
            "properties" => %{
              "collection" => %{"format" => "nsid", "type" => "string"},
              "did" => %{
                "description" => "The DID of the repo.",
                "format" => "did",
                "type" => "string"
              },
              "rkey" => %{
                "description" => "Record Key",
                "format" => "record-key",
                "type" => "string"
              }
            },
            "required" => ["did", "collection", "rkey"],
            "type" => "params"
          },
          "type" => "query"
        }
      },
      "id" => "com.atproto.sync.getRecord",
      "lexicon" => 1
    },
    %{
      "defs" => %{
        "main" => %{
          "description" =>
            "Download a repository export as CAR file. Optionally only a 'diff' since a previous revision. Does not require auth; implemented by PDS.",
          "errors" => [
            %{"name" => "RepoNotFound"},
            %{"name" => "RepoTakendown"},
            %{"name" => "RepoSuspended"},
            %{"name" => "RepoDeactivated"}
          ],
          "output" => %{"encoding" => "application/vnd.ipld.car"},
          "parameters" => %{
            "properties" => %{
              "did" => %{
                "description" => "The DID of the repo.",
                "format" => "did",
                "type" => "string"
              },
              "since" => %{
                "description" => "The revision ('rev') of the repo to create a diff from.",
                "format" => "tid",
                "type" => "string"
              }
            },
            "required" => ["did"],
            "type" => "params"
          },
          "type" => "query"
        }
      },
      "id" => "com.atproto.sync.getRepo",
      "lexicon" => 1
    },
    %{
      "defs" => %{
        "main" => %{
          "description" =>
            "Get the hosting status for a repository, on this server. Expected to be implemented by PDS and Relay.",
          "errors" => [%{"name" => "RepoNotFound"}],
          "output" => %{
            "encoding" => "application/json",
            "schema" => %{
              "properties" => %{
                "active" => %{"type" => "boolean"},
                "did" => %{"format" => "did", "type" => "string"},
                "rev" => %{
                  "description" => "Optional field, the current rev of the repo, if active=true",
                  "format" => "tid",
                  "type" => "string"
                },
                "status" => %{
                  "description" =>
                    "If active=false, this optional field indicates a possible reason for why the account is not active. If active=false and no status is supplied, then the host makes no claim for why the repository is no longer being hosted.",
                  "knownValues" => ["takendown", "suspended", "deleted", "deactivated", "desynchronized", "throttled"],
                  "type" => "string"
                }
              },
              "required" => ["did", "active"],
              "type" => "object"
            }
          },
          "parameters" => %{
            "properties" => %{
              "did" => %{
                "description" => "The DID of the repo.",
                "format" => "did",
                "type" => "string"
              }
            },
            "required" => ["did"],
            "type" => "params"
          },
          "type" => "query"
        }
      },
      "id" => "com.atproto.sync.getRepoStatus",
      "lexicon" => 1
    },
    %{
      "defs" => %{
        "main" => %{
          "description" =>
            "List blob CIDs for an account, since some repo revision. Does not require auth; implemented by PDS.",
          "errors" => [
            %{"name" => "RepoNotFound"},
            %{"name" => "RepoTakendown"},
            %{"name" => "RepoSuspended"},
            %{"name" => "RepoDeactivated"}
          ],
          "output" => %{
            "encoding" => "application/json",
            "schema" => %{
              "properties" => %{
                "cids" => %{
                  "items" => %{"format" => "cid", "type" => "string"},
                  "type" => "array"
                },
                "cursor" => %{"type" => "string"}
              },
              "required" => ["cids"],
              "type" => "object"
            }
          },
          "parameters" => %{
            "properties" => %{
              "cursor" => %{"type" => "string"},
              "did" => %{
                "description" => "The DID of the repo.",
                "format" => "did",
                "type" => "string"
              },
              "limit" => %{
                "default" => 500,
                "maximum" => 1000,
                "minimum" => 1,
                "type" => "integer"
              },
              "since" => %{
                "description" => "Optional revision of the repo to list blobs since.",
                "format" => "tid",
                "type" => "string"
              }
            },
            "required" => ["did"],
            "type" => "params"
          },
          "type" => "query"
        }
      },
      "id" => "com.atproto.sync.listBlobs",
      "lexicon" => 1
    },
    %{
      "defs" => %{
        "main" => %{
          "description" =>
            "Enumerates all the DID, rev, and commit CID for all repos hosted by this service. Does not require auth; implemented by PDS and Relay.",
          "output" => %{
            "encoding" => "application/json",
            "schema" => %{
              "properties" => %{
                "cursor" => %{"type" => "string"},
                "repos" => %{
                  "items" => %{"ref" => "#repo", "type" => "ref"},
                  "type" => "array"
                }
              },
              "required" => ["repos"],
              "type" => "object"
            }
          },
          "parameters" => %{
            "properties" => %{
              "cursor" => %{"type" => "string"},
              "limit" => %{
                "default" => 500,
                "maximum" => 1000,
                "minimum" => 1,
                "type" => "integer"
              }
            },
            "type" => "params"
          },
          "type" => "query"
        },
        "repo" => %{
          "properties" => %{
            "active" => %{"type" => "boolean"},
            "did" => %{"format" => "did", "type" => "string"},
            "head" => %{
              "description" => "Current repo commit CID",
              "format" => "cid",
              "type" => "string"
            },
            "rev" => %{"format" => "tid", "type" => "string"},
            "status" => %{
              "description" =>
                "If active=false, this optional field indicates a possible reason for why the account is not active. If active=false and no status is supplied, then the host makes no claim for why the repository is no longer being hosted.",
              "knownValues" => ["takendown", "suspended", "deleted", "deactivated", "desynchronized", "throttled"],
              "type" => "string"
            }
          },
          "required" => ["did", "head", "rev"],
          "type" => "object"
        }
      },
      "id" => "com.atproto.sync.listRepos",
      "lexicon" => 1
    },
    %{
      "defs" => %{
        "main" => %{
          "description" =>
            "Request a service to persistently crawl hosted repos. Expected use is new PDS instances declaring their existence to Relays. Does not require auth.",
          "errors" => [%{"name" => "HostBanned"}],
          "input" => %{
            "encoding" => "application/json",
            "schema" => %{
              "properties" => %{
                "hostname" => %{
                  "description" => "Hostname of the current service (eg, PDS) that is requesting to be crawled.",
                  "type" => "string"
                }
              },
              "required" => ["hostname"],
              "type" => "object"
            }
          },
          "type" => "procedure"
        }
      },
      "id" => "com.atproto.sync.requestCrawl",
      "lexicon" => 1
    },
    %{
      "defs" => %{
        "account" => %{
          "description" =>
            "Represents a change to an account's status on a host (eg, PDS or Relay). The semantics of this event are that the status is at the host which emitted the event, not necessarily that at the currently active PDS. Eg, a Relay takedown would emit a takedown with active=false, even if the PDS is still active.",
          "properties" => %{
            "active" => %{
              "description" =>
                "Indicates that the account has a repository which can be fetched from the host that emitted this event.",
              "type" => "boolean"
            },
            "did" => %{"format" => "did", "type" => "string"},
            "seq" => %{"type" => "integer"},
            "status" => %{
              "description" =>
                "If active=false, this optional field indicates a reason for why the account is not active.",
              "knownValues" => ["takendown", "suspended", "deleted", "deactivated", "desynchronized", "throttled"],
              "type" => "string"
            },
            "time" => %{"format" => "datetime", "type" => "string"}
          },
          "required" => ["seq", "did", "time", "active"],
          "type" => "object"
        },
        "commit" => %{
          "description" =>
            "Represents an update of repository state. Note that empty commits are allowed, which include no repo data changes, but an update to rev and signature.",
          "nullable" => ["since"],
          "properties" => %{
            "blobs" => %{
              "items" => %{
                "description" =>
                  "DEPRECATED -- will soon always be empty. List of new blobs (by CID) referenced by records in this commit.",
                "type" => "cid-link"
              },
              "type" => "array"
            },
            "blocks" => %{
              "description" =>
                "CAR file containing relevant blocks, as a diff since the previous repo state. The commit must be included as a block, and the commit block CID must be the first entry in the CAR header 'roots' list.",
              "maxLength" => 2_000_000,
              "type" => "bytes"
            },
            "commit" => %{
              "description" => "Repo commit object CID.",
              "type" => "cid-link"
            },
            "ops" => %{
              "items" => %{
                "description" =>
                  "List of repo mutation operations in this commit (eg, records created, updated, or deleted).",
                "ref" => "#repoOp",
                "type" => "ref"
              },
              "maxLength" => 200,
              "type" => "array"
            },
            "prevData" => %{
              "description" =>
                "The root CID of the MST tree for the previous commit from this repo (indicated by the 'since' revision field in this message). Corresponds to the 'data' field in the repo commit object. NOTE: this field is effectively required for the 'inductive' version of firehose.",
              "type" => "cid-link"
            },
            "rebase" => %{
              "description" => "DEPRECATED -- unused",
              "type" => "boolean"
            },
            "repo" => %{
              "description" =>
                "The repo this event comes from. Note that all other message types name this field 'did'.",
              "format" => "did",
              "type" => "string"
            },
            "rev" => %{
              "description" =>
                "The rev of the emitted commit. Note that this information is also in the commit object included in blocks, unless this is a tooBig event.",
              "format" => "tid",
              "type" => "string"
            },
            "seq" => %{
              "description" => "The stream sequence number of this message.",
              "type" => "integer"
            },
            "since" => %{
              "description" => "The rev of the last emitted commit from this repo (if any).",
              "format" => "tid",
              "type" => "string"
            },
            "time" => %{
              "description" => "Timestamp of when this message was originally broadcast.",
              "format" => "datetime",
              "type" => "string"
            },
            "tooBig" => %{
              "description" =>
                "DEPRECATED -- replaced by #sync event and data limits. Indicates that this commit contained too many ops, or data size was too large. Consumers will need to make a separate request to get missing data.",
              "type" => "boolean"
            }
          },
          "required" => ["seq", "rebase", "tooBig", "repo", "commit", "rev", "since", "blocks", "ops", "blobs", "time"],
          "type" => "object"
        },
        "identity" => %{
          "description" =>
            "Represents a change to an account's identity. Could be an updated handle, signing key, or pds hosting endpoint. Serves as a prod to all downstream services to refresh their identity cache.",
          "properties" => %{
            "did" => %{"format" => "did", "type" => "string"},
            "handle" => %{
              "description" =>
                "The current handle for the account, or 'handle.invalid' if validation fails. This field is optional, might have been validated or passed-through from an upstream source. Semantics and behaviors for PDS vs Relay may evolve in the future; see atproto specs for more details.",
              "format" => "handle",
              "type" => "string"
            },
            "seq" => %{"type" => "integer"},
            "time" => %{"format" => "datetime", "type" => "string"}
          },
          "required" => ["seq", "did", "time"],
          "type" => "object"
        },
        "info" => %{
          "properties" => %{
            "message" => %{"type" => "string"},
            "name" => %{"knownValues" => ["OutdatedCursor"], "type" => "string"}
          },
          "required" => ["name"],
          "type" => "object"
        },
        "main" => %{
          "description" =>
            "Repository event stream, aka Firehose endpoint. Outputs repo commits with diff data, and identity update events, for all repositories on the current server. See the atproto specifications for details around stream sequencing, repo versioning, CAR diff format, and more. Public and does not require auth; implemented by PDS and Relay.",
          "errors" => [
            %{"name" => "FutureCursor"},
            %{
              "description" =>
                "If the consumer of the stream can not keep up with events, and a backlog gets too large, the server will drop the connection.",
              "name" => "ConsumerTooSlow"
            }
          ],
          "message" => %{
            "schema" => %{
              "refs" => ["#commit", "#sync", "#identity", "#account", "#info"],
              "type" => "union"
            }
          },
          "parameters" => %{
            "properties" => %{
              "cursor" => %{
                "description" => "The last known event seq number to backfill from.",
                "type" => "integer"
              }
            },
            "type" => "params"
          },
          "type" => "subscription"
        },
        "repoOp" => %{
          "description" => "A repo operation, ie a mutation of a single record.",
          "nullable" => ["cid"],
          "properties" => %{
            "action" => %{
              "knownValues" => ["create", "update", "delete"],
              "type" => "string"
            },
            "cid" => %{
              "description" => "For creates and updates, the new record CID. For deletions, null.",
              "type" => "cid-link"
            },
            "path" => %{"type" => "string"},
            "prev" => %{
              "description" =>
                "For updates and deletes, the previous record CID (required for inductive firehose). For creations, field should not be defined.",
              "type" => "cid-link"
            }
          },
          "required" => ["action", "path", "cid"],
          "type" => "object"
        },
        "sync" => %{
          "description" =>
            "Updates the repo to a new state, without necessarily including that state on the firehose. Used to recover from broken commit streams, data loss incidents, or in situations where upstream host does not know recent state of the repository.",
          "properties" => %{
            "blocks" => %{
              "description" =>
                "CAR file containing the commit, as a block. The CAR header must include the commit block CID as the first 'root'.",
              "maxLength" => 10000,
              "type" => "bytes"
            },
            "did" => %{
              "description" => "The account this repo event corresponds to. Must match that in the commit object.",
              "format" => "did",
              "type" => "string"
            },
            "rev" => %{
              "description" => "The rev of the commit. This value must match that in the commit object.",
              "type" => "string"
            },
            "seq" => %{
              "description" => "The stream sequence number of this message.",
              "type" => "integer"
            },
            "time" => %{
              "description" => "Timestamp of when this message was originally broadcast.",
              "format" => "datetime",
              "type" => "string"
            }
          },
          "required" => ["seq", "did", "blocks", "rev", "time"],
          "type" => "object"
        }
      },
      "id" => "com.atproto.sync.subscribeRepos",
      "lexicon" => 1
    },
    %{
      "defs" => %{
        "main" => %{
          "description" => "List app passwords for the authenticated account.",
          "output" => %{
            "encoding" => "application/json",
            "schema" => %{
              "properties" => %{"passwords" => %{"items" => %{"type" => "unknown"}, "type" => "array"}},
              "required" => ["passwords"],
              "type" => "object"
            }
          },
          "type" => "query"
        }
      },
      "id" => "com.atproto.server.listAppPasswords",
      "lexicon" => 1
    },
    %{
      "defs" => %{
        "main" => %{
          "description" => "Create an app password. The secret is returned once.",
          "input" => %{
            "encoding" => "application/json",
            "schema" => %{
              "properties" => %{"name" => %{"type" => "string"}, "scope" => %{"type" => "string"}},
              "required" => ["name"],
              "type" => "object"
            }
          },
          "output" => %{
            "encoding" => "application/json",
            "schema" => %{
              "properties" => %{
                "createdAt" => %{"format" => "datetime", "type" => "string"},
                "id" => %{"type" => "integer"},
                "lastUsedAt" => %{"format" => "datetime", "type" => "string"},
                "name" => %{"type" => "string"},
                "password" => %{"type" => "string"},
                "revoked" => %{"type" => "boolean"},
                "scope" => %{"type" => "string"}
              },
              "required" => ["id", "name", "scope", "createdAt", "revoked", "password"],
              "type" => "object"
            }
          },
          "type" => "procedure"
        }
      },
      "id" => "com.atproto.server.createAppPassword",
      "lexicon" => 1
    },
    %{
      "defs" => %{
        "main" => %{
          "description" => "Revoke an app password by id.",
          "input" => %{
            "encoding" => "application/json",
            "schema" => %{
              "properties" => %{"id" => %{"type" => "integer"}},
              "required" => ["id"],
              "type" => "object"
            }
          },
          "output" => %{"encoding" => "application/json", "schema" => %{"properties" => %{}, "type" => "object"}},
          "type" => "procedure"
        }
      },
      "id" => "com.atproto.server.revokeAppPassword",
      "lexicon" => 1
    }
  ]

  @impl true
  def load(_opts), do: {:ok, @documents, @manifest}

  def documents, do: @documents
  def manifest, do: @manifest
end
