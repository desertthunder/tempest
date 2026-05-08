defmodule Tempest.LexiconFixtures do
  @moduledoc false

  def install!(test_context) do
    previous_config = Application.get_env(:tempest, Tempest.Lexicon.Registry, [])

    Application.put_env(:tempest, Tempest.Lexicon.Registry, documents: documents())

    ExUnit.Callbacks.on_exit(test_context, fn ->
      Application.put_env(:tempest, Tempest.Lexicon.Registry, previous_config)
    end)

    :ok
  end

  def documents do
    [profile(), strong_ref(), label_defs()]
  end

  def profile do
    %{
      "lexicon" => 1,
      "id" => "app.bsky.actor.profile",
      "defs" => %{
        "main" => %{
          "type" => "record",
          "key" => "literal:self",
          "record" => %{
            "type" => "object",
            "properties" => %{
              "displayName" => %{"type" => "string", "maxGraphemes" => 64, "maxLength" => 640},
              "description" => %{"type" => "string", "maxGraphemes" => 256, "maxLength" => 2560},
              "pronouns" => %{"type" => "string", "maxGraphemes" => 20, "maxLength" => 200},
              "website" => %{"type" => "string", "format" => "uri"},
              "avatar" => %{"type" => "blob", "accept" => ["image/png", "image/jpeg"], "maxSize" => 1_000_000},
              "banner" => %{"type" => "blob", "accept" => ["image/png", "image/jpeg"], "maxSize" => 1_000_000},
              "labels" => %{"type" => "union", "refs" => ["com.atproto.label.defs#selfLabels"]},
              "joinedViaStarterPack" => %{"type" => "ref", "ref" => "com.atproto.repo.strongRef"},
              "pinnedPost" => %{"type" => "ref", "ref" => "com.atproto.repo.strongRef"},
              "createdAt" => %{"type" => "string", "format" => "datetime"}
            }
          }
        }
      }
    }
  end

  def strong_ref do
    %{
      "lexicon" => 1,
      "id" => "com.atproto.repo.strongRef",
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
    }
  end

  def label_defs do
    %{
      "lexicon" => 1,
      "id" => "com.atproto.label.defs",
      "defs" => %{
        "selfLabels" => %{
          "type" => "object",
          "required" => ["values"],
          "properties" => %{
            "values" => %{
              "type" => "array",
              "items" => %{"type" => "ref", "ref" => "#selfLabel"},
              "maxLength" => 10
            }
          }
        },
        "selfLabel" => %{
          "type" => "object",
          "required" => ["val"],
          "properties" => %{
            "val" => %{"type" => "string", "maxLength" => 128}
          }
        }
      }
    }
  end
end
