defmodule Tempest.Lexicon.Bundled do
  @moduledoc """
  Bundled generated Lexicon documents.

  Regenerate with:

      mix tempest.lexicon.generate --source <path-to-lexicons> --commit <commit>
  """

  @behaviour Tempest.Lexicon.Provider

  @manifest %{
    "document_count" => 209,
    "document_ids" => [
      "app.bsky.actor.defs",
      "app.bsky.actor.getPreferences",
      "app.bsky.actor.getProfile",
      "app.bsky.actor.getProfiles",
      "app.bsky.actor.getSuggestions",
      "app.bsky.actor.profile",
      "app.bsky.actor.putPreferences",
      "app.bsky.actor.searchActors",
      "app.bsky.actor.searchActorsTypeahead",
      "app.bsky.actor.status",
      "app.bsky.ageassurance.begin",
      "app.bsky.ageassurance.defs",
      "app.bsky.ageassurance.getConfig",
      "app.bsky.ageassurance.getState",
      "app.bsky.authCreatePosts",
      "app.bsky.authDeleteContent",
      "app.bsky.authFullApp",
      "app.bsky.authManageFeedDeclarations",
      "app.bsky.authManageLabelerService",
      "app.bsky.authManageModeration",
      "app.bsky.authManageNotifications",
      "app.bsky.authManageProfile",
      "app.bsky.authViewAll",
      "app.bsky.bookmark.createBookmark",
      "app.bsky.bookmark.defs",
      "app.bsky.bookmark.deleteBookmark",
      "app.bsky.bookmark.getBookmarks",
      "app.bsky.contact.defs",
      "app.bsky.contact.dismissMatch",
      "app.bsky.contact.getMatches",
      "app.bsky.contact.getSyncStatus",
      "app.bsky.contact.importContacts",
      "app.bsky.contact.removeData",
      "app.bsky.contact.sendNotification",
      "app.bsky.contact.startPhoneVerification",
      "app.bsky.contact.verifyPhone",
      "app.bsky.draft.createDraft",
      "app.bsky.draft.defs",
      "app.bsky.draft.deleteDraft",
      "app.bsky.draft.getDrafts",
      "app.bsky.draft.updateDraft",
      "app.bsky.embed.defs",
      "app.bsky.embed.external",
      "app.bsky.embed.gallery",
      "app.bsky.embed.getEmbedExternalView",
      "app.bsky.embed.images",
      "app.bsky.embed.record",
      "app.bsky.embed.recordWithMedia",
      "app.bsky.embed.video",
      "app.bsky.feed.defs",
      "app.bsky.feed.describeFeedGenerator",
      "app.bsky.feed.generator",
      "app.bsky.feed.getActorFeeds",
      "app.bsky.feed.getActorLikes",
      "app.bsky.feed.getAuthorFeed",
      "app.bsky.feed.getFeed",
      "app.bsky.feed.getFeedGenerator",
      "app.bsky.feed.getFeedGenerators",
      "app.bsky.feed.getFeedSkeleton",
      "app.bsky.feed.getLikes",
      "app.bsky.feed.getListFeed",
      "app.bsky.feed.getPostThread",
      "app.bsky.feed.getPosts",
      "app.bsky.feed.getQuotes",
      "app.bsky.feed.getRepostedBy",
      "app.bsky.feed.getSuggestedFeeds",
      "app.bsky.feed.getTimeline",
      "app.bsky.feed.like",
      "app.bsky.feed.post",
      "app.bsky.feed.postgate",
      "app.bsky.feed.repost",
      "app.bsky.feed.searchPosts",
      "app.bsky.feed.sendInteractions",
      "app.bsky.feed.threadgate",
      "app.bsky.graph.block",
      "app.bsky.graph.defs",
      "app.bsky.graph.follow",
      "app.bsky.graph.getActorStarterPacks",
      "app.bsky.graph.getBlocks",
      "app.bsky.graph.getFollowers",
      "app.bsky.graph.getFollows",
      "app.bsky.graph.getKnownFollowers",
      "app.bsky.graph.getList",
      "app.bsky.graph.getListBlocks",
      "app.bsky.graph.getListMutes",
      "app.bsky.graph.getLists",
      "app.bsky.graph.getListsWithMembership",
      "app.bsky.graph.getMutes",
      "app.bsky.graph.getRelationships",
      "app.bsky.graph.getStarterPack",
      "app.bsky.graph.getStarterPacks",
      "app.bsky.graph.getStarterPacksWithMembership",
      "app.bsky.graph.getSuggestedFollowsByActor",
      "app.bsky.graph.list",
      "app.bsky.graph.listblock",
      "app.bsky.graph.listitem",
      "app.bsky.graph.muteActor",
      "app.bsky.graph.muteActorList",
      "app.bsky.graph.muteThread",
      "app.bsky.graph.searchStarterPacks",
      "app.bsky.graph.starterpack",
      "app.bsky.graph.unmuteActor",
      "app.bsky.graph.unmuteActorList",
      "app.bsky.graph.unmuteThread",
      "app.bsky.graph.verification",
      "app.bsky.labeler.defs",
      "app.bsky.labeler.getServices",
      "app.bsky.labeler.service",
      "app.bsky.notification.declaration",
      "app.bsky.notification.defs",
      "app.bsky.notification.getPreferences",
      "app.bsky.notification.getUnreadCount",
      "app.bsky.notification.listActivitySubscriptions",
      "app.bsky.notification.listNotifications",
      "app.bsky.notification.putActivitySubscription",
      "app.bsky.notification.putPreferences",
      "app.bsky.notification.putPreferencesV2",
      "app.bsky.notification.registerPush",
      "app.bsky.notification.unregisterPush",
      "app.bsky.notification.updateSeen",
      "app.bsky.richtext.facet",
      "app.bsky.unspecced.defs",
      "app.bsky.unspecced.getAgeAssuranceState",
      "app.bsky.unspecced.getConfig",
      "app.bsky.unspecced.getOnboardingSuggestedStarterPacks",
      "app.bsky.unspecced.getOnboardingSuggestedStarterPacksSkeleton",
      "app.bsky.unspecced.getOnboardingSuggestedUsersSkeleton",
      "app.bsky.unspecced.getPopularFeedGenerators",
      "app.bsky.unspecced.getPostThreadOtherV2",
      "app.bsky.unspecced.getPostThreadV2",
      "app.bsky.unspecced.getSuggestedFeeds",
      "app.bsky.unspecced.getSuggestedFeedsSkeleton",
      "app.bsky.unspecced.getSuggestedOnboardingUsers",
      "app.bsky.unspecced.getSuggestedStarterPacks",
      "app.bsky.unspecced.getSuggestedStarterPacksSkeleton",
      "app.bsky.unspecced.getSuggestedUsers",
      "app.bsky.unspecced.getSuggestedUsersForDiscover",
      "app.bsky.unspecced.getSuggestedUsersForDiscoverSkeleton",
      "app.bsky.unspecced.getSuggestedUsersForExplore",
      "app.bsky.unspecced.getSuggestedUsersForExploreSkeleton",
      "app.bsky.unspecced.getSuggestedUsersForSeeMore",
      "app.bsky.unspecced.getSuggestedUsersForSeeMoreSkeleton",
      "app.bsky.unspecced.getSuggestedUsersSkeleton",
      "app.bsky.unspecced.getSuggestionsSkeleton",
      "app.bsky.unspecced.getTaggedSuggestions",
      "app.bsky.unspecced.getTrendingTopics",
      "app.bsky.unspecced.getTrends",
      "app.bsky.unspecced.getTrendsSkeleton",
      "app.bsky.unspecced.initAgeAssurance",
      "app.bsky.unspecced.searchActorsSkeleton",
      "app.bsky.unspecced.searchPostsSkeleton",
      "app.bsky.unspecced.searchStarterPacksSkeleton",
      "app.bsky.video.defs",
      "app.bsky.video.getJobStatus",
      "app.bsky.video.getUploadLimits",
      "app.bsky.video.uploadVideo",
      "com.atproto.identity.getRecommendedDidCredentials",
      "com.atproto.identity.requestPlcOperationSignature",
      "com.atproto.identity.resolveHandle",
      "com.atproto.identity.signPlcOperation",
      "com.atproto.identity.submitPlcOperation",
      "com.atproto.identity.updateHandle",
      "com.atproto.label.defs",
      "com.atproto.lexicon.schema",
      "com.atproto.moderation.defs",
      "com.atproto.repo.applyWrites",
      "com.atproto.repo.createRecord",
      "com.atproto.repo.defs",
      "com.atproto.repo.deleteRecord",
      "com.atproto.repo.describeRepo",
      "com.atproto.repo.getRecord",
      "com.atproto.repo.importRepo",
      "com.atproto.repo.listMissingBlobs",
      "com.atproto.repo.listRecords",
      "com.atproto.repo.putRecord",
      "com.atproto.repo.strongRef",
      "com.atproto.repo.uploadBlob",
      "com.atproto.server.activateAccount",
      "com.atproto.server.checkAccountStatus",
      "com.atproto.server.confirmEmail",
      "com.atproto.server.createAccount",
      "com.atproto.server.createAppPassword",
      "com.atproto.server.createSession",
      "com.atproto.server.deactivateAccount",
      "com.atproto.server.deleteAccount",
      "com.atproto.server.deleteSession",
      "com.atproto.server.describeServer",
      "com.atproto.server.getServiceAuth",
      "com.atproto.server.getSession",
      "com.atproto.server.listAppPasswords",
      "com.atproto.server.refreshSession",
      "com.atproto.server.requestAccountDelete",
      "com.atproto.server.requestEmailConfirmation",
      "com.atproto.server.requestEmailUpdate",
      "com.atproto.server.requestPasswordReset",
      "com.atproto.server.reserveSigningKey",
      "com.atproto.server.resetPassword",
      "com.atproto.server.revokeAppPassword",
      "com.atproto.server.updateEmail",
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
    "generated_at" => "2026-06-14T00:00:00Z",
    "source_commit" => "6b4f57f49dd113d891bba38c89dada2b8547689b",
    "source_repo" => "https://github.com/bluesky-social/atproto"
  }

  @documents [
    %{
      "defs" => %{
        "profileAssociatedChat" => %{
          "properties" => %{
            "allowGroupInvites" => %{
              "knownValues" => ["all", "none", "following"],
              "type" => "string"
            },
            "allowIncoming" => %{
              "knownValues" => ["all", "none", "following"],
              "type" => "string"
            }
          },
          "required" => ["allowIncoming"],
          "type" => "object"
        },
        "knownFollowers" => %{
          "description" => "The subject's followers whom you also follow",
          "properties" => %{
            "count" => %{"type" => "integer"},
            "followers" => %{
              "items" => %{"ref" => "#profileViewBasic", "type" => "ref"},
              "maxLength" => 5,
              "minLength" => 0,
              "type" => "array"
            }
          },
          "required" => ["count", "followers"],
          "type" => "object"
        },
        "hiddenPostsPref" => %{
          "properties" => %{
            "items" => %{
              "description" => "A list of URIs of posts the account owner has hidden.",
              "items" => %{"format" => "at-uri", "type" => "string"},
              "type" => "array"
            }
          },
          "required" => ["items"],
          "type" => "object"
        },
        "savedFeedsPref" => %{
          "properties" => %{
            "pinned" => %{
              "items" => %{"format" => "at-uri", "type" => "string"},
              "type" => "array"
            },
            "saved" => %{
              "items" => %{"format" => "at-uri", "type" => "string"},
              "type" => "array"
            },
            "timelineIndex" => %{"type" => "integer"}
          },
          "required" => ["pinned", "saved"],
          "type" => "object"
        },
        "bskyAppProgressGuide" => %{
          "description" =>
            "If set, an active progress guide. Once completed, can be set to undefined. Should have unspecced fields tracking progress.",
          "properties" => %{"guide" => %{"maxLength" => 100, "type" => "string"}},
          "required" => ["guide"],
          "type" => "object"
        },
        "personalDetailsPref" => %{
          "properties" => %{
            "birthDate" => %{
              "description" => "The birth date of account owner.",
              "format" => "datetime",
              "type" => "string"
            }
          },
          "type" => "object"
        },
        "bskyAppStatePref" => %{
          "description" =>
            "A grab bag of state that's specific to the bsky.app program. Third-party apps shouldn't use this.",
          "properties" => %{
            "activeProgressGuide" => %{
              "ref" => "#bskyAppProgressGuide",
              "type" => "ref"
            },
            "nuxs" => %{
              "description" => "Storage for NUXs the user has encountered.",
              "items" => %{"ref" => "app.bsky.actor.defs#nux", "type" => "ref"},
              "maxLength" => 100,
              "type" => "array"
            },
            "queuedNudges" => %{
              "description" =>
                "An array of tokens which identify nudges (modals, popups, tours, highlight dots) that should be shown to the user.",
              "items" => %{"maxLength" => 100, "type" => "string"},
              "maxLength" => 1000,
              "type" => "array"
            }
          },
          "type" => "object"
        },
        "mutedWord" => %{
          "description" => "A word that the account owner has muted.",
          "properties" => %{
            "actorTarget" => %{
              "default" => "all",
              "description" => "Groups of users to apply the muted word to. If undefined, applies to all users.",
              "knownValues" => ["all", "exclude-following"],
              "type" => "string"
            },
            "expiresAt" => %{
              "description" => "The date and time at which the muted word will expire and no longer be applied.",
              "format" => "datetime",
              "type" => "string"
            },
            "id" => %{"type" => "string"},
            "targets" => %{
              "description" => "The intended targets of the muted word.",
              "items" => %{
                "ref" => "app.bsky.actor.defs#mutedWordTarget",
                "type" => "ref"
              },
              "type" => "array"
            },
            "value" => %{
              "description" => "The muted word itself.",
              "maxGraphemes" => 1000,
              "maxLength" => 10000,
              "type" => "string"
            }
          },
          "required" => ["value", "targets"],
          "type" => "object"
        },
        "feedViewPref" => %{
          "properties" => %{
            "feed" => %{
              "description" => "The URI of the feed, or an identifier which describes the feed.",
              "type" => "string"
            },
            "hideQuotePosts" => %{
              "description" => "Hide quote posts in the feed.",
              "type" => "boolean"
            },
            "hideReplies" => %{
              "description" => "Hide replies in the feed.",
              "type" => "boolean"
            },
            "hideRepliesByLikeCount" => %{
              "description" => "Hide replies in the feed if they do not have this number of likes.",
              "type" => "integer"
            },
            "hideRepliesByUnfollowed" => %{
              "default" => true,
              "description" => "Hide replies in the feed if they are not by followed users.",
              "type" => "boolean"
            },
            "hideReposts" => %{
              "description" => "Hide reposts in the feed.",
              "type" => "boolean"
            }
          },
          "required" => ["feed"],
          "type" => "object"
        },
        "viewerState" => %{
          "description" =>
            "Metadata about the requesting account's relationship with the subject account. Only has meaningful content for authed requests.",
          "properties" => %{
            "activitySubscription" => %{
              "description" => "This property is present only in selected cases, as an optimization.",
              "ref" => "app.bsky.notification.defs#activitySubscription",
              "type" => "ref"
            },
            "blockedBy" => %{"type" => "boolean"},
            "blocking" => %{"format" => "at-uri", "type" => "string"},
            "blockingByList" => %{
              "ref" => "app.bsky.graph.defs#listViewBasic",
              "type" => "ref"
            },
            "followedBy" => %{"format" => "at-uri", "type" => "string"},
            "following" => %{"format" => "at-uri", "type" => "string"},
            "knownFollowers" => %{
              "description" => "This property is present only in selected cases, as an optimization.",
              "ref" => "#knownFollowers",
              "type" => "ref"
            },
            "muted" => %{"type" => "boolean"},
            "mutedByList" => %{
              "ref" => "app.bsky.graph.defs#listViewBasic",
              "type" => "ref"
            }
          },
          "type" => "object"
        },
        "profileView" => %{
          "properties" => %{
            "associated" => %{"ref" => "#profileAssociated", "type" => "ref"},
            "avatar" => %{"format" => "uri", "type" => "string"},
            "createdAt" => %{"format" => "datetime", "type" => "string"},
            "debug" => %{
              "description" => "Debug information for internal development",
              "type" => "unknown"
            },
            "description" => %{
              "maxGraphemes" => 256,
              "maxLength" => 2560,
              "type" => "string"
            },
            "did" => %{"format" => "did", "type" => "string"},
            "displayName" => %{
              "maxGraphemes" => 64,
              "maxLength" => 640,
              "type" => "string"
            },
            "handle" => %{"format" => "handle", "type" => "string"},
            "indexedAt" => %{"format" => "datetime", "type" => "string"},
            "labels" => %{
              "items" => %{
                "ref" => "com.atproto.label.defs#label",
                "type" => "ref"
              },
              "type" => "array"
            },
            "pronouns" => %{"type" => "string"},
            "status" => %{"ref" => "#statusView", "type" => "ref"},
            "verification" => %{"ref" => "#verificationState", "type" => "ref"},
            "viewer" => %{"ref" => "#viewerState", "type" => "ref"}
          },
          "required" => ["did", "handle"],
          "type" => "object"
        },
        "savedFeedsPrefV2" => %{
          "properties" => %{
            "items" => %{
              "items" => %{
                "ref" => "app.bsky.actor.defs#savedFeed",
                "type" => "ref"
              },
              "type" => "array"
            }
          },
          "required" => ["items"],
          "type" => "object"
        },
        "profileAssociated" => %{
          "properties" => %{
            "activitySubscription" => %{
              "ref" => "#profileAssociatedActivitySubscription",
              "type" => "ref"
            },
            "chat" => %{"ref" => "#profileAssociatedChat", "type" => "ref"},
            "feedgens" => %{"type" => "integer"},
            "germ" => %{"ref" => "#profileAssociatedGerm", "type" => "ref"},
            "labeler" => %{"type" => "boolean"},
            "lists" => %{"type" => "integer"},
            "starterPacks" => %{"type" => "integer"}
          },
          "type" => "object"
        },
        "threadViewPref" => %{
          "properties" => %{
            "sort" => %{
              "description" => "Sorting mode for threads.",
              "knownValues" => ["oldest", "newest", "most-likes", "random", "hotness"],
              "type" => "string"
            }
          },
          "type" => "object"
        },
        "contentLabelPref" => %{
          "properties" => %{
            "label" => %{"type" => "string"},
            "labelerDid" => %{
              "description" => "Which labeler does this preference apply to? If undefined, applies globally.",
              "format" => "did",
              "type" => "string"
            },
            "visibility" => %{
              "knownValues" => ["ignore", "show", "warn", "hide"],
              "type" => "string"
            }
          },
          "required" => ["label", "visibility"],
          "type" => "object"
        },
        "interestsPref" => %{
          "properties" => %{
            "tags" => %{
              "description" =>
                "A list of tags which describe the account owner's interests gathered during onboarding.",
              "items" => %{
                "maxGraphemes" => 64,
                "maxLength" => 640,
                "type" => "string"
              },
              "maxLength" => 100,
              "type" => "array"
            }
          },
          "required" => ["tags"],
          "type" => "object"
        },
        "mutedWordsPref" => %{
          "properties" => %{
            "items" => %{
              "description" => "A list of words the account owner has muted.",
              "items" => %{
                "ref" => "app.bsky.actor.defs#mutedWord",
                "type" => "ref"
              },
              "type" => "array"
            }
          },
          "required" => ["items"],
          "type" => "object"
        },
        "savedFeed" => %{
          "properties" => %{
            "id" => %{"type" => "string"},
            "pinned" => %{"type" => "boolean"},
            "type" => %{
              "knownValues" => ["feed", "list", "timeline"],
              "type" => "string"
            },
            "value" => %{"type" => "string"}
          },
          "required" => ["id", "type", "value", "pinned"],
          "type" => "object"
        },
        "verificationPrefs" => %{
          "description" => "Preferences for how verified accounts appear in the app.",
          "properties" => %{
            "hideBadges" => %{
              "default" => false,
              "description" => "Hide the blue check badges for verified accounts and trusted verifiers.",
              "type" => "boolean"
            }
          },
          "required" => [],
          "type" => "object"
        },
        "profileAssociatedGerm" => %{
          "properties" => %{
            "messageMeUrl" => %{"format" => "uri", "type" => "string"},
            "showButtonTo" => %{
              "knownValues" => ["usersIFollow", "everyone"],
              "type" => "string"
            }
          },
          "required" => ["showButtonTo", "messageMeUrl"],
          "type" => "object"
        },
        "profileViewDetailed" => %{
          "properties" => %{
            "associated" => %{"ref" => "#profileAssociated", "type" => "ref"},
            "avatar" => %{"format" => "uri", "type" => "string"},
            "banner" => %{"format" => "uri", "type" => "string"},
            "createdAt" => %{"format" => "datetime", "type" => "string"},
            "debug" => %{
              "description" => "Debug information for internal development",
              "type" => "unknown"
            },
            "description" => %{
              "maxGraphemes" => 256,
              "maxLength" => 2560,
              "type" => "string"
            },
            "did" => %{"format" => "did", "type" => "string"},
            "displayName" => %{
              "maxGraphemes" => 64,
              "maxLength" => 640,
              "type" => "string"
            },
            "followersCount" => %{"type" => "integer"},
            "followsCount" => %{"type" => "integer"},
            "handle" => %{"format" => "handle", "type" => "string"},
            "indexedAt" => %{"format" => "datetime", "type" => "string"},
            "joinedViaStarterPack" => %{
              "ref" => "app.bsky.graph.defs#starterPackViewBasic",
              "type" => "ref"
            },
            "labels" => %{
              "items" => %{
                "ref" => "com.atproto.label.defs#label",
                "type" => "ref"
              },
              "type" => "array"
            },
            "pinnedPost" => %{
              "ref" => "com.atproto.repo.strongRef",
              "type" => "ref"
            },
            "postsCount" => %{"type" => "integer"},
            "pronouns" => %{"type" => "string"},
            "status" => %{"ref" => "#statusView", "type" => "ref"},
            "verification" => %{"ref" => "#verificationState", "type" => "ref"},
            "viewer" => %{"ref" => "#viewerState", "type" => "ref"},
            "website" => %{"format" => "uri", "type" => "string"}
          },
          "required" => ["did", "handle"],
          "type" => "object"
        },
        "adultContentPref" => %{
          "properties" => %{
            "enabled" => %{"default" => false, "type" => "boolean"}
          },
          "required" => ["enabled"],
          "type" => "object"
        },
        "profileViewBasic" => %{
          "properties" => %{
            "associated" => %{"ref" => "#profileAssociated", "type" => "ref"},
            "avatar" => %{"format" => "uri", "type" => "string"},
            "createdAt" => %{"format" => "datetime", "type" => "string"},
            "debug" => %{
              "description" => "Debug information for internal development",
              "type" => "unknown"
            },
            "did" => %{"format" => "did", "type" => "string"},
            "displayName" => %{
              "maxGraphemes" => 64,
              "maxLength" => 640,
              "type" => "string"
            },
            "handle" => %{"format" => "handle", "type" => "string"},
            "labels" => %{
              "items" => %{
                "ref" => "com.atproto.label.defs#label",
                "type" => "ref"
              },
              "type" => "array"
            },
            "pronouns" => %{"type" => "string"},
            "status" => %{"ref" => "#statusView", "type" => "ref"},
            "verification" => %{"ref" => "#verificationState", "type" => "ref"},
            "viewer" => %{"ref" => "#viewerState", "type" => "ref"}
          },
          "required" => ["did", "handle"],
          "type" => "object"
        },
        "labelersPref" => %{
          "properties" => %{
            "labelers" => %{
              "items" => %{"ref" => "#labelerPrefItem", "type" => "ref"},
              "type" => "array"
            }
          },
          "required" => ["labelers"],
          "type" => "object"
        },
        "liveEventPreferences" => %{
          "description" => "Preferences for live events.",
          "properties" => %{
            "hiddenFeedIds" => %{
              "description" => "A list of feed IDs that the user has hidden from live events.",
              "items" => %{"type" => "string"},
              "type" => "array"
            },
            "hideAllFeeds" => %{
              "default" => false,
              "description" => "Whether to hide all feeds from live events.",
              "type" => "boolean"
            }
          },
          "type" => "object"
        },
        "verificationView" => %{
          "description" => "An individual verification for an associated subject.",
          "properties" => %{
            "createdAt" => %{
              "description" => "Timestamp when the verification was created.",
              "format" => "datetime",
              "type" => "string"
            },
            "isValid" => %{
              "description" => "True if the verification passes validation, otherwise false.",
              "type" => "boolean"
            },
            "issuer" => %{
              "description" => "The user who issued this verification.",
              "format" => "did",
              "type" => "string"
            },
            "issuerDisplayName" => %{
              "description" => "The display name of the issuer.",
              "type" => "string"
            },
            "issuerHandle" => %{
              "description" => "The handle of the issuer.",
              "format" => "handle",
              "type" => "string"
            },
            "uri" => %{
              "description" => "The AT-URI of the verification record.",
              "format" => "at-uri",
              "type" => "string"
            }
          },
          "required" => ["issuer", "uri", "isValid", "createdAt"],
          "type" => "object"
        },
        "preferences" => %{
          "items" => %{
            "refs" => [
              "#adultContentPref",
              "#contentLabelPref",
              "#savedFeedsPref",
              "#savedFeedsPrefV2",
              "#personalDetailsPref",
              "#declaredAgePref",
              "#feedViewPref",
              "#threadViewPref",
              "#interestsPref",
              "#mutedWordsPref",
              "#hiddenPostsPref",
              "#bskyAppStatePref",
              "#labelersPref",
              "#postInteractionSettingsPref",
              "#verificationPrefs",
              "#liveEventPreferences"
            ],
            "type" => "union"
          },
          "type" => "array"
        },
        "nux" => %{
          "description" => "A new user experiences (NUX) storage object",
          "properties" => %{
            "completed" => %{"default" => false, "type" => "boolean"},
            "data" => %{
              "description" =>
                "Arbitrary data for the NUX. The structure is defined by the NUX itself. Limited to 300 characters.",
              "maxGraphemes" => 300,
              "maxLength" => 3000,
              "type" => "string"
            },
            "expiresAt" => %{
              "description" => "The date and time at which the NUX will expire and should be considered completed.",
              "format" => "datetime",
              "type" => "string"
            },
            "id" => %{"maxLength" => 100, "type" => "string"}
          },
          "required" => ["id", "completed"],
          "type" => "object"
        },
        "statusView" => %{
          "properties" => %{
            "cid" => %{"format" => "cid", "type" => "string"},
            "embed" => %{
              "description" => "An optional embed associated with the status.",
              "refs" => ["app.bsky.embed.external#view"],
              "type" => "union"
            },
            "expiresAt" => %{
              "description" =>
                "The date when this status will expire. The application might choose to no longer return the status after expiration.",
              "format" => "datetime",
              "type" => "string"
            },
            "isActive" => %{
              "description" =>
                "True if the status is not expired, false if it is expired. Only present if expiration was set.",
              "type" => "boolean"
            },
            "isDisabled" => %{
              "description" => "True if the user's go-live access has been disabled by a moderator, false otherwise.",
              "type" => "boolean"
            },
            "labels" => %{
              "items" => %{
                "ref" => "com.atproto.label.defs#label",
                "type" => "ref"
              },
              "type" => "array"
            },
            "record" => %{"type" => "unknown"},
            "status" => %{
              "description" => "The status for the account.",
              "knownValues" => ["app.bsky.actor.status#live"],
              "type" => "string"
            },
            "uri" => %{"format" => "at-uri", "type" => "string"}
          },
          "required" => ["status", "record"],
          "type" => "object"
        },
        "declaredAgePref" => %{
          "description" =>
            "Read-only preference containing value(s) inferred from the user's declared birthdate. Absence of this preference object in the response indicates that the user has not made a declaration.",
          "properties" => %{
            "isOverAge13" => %{
              "description" => "Indicates if the user has declared that they are over 13 years of age.",
              "type" => "boolean"
            },
            "isOverAge16" => %{
              "description" => "Indicates if the user has declared that they are over 16 years of age.",
              "type" => "boolean"
            },
            "isOverAge18" => %{
              "description" => "Indicates if the user has declared that they are over 18 years of age.",
              "type" => "boolean"
            }
          },
          "type" => "object"
        },
        "profileAssociatedActivitySubscription" => %{
          "properties" => %{
            "allowSubscriptions" => %{
              "knownValues" => ["followers", "mutuals", "none"],
              "type" => "string"
            }
          },
          "required" => ["allowSubscriptions"],
          "type" => "object"
        },
        "labelerPrefItem" => %{
          "properties" => %{"did" => %{"format" => "did", "type" => "string"}},
          "required" => ["did"],
          "type" => "object"
        },
        "postInteractionSettingsPref" => %{
          "description" =>
            "Default post interaction settings for the account. These values should be applied as default values when creating new posts. These refs should mirror the threadgate and postgate records exactly.",
          "properties" => %{
            "postgateEmbeddingRules" => %{
              "description" =>
                "Matches postgate record. List of rules defining who can embed this users posts. If value is an empty array or is undefined, no particular rules apply and anyone can embed.",
              "items" => %{
                "refs" => ["app.bsky.feed.postgate#disableRule"],
                "type" => "union"
              },
              "maxLength" => 5,
              "type" => "array"
            },
            "threadgateAllowRules" => %{
              "description" =>
                "Matches threadgate record. List of rules defining who can reply to this users posts. If value is an empty array, no one can reply. If value is undefined, anyone can reply.",
              "items" => %{
                "refs" => [
                  "app.bsky.feed.threadgate#mentionRule",
                  "app.bsky.feed.threadgate#followerRule",
                  "app.bsky.feed.threadgate#followingRule",
                  "app.bsky.feed.threadgate#listRule"
                ],
                "type" => "union"
              },
              "maxLength" => 5,
              "type" => "array"
            }
          },
          "required" => [],
          "type" => "object"
        },
        "mutedWordTarget" => %{
          "knownValues" => ["content", "tag"],
          "maxGraphemes" => 64,
          "maxLength" => 640,
          "type" => "string"
        },
        "verificationState" => %{
          "description" => "Represents the verification information about the user this object is attached to.",
          "properties" => %{
            "trustedVerifierStatus" => %{
              "description" => "The user's status as a trusted verifier.",
              "knownValues" => ["valid", "invalid", "none"],
              "type" => "string"
            },
            "verifications" => %{
              "description" =>
                "All verifications issued by trusted verifiers on behalf of this user. Verifications by untrusted verifiers are not included.",
              "items" => %{"ref" => "#verificationView", "type" => "ref"},
              "type" => "array"
            },
            "verifiedStatus" => %{
              "description" => "The user's status as a verified account.",
              "knownValues" => ["valid", "invalid", "none"],
              "type" => "string"
            }
          },
          "required" => ["verifications", "verifiedStatus", "trustedVerifierStatus"],
          "type" => "object"
        }
      },
      "id" => "app.bsky.actor.defs",
      "lexicon" => 1
    },
    %{
      "defs" => %{
        "main" => %{
          "description" =>
            "Get private preferences attached to the current account. Expected use is synchronization between multiple devices, and import/export during account migration. Requires auth.",
          "output" => %{
            "encoding" => "application/json",
            "schema" => %{
              "properties" => %{
                "preferences" => %{
                  "ref" => "app.bsky.actor.defs#preferences",
                  "type" => "ref"
                }
              },
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
          "description" =>
            "Get detailed profile view of an actor. Does not require auth, but contains relevant metadata with auth.",
          "output" => %{
            "encoding" => "application/json",
            "schema" => %{
              "ref" => "app.bsky.actor.defs#profileViewDetailed",
              "type" => "ref"
            }
          },
          "parameters" => %{
            "properties" => %{
              "actor" => %{
                "description" => "Handle or DID of account to fetch profile of.",
                "format" => "at-identifier",
                "type" => "string"
              }
            },
            "required" => ["actor"],
            "type" => "params"
          },
          "type" => "query"
        }
      },
      "id" => "app.bsky.actor.getProfile",
      "lexicon" => 1
    },
    %{
      "defs" => %{
        "main" => %{
          "description" => "Get detailed profile views of multiple actors.",
          "output" => %{
            "encoding" => "application/json",
            "schema" => %{
              "properties" => %{
                "profiles" => %{
                  "items" => %{
                    "ref" => "app.bsky.actor.defs#profileViewDetailed",
                    "type" => "ref"
                  },
                  "type" => "array"
                }
              },
              "required" => ["profiles"],
              "type" => "object"
            }
          },
          "parameters" => %{
            "properties" => %{
              "actors" => %{
                "items" => %{"format" => "at-identifier", "type" => "string"},
                "maxLength" => 25,
                "type" => "array"
              }
            },
            "required" => ["actors"],
            "type" => "params"
          },
          "type" => "query"
        }
      },
      "id" => "app.bsky.actor.getProfiles",
      "lexicon" => 1
    },
    %{
      "defs" => %{
        "main" => %{
          "description" =>
            "Get a list of suggested actors. Expected use is discovery of accounts to follow during new account onboarding.",
          "output" => %{
            "encoding" => "application/json",
            "schema" => %{
              "properties" => %{
                "actors" => %{
                  "items" => %{
                    "ref" => "app.bsky.actor.defs#profileView",
                    "type" => "ref"
                  },
                  "type" => "array"
                },
                "cursor" => %{"type" => "string"},
                "recId" => %{
                  "description" => "DEPRECATED: use recIdStr instead.",
                  "type" => "integer"
                },
                "recIdStr" => %{
                  "description" => "Snowflake for this recommendation, use when submitting recommendation events.",
                  "type" => "string"
                }
              },
              "required" => ["actors"],
              "type" => "object"
            }
          },
          "parameters" => %{
            "properties" => %{
              "cursor" => %{"type" => "string"},
              "limit" => %{
                "default" => 50,
                "maximum" => 100,
                "minimum" => 1,
                "type" => "integer"
              }
            },
            "type" => "params"
          },
          "type" => "query"
        }
      },
      "id" => "app.bsky.actor.getSuggestions",
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
          "description" => "Set the private preferences attached to the account.",
          "input" => %{
            "encoding" => "application/json",
            "schema" => %{
              "properties" => %{
                "preferences" => %{
                  "ref" => "app.bsky.actor.defs#preferences",
                  "type" => "ref"
                }
              },
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
          "description" => "Find actors (profiles) matching search criteria. Does not require auth.",
          "output" => %{
            "encoding" => "application/json",
            "schema" => %{
              "properties" => %{
                "actors" => %{
                  "items" => %{
                    "ref" => "app.bsky.actor.defs#profileView",
                    "type" => "ref"
                  },
                  "type" => "array"
                },
                "cursor" => %{"type" => "string"}
              },
              "required" => ["actors"],
              "type" => "object"
            }
          },
          "parameters" => %{
            "properties" => %{
              "cursor" => %{"type" => "string"},
              "limit" => %{
                "default" => 25,
                "maximum" => 100,
                "minimum" => 1,
                "type" => "integer"
              },
              "q" => %{
                "description" =>
                  "Search query string. Syntax, phrase, boolean, and faceting is unspecified, but Lucene query syntax is recommended.",
                "type" => "string"
              },
              "term" => %{
                "description" => "DEPRECATED: use 'q' instead.",
                "type" => "string"
              }
            },
            "type" => "params"
          },
          "type" => "query"
        }
      },
      "id" => "app.bsky.actor.searchActors",
      "lexicon" => 1
    },
    %{
      "defs" => %{
        "main" => %{
          "description" =>
            "Find actor suggestions for a prefix search term. Expected use is for auto-completion during text field entry. Does not require auth.",
          "output" => %{
            "encoding" => "application/json",
            "schema" => %{
              "properties" => %{
                "actors" => %{
                  "items" => %{
                    "ref" => "app.bsky.actor.defs#profileViewBasic",
                    "type" => "ref"
                  },
                  "type" => "array"
                }
              },
              "required" => ["actors"],
              "type" => "object"
            }
          },
          "parameters" => %{
            "properties" => %{
              "limit" => %{
                "default" => 10,
                "maximum" => 100,
                "minimum" => 1,
                "type" => "integer"
              },
              "q" => %{
                "description" => "Search query prefix; not a full query string.",
                "type" => "string"
              },
              "term" => %{
                "description" => "DEPRECATED: use 'q' instead.",
                "type" => "string"
              }
            },
            "type" => "params"
          },
          "type" => "query"
        }
      },
      "id" => "app.bsky.actor.searchActorsTypeahead",
      "lexicon" => 1
    },
    %{
      "defs" => %{
        "live" => %{
          "description" => "Advertises an account as currently offering live content.",
          "type" => "token"
        },
        "main" => %{
          "description" => "A declaration of a Bluesky account status.",
          "key" => "literal:self",
          "record" => %{
            "properties" => %{
              "createdAt" => %{"format" => "datetime", "type" => "string"},
              "durationMinutes" => %{
                "description" =>
                  "The duration of the status in minutes. Applications can choose to impose minimum and maximum limits.",
                "minimum" => 1,
                "type" => "integer"
              },
              "embed" => %{
                "description" => "An optional embed associated with the status.",
                "refs" => ["app.bsky.embed.external"],
                "type" => "union"
              },
              "status" => %{
                "description" => "The status for the account.",
                "knownValues" => ["app.bsky.actor.status#live"],
                "type" => "string"
              }
            },
            "required" => ["status", "createdAt"],
            "type" => "object"
          },
          "type" => "record"
        }
      },
      "id" => "app.bsky.actor.status",
      "lexicon" => 1
    },
    %{
      "defs" => %{
        "main" => %{
          "description" => "Initiate Age Assurance for an account.",
          "errors" => [
            %{"name" => "InvalidEmail"},
            %{"name" => "DidTooLong"},
            %{"name" => "InvalidInitiation"},
            %{"name" => "RegionNotSupported"}
          ],
          "input" => %{
            "encoding" => "application/json",
            "schema" => %{
              "properties" => %{
                "countryCode" => %{
                  "description" => "An ISO 3166-1 alpha-2 code of the user's location.",
                  "type" => "string"
                },
                "email" => %{
                  "description" => "The user's email address to receive Age Assurance instructions.",
                  "type" => "string"
                },
                "language" => %{
                  "description" => "The user's preferred language for communication during the Age Assurance process.",
                  "type" => "string"
                },
                "regionCode" => %{
                  "description" => "An optional ISO 3166-2 code of the user's region or state within the country.",
                  "type" => "string"
                }
              },
              "required" => ["email", "language", "countryCode"],
              "type" => "object"
            }
          },
          "output" => %{
            "encoding" => "application/json",
            "schema" => %{
              "ref" => "app.bsky.ageassurance.defs#state",
              "type" => "ref"
            }
          },
          "type" => "procedure"
        }
      },
      "id" => "app.bsky.ageassurance.begin",
      "lexicon" => 1
    },
    %{
      "defs" => %{
        "access" => %{
          "description" => "The access level granted based on Age Assurance data we've processed.",
          "knownValues" => ["unknown", "none", "safe", "full"],
          "type" => "string"
        },
        "config" => %{
          "description" => "",
          "properties" => %{
            "regions" => %{
              "description" => "The per-region Age Assurance configuration.",
              "items" => %{
                "ref" => "app.bsky.ageassurance.defs#configRegion",
                "type" => "ref"
              },
              "type" => "array"
            }
          },
          "required" => ["regions"],
          "type" => "object"
        },
        "configRegion" => %{
          "description" => "The Age Assurance configuration for a specific region.",
          "properties" => %{
            "countryCode" => %{
              "description" => "The ISO 3166-1 alpha-2 country code this configuration applies to.",
              "type" => "string"
            },
            "minAccessAge" => %{
              "description" => "The minimum age (as a whole integer) required to use Bluesky in this region.",
              "type" => "integer"
            },
            "regionCode" => %{
              "description" =>
                "The ISO 3166-2 region code this configuration applies to. If omitted, the configuration applies to the entire country.",
              "type" => "string"
            },
            "rules" => %{
              "description" =>
                "The ordered list of Age Assurance rules that apply to this region. Rules should be applied in order, and the first matching rule determines the access level granted. The rules array should always include a default rule as the last item.",
              "items" => %{
                "refs" => [
                  "#configRegionRuleDefault",
                  "#configRegionRuleIfDeclaredOverAge",
                  "#configRegionRuleIfDeclaredUnderAge",
                  "#configRegionRuleIfAssuredOverAge",
                  "#configRegionRuleIfAssuredUnderAge",
                  "#configRegionRuleIfAccountNewerThan",
                  "#configRegionRuleIfAccountOlderThan"
                ],
                "type" => "union"
              },
              "type" => "array"
            }
          },
          "required" => ["countryCode", "minAccessAge", "rules"],
          "type" => "object"
        },
        "configRegionRuleDefault" => %{
          "description" => "Age Assurance rule that applies by default.",
          "properties" => %{
            "access" => %{
              "ref" => "app.bsky.ageassurance.defs#access",
              "type" => "ref"
            }
          },
          "required" => ["access"],
          "type" => "object"
        },
        "configRegionRuleIfAccountNewerThan" => %{
          "description" => "Age Assurance rule that applies if the account is equal-to or newer than a certain date.",
          "properties" => %{
            "access" => %{
              "ref" => "app.bsky.ageassurance.defs#access",
              "type" => "ref"
            },
            "date" => %{
              "description" => "The date threshold as a datetime string.",
              "format" => "datetime",
              "type" => "string"
            }
          },
          "required" => ["date", "access"],
          "type" => "object"
        },
        "configRegionRuleIfAccountOlderThan" => %{
          "description" => "Age Assurance rule that applies if the account is older than a certain date.",
          "properties" => %{
            "access" => %{
              "ref" => "app.bsky.ageassurance.defs#access",
              "type" => "ref"
            },
            "date" => %{
              "description" => "The date threshold as a datetime string.",
              "format" => "datetime",
              "type" => "string"
            }
          },
          "required" => ["date", "access"],
          "type" => "object"
        },
        "configRegionRuleIfAssuredOverAge" => %{
          "description" =>
            "Age Assurance rule that applies if the user has been assured to be equal-to or over a certain age.",
          "properties" => %{
            "access" => %{
              "ref" => "app.bsky.ageassurance.defs#access",
              "type" => "ref"
            },
            "age" => %{
              "description" => "The age threshold as a whole integer.",
              "type" => "integer"
            }
          },
          "required" => ["age", "access"],
          "type" => "object"
        },
        "configRegionRuleIfAssuredUnderAge" => %{
          "description" => "Age Assurance rule that applies if the user has been assured to be under a certain age.",
          "properties" => %{
            "access" => %{
              "ref" => "app.bsky.ageassurance.defs#access",
              "type" => "ref"
            },
            "age" => %{
              "description" => "The age threshold as a whole integer.",
              "type" => "integer"
            }
          },
          "required" => ["age", "access"],
          "type" => "object"
        },
        "configRegionRuleIfDeclaredOverAge" => %{
          "description" =>
            "Age Assurance rule that applies if the user has declared themselves equal-to or over a certain age.",
          "properties" => %{
            "access" => %{
              "ref" => "app.bsky.ageassurance.defs#access",
              "type" => "ref"
            },
            "age" => %{
              "description" => "The age threshold as a whole integer.",
              "type" => "integer"
            }
          },
          "required" => ["age", "access"],
          "type" => "object"
        },
        "configRegionRuleIfDeclaredUnderAge" => %{
          "description" => "Age Assurance rule that applies if the user has declared themselves under a certain age.",
          "properties" => %{
            "access" => %{
              "ref" => "app.bsky.ageassurance.defs#access",
              "type" => "ref"
            },
            "age" => %{
              "description" => "The age threshold as a whole integer.",
              "type" => "integer"
            }
          },
          "required" => ["age", "access"],
          "type" => "object"
        },
        "event" => %{
          "description" => "Object used to store Age Assurance data in stash.",
          "properties" => %{
            "access" => %{
              "description" => "The access level granted based on Age Assurance data we've processed.",
              "knownValues" => ["unknown", "none", "safe", "full"],
              "type" => "string"
            },
            "attemptId" => %{
              "description" => "The unique identifier for this instance of the Age Assurance flow, in UUID format.",
              "type" => "string"
            },
            "completeIp" => %{
              "description" => "The IP address used when completing the Age Assurance flow.",
              "type" => "string"
            },
            "completeUa" => %{
              "description" => "The user agent used when completing the Age Assurance flow.",
              "type" => "string"
            },
            "countryCode" => %{
              "description" => "The ISO 3166-1 alpha-2 country code provided when beginning the Age Assurance flow.",
              "type" => "string"
            },
            "createdAt" => %{
              "description" => "The date and time of this write operation.",
              "format" => "datetime",
              "type" => "string"
            },
            "email" => %{
              "description" => "The email used for Age Assurance.",
              "type" => "string"
            },
            "initIp" => %{
              "description" => "The IP address used when initiating the Age Assurance flow.",
              "type" => "string"
            },
            "initUa" => %{
              "description" => "The user agent used when initiating the Age Assurance flow.",
              "type" => "string"
            },
            "regionCode" => %{
              "description" => "The ISO 3166-2 region code provided when beginning the Age Assurance flow.",
              "type" => "string"
            },
            "status" => %{
              "description" => "The status of the Age Assurance process.",
              "knownValues" => ["unknown", "pending", "assured", "blocked"],
              "type" => "string"
            }
          },
          "required" => ["createdAt", "status", "access", "attemptId", "countryCode"],
          "type" => "object"
        },
        "state" => %{
          "description" => "The user's computed Age Assurance state.",
          "properties" => %{
            "access" => %{
              "ref" => "app.bsky.ageassurance.defs#access",
              "type" => "ref"
            },
            "lastInitiatedAt" => %{
              "description" => "The timestamp when this state was last updated.",
              "format" => "datetime",
              "type" => "string"
            },
            "status" => %{
              "ref" => "app.bsky.ageassurance.defs#status",
              "type" => "ref"
            }
          },
          "required" => ["status", "access"],
          "type" => "object"
        },
        "stateMetadata" => %{
          "description" => "Additional metadata needed to compute Age Assurance state client-side.",
          "properties" => %{
            "accountCreatedAt" => %{
              "description" => "The account creation timestamp.",
              "format" => "datetime",
              "type" => "string"
            }
          },
          "required" => [],
          "type" => "object"
        },
        "status" => %{
          "description" => "The status of the Age Assurance process.",
          "knownValues" => ["unknown", "pending", "assured", "blocked"],
          "type" => "string"
        }
      },
      "id" => "app.bsky.ageassurance.defs",
      "lexicon" => 1
    },
    %{
      "defs" => %{
        "main" => %{
          "description" => "Returns Age Assurance configuration for use on the client.",
          "output" => %{
            "encoding" => "application/json",
            "schema" => %{
              "ref" => "app.bsky.ageassurance.defs#config",
              "type" => "ref"
            }
          },
          "type" => "query"
        }
      },
      "id" => "app.bsky.ageassurance.getConfig",
      "lexicon" => 1
    },
    %{
      "defs" => %{
        "main" => %{
          "description" =>
            "Returns server-computed Age Assurance state, if available, and any additional metadata needed to compute Age Assurance state client-side.",
          "output" => %{
            "encoding" => "application/json",
            "schema" => %{
              "properties" => %{
                "metadata" => %{
                  "ref" => "app.bsky.ageassurance.defs#stateMetadata",
                  "type" => "ref"
                },
                "state" => %{
                  "ref" => "app.bsky.ageassurance.defs#state",
                  "type" => "ref"
                }
              },
              "required" => ["state", "metadata"],
              "type" => "object"
            }
          },
          "parameters" => %{
            "properties" => %{
              "countryCode" => %{"type" => "string"},
              "regionCode" => %{"type" => "string"}
            },
            "required" => ["countryCode"],
            "type" => "params"
          },
          "type" => "query"
        }
      },
      "id" => "app.bsky.ageassurance.getState",
      "lexicon" => 1
    },
    %{
      "defs" => %{
        "main" => %{
          "detail" => "Can not update or delete posts.",
          "detail:lang" => %{},
          "permissions" => [
            %{
              "inheritAud" => true,
              "lxm" => ["app.bsky.video.uploadVideo", "app.bsky.video.getJobStatus", "app.bsky.video.getUploadLimits"],
              "resource" => "rpc",
              "type" => "permission"
            },
            %{
              "action" => ["create"],
              "collection" => ["app.bsky.feed.post", "app.bsky.feed.postgate", "app.bsky.feed.threadgate"],
              "resource" => "repo",
              "type" => "permission"
            }
          ],
          "title" => "Create Bluesky Posts",
          "title:lang" => %{},
          "type" => "permission-set"
        }
      },
      "id" => "app.bsky.authCreatePosts",
      "lexicon" => 1
    },
    %{
      "defs" => %{
        "main" => %{
          "detail" => "Clean up public account history: posts, reposts, and likes.",
          "detail:lang" => %{},
          "permissions" => [
            %{
              "action" => ["delete"],
              "collection" => [
                "app.bsky.feed.like",
                "app.bsky.feed.post",
                "app.bsky.feed.postgate",
                "app.bsky.feed.repost",
                "app.bsky.feed.threadgate"
              ],
              "resource" => "repo",
              "type" => "permission"
            }
          ],
          "title" => "Delete Bluesky Content",
          "title:lang" => %{},
          "type" => "permission-set"
        }
      },
      "id" => "app.bsky.authDeleteContent",
      "lexicon" => 1
    },
    %{
      "defs" => %{
        "main" => %{
          "detail" =>
            "Manage all public content and interactions, private preferences and subscriptions, and other Bluesky-specific app features and data.",
          "detail:lang" => %{},
          "permissions" => [
            %{
              "inheritAud" => true,
              "lxm" => [
                "app.bsky.actor.getPreferences",
                "app.bsky.actor.getProfile",
                "app.bsky.actor.getProfiles",
                "app.bsky.actor.getSuggestions",
                "app.bsky.actor.putPreferences",
                "app.bsky.actor.searchActors",
                "app.bsky.actor.searchActorsTypeahead",
                "app.bsky.bookmark.createBookmark",
                "app.bsky.bookmark.deleteBookmark",
                "app.bsky.bookmark.getBookmarks",
                "app.bsky.contact.dismissMatch",
                "app.bsky.contact.getMatches",
                "app.bsky.contact.getSyncStatus",
                "app.bsky.contact.importContacts",
                "app.bsky.contact.removeData",
                "app.bsky.contact.startPhoneVerification",
                "app.bsky.contact.verifyPhone",
                "app.bsky.feed.describeFeedGenerator",
                "app.bsky.feed.getActorFeeds",
                "app.bsky.feed.getActorLikes",
                "app.bsky.feed.getAuthorFeed",
                "app.bsky.feed.getFeed",
                "app.bsky.feed.getFeedGenerator",
                "app.bsky.feed.getFeedGenerators",
                "app.bsky.feed.getFeedSkeleton",
                "app.bsky.feed.getLikes",
                "app.bsky.feed.getListFeed",
                "app.bsky.feed.getPostThread",
                "app.bsky.feed.getPosts",
                "app.bsky.feed.getQuotes",
                "app.bsky.feed.getRepostedBy",
                "app.bsky.feed.getSuggestedFeeds",
                "app.bsky.feed.getTimeline",
                "app.bsky.feed.searchPosts",
                "app.bsky.feed.sendInteractions",
                "app.bsky.graph.getActorStarterPacks",
                "app.bsky.graph.getBlocks",
                "app.bsky.graph.getFollowers",
                "app.bsky.graph.getFollows",
                "app.bsky.graph.getKnownFollowers",
                "app.bsky.graph.getList",
                "app.bsky.graph.getListBlocks",
                "app.bsky.graph.getListMutes",
                "app.bsky.graph.getLists",
                "app.bsky.graph.getListsWithMembership",
                "app.bsky.graph.getMutes",
                "app.bsky.graph.getRelationships",
                "app.bsky.graph.getStarterPack",
                "app.bsky.graph.getStarterPacks",
                "app.bsky.graph.getStarterPacksWithMembership",
                "app.bsky.graph.getSuggestedFollowsByActor",
                "app.bsky.graph.muteActor",
                "app.bsky.graph.muteActorList",
                "app.bsky.graph.muteThread",
                "app.bsky.graph.searchStarterPacks",
                "app.bsky.graph.unmuteActor",
                "app.bsky.graph.unmuteActorList",
                "app.bsky.graph.unmuteThread",
                "app.bsky.labeler.getServices",
                "app.bsky.notification.getPreferences",
                "app.bsky.notification.getUnreadCount",
                "app.bsky.notification.listActivitySubscriptions",
                "app.bsky.notification.listNotifications",
                "app.bsky.notification.putActivitySubscription",
                "app.bsky.notification.putPreferences",
                "app.bsky.notification.putPreferencesV2",
                "app.bsky.notification.registerPush",
                "app.bsky.notification.unregisterPush",
                "app.bsky.notification.updateSeen",
                "app.bsky.unspecced.getAgeAssuranceState",
                "app.bsky.unspecced.getConfig",
                "app.bsky.unspecced.getOnboardingSuggestedStarterPacks",
                "app.bsky.unspecced.getPopularFeedGenerators",
                "app.bsky.unspecced.getPostThreadOtherV2",
                "app.bsky.unspecced.getPostThreadV2",
                "app.bsky.unspecced.getSuggestedFeeds",
                "app.bsky.unspecced.getSuggestedFeedsSkeleton",
                "app.bsky.unspecced.getSuggestedStarterPacks",
                "app.bsky.unspecced.getSuggestedStarterPacksSkeleton",
                "app.bsky.unspecced.getSuggestedUsers",
                "app.bsky.unspecced.getSuggestedUsersSkeleton",
                "app.bsky.unspecced.getSuggestionsSkeleton",
                "app.bsky.unspecced.getTaggedSuggestions",
                "app.bsky.unspecced.getTrendingTopics",
                "app.bsky.unspecced.getTrends",
                "app.bsky.unspecced.getTrendsSkeleton",
                "app.bsky.unspecced.initAgeAssurance",
                "app.bsky.unspecced.searchActorsSkeleton",
                "app.bsky.unspecced.searchPostsSkeleton",
                "app.bsky.unspecced.searchStarterPacksSkeleton",
                "app.bsky.video.getJobStatus",
                "app.bsky.video.getUploadLimits",
                "app.bsky.video.uploadVideo"
              ],
              "resource" => "rpc",
              "type" => "permission"
            },
            %{
              "action" => ["create", "update", "delete"],
              "collection" => [
                "app.bsky.actor.profile",
                "app.bsky.actor.status",
                "app.bsky.feed.like",
                "app.bsky.feed.post",
                "app.bsky.feed.postgate",
                "app.bsky.feed.repost",
                "app.bsky.feed.threadgate",
                "app.bsky.graph.block",
                "app.bsky.graph.follow",
                "app.bsky.graph.list",
                "app.bsky.graph.listblock",
                "app.bsky.graph.listitem",
                "app.bsky.graph.starterpack",
                "app.bsky.notification.declaration"
              ],
              "resource" => "repo",
              "type" => "permission"
            }
          ],
          "title" => "Full Bluesky Social App Permissions",
          "title:lang" => %{},
          "type" => "permission-set"
        }
      },
      "id" => "app.bsky.authFullApp",
      "lexicon" => 1
    },
    %{
      "defs" => %{
        "main" => %{
          "detail" => "Configure feed generator declaration records.",
          "detail:lang" => %{},
          "permissions" => [
            %{
              "action" => ["create", "update", "delete"],
              "collection" => ["app.bsky.feed.generator"],
              "resource" => "repo",
              "type" => "permission"
            }
          ],
          "title" => "Manage Hosted Feeds",
          "title:lang" => %{},
          "type" => "permission-set"
        }
      },
      "id" => "app.bsky.authManageFeedDeclarations",
      "lexicon" => 1
    },
    %{
      "defs" => %{
        "main" => %{
          "detail" => "Configure labeler declaration records.",
          "detail:lang" => %{},
          "permissions" => [
            %{
              "action" => ["create", "update", "delete"],
              "collection" => ["app.bsky.labeler.service"],
              "resource" => "repo",
              "type" => "permission"
            }
          ],
          "title" => "Manage Hosted Labeling Service",
          "title:lang" => %{},
          "type" => "permission-set"
        }
      },
      "id" => "app.bsky.authManageLabelerService",
      "lexicon" => 1
    },
    %{
      "defs" => %{
        "main" => %{
          "detail" => "Control over blocks, mutes, mod lists, mod services, and preferences.",
          "detail:lang" => %{},
          "permissions" => [
            %{
              "inheritAud" => true,
              "lxm" => [
                "app.bsky.actor.getPreferences",
                "app.bsky.actor.putPreferences",
                "app.bsky.graph.muteActor",
                "app.bsky.graph.muteActorList",
                "app.bsky.graph.muteThread",
                "app.bsky.graph.unmuteActor",
                "app.bsky.graph.unmuteActorList",
                "app.bsky.graph.unmuteThread"
              ],
              "resource" => "rpc",
              "type" => "permission"
            },
            %{
              "action" => ["create", "update", "delete"],
              "collection" => ["app.bsky.graph.block", "app.bsky.graph.listblock"],
              "resource" => "repo",
              "type" => "permission"
            }
          ],
          "title" => "Manage Personal Moderation",
          "title:lang" => %{},
          "type" => "permission-set"
        }
      },
      "id" => "app.bsky.authManageModeration",
      "lexicon" => 1
    },
    %{
      "defs" => %{
        "main" => %{
          "detail" => "View and configure notifications for the Bluesky app.",
          "detail:lang" => %{},
          "permissions" => [
            %{
              "inheritAud" => true,
              "lxm" => [
                "app.bsky.notification.getPreferences",
                "app.bsky.notification.getUnreadCount",
                "app.bsky.notification.listActivitySubscriptions",
                "app.bsky.notification.listNotifications",
                "app.bsky.notification.putActivitySubscription",
                "app.bsky.notification.putPreferences",
                "app.bsky.notification.putPreferencesV2",
                "app.bsky.notification.registerPush",
                "app.bsky.notification.unregisterPush",
                "app.bsky.notification.updateSeen"
              ],
              "resource" => "rpc",
              "type" => "permission"
            }
          ],
          "title" => "Manage Bluesky Notifications",
          "title:lang" => %{},
          "type" => "permission-set"
        }
      },
      "id" => "app.bsky.authManageNotifications",
      "lexicon" => 1
    },
    %{
      "defs" => %{
        "main" => %{
          "detail" => "Update profile data, as well as status and public chat visibility.",
          "detail:lang" => %{},
          "permissions" => [
            %{
              "action" => ["create", "update", "delete"],
              "collection" => ["app.bsky.actor.profile", "app.bsky.actor.status", "app.bsky.notification.declaration"],
              "resource" => "repo",
              "type" => "permission"
            }
          ],
          "title" => "Manage Bluesky Profile",
          "title:lang" => %{},
          "type" => "permission-set"
        }
      },
      "id" => "app.bsky.authManageProfile",
      "lexicon" => 1
    },
    %{
      "defs" => %{
        "main" => %{
          "detail" =>
            "View Bluesky network content from account perspective, and read all notifications and preferences.",
          "detail:lang" => %{},
          "permissions" => [
            %{
              "inheritAud" => true,
              "lxm" => [
                "app.bsky.actor.getPreferences",
                "app.bsky.actor.getProfile",
                "app.bsky.actor.getProfiles",
                "app.bsky.actor.getSuggestions",
                "app.bsky.actor.searchActors",
                "app.bsky.actor.searchActorsTypeahead",
                "app.bsky.bookmark.getBookmarks",
                "app.bsky.feed.describeFeedGenerator",
                "app.bsky.feed.getActorFeeds",
                "app.bsky.feed.getActorLikes",
                "app.bsky.feed.getAuthorFeed",
                "app.bsky.feed.getFeed",
                "app.bsky.feed.getFeedGenerator",
                "app.bsky.feed.getFeedGenerators",
                "app.bsky.feed.getFeedSkeleton",
                "app.bsky.feed.getLikes",
                "app.bsky.feed.getListFeed",
                "app.bsky.feed.getPostThread",
                "app.bsky.feed.getPosts",
                "app.bsky.feed.getQuotes",
                "app.bsky.feed.getRepostedBy",
                "app.bsky.feed.getSuggestedFeeds",
                "app.bsky.feed.getTimeline",
                "app.bsky.feed.searchPosts",
                "app.bsky.graph.getActorStarterPacks",
                "app.bsky.graph.getBlocks",
                "app.bsky.graph.getFollowers",
                "app.bsky.graph.getFollows",
                "app.bsky.graph.getKnownFollowers",
                "app.bsky.graph.getListBlocks",
                "app.bsky.graph.getListMutes",
                "app.bsky.graph.getLists",
                "app.bsky.graph.getListsWithMembership",
                "app.bsky.graph.getMutes",
                "app.bsky.graph.getRelationships",
                "app.bsky.graph.getStarterPack",
                "app.bsky.graph.getStarterPacks",
                "app.bsky.graph.getStarterPacksWithMembership",
                "app.bsky.graph.getSuggestedFollowsByActor",
                "app.bsky.graph.searchStarterPacks",
                "app.bsky.labeler.getServices",
                "app.bsky.notification.getPreferences",
                "app.bsky.notification.getUnreadCount",
                "app.bsky.notification.listActivitySubscriptions",
                "app.bsky.notification.listNotifications",
                "app.bsky.notification.updateSeen",
                "app.bsky.unspecced.getAgeAssuranceState",
                "app.bsky.unspecced.getConfig",
                "app.bsky.unspecced.getOnboardingSuggestedStarterPacks",
                "app.bsky.unspecced.getPopularFeedGenerators",
                "app.bsky.unspecced.getPostThreadOtherV2",
                "app.bsky.unspecced.getPostThreadV2",
                "app.bsky.unspecced.getSuggestedFeeds",
                "app.bsky.unspecced.getSuggestedFeedsSkeleton",
                "app.bsky.unspecced.getSuggestedStarterPacks",
                "app.bsky.unspecced.getSuggestedStarterPacksSkeleton",
                "app.bsky.unspecced.getSuggestedUsers",
                "app.bsky.unspecced.getSuggestedUsersSkeleton",
                "app.bsky.unspecced.getSuggestionsSkeleton",
                "app.bsky.unspecced.getTaggedSuggestions",
                "app.bsky.unspecced.getTrendingTopics",
                "app.bsky.unspecced.getTrends",
                "app.bsky.unspecced.getTrendsSkeleton",
                "app.bsky.unspecced.searchActorsSkeleton",
                "app.bsky.unspecced.searchPostsSkeleton",
                "app.bsky.unspecced.searchStarterPacksSkeleton",
                "app.bsky.video.getUploadLimits"
              ],
              "resource" => "rpc",
              "type" => "permission"
            }
          ],
          "title" => "Read-only access to all content",
          "title:lang" => %{},
          "type" => "permission-set"
        }
      },
      "id" => "app.bsky.authViewAll",
      "lexicon" => 1
    },
    %{
      "defs" => %{
        "main" => %{
          "description" =>
            "Creates a private bookmark for the specified record. Currently, only `app.bsky.feed.post` records are supported. Requires authentication.",
          "errors" => [
            %{
              "description" => "The URI to be bookmarked is for an unsupported collection.",
              "name" => "UnsupportedCollection"
            }
          ],
          "input" => %{
            "encoding" => "application/json",
            "schema" => %{
              "properties" => %{
                "cid" => %{"format" => "cid", "type" => "string"},
                "uri" => %{"format" => "at-uri", "type" => "string"}
              },
              "required" => ["uri", "cid"],
              "type" => "object"
            }
          },
          "type" => "procedure"
        }
      },
      "id" => "app.bsky.bookmark.createBookmark",
      "lexicon" => 1
    },
    %{
      "defs" => %{
        "bookmark" => %{
          "description" => "Object used to store bookmark data in stash.",
          "properties" => %{
            "subject" => %{
              "description" =>
                "A strong ref to the record to be bookmarked. Currently, only `app.bsky.feed.post` records are supported.",
              "ref" => "com.atproto.repo.strongRef",
              "type" => "ref"
            }
          },
          "required" => ["subject"],
          "type" => "object"
        },
        "bookmarkView" => %{
          "properties" => %{
            "createdAt" => %{"format" => "datetime", "type" => "string"},
            "item" => %{
              "refs" => [
                "app.bsky.feed.defs#blockedPost",
                "app.bsky.feed.defs#notFoundPost",
                "app.bsky.feed.defs#postView"
              ],
              "type" => "union"
            },
            "subject" => %{
              "description" => "A strong ref to the bookmarked record.",
              "ref" => "com.atproto.repo.strongRef",
              "type" => "ref"
            }
          },
          "required" => ["subject", "item"],
          "type" => "object"
        }
      },
      "id" => "app.bsky.bookmark.defs",
      "lexicon" => 1
    },
    %{
      "defs" => %{
        "main" => %{
          "description" =>
            "Deletes a private bookmark for the specified record. Currently, only `app.bsky.feed.post` records are supported. Requires authentication.",
          "errors" => [
            %{
              "description" => "The URI to be bookmarked is for an unsupported collection.",
              "name" => "UnsupportedCollection"
            }
          ],
          "input" => %{
            "encoding" => "application/json",
            "schema" => %{
              "properties" => %{
                "uri" => %{"format" => "at-uri", "type" => "string"}
              },
              "required" => ["uri"],
              "type" => "object"
            }
          },
          "type" => "procedure"
        }
      },
      "id" => "app.bsky.bookmark.deleteBookmark",
      "lexicon" => 1
    },
    %{
      "defs" => %{
        "main" => %{
          "description" => "Gets views of records bookmarked by the authenticated user. Requires authentication.",
          "output" => %{
            "encoding" => "application/json",
            "schema" => %{
              "properties" => %{
                "bookmarks" => %{
                  "items" => %{
                    "ref" => "app.bsky.bookmark.defs#bookmarkView",
                    "type" => "ref"
                  },
                  "type" => "array"
                },
                "cursor" => %{"type" => "string"}
              },
              "required" => ["bookmarks"],
              "type" => "object"
            }
          },
          "parameters" => %{
            "properties" => %{
              "cursor" => %{"type" => "string"},
              "limit" => %{
                "default" => 50,
                "maximum" => 100,
                "minimum" => 1,
                "type" => "integer"
              }
            },
            "type" => "params"
          },
          "type" => "query"
        }
      },
      "id" => "app.bsky.bookmark.getBookmarks",
      "lexicon" => 1
    },
    %{
      "defs" => %{
        "matchAndContactIndex" => %{
          "description" =>
            "Associates a profile with the positional index of the contact import input in the call to `app.bsky.contact.importContacts`, so clients can know which phone caused a particular match.",
          "properties" => %{
            "contactIndex" => %{
              "description" => "The index of this match in the import contact input.",
              "maximum" => 999,
              "minimum" => 0,
              "type" => "integer"
            },
            "match" => %{
              "description" => "Profile of the matched user.",
              "ref" => "app.bsky.actor.defs#profileView",
              "type" => "ref"
            }
          },
          "required" => ["match", "contactIndex"],
          "type" => "object"
        },
        "notification" => %{
          "description" => "A stash object to be sent via bsync representing a notification to be created.",
          "properties" => %{
            "from" => %{
              "description" => "The DID of who this notification comes from.",
              "format" => "did",
              "type" => "string"
            },
            "to" => %{
              "description" => "The DID of who this notification should go to.",
              "format" => "did",
              "type" => "string"
            }
          },
          "required" => ["from", "to"],
          "type" => "object"
        },
        "syncStatus" => %{
          "properties" => %{
            "matchesCount" => %{
              "description" =>
                "Number of existing contact matches resulting of the user imports and of their imported contacts having imported the user. Matches stop being counted when the user either follows the matched contact or dismisses the match.",
              "minimum" => 0,
              "type" => "integer"
            },
            "syncedAt" => %{
              "description" => "Last date when contacts where imported.",
              "format" => "datetime",
              "type" => "string"
            }
          },
          "required" => ["syncedAt", "matchesCount"],
          "type" => "object"
        }
      },
      "id" => "app.bsky.contact.defs",
      "lexicon" => 1
    },
    %{
      "defs" => %{
        "main" => %{
          "description" =>
            "Removes a match that was found via contact import. It shouldn't appear again if the same contact is re-imported. Requires authentication.",
          "errors" => [%{"name" => "InvalidDid"}, %{"name" => "InternalError"}],
          "input" => %{
            "encoding" => "application/json",
            "schema" => %{
              "properties" => %{
                "subject" => %{
                  "description" => "The subject's DID to dismiss the match with.",
                  "format" => "did",
                  "type" => "string"
                }
              },
              "required" => ["subject"],
              "type" => "object"
            }
          },
          "output" => %{
            "encoding" => "application/json",
            "schema" => %{"properties" => %{}, "type" => "object"}
          },
          "type" => "procedure"
        }
      },
      "id" => "app.bsky.contact.dismissMatch",
      "lexicon" => 1
    },
    %{
      "defs" => %{
        "main" => %{
          "description" =>
            "Returns the matched contacts (contacts that were mutually imported). Excludes dismissed matches. Requires authentication.",
          "errors" => [
            %{"name" => "InvalidDid"},
            %{"name" => "InvalidLimit"},
            %{"name" => "InvalidCursor"},
            %{"name" => "InternalError"}
          ],
          "output" => %{
            "encoding" => "application/json",
            "schema" => %{
              "properties" => %{
                "cursor" => %{"type" => "string"},
                "matches" => %{
                  "items" => %{
                    "ref" => "app.bsky.actor.defs#profileView",
                    "type" => "ref"
                  },
                  "type" => "array"
                }
              },
              "required" => ["matches"],
              "type" => "object"
            }
          },
          "parameters" => %{
            "properties" => %{
              "cursor" => %{"type" => "string"},
              "limit" => %{
                "default" => 50,
                "maximum" => 100,
                "minimum" => 1,
                "type" => "integer"
              }
            },
            "type" => "params"
          },
          "type" => "query"
        }
      },
      "id" => "app.bsky.contact.getMatches",
      "lexicon" => 1
    },
    %{
      "defs" => %{
        "main" => %{
          "description" => "Gets the user's current contact import status. Requires authentication.",
          "errors" => [%{"name" => "InvalidDid"}, %{"name" => "InternalError"}],
          "output" => %{
            "encoding" => "application/json",
            "schema" => %{
              "properties" => %{
                "syncStatus" => %{
                  "description" =>
                    "If present, indicates the user has imported their contacts. If not present, indicates the user never used the feature or called `app.bsky.contact.removeData` and didn't import again since.",
                  "ref" => "app.bsky.contact.defs#syncStatus",
                  "type" => "ref"
                }
              },
              "type" => "object"
            }
          },
          "parameters" => %{"properties" => %{}, "type" => "params"},
          "type" => "query"
        }
      },
      "id" => "app.bsky.contact.getSyncStatus",
      "lexicon" => 1
    },
    %{
      "defs" => %{
        "main" => %{
          "description" =>
            "Import contacts for securely matching with other users. This follows the protocol explained in https://docs.bsky.app/blog/contact-import-rfc. Requires authentication.",
          "errors" => [
            %{"name" => "InvalidDid"},
            %{"name" => "InvalidContacts"},
            %{"name" => "TooManyContacts"},
            %{"name" => "InvalidToken"},
            %{"name" => "InternalError"}
          ],
          "input" => %{
            "encoding" => "application/json",
            "schema" => %{
              "properties" => %{
                "contacts" => %{
                  "description" =>
                    "List of phone numbers in global E.164 format (e.g., '+12125550123'). Phone numbers that cannot be normalized into a valid phone number will be discarded. Should not repeat the 'phone' input used in `app.bsky.contact.verifyPhone`.",
                  "items" => %{"type" => "string"},
                  "maxLength" => 1000,
                  "minLength" => 1,
                  "type" => "array"
                },
                "token" => %{
                  "description" =>
                    "JWT to authenticate the call. Use the JWT received as a response to the call to `app.bsky.contact.verifyPhone`.",
                  "type" => "string"
                }
              },
              "required" => ["token", "contacts"],
              "type" => "object"
            }
          },
          "output" => %{
            "encoding" => "application/json",
            "schema" => %{
              "properties" => %{
                "matchesAndContactIndexes" => %{
                  "description" =>
                    "The users that matched during import and their indexes on the input contacts, so the client can correlate with its local list.",
                  "items" => %{
                    "ref" => "app.bsky.contact.defs#matchAndContactIndex",
                    "type" => "ref"
                  },
                  "type" => "array"
                }
              },
              "required" => ["matchesAndContactIndexes"],
              "type" => "object"
            }
          },
          "type" => "procedure"
        }
      },
      "id" => "app.bsky.contact.importContacts",
      "lexicon" => 1
    },
    %{
      "defs" => %{
        "main" => %{
          "description" =>
            "Removes all stored hashes used for contact matching, existing matches, and sync status. Requires authentication.",
          "errors" => [%{"name" => "InvalidDid"}, %{"name" => "InternalError"}],
          "input" => %{
            "encoding" => "application/json",
            "schema" => %{"properties" => %{}, "type" => "object"}
          },
          "output" => %{
            "encoding" => "application/json",
            "schema" => %{"properties" => %{}, "type" => "object"}
          },
          "type" => "procedure"
        }
      },
      "id" => "app.bsky.contact.removeData",
      "lexicon" => 1
    },
    %{
      "defs" => %{
        "main" => %{
          "description" =>
            "System endpoint to send notifications related to contact imports. Requires role authentication.",
          "input" => %{
            "encoding" => "application/json",
            "schema" => %{
              "properties" => %{
                "from" => %{
                  "description" => "The DID of who this notification comes from.",
                  "format" => "did",
                  "type" => "string"
                },
                "to" => %{
                  "description" => "The DID of who this notification should go to.",
                  "format" => "did",
                  "type" => "string"
                }
              },
              "required" => ["from", "to"],
              "type" => "object"
            }
          },
          "output" => %{
            "encoding" => "application/json",
            "schema" => %{"properties" => %{}, "type" => "object"}
          },
          "type" => "procedure"
        }
      },
      "id" => "app.bsky.contact.sendNotification",
      "lexicon" => 1
    },
    %{
      "defs" => %{
        "main" => %{
          "description" =>
            "Starts a phone verification flow. The phone passed will receive a code via SMS that should be passed to `app.bsky.contact.verifyPhone`. Requires authentication.",
          "errors" => [
            %{"name" => "RateLimitExceeded"},
            %{"name" => "InvalidDid"},
            %{"name" => "InvalidPhone"},
            %{"name" => "InternalError"}
          ],
          "input" => %{
            "encoding" => "application/json",
            "schema" => %{
              "properties" => %{
                "phone" => %{
                  "description" => "The phone number to receive the code via SMS.",
                  "type" => "string"
                }
              },
              "required" => ["phone"],
              "type" => "object"
            }
          },
          "output" => %{
            "encoding" => "application/json",
            "schema" => %{"properties" => %{}, "type" => "object"}
          },
          "type" => "procedure"
        }
      },
      "id" => "app.bsky.contact.startPhoneVerification",
      "lexicon" => 1
    },
    %{
      "defs" => %{
        "main" => %{
          "description" =>
            "Verifies control over a phone number with a code received via SMS and starts a contact import session. Requires authentication.",
          "errors" => [
            %{"name" => "RateLimitExceeded"},
            %{"name" => "InvalidDid"},
            %{"name" => "InvalidPhone"},
            %{"name" => "InvalidCode"},
            %{"name" => "InternalError"}
          ],
          "input" => %{
            "encoding" => "application/json",
            "schema" => %{
              "properties" => %{
                "code" => %{
                  "description" =>
                    "The code received via SMS as a result of the call to `app.bsky.contact.startPhoneVerification`.",
                  "type" => "string"
                },
                "phone" => %{
                  "description" =>
                    "The phone number to verify. Should be the same as the one passed to `app.bsky.contact.startPhoneVerification`.",
                  "type" => "string"
                }
              },
              "required" => ["phone", "code"],
              "type" => "object"
            }
          },
          "output" => %{
            "encoding" => "application/json",
            "schema" => %{
              "properties" => %{
                "token" => %{
                  "description" =>
                    "JWT to be used in a call to `app.bsky.contact.importContacts`. It is only valid for a single call.",
                  "type" => "string"
                }
              },
              "required" => ["token"],
              "type" => "object"
            }
          },
          "type" => "procedure"
        }
      },
      "id" => "app.bsky.contact.verifyPhone",
      "lexicon" => 1
    },
    %{
      "defs" => %{
        "main" => %{
          "description" =>
            "Inserts a draft using private storage (stash). An upper limit of drafts might be enforced. Requires authentication.",
          "errors" => [
            %{
              "description" => "Trying to insert a new draft when the limit was already reached.",
              "name" => "DraftLimitReached"
            }
          ],
          "input" => %{
            "encoding" => "application/json",
            "schema" => %{
              "properties" => %{
                "draft" => %{
                  "ref" => "app.bsky.draft.defs#draft",
                  "type" => "ref"
                }
              },
              "required" => ["draft"],
              "type" => "object"
            }
          },
          "output" => %{
            "encoding" => "application/json",
            "schema" => %{
              "properties" => %{
                "id" => %{
                  "description" => "The ID of the created draft.",
                  "type" => "string"
                }
              },
              "required" => ["id"],
              "type" => "object"
            }
          },
          "type" => "procedure"
        }
      },
      "id" => "app.bsky.draft.createDraft",
      "lexicon" => 1
    },
    %{
      "defs" => %{
        "draft" => %{
          "description" => "A draft containing an array of draft posts.",
          "properties" => %{
            "deviceId" => %{
              "description" => "UUIDv4 identifier of the device that created this draft.",
              "maxLength" => 100,
              "type" => "string"
            },
            "deviceName" => %{
              "description" => "The device and/or platform on which the draft was created.",
              "maxLength" => 100,
              "type" => "string"
            },
            "langs" => %{
              "description" => "Indicates human language of posts primary text content.",
              "items" => %{"format" => "language", "type" => "string"},
              "maxLength" => 3,
              "type" => "array"
            },
            "postgateEmbeddingRules" => %{
              "description" => "Embedding rules for the postgates to be created when this draft is published.",
              "items" => %{
                "refs" => ["app.bsky.feed.postgate#disableRule"],
                "type" => "union"
              },
              "maxLength" => 5,
              "type" => "array"
            },
            "posts" => %{
              "description" => "Array of draft posts that compose this draft.",
              "items" => %{"ref" => "#draftPost", "type" => "ref"},
              "maxLength" => 100,
              "minLength" => 1,
              "type" => "array"
            },
            "threadgateAllow" => %{
              "description" => "Allow-rules for the threadgate to be created when this draft is published.",
              "items" => %{
                "refs" => [
                  "app.bsky.feed.threadgate#mentionRule",
                  "app.bsky.feed.threadgate#followerRule",
                  "app.bsky.feed.threadgate#followingRule",
                  "app.bsky.feed.threadgate#listRule"
                ],
                "type" => "union"
              },
              "maxLength" => 5,
              "type" => "array"
            }
          },
          "required" => ["posts"],
          "type" => "object"
        },
        "draftEmbedCaption" => %{
          "properties" => %{
            "content" => %{"maxLength" => 10000, "type" => "string"},
            "lang" => %{"format" => "language", "type" => "string"}
          },
          "required" => ["lang", "content"],
          "type" => "object"
        },
        "draftEmbedExternal" => %{
          "properties" => %{"uri" => %{"format" => "uri", "type" => "string"}},
          "required" => ["uri"],
          "type" => "object"
        },
        "draftEmbedGallery" => %{
          "properties" => %{
            "items" => %{"ref" => "#draftEmbedGalleryItems", "type" => "ref"}
          },
          "required" => ["items"],
          "type" => "object"
        },
        "draftEmbedGalleryItems" => %{
          "description" =>
            "The schema-level maxLength of 20 is a future-proof ceiling. Clients should currently enforce a soft limit of 10 items in authoring UIs.",
          "items" => %{"refs" => ["#draftEmbedImage"], "type" => "union"},
          "maxLength" => 20,
          "type" => "array"
        },
        "draftEmbedImage" => %{
          "properties" => %{
            "alt" => %{"maxGraphemes" => 2000, "type" => "string"},
            "localRef" => %{"ref" => "#draftEmbedLocalRef", "type" => "ref"}
          },
          "required" => ["localRef"],
          "type" => "object"
        },
        "draftEmbedLocalRef" => %{
          "properties" => %{
            "path" => %{
              "description" =>
                "Local, on-device ref to file to be embedded. Embeds are currently device-bound for drafts.",
              "maxLength" => 1024,
              "minLength" => 1,
              "type" => "string"
            }
          },
          "required" => ["path"],
          "type" => "object"
        },
        "draftEmbedRecord" => %{
          "properties" => %{
            "record" => %{"ref" => "com.atproto.repo.strongRef", "type" => "ref"}
          },
          "required" => ["record"],
          "type" => "object"
        },
        "draftEmbedVideo" => %{
          "properties" => %{
            "alt" => %{"maxGraphemes" => 2000, "type" => "string"},
            "captions" => %{
              "items" => %{"ref" => "#draftEmbedCaption", "type" => "ref"},
              "maxLength" => 20,
              "type" => "array"
            },
            "localRef" => %{"ref" => "#draftEmbedLocalRef", "type" => "ref"}
          },
          "required" => ["localRef"],
          "type" => "object"
        },
        "draftPost" => %{
          "description" => "One of the posts that compose a draft.",
          "properties" => %{
            "embedExternals" => %{
              "items" => %{"ref" => "#draftEmbedExternal", "type" => "ref"},
              "maxLength" => 1,
              "type" => "array"
            },
            "embedGallery" => %{"ref" => "#draftEmbedGallery", "type" => "ref"},
            "embedImages" => %{
              "items" => %{"ref" => "#draftEmbedImage", "type" => "ref"},
              "maxLength" => 4,
              "type" => "array"
            },
            "embedRecords" => %{
              "items" => %{"ref" => "#draftEmbedRecord", "type" => "ref"},
              "maxLength" => 1,
              "type" => "array"
            },
            "embedVideos" => %{
              "items" => %{"ref" => "#draftEmbedVideo", "type" => "ref"},
              "maxLength" => 1,
              "type" => "array"
            },
            "labels" => %{
              "description" => "Self-label values for this post. Effectively content warnings.",
              "refs" => ["com.atproto.label.defs#selfLabels"],
              "type" => "union"
            },
            "text" => %{
              "description" =>
                "The primary post content. It has a higher limit than post contents to allow storing a larger text that can later be refined into smaller posts.",
              "maxGraphemes" => 1000,
              "maxLength" => 10000,
              "type" => "string"
            }
          },
          "required" => ["text"],
          "type" => "object"
        },
        "draftView" => %{
          "description" => "View to present drafts data to users.",
          "properties" => %{
            "createdAt" => %{
              "description" => "The time the draft was created.",
              "format" => "datetime",
              "type" => "string"
            },
            "draft" => %{"ref" => "#draft", "type" => "ref"},
            "id" => %{
              "description" => "A TID to be used as a draft identifier.",
              "format" => "tid",
              "type" => "string"
            },
            "updatedAt" => %{
              "description" => "The time the draft was last updated.",
              "format" => "datetime",
              "type" => "string"
            }
          },
          "required" => ["id", "draft", "createdAt", "updatedAt"],
          "type" => "object"
        },
        "draftWithId" => %{
          "description" => "A draft with an identifier, used to store drafts in private storage (stash).",
          "properties" => %{
            "draft" => %{"ref" => "#draft", "type" => "ref"},
            "id" => %{
              "description" => "A TID to be used as a draft identifier.",
              "format" => "tid",
              "type" => "string"
            }
          },
          "required" => ["id", "draft"],
          "type" => "object"
        }
      },
      "id" => "app.bsky.draft.defs",
      "lexicon" => 1
    },
    %{
      "defs" => %{
        "main" => %{
          "description" => "Deletes a draft by ID. Requires authentication.",
          "input" => %{
            "encoding" => "application/json",
            "schema" => %{
              "properties" => %{"id" => %{"format" => "tid", "type" => "string"}},
              "required" => ["id"],
              "type" => "object"
            }
          },
          "type" => "procedure"
        }
      },
      "id" => "app.bsky.draft.deleteDraft",
      "lexicon" => 1
    },
    %{
      "defs" => %{
        "main" => %{
          "description" => "Gets views of user drafts. Requires authentication.",
          "output" => %{
            "encoding" => "application/json",
            "schema" => %{
              "properties" => %{
                "cursor" => %{"type" => "string"},
                "drafts" => %{
                  "items" => %{
                    "ref" => "app.bsky.draft.defs#draftView",
                    "type" => "ref"
                  },
                  "type" => "array"
                }
              },
              "required" => ["drafts"],
              "type" => "object"
            }
          },
          "parameters" => %{
            "properties" => %{
              "cursor" => %{"type" => "string"},
              "limit" => %{
                "default" => 50,
                "maximum" => 100,
                "minimum" => 1,
                "type" => "integer"
              }
            },
            "type" => "params"
          },
          "type" => "query"
        }
      },
      "id" => "app.bsky.draft.getDrafts",
      "lexicon" => 1
    },
    %{
      "defs" => %{
        "main" => %{
          "description" =>
            "Updates a draft using private storage (stash). If the draft ID points to a non-existing ID, the update will be silently ignored. This is done because updates don't enforce draft limit, so it accepts all writes, but will ignore invalid ones. Requires authentication.",
          "input" => %{
            "encoding" => "application/json",
            "schema" => %{
              "properties" => %{
                "draft" => %{
                  "ref" => "app.bsky.draft.defs#draftWithId",
                  "type" => "ref"
                }
              },
              "required" => ["draft"],
              "type" => "object"
            }
          },
          "type" => "procedure"
        }
      },
      "id" => "app.bsky.draft.updateDraft",
      "lexicon" => 1
    },
    %{
      "defs" => %{
        "aspectRatio" => %{
          "description" =>
            "width:height represents an aspect ratio. It may be approximate, and may not correspond to absolute dimensions in any given unit.",
          "properties" => %{
            "height" => %{"minimum" => 1, "type" => "integer"},
            "width" => %{"minimum" => 1, "type" => "integer"}
          },
          "required" => ["width", "height"],
          "type" => "object"
        }
      },
      "id" => "app.bsky.embed.defs",
      "lexicon" => 1
    },
    %{
      "defs" => %{
        "colorRGB" => %{
          "description" => "RGB color definition, inspired by site.standard.theme.color#rgb",
          "properties" => %{
            "b" => %{"maximum" => 255, "minimum" => 0, "type" => "integer"},
            "g" => %{"maximum" => 255, "minimum" => 0, "type" => "integer"},
            "r" => %{"maximum" => 255, "minimum" => 0, "type" => "integer"}
          },
          "required" => ["r", "g", "b"],
          "type" => "object"
        },
        "external" => %{
          "properties" => %{
            "associatedRefs" => %{
              "description" => "StrongRefs (uri+cid) of the Atmosphere records that backed this view.",
              "items" => %{"ref" => "com.atproto.repo.strongRef", "type" => "ref"},
              "type" => "array"
            },
            "description" => %{"type" => "string"},
            "thumb" => %{
              "accept" => ["image/*"],
              "maxSize" => 1_000_000,
              "type" => "blob"
            },
            "title" => %{"type" => "string"},
            "uri" => %{"format" => "uri", "type" => "string"}
          },
          "required" => ["uri", "title", "description"],
          "type" => "object"
        },
        "main" => %{
          "description" =>
            "A representation of some externally linked content (eg, a URL and 'card'), embedded in a Bluesky record (eg, a post).",
          "properties" => %{
            "external" => %{"ref" => "#external", "type" => "ref"}
          },
          "required" => ["external"],
          "type" => "object"
        },
        "view" => %{
          "properties" => %{
            "external" => %{"ref" => "#viewExternal", "type" => "ref"}
          },
          "required" => ["external"],
          "type" => "object"
        },
        "viewExternal" => %{
          "properties" => %{
            "associatedProfiles" => %{
              "description" => "Profiles of the owners of the Atmosphere records that backed this view.",
              "items" => %{
                "ref" => "app.bsky.actor.defs#profileViewBasic",
                "type" => "ref"
              },
              "type" => "array"
            },
            "associatedRefs" => %{
              "description" => "StrongRefs (uri+cid) of the Atmosphere records that backed this view.",
              "items" => %{"ref" => "com.atproto.repo.strongRef", "type" => "ref"},
              "type" => "array"
            },
            "createdAt" => %{
              "description" =>
                "When the external content was created, if available. Example: a publication date, for an article.",
              "format" => "datetime",
              "type" => "string"
            },
            "description" => %{"type" => "string"},
            "labels" => %{
              "items" => %{
                "ref" => "com.atproto.label.defs#label",
                "type" => "ref"
              },
              "type" => "array"
            },
            "readingTime" => %{
              "description" => "Estimated reading time in minutes, if applicable and available.",
              "type" => "integer"
            },
            "source" => %{"ref" => "#viewExternalSource", "type" => "ref"},
            "thumb" => %{"format" => "uri", "type" => "string"},
            "title" => %{"type" => "string"},
            "updatedAt" => %{
              "description" => "When the external content was updated, if available.",
              "format" => "datetime",
              "type" => "string"
            },
            "uri" => %{"format" => "uri", "type" => "string"}
          },
          "required" => ["uri", "title", "description"],
          "type" => "object"
        },
        "viewExternalSource" => %{
          "description" => "The source of an external embed, such as a standard.site publication.",
          "properties" => %{
            "description" => %{"type" => "string"},
            "icon" => %{
              "description" =>
                "Fully-qualified URL where an icon representing the source can be fetched. For example, CDN location provided by the App View.",
              "format" => "uri",
              "type" => "string"
            },
            "theme" => %{"ref" => "#viewExternalSourceTheme", "type" => "ref"},
            "title" => %{"type" => "string"},
            "uri" => %{
              "description" =>
                "URI of the source, if available. Example: the https:// URL of a site.standard.publication record.",
              "format" => "uri",
              "type" => "string"
            }
          },
          "required" => ["uri", "title"],
          "type" => "object"
        },
        "viewExternalSourceTheme" => %{
          "description" =>
            "The theme colors of an external source, such as a site.standard.publication. These colors may be used when rendering an embed from that source.",
          "properties" => %{
            "accentForegroundRGB" => %{"ref" => "#colorRGB", "type" => "ref"},
            "accentRGB" => %{"ref" => "#colorRGB", "type" => "ref"},
            "backgroundRGB" => %{"ref" => "#colorRGB", "type" => "ref"},
            "foregroundRGB" => %{"ref" => "#colorRGB", "type" => "ref"}
          },
          "type" => "object"
        }
      },
      "id" => "app.bsky.embed.external",
      "lexicon" => 1
    },
    %{
      "defs" => %{
        "image" => %{
          "properties" => %{
            "alt" => %{
              "description" => "Alt text description of the image, for accessibility.",
              "type" => "string"
            },
            "aspectRatio" => %{
              "ref" => "app.bsky.embed.defs#aspectRatio",
              "type" => "ref"
            },
            "image" => %{
              "accept" => ["image/*"],
              "maxSize" => 2_000_000,
              "type" => "blob"
            }
          },
          "required" => ["image", "alt", "aspectRatio"],
          "type" => "object"
        },
        "main" => %{
          "properties" => %{
            "items" => %{
              "description" =>
                "The schema-level maxLength of 20 is a future-proof ceiling. Clients should currently enforce a soft limit of 10 items in authoring UIs.",
              "items" => %{
                "description" =>
                  "The media items in the gallery. Each item may be of a different type, but all types must be supported by the client.",
                "refs" => ["#image"],
                "type" => "union"
              },
              "maxLength" => 20,
              "type" => "array"
            }
          },
          "required" => ["items"],
          "type" => "object"
        },
        "view" => %{
          "properties" => %{
            "items" => %{
              "items" => %{"refs" => ["#viewImage"], "type" => "union"},
              "type" => "array"
            }
          },
          "required" => ["items"],
          "type" => "object"
        },
        "viewImage" => %{
          "properties" => %{
            "alt" => %{
              "description" => "Alt text description of the image, for accessibility.",
              "type" => "string"
            },
            "aspectRatio" => %{
              "ref" => "app.bsky.embed.defs#aspectRatio",
              "type" => "ref"
            },
            "fullsize" => %{
              "description" =>
                "Fully-qualified URL where a large version of the image can be fetched. May or may not be the exact original blob. For example, CDN location provided by the App View.",
              "format" => "uri",
              "type" => "string"
            },
            "thumbnail" => %{
              "description" =>
                "Fully-qualified URL where a thumbnail of the image can be fetched. For example, CDN location provided by the App View.",
              "format" => "uri",
              "type" => "string"
            }
          },
          "required" => ["thumbnail", "fullsize", "alt", "aspectRatio"],
          "type" => "object"
        }
      },
      "description" => "An assortment of media embedded in a Bluesky record (eg, a post).",
      "id" => "app.bsky.embed.gallery",
      "lexicon" => 1
    },
    %{
      "defs" => %{
        "main" => %{
          "description" =>
            "Resolve one or more AT-URIs into the data needed to render an enhanced external embed. Returns `associatedRefs` (strongRefs to embed into a post's external.associatedRefs), the raw `associatedRecords`, and a hydrated `view`. The response is empty (`{}`) when no records were resolvable, or when validation determined the resolved records don't actually back the requested URL; clients should fall back to their own link-card rendering in that case and skip writing strongRefs to the post.",
          "output" => %{
            "encoding" => "application/json",
            "schema" => %{
              "properties" => %{
                "associatedRecords" => %{
                  "items" => %{
                    "description" =>
                      "The raw record data of the Atmosphere records that backed this view. This is returned for convenience, to avoid the need for the client to separately fetch the record data for the associatedRefs. Example: the site.standard.document and site.standard.publication records that backed this view.",
                    "type" => "unknown"
                  },
                  "type" => "array"
                },
                "associatedRefs" => %{
                  "description" =>
                    "StrongRefs (URI+CID) of the Atmosphere records that backed this view, suitable for embedding into a post's external.associatedRefs.",
                  "items" => %{
                    "ref" => "com.atproto.repo.strongRef",
                    "type" => "ref"
                  },
                  "type" => "array"
                },
                "view" => %{
                  "description" =>
                    "Hydrated view of the embed. Present only when the resolved records back the requested URL and supply enough information to populate the required `viewExternal` fields. Omitted alongside the rest of the response when no records resolved or validation failed.",
                  "ref" => "app.bsky.embed.external#view",
                  "type" => "ref"
                }
              },
              "type" => "object"
            }
          },
          "parameters" => %{
            "properties" => %{
              "uris" => %{
                "description" =>
                  "AT-URIs of any Atmosphere records that can be resolved and used to construct #externalView views. Example: a site.standard.document and optionally its associated site.standard.publication.",
                "items" => %{"format" => "at-uri", "type" => "string"},
                "maxLength" => 4,
                "type" => "array"
              },
              "url" => %{
                "description" =>
                  "The canonical web URL the embed represents (typically the URL the user pasted into the composer). Used as the returned view's `uri`. May be used for validation in the future.",
                "format" => "uri",
                "type" => "string"
              }
            },
            "required" => ["url", "uris"],
            "type" => "params"
          },
          "type" => "query"
        }
      },
      "id" => "app.bsky.embed.getEmbedExternalView",
      "lexicon" => 1
    },
    %{
      "defs" => %{
        "image" => %{
          "properties" => %{
            "alt" => %{
              "description" => "Alt text description of the image, for accessibility.",
              "type" => "string"
            },
            "aspectRatio" => %{
              "ref" => "app.bsky.embed.defs#aspectRatio",
              "type" => "ref"
            },
            "image" => %{
              "accept" => ["image/*"],
              "description" => "The raw image file. May be up to 2 MB, formerly limited to 1 MB.",
              "maxSize" => 2_000_000,
              "type" => "blob"
            }
          },
          "required" => ["image", "alt"],
          "type" => "object"
        },
        "main" => %{
          "properties" => %{
            "images" => %{
              "items" => %{"ref" => "#image", "type" => "ref"},
              "maxLength" => 4,
              "type" => "array"
            }
          },
          "required" => ["images"],
          "type" => "object"
        },
        "view" => %{
          "properties" => %{
            "images" => %{
              "items" => %{"ref" => "#viewImage", "type" => "ref"},
              "maxLength" => 4,
              "type" => "array"
            }
          },
          "required" => ["images"],
          "type" => "object"
        },
        "viewImage" => %{
          "properties" => %{
            "alt" => %{
              "description" => "Alt text description of the image, for accessibility.",
              "type" => "string"
            },
            "aspectRatio" => %{
              "ref" => "app.bsky.embed.defs#aspectRatio",
              "type" => "ref"
            },
            "fullsize" => %{
              "description" =>
                "Fully-qualified URL where a large version of the image can be fetched. May or may not be the exact original blob. For example, CDN location provided by the App View.",
              "format" => "uri",
              "type" => "string"
            },
            "thumb" => %{
              "description" =>
                "Fully-qualified URL where a thumbnail of the image can be fetched. For example, CDN location provided by the App View.",
              "format" => "uri",
              "type" => "string"
            }
          },
          "required" => ["thumb", "fullsize", "alt"],
          "type" => "object"
        }
      },
      "description" => "A set of images embedded in a Bluesky record (eg, a post).",
      "id" => "app.bsky.embed.images",
      "lexicon" => 1
    },
    %{
      "defs" => %{
        "main" => %{
          "properties" => %{
            "record" => %{"ref" => "com.atproto.repo.strongRef", "type" => "ref"}
          },
          "required" => ["record"],
          "type" => "object"
        },
        "view" => %{
          "properties" => %{
            "record" => %{
              "refs" => [
                "#viewRecord",
                "#viewNotFound",
                "#viewBlocked",
                "#viewDetached",
                "app.bsky.feed.defs#generatorView",
                "app.bsky.graph.defs#listView",
                "app.bsky.labeler.defs#labelerView",
                "app.bsky.graph.defs#starterPackViewBasic"
              ],
              "type" => "union"
            }
          },
          "required" => ["record"],
          "type" => "object"
        },
        "viewBlocked" => %{
          "properties" => %{
            "author" => %{
              "ref" => "app.bsky.feed.defs#blockedAuthor",
              "type" => "ref"
            },
            "blocked" => %{"const" => true, "type" => "boolean"},
            "uri" => %{"format" => "at-uri", "type" => "string"}
          },
          "required" => ["uri", "blocked", "author"],
          "type" => "object"
        },
        "viewDetached" => %{
          "properties" => %{
            "detached" => %{"const" => true, "type" => "boolean"},
            "uri" => %{"format" => "at-uri", "type" => "string"}
          },
          "required" => ["uri", "detached"],
          "type" => "object"
        },
        "viewNotFound" => %{
          "properties" => %{
            "notFound" => %{"const" => true, "type" => "boolean"},
            "uri" => %{"format" => "at-uri", "type" => "string"}
          },
          "required" => ["uri", "notFound"],
          "type" => "object"
        },
        "viewRecord" => %{
          "properties" => %{
            "author" => %{
              "ref" => "app.bsky.actor.defs#profileViewBasic",
              "type" => "ref"
            },
            "cid" => %{"format" => "cid", "type" => "string"},
            "embeds" => %{
              "items" => %{
                "refs" => [
                  "app.bsky.embed.images#view",
                  "app.bsky.embed.video#view",
                  "app.bsky.embed.gallery#view",
                  "app.bsky.embed.external#view",
                  "app.bsky.embed.record#view",
                  "app.bsky.embed.recordWithMedia#view"
                ],
                "type" => "union"
              },
              "type" => "array"
            },
            "indexedAt" => %{"format" => "datetime", "type" => "string"},
            "labels" => %{
              "items" => %{
                "ref" => "com.atproto.label.defs#label",
                "type" => "ref"
              },
              "type" => "array"
            },
            "likeCount" => %{"type" => "integer"},
            "quoteCount" => %{"type" => "integer"},
            "replyCount" => %{"type" => "integer"},
            "repostCount" => %{"type" => "integer"},
            "uri" => %{"format" => "at-uri", "type" => "string"},
            "value" => %{
              "description" => "The record data itself.",
              "type" => "unknown"
            }
          },
          "required" => ["uri", "cid", "author", "value", "indexedAt"],
          "type" => "object"
        }
      },
      "description" =>
        "A representation of a record embedded in a Bluesky record (eg, a post). For example, a quote-post, or sharing a feed generator record.",
      "id" => "app.bsky.embed.record",
      "lexicon" => 1
    },
    %{
      "defs" => %{
        "main" => %{
          "properties" => %{
            "media" => %{
              "refs" => [
                "app.bsky.embed.images",
                "app.bsky.embed.video",
                "app.bsky.embed.gallery",
                "app.bsky.embed.external"
              ],
              "type" => "union"
            },
            "record" => %{"ref" => "app.bsky.embed.record", "type" => "ref"}
          },
          "required" => ["record", "media"],
          "type" => "object"
        },
        "view" => %{
          "properties" => %{
            "media" => %{
              "refs" => [
                "app.bsky.embed.images#view",
                "app.bsky.embed.video#view",
                "app.bsky.embed.gallery#view",
                "app.bsky.embed.external#view"
              ],
              "type" => "union"
            },
            "record" => %{"ref" => "app.bsky.embed.record#view", "type" => "ref"}
          },
          "required" => ["record", "media"],
          "type" => "object"
        }
      },
      "description" =>
        "A representation of a record embedded in a Bluesky record (eg, a post), alongside other compatible embeds. For example, a quote post and image, or a quote post and external URL card.",
      "id" => "app.bsky.embed.recordWithMedia",
      "lexicon" => 1
    },
    %{
      "defs" => %{
        "caption" => %{
          "properties" => %{
            "file" => %{
              "accept" => ["text/vtt"],
              "maxSize" => 20000,
              "type" => "blob"
            },
            "lang" => %{"format" => "language", "type" => "string"}
          },
          "required" => ["lang", "file"],
          "type" => "object"
        },
        "main" => %{
          "properties" => %{
            "alt" => %{
              "description" => "Alt text description of the video, for accessibility.",
              "maxGraphemes" => 1000,
              "maxLength" => 10000,
              "type" => "string"
            },
            "aspectRatio" => %{
              "ref" => "app.bsky.embed.defs#aspectRatio",
              "type" => "ref"
            },
            "captions" => %{
              "items" => %{"ref" => "#caption", "type" => "ref"},
              "maxLength" => 20,
              "type" => "array"
            },
            "presentation" => %{
              "description" => "A hint to the client about how to present the video.",
              "knownValues" => ["default", "gif"],
              "type" => "string"
            },
            "video" => %{
              "accept" => ["video/mp4"],
              "description" => "The mp4 video file. May be up to 100mb, formerly limited to 50mb.",
              "maxSize" => 100_000_000,
              "type" => "blob"
            }
          },
          "required" => ["video"],
          "type" => "object"
        },
        "view" => %{
          "properties" => %{
            "alt" => %{
              "maxGraphemes" => 1000,
              "maxLength" => 10000,
              "type" => "string"
            },
            "aspectRatio" => %{
              "ref" => "app.bsky.embed.defs#aspectRatio",
              "type" => "ref"
            },
            "cid" => %{"format" => "cid", "type" => "string"},
            "playlist" => %{"format" => "uri", "type" => "string"},
            "presentation" => %{
              "description" => "A hint to the client about how to present the video.",
              "knownValues" => ["default", "gif"],
              "type" => "string"
            },
            "thumbnail" => %{"format" => "uri", "type" => "string"}
          },
          "required" => ["cid", "playlist"],
          "type" => "object"
        }
      },
      "description" => "A video embedded in a Bluesky record (eg, a post).",
      "id" => "app.bsky.embed.video",
      "lexicon" => 1
    },
    %{
      "defs" => %{
        "blockedAuthor" => %{
          "properties" => %{
            "did" => %{"format" => "did", "type" => "string"},
            "viewer" => %{
              "ref" => "app.bsky.actor.defs#viewerState",
              "type" => "ref"
            }
          },
          "required" => ["did"],
          "type" => "object"
        },
        "blockedPost" => %{
          "properties" => %{
            "author" => %{"ref" => "#blockedAuthor", "type" => "ref"},
            "blocked" => %{"const" => true, "type" => "boolean"},
            "uri" => %{"format" => "at-uri", "type" => "string"}
          },
          "required" => ["uri", "blocked", "author"],
          "type" => "object"
        },
        "clickthroughAuthor" => %{
          "description" => "User clicked through to the author of the feed item",
          "type" => "token"
        },
        "clickthroughEmbed" => %{
          "description" => "User clicked through to the embedded content of the feed item",
          "type" => "token"
        },
        "clickthroughItem" => %{
          "description" => "User clicked through to the feed item",
          "type" => "token"
        },
        "clickthroughReposter" => %{
          "description" => "User clicked through to the reposter of the feed item",
          "type" => "token"
        },
        "contentModeUnspecified" => %{
          "description" => "Declares the feed generator returns any types of posts.",
          "type" => "token"
        },
        "contentModeVideo" => %{
          "description" => "Declares the feed generator returns posts containing app.bsky.embed.video embeds.",
          "type" => "token"
        },
        "feedViewPost" => %{
          "properties" => %{
            "feedContext" => %{
              "description" => "Context provided by feed generator that may be passed back alongside interactions.",
              "maxLength" => 2000,
              "type" => "string"
            },
            "post" => %{"ref" => "#postView", "type" => "ref"},
            "reason" => %{
              "refs" => ["#reasonRepost", "#reasonPin"],
              "type" => "union"
            },
            "reply" => %{"ref" => "#replyRef", "type" => "ref"},
            "reqId" => %{
              "description" => "Unique identifier per request that may be passed back alongside interactions.",
              "maxLength" => 100,
              "type" => "string"
            }
          },
          "required" => ["post"],
          "type" => "object"
        },
        "generatorView" => %{
          "properties" => %{
            "acceptsInteractions" => %{"type" => "boolean"},
            "avatar" => %{"format" => "uri", "type" => "string"},
            "cid" => %{"format" => "cid", "type" => "string"},
            "contentMode" => %{
              "knownValues" => ["app.bsky.feed.defs#contentModeUnspecified", "app.bsky.feed.defs#contentModeVideo"],
              "type" => "string"
            },
            "creator" => %{
              "ref" => "app.bsky.actor.defs#profileView",
              "type" => "ref"
            },
            "description" => %{
              "maxGraphemes" => 300,
              "maxLength" => 3000,
              "type" => "string"
            },
            "descriptionFacets" => %{
              "items" => %{"ref" => "app.bsky.richtext.facet", "type" => "ref"},
              "type" => "array"
            },
            "did" => %{"format" => "did", "type" => "string"},
            "displayName" => %{"type" => "string"},
            "indexedAt" => %{"format" => "datetime", "type" => "string"},
            "labels" => %{
              "items" => %{
                "ref" => "com.atproto.label.defs#label",
                "type" => "ref"
              },
              "type" => "array"
            },
            "likeCount" => %{"minimum" => 0, "type" => "integer"},
            "uri" => %{"format" => "at-uri", "type" => "string"},
            "viewer" => %{"ref" => "#generatorViewerState", "type" => "ref"}
          },
          "required" => ["uri", "cid", "did", "creator", "displayName", "indexedAt"],
          "type" => "object"
        },
        "generatorViewerState" => %{
          "properties" => %{"like" => %{"format" => "at-uri", "type" => "string"}},
          "type" => "object"
        },
        "interaction" => %{
          "properties" => %{
            "event" => %{
              "knownValues" => [
                "app.bsky.feed.defs#requestLess",
                "app.bsky.feed.defs#requestMore",
                "app.bsky.feed.defs#clickthroughItem",
                "app.bsky.feed.defs#clickthroughAuthor",
                "app.bsky.feed.defs#clickthroughReposter",
                "app.bsky.feed.defs#clickthroughEmbed",
                "app.bsky.feed.defs#interactionSeen",
                "app.bsky.feed.defs#interactionLike",
                "app.bsky.feed.defs#interactionRepost",
                "app.bsky.feed.defs#interactionReply",
                "app.bsky.feed.defs#interactionQuote",
                "app.bsky.feed.defs#interactionShare"
              ],
              "type" => "string"
            },
            "feedContext" => %{
              "description" =>
                "Context on a feed item that was originally supplied by the feed generator on getFeedSkeleton.",
              "maxLength" => 2000,
              "type" => "string"
            },
            "item" => %{"format" => "at-uri", "type" => "string"},
            "reqId" => %{
              "description" => "Unique identifier per request that may be passed back alongside interactions.",
              "maxLength" => 100,
              "type" => "string"
            }
          },
          "type" => "object"
        },
        "interactionLike" => %{
          "description" => "User liked the feed item",
          "type" => "token"
        },
        "interactionQuote" => %{
          "description" => "User quoted the feed item",
          "type" => "token"
        },
        "interactionReply" => %{
          "description" => "User replied to the feed item",
          "type" => "token"
        },
        "interactionRepost" => %{
          "description" => "User reposted the feed item",
          "type" => "token"
        },
        "interactionSeen" => %{
          "description" => "Feed item was seen by user",
          "type" => "token"
        },
        "interactionShare" => %{
          "description" => "User shared the feed item",
          "type" => "token"
        },
        "notFoundPost" => %{
          "properties" => %{
            "notFound" => %{"const" => true, "type" => "boolean"},
            "uri" => %{"format" => "at-uri", "type" => "string"}
          },
          "required" => ["uri", "notFound"],
          "type" => "object"
        },
        "postView" => %{
          "properties" => %{
            "author" => %{
              "ref" => "app.bsky.actor.defs#profileViewBasic",
              "type" => "ref"
            },
            "bookmarkCount" => %{"type" => "integer"},
            "cid" => %{"format" => "cid", "type" => "string"},
            "debug" => %{
              "description" => "Debug information for internal development",
              "type" => "unknown"
            },
            "embed" => %{
              "refs" => [
                "app.bsky.embed.images#view",
                "app.bsky.embed.video#view",
                "app.bsky.embed.gallery#view",
                "app.bsky.embed.external#view",
                "app.bsky.embed.record#view",
                "app.bsky.embed.recordWithMedia#view"
              ],
              "type" => "union"
            },
            "indexedAt" => %{"format" => "datetime", "type" => "string"},
            "labels" => %{
              "items" => %{
                "ref" => "com.atproto.label.defs#label",
                "type" => "ref"
              },
              "type" => "array"
            },
            "likeCount" => %{"type" => "integer"},
            "quoteCount" => %{"type" => "integer"},
            "record" => %{"type" => "unknown"},
            "replyCount" => %{"type" => "integer"},
            "repostCount" => %{"type" => "integer"},
            "threadgate" => %{"ref" => "#threadgateView", "type" => "ref"},
            "uri" => %{"format" => "at-uri", "type" => "string"},
            "viewer" => %{"ref" => "#viewerState", "type" => "ref"}
          },
          "required" => ["uri", "cid", "author", "record", "indexedAt"],
          "type" => "object"
        },
        "reasonPin" => %{"properties" => %{}, "type" => "object"},
        "reasonRepost" => %{
          "properties" => %{
            "by" => %{
              "ref" => "app.bsky.actor.defs#profileViewBasic",
              "type" => "ref"
            },
            "cid" => %{"format" => "cid", "type" => "string"},
            "indexedAt" => %{"format" => "datetime", "type" => "string"},
            "uri" => %{"format" => "at-uri", "type" => "string"}
          },
          "required" => ["by", "indexedAt"],
          "type" => "object"
        },
        "replyRef" => %{
          "properties" => %{
            "grandparentAuthor" => %{
              "description" => "When parent is a reply to another post, this is the author of that post.",
              "ref" => "app.bsky.actor.defs#profileViewBasic",
              "type" => "ref"
            },
            "parent" => %{
              "refs" => ["#postView", "#notFoundPost", "#blockedPost"],
              "type" => "union"
            },
            "root" => %{
              "refs" => ["#postView", "#notFoundPost", "#blockedPost"],
              "type" => "union"
            }
          },
          "required" => ["root", "parent"],
          "type" => "object"
        },
        "requestLess" => %{
          "description" => "Request that less content like the given feed item be shown in the feed",
          "type" => "token"
        },
        "requestMore" => %{
          "description" => "Request that more content like the given feed item be shown in the feed",
          "type" => "token"
        },
        "skeletonFeedPost" => %{
          "properties" => %{
            "feedContext" => %{
              "description" =>
                "Context that will be passed through to client and may be passed to feed generator back alongside interactions.",
              "maxLength" => 2000,
              "type" => "string"
            },
            "post" => %{"format" => "at-uri", "type" => "string"},
            "reason" => %{
              "refs" => ["#skeletonReasonRepost", "#skeletonReasonPin"],
              "type" => "union"
            }
          },
          "required" => ["post"],
          "type" => "object"
        },
        "skeletonReasonPin" => %{"properties" => %{}, "type" => "object"},
        "skeletonReasonRepost" => %{
          "properties" => %{
            "repost" => %{"format" => "at-uri", "type" => "string"}
          },
          "required" => ["repost"],
          "type" => "object"
        },
        "threadContext" => %{
          "description" => "Metadata about this post within the context of the thread it is in.",
          "properties" => %{
            "rootAuthorLike" => %{"format" => "at-uri", "type" => "string"}
          },
          "type" => "object"
        },
        "threadViewPost" => %{
          "properties" => %{
            "parent" => %{
              "refs" => ["#threadViewPost", "#notFoundPost", "#blockedPost"],
              "type" => "union"
            },
            "post" => %{"ref" => "#postView", "type" => "ref"},
            "replies" => %{
              "items" => %{
                "refs" => ["#threadViewPost", "#notFoundPost", "#blockedPost"],
                "type" => "union"
              },
              "type" => "array"
            },
            "threadContext" => %{"ref" => "#threadContext", "type" => "ref"}
          },
          "required" => ["post"],
          "type" => "object"
        },
        "threadgateView" => %{
          "properties" => %{
            "cid" => %{"format" => "cid", "type" => "string"},
            "lists" => %{
              "items" => %{
                "ref" => "app.bsky.graph.defs#listViewBasic",
                "type" => "ref"
              },
              "type" => "array"
            },
            "record" => %{"type" => "unknown"},
            "uri" => %{"format" => "at-uri", "type" => "string"}
          },
          "type" => "object"
        },
        "viewerState" => %{
          "description" =>
            "Metadata about the requesting account's relationship with the subject content. Only has meaningful content for authed requests.",
          "properties" => %{
            "bookmarked" => %{"type" => "boolean"},
            "embeddingDisabled" => %{"type" => "boolean"},
            "like" => %{"format" => "at-uri", "type" => "string"},
            "pinned" => %{"type" => "boolean"},
            "replyDisabled" => %{"type" => "boolean"},
            "repost" => %{"format" => "at-uri", "type" => "string"},
            "threadMuted" => %{"type" => "boolean"}
          },
          "type" => "object"
        }
      },
      "id" => "app.bsky.feed.defs",
      "lexicon" => 1
    },
    %{
      "defs" => %{
        "feed" => %{
          "properties" => %{"uri" => %{"format" => "at-uri", "type" => "string"}},
          "required" => ["uri"],
          "type" => "object"
        },
        "links" => %{
          "properties" => %{
            "privacyPolicy" => %{"type" => "string"},
            "termsOfService" => %{"type" => "string"}
          },
          "type" => "object"
        },
        "main" => %{
          "description" =>
            "Get information about a feed generator, including policies and offered feed URIs. Does not require auth; implemented by Feed Generator services (not App View).",
          "output" => %{
            "encoding" => "application/json",
            "schema" => %{
              "properties" => %{
                "did" => %{"format" => "did", "type" => "string"},
                "feeds" => %{
                  "items" => %{"ref" => "#feed", "type" => "ref"},
                  "type" => "array"
                },
                "links" => %{"ref" => "#links", "type" => "ref"}
              },
              "required" => ["did", "feeds"],
              "type" => "object"
            }
          },
          "type" => "query"
        }
      },
      "id" => "app.bsky.feed.describeFeedGenerator",
      "lexicon" => 1
    },
    %{
      "defs" => %{
        "main" => %{
          "description" =>
            "Record declaring of the existence of a feed generator, and containing metadata about it. The record can exist in any repository.",
          "key" => "any",
          "record" => %{
            "properties" => %{
              "acceptsInteractions" => %{
                "description" =>
                  "Declaration that a feed accepts feedback interactions from a client through app.bsky.feed.sendInteractions",
                "type" => "boolean"
              },
              "avatar" => %{
                "accept" => ["image/png", "image/jpeg"],
                "maxSize" => 1_000_000,
                "type" => "blob"
              },
              "contentMode" => %{
                "knownValues" => ["app.bsky.feed.defs#contentModeUnspecified", "app.bsky.feed.defs#contentModeVideo"],
                "type" => "string"
              },
              "createdAt" => %{"format" => "datetime", "type" => "string"},
              "description" => %{
                "maxGraphemes" => 300,
                "maxLength" => 3000,
                "type" => "string"
              },
              "descriptionFacets" => %{
                "items" => %{"ref" => "app.bsky.richtext.facet", "type" => "ref"},
                "type" => "array"
              },
              "did" => %{"format" => "did", "type" => "string"},
              "displayName" => %{
                "maxGraphemes" => 24,
                "maxLength" => 240,
                "type" => "string"
              },
              "labels" => %{
                "description" => "Self-label values",
                "refs" => ["com.atproto.label.defs#selfLabels"],
                "type" => "union"
              }
            },
            "required" => ["did", "displayName", "createdAt"],
            "type" => "object"
          },
          "type" => "record"
        }
      },
      "id" => "app.bsky.feed.generator",
      "lexicon" => 1
    },
    %{
      "defs" => %{
        "main" => %{
          "description" => "Get a list of feeds (feed generator records) created by the actor (in the actor's repo).",
          "output" => %{
            "encoding" => "application/json",
            "schema" => %{
              "properties" => %{
                "cursor" => %{"type" => "string"},
                "feeds" => %{
                  "items" => %{
                    "ref" => "app.bsky.feed.defs#generatorView",
                    "type" => "ref"
                  },
                  "type" => "array"
                }
              },
              "required" => ["feeds"],
              "type" => "object"
            }
          },
          "parameters" => %{
            "properties" => %{
              "actor" => %{"format" => "at-identifier", "type" => "string"},
              "cursor" => %{"type" => "string"},
              "limit" => %{
                "default" => 50,
                "maximum" => 100,
                "minimum" => 1,
                "type" => "integer"
              }
            },
            "required" => ["actor"],
            "type" => "params"
          },
          "type" => "query"
        }
      },
      "id" => "app.bsky.feed.getActorFeeds",
      "lexicon" => 1
    },
    %{
      "defs" => %{
        "main" => %{
          "description" =>
            "Get a list of posts liked by an actor. Requires auth, actor must be the requesting account.",
          "errors" => [%{"name" => "BlockedActor"}, %{"name" => "BlockedByActor"}],
          "output" => %{
            "encoding" => "application/json",
            "schema" => %{
              "properties" => %{
                "cursor" => %{"type" => "string"},
                "feed" => %{
                  "items" => %{
                    "ref" => "app.bsky.feed.defs#feedViewPost",
                    "type" => "ref"
                  },
                  "type" => "array"
                }
              },
              "required" => ["feed"],
              "type" => "object"
            }
          },
          "parameters" => %{
            "properties" => %{
              "actor" => %{"format" => "at-identifier", "type" => "string"},
              "cursor" => %{"type" => "string"},
              "limit" => %{
                "default" => 50,
                "maximum" => 100,
                "minimum" => 1,
                "type" => "integer"
              }
            },
            "required" => ["actor"],
            "type" => "params"
          },
          "type" => "query"
        }
      },
      "id" => "app.bsky.feed.getActorLikes",
      "lexicon" => 1
    },
    %{
      "defs" => %{
        "main" => %{
          "description" =>
            "Get a view of an actor's 'author feed' (post and reposts by the author). Does not require auth.",
          "errors" => [%{"name" => "BlockedActor"}, %{"name" => "BlockedByActor"}],
          "output" => %{
            "encoding" => "application/json",
            "schema" => %{
              "properties" => %{
                "cursor" => %{"type" => "string"},
                "feed" => %{
                  "items" => %{
                    "ref" => "app.bsky.feed.defs#feedViewPost",
                    "type" => "ref"
                  },
                  "type" => "array"
                }
              },
              "required" => ["feed"],
              "type" => "object"
            }
          },
          "parameters" => %{
            "properties" => %{
              "actor" => %{"format" => "at-identifier", "type" => "string"},
              "cursor" => %{"type" => "string"},
              "filter" => %{
                "default" => "posts_with_replies",
                "description" => "Combinations of post/repost types to include in response.",
                "knownValues" => [
                  "posts_with_replies",
                  "posts_no_replies",
                  "posts_with_media",
                  "posts_and_author_threads",
                  "posts_with_video"
                ],
                "type" => "string"
              },
              "includePins" => %{"default" => false, "type" => "boolean"},
              "limit" => %{
                "default" => 50,
                "maximum" => 100,
                "minimum" => 1,
                "type" => "integer"
              }
            },
            "required" => ["actor"],
            "type" => "params"
          },
          "type" => "query"
        }
      },
      "id" => "app.bsky.feed.getAuthorFeed",
      "lexicon" => 1
    },
    %{
      "defs" => %{
        "main" => %{
          "description" => "Get a hydrated feed from an actor's selected feed generator. Implemented by App View.",
          "errors" => [%{"name" => "UnknownFeed"}],
          "output" => %{
            "encoding" => "application/json",
            "schema" => %{
              "properties" => %{
                "cursor" => %{"type" => "string"},
                "feed" => %{
                  "items" => %{
                    "ref" => "app.bsky.feed.defs#feedViewPost",
                    "type" => "ref"
                  },
                  "type" => "array"
                }
              },
              "required" => ["feed"],
              "type" => "object"
            }
          },
          "parameters" => %{
            "properties" => %{
              "cursor" => %{"type" => "string"},
              "feed" => %{"format" => "at-uri", "type" => "string"},
              "limit" => %{
                "default" => 50,
                "maximum" => 100,
                "minimum" => 1,
                "type" => "integer"
              }
            },
            "required" => ["feed"],
            "type" => "params"
          },
          "type" => "query"
        }
      },
      "id" => "app.bsky.feed.getFeed",
      "lexicon" => 1
    },
    %{
      "defs" => %{
        "main" => %{
          "description" => "Get information about a feed generator. Implemented by AppView.",
          "output" => %{
            "encoding" => "application/json",
            "schema" => %{
              "properties" => %{
                "isOnline" => %{
                  "description" =>
                    "Indicates whether the feed generator service has been online recently, or else seems to be inactive.",
                  "type" => "boolean"
                },
                "isValid" => %{
                  "description" =>
                    "Indicates whether the feed generator service is compatible with the record declaration.",
                  "type" => "boolean"
                },
                "view" => %{
                  "ref" => "app.bsky.feed.defs#generatorView",
                  "type" => "ref"
                }
              },
              "required" => ["view", "isOnline", "isValid"],
              "type" => "object"
            }
          },
          "parameters" => %{
            "properties" => %{
              "feed" => %{
                "description" => "AT-URI of the feed generator record.",
                "format" => "at-uri",
                "type" => "string"
              }
            },
            "required" => ["feed"],
            "type" => "params"
          },
          "type" => "query"
        }
      },
      "id" => "app.bsky.feed.getFeedGenerator",
      "lexicon" => 1
    },
    %{
      "defs" => %{
        "main" => %{
          "description" => "Get information about a list of feed generators.",
          "output" => %{
            "encoding" => "application/json",
            "schema" => %{
              "properties" => %{
                "feeds" => %{
                  "items" => %{
                    "ref" => "app.bsky.feed.defs#generatorView",
                    "type" => "ref"
                  },
                  "type" => "array"
                }
              },
              "required" => ["feeds"],
              "type" => "object"
            }
          },
          "parameters" => %{
            "properties" => %{
              "feeds" => %{
                "items" => %{"format" => "at-uri", "type" => "string"},
                "type" => "array"
              }
            },
            "required" => ["feeds"],
            "type" => "params"
          },
          "type" => "query"
        }
      },
      "id" => "app.bsky.feed.getFeedGenerators",
      "lexicon" => 1
    },
    %{
      "defs" => %{
        "main" => %{
          "description" =>
            "Get a skeleton of a feed provided by a feed generator. Auth is optional, depending on provider requirements, and provides the DID of the requester. Implemented by Feed Generator Service.",
          "errors" => [%{"name" => "UnknownFeed"}],
          "output" => %{
            "encoding" => "application/json",
            "schema" => %{
              "properties" => %{
                "cursor" => %{"type" => "string"},
                "feed" => %{
                  "items" => %{
                    "ref" => "app.bsky.feed.defs#skeletonFeedPost",
                    "type" => "ref"
                  },
                  "type" => "array"
                },
                "reqId" => %{
                  "description" => "Unique identifier per request that may be passed back alongside interactions.",
                  "maxLength" => 100,
                  "type" => "string"
                }
              },
              "required" => ["feed"],
              "type" => "object"
            }
          },
          "parameters" => %{
            "properties" => %{
              "cursor" => %{"type" => "string"},
              "feed" => %{
                "description" => "Reference to feed generator record describing the specific feed being requested.",
                "format" => "at-uri",
                "type" => "string"
              },
              "limit" => %{
                "default" => 50,
                "maximum" => 100,
                "minimum" => 1,
                "type" => "integer"
              }
            },
            "required" => ["feed"],
            "type" => "params"
          },
          "type" => "query"
        }
      },
      "id" => "app.bsky.feed.getFeedSkeleton",
      "lexicon" => 1
    },
    %{
      "defs" => %{
        "like" => %{
          "properties" => %{
            "actor" => %{
              "ref" => "app.bsky.actor.defs#profileView",
              "type" => "ref"
            },
            "createdAt" => %{"format" => "datetime", "type" => "string"},
            "indexedAt" => %{"format" => "datetime", "type" => "string"}
          },
          "required" => ["indexedAt", "createdAt", "actor"],
          "type" => "object"
        },
        "main" => %{
          "description" => "Get like records which reference a subject (by AT-URI and CID).",
          "output" => %{
            "encoding" => "application/json",
            "schema" => %{
              "properties" => %{
                "cid" => %{"format" => "cid", "type" => "string"},
                "cursor" => %{"type" => "string"},
                "likes" => %{
                  "items" => %{"ref" => "#like", "type" => "ref"},
                  "type" => "array"
                },
                "uri" => %{"format" => "at-uri", "type" => "string"}
              },
              "required" => ["uri", "likes"],
              "type" => "object"
            }
          },
          "parameters" => %{
            "properties" => %{
              "cid" => %{
                "description" => "CID of the subject record (aka, specific version of record), to filter likes.",
                "format" => "cid",
                "type" => "string"
              },
              "cursor" => %{"type" => "string"},
              "limit" => %{
                "default" => 50,
                "maximum" => 100,
                "minimum" => 1,
                "type" => "integer"
              },
              "uri" => %{
                "description" => "AT-URI of the subject (eg, a post record).",
                "format" => "at-uri",
                "type" => "string"
              }
            },
            "required" => ["uri"],
            "type" => "params"
          },
          "type" => "query"
        }
      },
      "id" => "app.bsky.feed.getLikes",
      "lexicon" => 1
    },
    %{
      "defs" => %{
        "main" => %{
          "description" =>
            "Get a feed of recent posts from a list (posts and reposts from any actors on the list). Does not require auth.",
          "errors" => [%{"name" => "UnknownList"}],
          "output" => %{
            "encoding" => "application/json",
            "schema" => %{
              "properties" => %{
                "cursor" => %{"type" => "string"},
                "feed" => %{
                  "items" => %{
                    "ref" => "app.bsky.feed.defs#feedViewPost",
                    "type" => "ref"
                  },
                  "type" => "array"
                }
              },
              "required" => ["feed"],
              "type" => "object"
            }
          },
          "parameters" => %{
            "properties" => %{
              "cursor" => %{"type" => "string"},
              "limit" => %{
                "default" => 50,
                "maximum" => 100,
                "minimum" => 1,
                "type" => "integer"
              },
              "list" => %{
                "description" => "Reference (AT-URI) to the list record.",
                "format" => "at-uri",
                "type" => "string"
              }
            },
            "required" => ["list"],
            "type" => "params"
          },
          "type" => "query"
        }
      },
      "id" => "app.bsky.feed.getListFeed",
      "lexicon" => 1
    },
    %{
      "defs" => %{
        "main" => %{
          "description" =>
            "Get posts in a thread. Does not require auth, but additional metadata and filtering will be applied for authed requests.",
          "errors" => [%{"name" => "NotFound"}],
          "output" => %{
            "encoding" => "application/json",
            "schema" => %{
              "properties" => %{
                "thread" => %{
                  "refs" => [
                    "app.bsky.feed.defs#threadViewPost",
                    "app.bsky.feed.defs#notFoundPost",
                    "app.bsky.feed.defs#blockedPost"
                  ],
                  "type" => "union"
                },
                "threadgate" => %{
                  "ref" => "app.bsky.feed.defs#threadgateView",
                  "type" => "ref"
                }
              },
              "required" => ["thread"],
              "type" => "object"
            }
          },
          "parameters" => %{
            "properties" => %{
              "depth" => %{
                "default" => 6,
                "description" => "How many levels of reply depth should be included in response.",
                "maximum" => 1000,
                "minimum" => 0,
                "type" => "integer"
              },
              "parentHeight" => %{
                "default" => 80,
                "description" => "How many levels of parent (and grandparent, etc) post to include.",
                "maximum" => 1000,
                "minimum" => 0,
                "type" => "integer"
              },
              "uri" => %{
                "description" => "Reference (AT-URI) to post record.",
                "format" => "at-uri",
                "type" => "string"
              }
            },
            "required" => ["uri"],
            "type" => "params"
          },
          "type" => "query"
        }
      },
      "id" => "app.bsky.feed.getPostThread",
      "lexicon" => 1
    },
    %{
      "defs" => %{
        "main" => %{
          "description" =>
            "Gets post views for a specified list of posts (by AT-URI). This is sometimes referred to as 'hydrating' a 'feed skeleton'.",
          "output" => %{
            "encoding" => "application/json",
            "schema" => %{
              "properties" => %{
                "posts" => %{
                  "items" => %{
                    "ref" => "app.bsky.feed.defs#postView",
                    "type" => "ref"
                  },
                  "type" => "array"
                }
              },
              "required" => ["posts"],
              "type" => "object"
            }
          },
          "parameters" => %{
            "properties" => %{
              "uris" => %{
                "description" => "List of post AT-URIs to return hydrated views for.",
                "items" => %{"format" => "at-uri", "type" => "string"},
                "maxLength" => 25,
                "type" => "array"
              }
            },
            "required" => ["uris"],
            "type" => "params"
          },
          "type" => "query"
        }
      },
      "id" => "app.bsky.feed.getPosts",
      "lexicon" => 1
    },
    %{
      "defs" => %{
        "main" => %{
          "description" => "Get a list of quotes for a given post.",
          "output" => %{
            "encoding" => "application/json",
            "schema" => %{
              "properties" => %{
                "cid" => %{"format" => "cid", "type" => "string"},
                "cursor" => %{"type" => "string"},
                "posts" => %{
                  "items" => %{
                    "ref" => "app.bsky.feed.defs#postView",
                    "type" => "ref"
                  },
                  "type" => "array"
                },
                "uri" => %{"format" => "at-uri", "type" => "string"}
              },
              "required" => ["uri", "posts"],
              "type" => "object"
            }
          },
          "parameters" => %{
            "properties" => %{
              "cid" => %{
                "description" => "If supplied, filters to quotes of specific version (by CID) of the post record.",
                "format" => "cid",
                "type" => "string"
              },
              "cursor" => %{"type" => "string"},
              "limit" => %{
                "default" => 50,
                "maximum" => 100,
                "minimum" => 1,
                "type" => "integer"
              },
              "uri" => %{
                "description" => "Reference (AT-URI) of post record",
                "format" => "at-uri",
                "type" => "string"
              }
            },
            "required" => ["uri"],
            "type" => "params"
          },
          "type" => "query"
        }
      },
      "id" => "app.bsky.feed.getQuotes",
      "lexicon" => 1
    },
    %{
      "defs" => %{
        "main" => %{
          "description" => "Get a list of reposts for a given post.",
          "output" => %{
            "encoding" => "application/json",
            "schema" => %{
              "properties" => %{
                "cid" => %{"format" => "cid", "type" => "string"},
                "cursor" => %{"type" => "string"},
                "repostedBy" => %{
                  "items" => %{
                    "ref" => "app.bsky.actor.defs#profileView",
                    "type" => "ref"
                  },
                  "type" => "array"
                },
                "uri" => %{"format" => "at-uri", "type" => "string"}
              },
              "required" => ["uri", "repostedBy"],
              "type" => "object"
            }
          },
          "parameters" => %{
            "properties" => %{
              "cid" => %{
                "description" => "If supplied, filters to reposts of specific version (by CID) of the post record.",
                "format" => "cid",
                "type" => "string"
              },
              "cursor" => %{"type" => "string"},
              "limit" => %{
                "default" => 50,
                "maximum" => 100,
                "minimum" => 1,
                "type" => "integer"
              },
              "uri" => %{
                "description" => "Reference (AT-URI) of post record",
                "format" => "at-uri",
                "type" => "string"
              }
            },
            "required" => ["uri"],
            "type" => "params"
          },
          "type" => "query"
        }
      },
      "id" => "app.bsky.feed.getRepostedBy",
      "lexicon" => 1
    },
    %{
      "defs" => %{
        "main" => %{
          "description" => "Get a list of suggested feeds (feed generators) for the requesting account.",
          "output" => %{
            "encoding" => "application/json",
            "schema" => %{
              "properties" => %{
                "cursor" => %{"type" => "string"},
                "feeds" => %{
                  "items" => %{
                    "ref" => "app.bsky.feed.defs#generatorView",
                    "type" => "ref"
                  },
                  "type" => "array"
                }
              },
              "required" => ["feeds"],
              "type" => "object"
            }
          },
          "parameters" => %{
            "properties" => %{
              "cursor" => %{"type" => "string"},
              "limit" => %{
                "default" => 50,
                "maximum" => 100,
                "minimum" => 1,
                "type" => "integer"
              }
            },
            "type" => "params"
          },
          "type" => "query"
        }
      },
      "id" => "app.bsky.feed.getSuggestedFeeds",
      "lexicon" => 1
    },
    %{
      "defs" => %{
        "main" => %{
          "description" =>
            "Get a view of the requesting account's home timeline. This is expected to be some form of reverse-chronological feed.",
          "output" => %{
            "encoding" => "application/json",
            "schema" => %{
              "properties" => %{
                "cursor" => %{"type" => "string"},
                "feed" => %{
                  "items" => %{
                    "ref" => "app.bsky.feed.defs#feedViewPost",
                    "type" => "ref"
                  },
                  "type" => "array"
                }
              },
              "required" => ["feed"],
              "type" => "object"
            }
          },
          "parameters" => %{
            "properties" => %{
              "algorithm" => %{
                "description" =>
                  "Variant 'algorithm' for timeline. Implementation-specific. NOTE: most feed flexibility has been moved to feed generator mechanism.",
                "type" => "string"
              },
              "cursor" => %{"type" => "string"},
              "limit" => %{
                "default" => 50,
                "maximum" => 100,
                "minimum" => 1,
                "type" => "integer"
              }
            },
            "type" => "params"
          },
          "type" => "query"
        }
      },
      "id" => "app.bsky.feed.getTimeline",
      "lexicon" => 1
    },
    %{
      "defs" => %{
        "main" => %{
          "description" => "Record declaring a 'like' of a piece of subject content.",
          "key" => "tid",
          "record" => %{
            "properties" => %{
              "createdAt" => %{"format" => "datetime", "type" => "string"},
              "subject" => %{
                "ref" => "com.atproto.repo.strongRef",
                "type" => "ref"
              },
              "via" => %{"ref" => "com.atproto.repo.strongRef", "type" => "ref"}
            },
            "required" => ["subject", "createdAt"],
            "type" => "object"
          },
          "type" => "record"
        }
      },
      "id" => "app.bsky.feed.like",
      "lexicon" => 1
    },
    %{
      "defs" => %{
        "entity" => %{
          "description" => "Deprecated: use facets instead.",
          "properties" => %{
            "index" => %{"ref" => "#textSlice", "type" => "ref"},
            "type" => %{
              "description" => "Expected values are 'mention' and 'link'.",
              "type" => "string"
            },
            "value" => %{"type" => "string"}
          },
          "required" => ["index", "type", "value"],
          "type" => "object"
        },
        "main" => %{
          "description" => "Record containing a Bluesky post.",
          "key" => "tid",
          "record" => %{
            "properties" => %{
              "createdAt" => %{
                "description" => "Client-declared timestamp when this post was originally created.",
                "format" => "datetime",
                "type" => "string"
              },
              "embed" => %{
                "refs" => [
                  "app.bsky.embed.images",
                  "app.bsky.embed.video",
                  "app.bsky.embed.gallery",
                  "app.bsky.embed.external",
                  "app.bsky.embed.record",
                  "app.bsky.embed.recordWithMedia"
                ],
                "type" => "union"
              },
              "entities" => %{
                "description" => "DEPRECATED: replaced by app.bsky.richtext.facet.",
                "items" => %{"ref" => "#entity", "type" => "ref"},
                "type" => "array"
              },
              "facets" => %{
                "description" => "Annotations of text (mentions, URLs, hashtags, etc)",
                "items" => %{"ref" => "app.bsky.richtext.facet", "type" => "ref"},
                "type" => "array"
              },
              "labels" => %{
                "description" => "Self-label values for this post. Effectively content warnings.",
                "refs" => ["com.atproto.label.defs#selfLabels"],
                "type" => "union"
              },
              "langs" => %{
                "description" => "Indicates human language of post primary text content.",
                "items" => %{"format" => "language", "type" => "string"},
                "maxLength" => 3,
                "type" => "array"
              },
              "reply" => %{"ref" => "#replyRef", "type" => "ref"},
              "tags" => %{
                "description" => "Additional hashtags, in addition to any included in post text and facets.",
                "items" => %{
                  "maxGraphemes" => 64,
                  "maxLength" => 640,
                  "type" => "string"
                },
                "maxLength" => 8,
                "type" => "array"
              },
              "text" => %{
                "description" => "The primary post content. May be an empty string, if there are embeds.",
                "maxGraphemes" => 300,
                "maxLength" => 3000,
                "type" => "string"
              }
            },
            "required" => ["text", "createdAt"],
            "type" => "object"
          },
          "type" => "record"
        },
        "replyRef" => %{
          "properties" => %{
            "parent" => %{"ref" => "com.atproto.repo.strongRef", "type" => "ref"},
            "root" => %{"ref" => "com.atproto.repo.strongRef", "type" => "ref"}
          },
          "required" => ["root", "parent"],
          "type" => "object"
        },
        "textSlice" => %{
          "description" =>
            "Deprecated. Use app.bsky.richtext instead -- A text segment. Start is inclusive, end is exclusive. Indices are for utf16-encoded strings.",
          "properties" => %{
            "end" => %{"minimum" => 0, "type" => "integer"},
            "start" => %{"minimum" => 0, "type" => "integer"}
          },
          "required" => ["start", "end"],
          "type" => "object"
        }
      },
      "id" => "app.bsky.feed.post",
      "lexicon" => 1
    },
    %{
      "defs" => %{
        "disableRule" => %{
          "description" => "Disables embedding of this post.",
          "properties" => %{},
          "type" => "object"
        },
        "main" => %{
          "description" =>
            "Record defining interaction rules for a post. The record key (rkey) of the postgate record must match the record key of the post, and that record must be in the same repository.",
          "key" => "tid",
          "record" => %{
            "properties" => %{
              "createdAt" => %{"format" => "datetime", "type" => "string"},
              "detachedEmbeddingUris" => %{
                "description" => "List of AT-URIs embedding this post that the author has detached from.",
                "items" => %{"format" => "at-uri", "type" => "string"},
                "maxLength" => 50,
                "type" => "array"
              },
              "embeddingRules" => %{
                "description" =>
                  "List of rules defining who can embed this post. If value is an empty array or is undefined, no particular rules apply and anyone can embed.",
                "items" => %{"refs" => ["#disableRule"], "type" => "union"},
                "maxLength" => 5,
                "type" => "array"
              },
              "post" => %{
                "description" => "Reference (AT-URI) to the post record.",
                "format" => "at-uri",
                "type" => "string"
              }
            },
            "required" => ["post", "createdAt"],
            "type" => "object"
          },
          "type" => "record"
        }
      },
      "id" => "app.bsky.feed.postgate",
      "lexicon" => 1
    },
    %{
      "defs" => %{
        "main" => %{
          "description" => "Record representing a 'repost' of an existing Bluesky post.",
          "key" => "tid",
          "record" => %{
            "properties" => %{
              "createdAt" => %{"format" => "datetime", "type" => "string"},
              "subject" => %{
                "ref" => "com.atproto.repo.strongRef",
                "type" => "ref"
              },
              "via" => %{"ref" => "com.atproto.repo.strongRef", "type" => "ref"}
            },
            "required" => ["subject", "createdAt"],
            "type" => "object"
          },
          "type" => "record"
        }
      },
      "id" => "app.bsky.feed.repost",
      "lexicon" => 1
    },
    %{
      "defs" => %{
        "main" => %{
          "description" =>
            "Find posts matching search criteria, returning views of those posts. Note that this API endpoint may require authentication (eg, not public) for some service providers and implementations.",
          "errors" => [%{"name" => "BadQueryString"}],
          "output" => %{
            "encoding" => "application/json",
            "schema" => %{
              "properties" => %{
                "cursor" => %{"type" => "string"},
                "hitsTotal" => %{
                  "description" =>
                    "Count of search hits. Optional, may be rounded/truncated, and may not be possible to paginate through all hits.",
                  "type" => "integer"
                },
                "posts" => %{
                  "items" => %{
                    "ref" => "app.bsky.feed.defs#postView",
                    "type" => "ref"
                  },
                  "type" => "array"
                }
              },
              "required" => ["posts"],
              "type" => "object"
            }
          },
          "parameters" => %{
            "properties" => %{
              "author" => %{
                "description" => "Filter to posts by the given account. Handles are resolved to DID before query-time.",
                "format" => "at-identifier",
                "type" => "string"
              },
              "cursor" => %{
                "description" =>
                  "Optional pagination mechanism; may not necessarily allow scrolling through entire result set.",
                "type" => "string"
              },
              "domain" => %{
                "description" =>
                  "Filter to posts with URLs (facet links or embeds) linking to the given domain (hostname). Server may apply hostname normalization.",
                "type" => "string"
              },
              "lang" => %{
                "description" =>
                  "Filter to posts in the given language. Expected to be based on post language field, though server may override language detection.",
                "format" => "language",
                "type" => "string"
              },
              "limit" => %{
                "default" => 25,
                "maximum" => 100,
                "minimum" => 1,
                "type" => "integer"
              },
              "mentions" => %{
                "description" =>
                  "Filter to posts which mention the given account. Handles are resolved to DID before query-time. Only matches rich-text facet mentions.",
                "format" => "at-identifier",
                "type" => "string"
              },
              "q" => %{
                "description" =>
                  "Search query string; syntax, phrase, boolean, and faceting is unspecified, but Lucene query syntax is recommended.",
                "type" => "string"
              },
              "since" => %{
                "description" =>
                  "Filter results for posts after the indicated datetime (inclusive). Expected to use 'sortAt' timestamp, which may not match 'createdAt'. Can be a datetime, or just an ISO date (YYYY-MM-DD).",
                "type" => "string"
              },
              "sort" => %{
                "default" => "latest",
                "description" => "Specifies the ranking order of results.",
                "knownValues" => ["top", "latest"],
                "type" => "string"
              },
              "tag" => %{
                "description" =>
                  "Filter to posts with the given tag (hashtag), based on rich-text facet or tag field. Do not include the hash (#) prefix. Multiple tags can be specified, with 'AND' matching.",
                "items" => %{
                  "maxGraphemes" => 64,
                  "maxLength" => 640,
                  "type" => "string"
                },
                "type" => "array"
              },
              "until" => %{
                "description" =>
                  "Filter results for posts before the indicated datetime (not inclusive). Expected to use 'sortAt' timestamp, which may not match 'createdAt'. Can be a datetime, or just an ISO date (YYY-MM-DD).",
                "type" => "string"
              },
              "url" => %{
                "description" =>
                  "Filter to posts with links (facet links or embeds) pointing to this URL. Server may apply URL normalization or fuzzy matching.",
                "format" => "uri",
                "type" => "string"
              }
            },
            "required" => ["q"],
            "type" => "params"
          },
          "type" => "query"
        }
      },
      "id" => "app.bsky.feed.searchPosts",
      "lexicon" => 1
    },
    %{
      "defs" => %{
        "main" => %{
          "description" =>
            "Send information about interactions with feed items back to the feed generator that served them.",
          "input" => %{
            "encoding" => "application/json",
            "schema" => %{
              "properties" => %{
                "feed" => %{"format" => "at-uri", "type" => "string"},
                "interactions" => %{
                  "items" => %{
                    "ref" => "app.bsky.feed.defs#interaction",
                    "type" => "ref"
                  },
                  "type" => "array"
                }
              },
              "required" => ["interactions"],
              "type" => "object"
            }
          },
          "output" => %{
            "encoding" => "application/json",
            "schema" => %{"properties" => %{}, "type" => "object"}
          },
          "type" => "procedure"
        }
      },
      "id" => "app.bsky.feed.sendInteractions",
      "lexicon" => 1
    },
    %{
      "defs" => %{
        "followerRule" => %{
          "description" => "Allow replies from actors who follow you.",
          "properties" => %{},
          "type" => "object"
        },
        "followingRule" => %{
          "description" => "Allow replies from actors you follow.",
          "properties" => %{},
          "type" => "object"
        },
        "listRule" => %{
          "description" => "Allow replies from actors on a list.",
          "properties" => %{"list" => %{"format" => "at-uri", "type" => "string"}},
          "required" => ["list"],
          "type" => "object"
        },
        "main" => %{
          "description" =>
            "Record defining interaction gating rules for a thread (aka, reply controls). The record key (rkey) of the threadgate record must match the record key of the thread's root post, and that record must be in the same repository.",
          "key" => "tid",
          "record" => %{
            "properties" => %{
              "allow" => %{
                "description" =>
                  "List of rules defining who can reply to this post. If value is an empty array, no one can reply. If value is undefined, anyone can reply.",
                "items" => %{
                  "refs" => ["#mentionRule", "#followerRule", "#followingRule", "#listRule"],
                  "type" => "union"
                },
                "maxLength" => 5,
                "type" => "array"
              },
              "createdAt" => %{"format" => "datetime", "type" => "string"},
              "hiddenReplies" => %{
                "description" => "List of hidden reply URIs.",
                "items" => %{"format" => "at-uri", "type" => "string"},
                "maxLength" => 300,
                "type" => "array"
              },
              "post" => %{
                "description" => "Reference (AT-URI) to the post record.",
                "format" => "at-uri",
                "type" => "string"
              }
            },
            "required" => ["post", "createdAt"],
            "type" => "object"
          },
          "type" => "record"
        },
        "mentionRule" => %{
          "description" => "Allow replies from actors mentioned in your post.",
          "properties" => %{},
          "type" => "object"
        }
      },
      "id" => "app.bsky.feed.threadgate",
      "lexicon" => 1
    },
    %{
      "defs" => %{
        "main" => %{
          "description" =>
            "Record declaring a 'block' relationship against another account. NOTE: blocks are public in Bluesky; see blog posts for details.",
          "key" => "tid",
          "record" => %{
            "properties" => %{
              "createdAt" => %{"format" => "datetime", "type" => "string"},
              "subject" => %{
                "description" => "DID of the account to be blocked.",
                "format" => "did",
                "type" => "string"
              }
            },
            "required" => ["subject", "createdAt"],
            "type" => "object"
          },
          "type" => "record"
        }
      },
      "id" => "app.bsky.graph.block",
      "lexicon" => 1
    },
    %{
      "defs" => %{
        "curatelist" => %{
          "description" => "A list of actors used for curation purposes such as list feeds or interaction gating.",
          "type" => "token"
        },
        "listItemView" => %{
          "properties" => %{
            "subject" => %{
              "ref" => "app.bsky.actor.defs#profileView",
              "type" => "ref"
            },
            "uri" => %{"format" => "at-uri", "type" => "string"}
          },
          "required" => ["uri", "subject"],
          "type" => "object"
        },
        "listPurpose" => %{
          "knownValues" => [
            "app.bsky.graph.defs#modlist",
            "app.bsky.graph.defs#curatelist",
            "app.bsky.graph.defs#referencelist"
          ],
          "type" => "string"
        },
        "listView" => %{
          "properties" => %{
            "avatar" => %{"format" => "uri", "type" => "string"},
            "cid" => %{"format" => "cid", "type" => "string"},
            "creator" => %{
              "ref" => "app.bsky.actor.defs#profileView",
              "type" => "ref"
            },
            "description" => %{
              "maxGraphemes" => 300,
              "maxLength" => 3000,
              "type" => "string"
            },
            "descriptionFacets" => %{
              "items" => %{"ref" => "app.bsky.richtext.facet", "type" => "ref"},
              "type" => "array"
            },
            "indexedAt" => %{"format" => "datetime", "type" => "string"},
            "labels" => %{
              "items" => %{
                "ref" => "com.atproto.label.defs#label",
                "type" => "ref"
              },
              "type" => "array"
            },
            "listItemCount" => %{"minimum" => 0, "type" => "integer"},
            "name" => %{"maxLength" => 64, "minLength" => 1, "type" => "string"},
            "purpose" => %{"ref" => "#listPurpose", "type" => "ref"},
            "uri" => %{"format" => "at-uri", "type" => "string"},
            "viewer" => %{"ref" => "#listViewerState", "type" => "ref"}
          },
          "required" => ["uri", "cid", "creator", "name", "purpose", "indexedAt"],
          "type" => "object"
        },
        "listViewBasic" => %{
          "properties" => %{
            "avatar" => %{"format" => "uri", "type" => "string"},
            "cid" => %{"format" => "cid", "type" => "string"},
            "indexedAt" => %{"format" => "datetime", "type" => "string"},
            "labels" => %{
              "items" => %{
                "ref" => "com.atproto.label.defs#label",
                "type" => "ref"
              },
              "type" => "array"
            },
            "listItemCount" => %{"minimum" => 0, "type" => "integer"},
            "name" => %{"maxLength" => 64, "minLength" => 1, "type" => "string"},
            "purpose" => %{"ref" => "#listPurpose", "type" => "ref"},
            "uri" => %{"format" => "at-uri", "type" => "string"},
            "viewer" => %{"ref" => "#listViewerState", "type" => "ref"}
          },
          "required" => ["uri", "cid", "name", "purpose"],
          "type" => "object"
        },
        "listViewerState" => %{
          "properties" => %{
            "blocked" => %{"format" => "at-uri", "type" => "string"},
            "muted" => %{"type" => "boolean"}
          },
          "type" => "object"
        },
        "modlist" => %{
          "description" => "A list of actors to apply an aggregate moderation action (mute/block) on.",
          "type" => "token"
        },
        "notFoundActor" => %{
          "description" => "indicates that a handle or DID could not be resolved",
          "properties" => %{
            "actor" => %{"format" => "at-identifier", "type" => "string"},
            "notFound" => %{"const" => true, "type" => "boolean"}
          },
          "required" => ["actor", "notFound"],
          "type" => "object"
        },
        "referencelist" => %{
          "description" => "A list of actors used for only for reference purposes such as within a starter pack.",
          "type" => "token"
        },
        "relationship" => %{
          "description" =>
            "lists the bi-directional graph relationships between one actor (not indicated in the object), and the target actors (the DID included in the object)",
          "properties" => %{
            "blockedBy" => %{
              "description" => "if the actor is blocked by this DID, contains the AT-URI of the block record",
              "format" => "at-uri",
              "type" => "string"
            },
            "blockedByList" => %{
              "description" =>
                "if the actor is blocked by this DID via a block list, contains the AT-URI of the listblock record",
              "format" => "at-uri",
              "type" => "string"
            },
            "blocking" => %{
              "description" => "if the actor blocks this DID, this is the AT-URI of the block record",
              "format" => "at-uri",
              "type" => "string"
            },
            "blockingByList" => %{
              "description" =>
                "if the actor blocks this DID via a block list, this is the AT-URI of the listblock record",
              "format" => "at-uri",
              "type" => "string"
            },
            "did" => %{"format" => "did", "type" => "string"},
            "followedBy" => %{
              "description" => "if the actor is followed by this DID, contains the AT-URI of the follow record",
              "format" => "at-uri",
              "type" => "string"
            },
            "following" => %{
              "description" => "if the actor follows this DID, this is the AT-URI of the follow record",
              "format" => "at-uri",
              "type" => "string"
            }
          },
          "required" => ["did"],
          "type" => "object"
        },
        "starterPackView" => %{
          "properties" => %{
            "cid" => %{"format" => "cid", "type" => "string"},
            "creator" => %{
              "ref" => "app.bsky.actor.defs#profileViewBasic",
              "type" => "ref"
            },
            "feeds" => %{
              "items" => %{
                "ref" => "app.bsky.feed.defs#generatorView",
                "type" => "ref"
              },
              "maxLength" => 3,
              "type" => "array"
            },
            "indexedAt" => %{"format" => "datetime", "type" => "string"},
            "joinedAllTimeCount" => %{"minimum" => 0, "type" => "integer"},
            "joinedWeekCount" => %{"minimum" => 0, "type" => "integer"},
            "labels" => %{
              "items" => %{
                "ref" => "com.atproto.label.defs#label",
                "type" => "ref"
              },
              "type" => "array"
            },
            "list" => %{"ref" => "#listViewBasic", "type" => "ref"},
            "listItemsSample" => %{
              "items" => %{"ref" => "#listItemView", "type" => "ref"},
              "maxLength" => 12,
              "type" => "array"
            },
            "record" => %{"type" => "unknown"},
            "uri" => %{"format" => "at-uri", "type" => "string"}
          },
          "required" => ["uri", "cid", "record", "creator", "indexedAt"],
          "type" => "object"
        },
        "starterPackViewBasic" => %{
          "properties" => %{
            "cid" => %{"format" => "cid", "type" => "string"},
            "creator" => %{
              "ref" => "app.bsky.actor.defs#profileViewBasic",
              "type" => "ref"
            },
            "indexedAt" => %{"format" => "datetime", "type" => "string"},
            "joinedAllTimeCount" => %{"minimum" => 0, "type" => "integer"},
            "joinedWeekCount" => %{"minimum" => 0, "type" => "integer"},
            "labels" => %{
              "items" => %{
                "ref" => "com.atproto.label.defs#label",
                "type" => "ref"
              },
              "type" => "array"
            },
            "listItemCount" => %{"minimum" => 0, "type" => "integer"},
            "record" => %{"type" => "unknown"},
            "uri" => %{"format" => "at-uri", "type" => "string"}
          },
          "required" => ["uri", "cid", "record", "creator", "indexedAt"],
          "type" => "object"
        }
      },
      "id" => "app.bsky.graph.defs",
      "lexicon" => 1
    },
    %{
      "defs" => %{
        "main" => %{
          "description" =>
            "Record declaring a social 'follow' relationship of another account. Duplicate follows will be ignored by the AppView.",
          "key" => "tid",
          "record" => %{
            "properties" => %{
              "createdAt" => %{"format" => "datetime", "type" => "string"},
              "subject" => %{"format" => "did", "type" => "string"},
              "via" => %{"ref" => "com.atproto.repo.strongRef", "type" => "ref"}
            },
            "required" => ["subject", "createdAt"],
            "type" => "object"
          },
          "type" => "record"
        }
      },
      "id" => "app.bsky.graph.follow",
      "lexicon" => 1
    },
    %{
      "defs" => %{
        "main" => %{
          "description" => "Get a list of starter packs created by the actor.",
          "output" => %{
            "encoding" => "application/json",
            "schema" => %{
              "properties" => %{
                "cursor" => %{"type" => "string"},
                "starterPacks" => %{
                  "items" => %{
                    "ref" => "app.bsky.graph.defs#starterPackViewBasic",
                    "type" => "ref"
                  },
                  "type" => "array"
                }
              },
              "required" => ["starterPacks"],
              "type" => "object"
            }
          },
          "parameters" => %{
            "properties" => %{
              "actor" => %{"format" => "at-identifier", "type" => "string"},
              "cursor" => %{"type" => "string"},
              "limit" => %{
                "default" => 50,
                "maximum" => 100,
                "minimum" => 1,
                "type" => "integer"
              }
            },
            "required" => ["actor"],
            "type" => "params"
          },
          "type" => "query"
        }
      },
      "id" => "app.bsky.graph.getActorStarterPacks",
      "lexicon" => 1
    },
    %{
      "defs" => %{
        "main" => %{
          "description" => "Enumerates which accounts the requesting account is currently blocking. Requires auth.",
          "output" => %{
            "encoding" => "application/json",
            "schema" => %{
              "properties" => %{
                "blocks" => %{
                  "items" => %{
                    "ref" => "app.bsky.actor.defs#profileView",
                    "type" => "ref"
                  },
                  "type" => "array"
                },
                "cursor" => %{"type" => "string"}
              },
              "required" => ["blocks"],
              "type" => "object"
            }
          },
          "parameters" => %{
            "properties" => %{
              "cursor" => %{"type" => "string"},
              "limit" => %{
                "default" => 50,
                "maximum" => 100,
                "minimum" => 1,
                "type" => "integer"
              }
            },
            "type" => "params"
          },
          "type" => "query"
        }
      },
      "id" => "app.bsky.graph.getBlocks",
      "lexicon" => 1
    },
    %{
      "defs" => %{
        "main" => %{
          "description" => "Enumerates accounts which follow a specified account (actor).",
          "output" => %{
            "encoding" => "application/json",
            "schema" => %{
              "properties" => %{
                "cursor" => %{"type" => "string"},
                "followers" => %{
                  "items" => %{
                    "ref" => "app.bsky.actor.defs#profileView",
                    "type" => "ref"
                  },
                  "type" => "array"
                },
                "subject" => %{
                  "ref" => "app.bsky.actor.defs#profileView",
                  "type" => "ref"
                }
              },
              "required" => ["subject", "followers"],
              "type" => "object"
            }
          },
          "parameters" => %{
            "properties" => %{
              "actor" => %{"format" => "at-identifier", "type" => "string"},
              "cursor" => %{"type" => "string"},
              "limit" => %{
                "default" => 50,
                "maximum" => 100,
                "minimum" => 1,
                "type" => "integer"
              }
            },
            "required" => ["actor"],
            "type" => "params"
          },
          "type" => "query"
        }
      },
      "id" => "app.bsky.graph.getFollowers",
      "lexicon" => 1
    },
    %{
      "defs" => %{
        "main" => %{
          "description" => "Enumerates accounts which a specified account (actor) follows.",
          "output" => %{
            "encoding" => "application/json",
            "schema" => %{
              "properties" => %{
                "cursor" => %{"type" => "string"},
                "follows" => %{
                  "items" => %{
                    "ref" => "app.bsky.actor.defs#profileView",
                    "type" => "ref"
                  },
                  "type" => "array"
                },
                "subject" => %{
                  "ref" => "app.bsky.actor.defs#profileView",
                  "type" => "ref"
                }
              },
              "required" => ["subject", "follows"],
              "type" => "object"
            }
          },
          "parameters" => %{
            "properties" => %{
              "actor" => %{"format" => "at-identifier", "type" => "string"},
              "cursor" => %{"type" => "string"},
              "limit" => %{
                "default" => 50,
                "maximum" => 100,
                "minimum" => 1,
                "type" => "integer"
              }
            },
            "required" => ["actor"],
            "type" => "params"
          },
          "type" => "query"
        }
      },
      "id" => "app.bsky.graph.getFollows",
      "lexicon" => 1
    },
    %{
      "defs" => %{
        "main" => %{
          "description" =>
            "Enumerates accounts which follow a specified account (actor) and are followed by the viewer.",
          "output" => %{
            "encoding" => "application/json",
            "schema" => %{
              "properties" => %{
                "cursor" => %{"type" => "string"},
                "followers" => %{
                  "items" => %{
                    "ref" => "app.bsky.actor.defs#profileView",
                    "type" => "ref"
                  },
                  "type" => "array"
                },
                "subject" => %{
                  "ref" => "app.bsky.actor.defs#profileView",
                  "type" => "ref"
                }
              },
              "required" => ["subject", "followers"],
              "type" => "object"
            }
          },
          "parameters" => %{
            "properties" => %{
              "actor" => %{"format" => "at-identifier", "type" => "string"},
              "cursor" => %{"type" => "string"},
              "limit" => %{
                "default" => 50,
                "maximum" => 100,
                "minimum" => 1,
                "type" => "integer"
              }
            },
            "required" => ["actor"],
            "type" => "params"
          },
          "type" => "query"
        }
      },
      "id" => "app.bsky.graph.getKnownFollowers",
      "lexicon" => 1
    },
    %{
      "defs" => %{
        "main" => %{
          "description" => "Gets a 'view' (with additional context) of a specified list.",
          "output" => %{
            "encoding" => "application/json",
            "schema" => %{
              "properties" => %{
                "cursor" => %{"type" => "string"},
                "items" => %{
                  "items" => %{
                    "ref" => "app.bsky.graph.defs#listItemView",
                    "type" => "ref"
                  },
                  "type" => "array"
                },
                "list" => %{
                  "ref" => "app.bsky.graph.defs#listView",
                  "type" => "ref"
                }
              },
              "required" => ["list", "items"],
              "type" => "object"
            }
          },
          "parameters" => %{
            "properties" => %{
              "cursor" => %{"type" => "string"},
              "limit" => %{
                "default" => 50,
                "maximum" => 100,
                "minimum" => 1,
                "type" => "integer"
              },
              "list" => %{
                "description" => "Reference (AT-URI) of the list record to hydrate.",
                "format" => "at-uri",
                "type" => "string"
              }
            },
            "required" => ["list"],
            "type" => "params"
          },
          "type" => "query"
        }
      },
      "id" => "app.bsky.graph.getList",
      "lexicon" => 1
    },
    %{
      "defs" => %{
        "main" => %{
          "description" => "Get mod lists that the requesting account (actor) is blocking. Requires auth.",
          "output" => %{
            "encoding" => "application/json",
            "schema" => %{
              "properties" => %{
                "cursor" => %{"type" => "string"},
                "lists" => %{
                  "items" => %{
                    "ref" => "app.bsky.graph.defs#listView",
                    "type" => "ref"
                  },
                  "type" => "array"
                }
              },
              "required" => ["lists"],
              "type" => "object"
            }
          },
          "parameters" => %{
            "properties" => %{
              "cursor" => %{"type" => "string"},
              "limit" => %{
                "default" => 50,
                "maximum" => 100,
                "minimum" => 1,
                "type" => "integer"
              }
            },
            "type" => "params"
          },
          "type" => "query"
        }
      },
      "id" => "app.bsky.graph.getListBlocks",
      "lexicon" => 1
    },
    %{
      "defs" => %{
        "main" => %{
          "description" =>
            "Enumerates mod lists that the requesting account (actor) currently has muted. Requires auth.",
          "output" => %{
            "encoding" => "application/json",
            "schema" => %{
              "properties" => %{
                "cursor" => %{"type" => "string"},
                "lists" => %{
                  "items" => %{
                    "ref" => "app.bsky.graph.defs#listView",
                    "type" => "ref"
                  },
                  "type" => "array"
                }
              },
              "required" => ["lists"],
              "type" => "object"
            }
          },
          "parameters" => %{
            "properties" => %{
              "cursor" => %{"type" => "string"},
              "limit" => %{
                "default" => 50,
                "maximum" => 100,
                "minimum" => 1,
                "type" => "integer"
              }
            },
            "type" => "params"
          },
          "type" => "query"
        }
      },
      "id" => "app.bsky.graph.getListMutes",
      "lexicon" => 1
    },
    %{
      "defs" => %{
        "main" => %{
          "description" => "Enumerates the lists created by a specified account (actor).",
          "output" => %{
            "encoding" => "application/json",
            "schema" => %{
              "properties" => %{
                "cursor" => %{"type" => "string"},
                "lists" => %{
                  "items" => %{
                    "ref" => "app.bsky.graph.defs#listView",
                    "type" => "ref"
                  },
                  "type" => "array"
                }
              },
              "required" => ["lists"],
              "type" => "object"
            }
          },
          "parameters" => %{
            "properties" => %{
              "actor" => %{
                "description" => "The account (actor) to enumerate lists from.",
                "format" => "at-identifier",
                "type" => "string"
              },
              "cursor" => %{"type" => "string"},
              "limit" => %{
                "default" => 50,
                "maximum" => 100,
                "minimum" => 1,
                "type" => "integer"
              },
              "purposes" => %{
                "description" => "Optional filter by list purpose. If not specified, all supported types are returned.",
                "items" => %{
                  "knownValues" => ["modlist", "curatelist"],
                  "type" => "string"
                },
                "type" => "array"
              }
            },
            "required" => ["actor"],
            "type" => "params"
          },
          "type" => "query"
        }
      },
      "id" => "app.bsky.graph.getLists",
      "lexicon" => 1
    },
    %{
      "defs" => %{
        "listWithMembership" => %{
          "description" => "A list and an optional list item indicating membership of a target user to that list.",
          "properties" => %{
            "list" => %{"ref" => "app.bsky.graph.defs#listView", "type" => "ref"},
            "listItem" => %{
              "ref" => "app.bsky.graph.defs#listItemView",
              "type" => "ref"
            }
          },
          "required" => ["list"],
          "type" => "object"
        },
        "main" => %{
          "description" =>
            "Enumerates the lists created by the session user, and includes membership information about `actor` in those lists. Only supports curation and moderation lists (no reference lists, used in starter packs). Requires auth.",
          "output" => %{
            "encoding" => "application/json",
            "schema" => %{
              "properties" => %{
                "cursor" => %{"type" => "string"},
                "listsWithMembership" => %{
                  "items" => %{"ref" => "#listWithMembership", "type" => "ref"},
                  "type" => "array"
                }
              },
              "required" => ["listsWithMembership"],
              "type" => "object"
            }
          },
          "parameters" => %{
            "properties" => %{
              "actor" => %{
                "description" => "The account (actor) to check for membership.",
                "format" => "at-identifier",
                "type" => "string"
              },
              "cursor" => %{"type" => "string"},
              "limit" => %{
                "default" => 50,
                "maximum" => 100,
                "minimum" => 1,
                "type" => "integer"
              },
              "purposes" => %{
                "description" => "Optional filter by list purpose. If not specified, all supported types are returned.",
                "items" => %{
                  "knownValues" => ["modlist", "curatelist"],
                  "type" => "string"
                },
                "type" => "array"
              }
            },
            "required" => ["actor"],
            "type" => "params"
          },
          "type" => "query"
        }
      },
      "id" => "app.bsky.graph.getListsWithMembership",
      "lexicon" => 1
    },
    %{
      "defs" => %{
        "main" => %{
          "description" =>
            "Enumerates accounts that the requesting account (actor) currently has muted. Requires auth.",
          "output" => %{
            "encoding" => "application/json",
            "schema" => %{
              "properties" => %{
                "cursor" => %{"type" => "string"},
                "mutes" => %{
                  "items" => %{
                    "ref" => "app.bsky.actor.defs#profileView",
                    "type" => "ref"
                  },
                  "type" => "array"
                }
              },
              "required" => ["mutes"],
              "type" => "object"
            }
          },
          "parameters" => %{
            "properties" => %{
              "cursor" => %{"type" => "string"},
              "limit" => %{
                "default" => 50,
                "maximum" => 100,
                "minimum" => 1,
                "type" => "integer"
              }
            },
            "type" => "params"
          },
          "type" => "query"
        }
      },
      "id" => "app.bsky.graph.getMutes",
      "lexicon" => 1
    },
    %{
      "defs" => %{
        "main" => %{
          "description" =>
            "Enumerates public relationships between one account, and a list of other accounts. Does not require auth.",
          "errors" => [
            %{
              "description" => "the primary actor at-identifier could not be resolved",
              "name" => "ActorNotFound"
            }
          ],
          "output" => %{
            "encoding" => "application/json",
            "schema" => %{
              "properties" => %{
                "actor" => %{"format" => "did", "type" => "string"},
                "relationships" => %{
                  "items" => %{
                    "refs" => ["app.bsky.graph.defs#relationship", "app.bsky.graph.defs#notFoundActor"],
                    "type" => "union"
                  },
                  "type" => "array"
                }
              },
              "required" => ["relationships"],
              "type" => "object"
            }
          },
          "parameters" => %{
            "properties" => %{
              "actor" => %{
                "description" => "Primary account requesting relationships for.",
                "format" => "at-identifier",
                "type" => "string"
              },
              "others" => %{
                "description" => "List of 'other' accounts to be related back to the primary.",
                "items" => %{"format" => "at-identifier", "type" => "string"},
                "maxLength" => 30,
                "type" => "array"
              }
            },
            "required" => ["actor"],
            "type" => "params"
          },
          "type" => "query"
        }
      },
      "id" => "app.bsky.graph.getRelationships",
      "lexicon" => 1
    },
    %{
      "defs" => %{
        "main" => %{
          "description" => "Gets a view of a starter pack.",
          "output" => %{
            "encoding" => "application/json",
            "schema" => %{
              "properties" => %{
                "starterPack" => %{
                  "ref" => "app.bsky.graph.defs#starterPackView",
                  "type" => "ref"
                }
              },
              "required" => ["starterPack"],
              "type" => "object"
            }
          },
          "parameters" => %{
            "properties" => %{
              "starterPack" => %{
                "description" => "Reference (AT-URI) of the starter pack record.",
                "format" => "at-uri",
                "type" => "string"
              }
            },
            "required" => ["starterPack"],
            "type" => "params"
          },
          "type" => "query"
        }
      },
      "id" => "app.bsky.graph.getStarterPack",
      "lexicon" => 1
    },
    %{
      "defs" => %{
        "main" => %{
          "description" => "Get views for a list of starter packs.",
          "output" => %{
            "encoding" => "application/json",
            "schema" => %{
              "properties" => %{
                "starterPacks" => %{
                  "items" => %{
                    "ref" => "app.bsky.graph.defs#starterPackViewBasic",
                    "type" => "ref"
                  },
                  "type" => "array"
                }
              },
              "required" => ["starterPacks"],
              "type" => "object"
            }
          },
          "parameters" => %{
            "properties" => %{
              "uris" => %{
                "items" => %{"format" => "at-uri", "type" => "string"},
                "maxLength" => 25,
                "type" => "array"
              }
            },
            "required" => ["uris"],
            "type" => "params"
          },
          "type" => "query"
        }
      },
      "id" => "app.bsky.graph.getStarterPacks",
      "lexicon" => 1
    },
    %{
      "defs" => %{
        "main" => %{
          "description" =>
            "Enumerates the starter packs created by the session user, and includes membership information about `actor` in those starter packs. Requires auth.",
          "output" => %{
            "encoding" => "application/json",
            "schema" => %{
              "properties" => %{
                "cursor" => %{"type" => "string"},
                "starterPacksWithMembership" => %{
                  "items" => %{
                    "ref" => "#starterPackWithMembership",
                    "type" => "ref"
                  },
                  "type" => "array"
                }
              },
              "required" => ["starterPacksWithMembership"],
              "type" => "object"
            }
          },
          "parameters" => %{
            "properties" => %{
              "actor" => %{
                "description" => "The account (actor) to check for membership.",
                "format" => "at-identifier",
                "type" => "string"
              },
              "cursor" => %{"type" => "string"},
              "limit" => %{
                "default" => 50,
                "maximum" => 100,
                "minimum" => 1,
                "type" => "integer"
              }
            },
            "required" => ["actor"],
            "type" => "params"
          },
          "type" => "query"
        },
        "starterPackWithMembership" => %{
          "description" =>
            "A starter pack and an optional list item indicating membership of a target user to that starter pack.",
          "properties" => %{
            "listItem" => %{
              "ref" => "app.bsky.graph.defs#listItemView",
              "type" => "ref"
            },
            "starterPack" => %{
              "ref" => "app.bsky.graph.defs#starterPackView",
              "type" => "ref"
            }
          },
          "required" => ["starterPack"],
          "type" => "object"
        }
      },
      "id" => "app.bsky.graph.getStarterPacksWithMembership",
      "lexicon" => 1
    },
    %{
      "defs" => %{
        "main" => %{
          "description" =>
            "Enumerates follows similar to a given account (actor). Expected use is to recommend additional accounts immediately after following one account.",
          "output" => %{
            "encoding" => "application/json",
            "schema" => %{
              "properties" => %{
                "isFallback" => %{
                  "default" => false,
                  "description" =>
                    "DEPRECATED, unused. Previously: if true, response has fallen-back to generic results, and is not scoped using relativeToDid",
                  "type" => "boolean"
                },
                "recId" => %{
                  "description" => "DEPRECATED: use recIdStr instead.",
                  "type" => "integer"
                },
                "recIdStr" => %{
                  "description" => "Snowflake for this recommendation, use when submitting recommendation events.",
                  "type" => "string"
                },
                "suggestions" => %{
                  "items" => %{
                    "ref" => "app.bsky.actor.defs#profileView",
                    "type" => "ref"
                  },
                  "type" => "array"
                }
              },
              "required" => ["suggestions"],
              "type" => "object"
            }
          },
          "parameters" => %{
            "properties" => %{
              "actor" => %{"format" => "at-identifier", "type" => "string"}
            },
            "required" => ["actor"],
            "type" => "params"
          },
          "type" => "query"
        }
      },
      "id" => "app.bsky.graph.getSuggestedFollowsByActor",
      "lexicon" => 1
    },
    %{
      "defs" => %{
        "main" => %{
          "description" =>
            "Record representing a list of accounts (actors). Scope includes both moderation-oriented lists and curration-oriented lists.",
          "key" => "tid",
          "record" => %{
            "properties" => %{
              "avatar" => %{
                "accept" => ["image/png", "image/jpeg"],
                "maxSize" => 1_000_000,
                "type" => "blob"
              },
              "createdAt" => %{"format" => "datetime", "type" => "string"},
              "description" => %{
                "maxGraphemes" => 300,
                "maxLength" => 3000,
                "type" => "string"
              },
              "descriptionFacets" => %{
                "items" => %{"ref" => "app.bsky.richtext.facet", "type" => "ref"},
                "type" => "array"
              },
              "labels" => %{
                "refs" => ["com.atproto.label.defs#selfLabels"],
                "type" => "union"
              },
              "name" => %{
                "description" => "Display name for list; can not be empty.",
                "maxLength" => 64,
                "minLength" => 1,
                "type" => "string"
              },
              "purpose" => %{
                "description" => "Defines the purpose of the list (aka, moderation-oriented or curration-oriented)",
                "ref" => "app.bsky.graph.defs#listPurpose",
                "type" => "ref"
              }
            },
            "required" => ["name", "purpose", "createdAt"],
            "type" => "object"
          },
          "type" => "record"
        }
      },
      "id" => "app.bsky.graph.list",
      "lexicon" => 1
    },
    %{
      "defs" => %{
        "main" => %{
          "description" =>
            "Record representing a block relationship against an entire an entire list of accounts (actors).",
          "key" => "tid",
          "record" => %{
            "properties" => %{
              "createdAt" => %{"format" => "datetime", "type" => "string"},
              "subject" => %{
                "description" => "Reference (AT-URI) to the mod list record.",
                "format" => "at-uri",
                "type" => "string"
              }
            },
            "required" => ["subject", "createdAt"],
            "type" => "object"
          },
          "type" => "record"
        }
      },
      "id" => "app.bsky.graph.listblock",
      "lexicon" => 1
    },
    %{
      "defs" => %{
        "main" => %{
          "description" =>
            "Record representing an account's inclusion on a specific list. The AppView will ignore duplicate listitem records.",
          "key" => "tid",
          "record" => %{
            "properties" => %{
              "createdAt" => %{"format" => "datetime", "type" => "string"},
              "list" => %{
                "description" => "Reference (AT-URI) to the list record (app.bsky.graph.list).",
                "format" => "at-uri",
                "type" => "string"
              },
              "subject" => %{
                "description" => "The account which is included on the list.",
                "format" => "did",
                "type" => "string"
              }
            },
            "required" => ["subject", "list", "createdAt"],
            "type" => "object"
          },
          "type" => "record"
        }
      },
      "id" => "app.bsky.graph.listitem",
      "lexicon" => 1
    },
    %{
      "defs" => %{
        "main" => %{
          "description" =>
            "Creates a mute relationship for the specified account. Mutes are private in Bluesky. Requires auth.",
          "input" => %{
            "encoding" => "application/json",
            "schema" => %{
              "properties" => %{
                "actor" => %{"format" => "at-identifier", "type" => "string"}
              },
              "required" => ["actor"],
              "type" => "object"
            }
          },
          "type" => "procedure"
        }
      },
      "id" => "app.bsky.graph.muteActor",
      "lexicon" => 1
    },
    %{
      "defs" => %{
        "main" => %{
          "description" =>
            "Creates a mute relationship for the specified list of accounts. Mutes are private in Bluesky. Requires auth.",
          "input" => %{
            "encoding" => "application/json",
            "schema" => %{
              "properties" => %{
                "list" => %{"format" => "at-uri", "type" => "string"}
              },
              "required" => ["list"],
              "type" => "object"
            }
          },
          "type" => "procedure"
        }
      },
      "id" => "app.bsky.graph.muteActorList",
      "lexicon" => 1
    },
    %{
      "defs" => %{
        "main" => %{
          "description" =>
            "Mutes a thread preventing notifications from the thread and any of its children. Mutes are private in Bluesky. Requires auth.",
          "input" => %{
            "encoding" => "application/json",
            "schema" => %{
              "properties" => %{
                "root" => %{"format" => "at-uri", "type" => "string"}
              },
              "required" => ["root"],
              "type" => "object"
            }
          },
          "type" => "procedure"
        }
      },
      "id" => "app.bsky.graph.muteThread",
      "lexicon" => 1
    },
    %{
      "defs" => %{
        "main" => %{
          "description" => "Find starter packs matching search criteria. Does not require auth.",
          "output" => %{
            "encoding" => "application/json",
            "schema" => %{
              "properties" => %{
                "cursor" => %{"type" => "string"},
                "starterPacks" => %{
                  "items" => %{
                    "ref" => "app.bsky.graph.defs#starterPackViewBasic",
                    "type" => "ref"
                  },
                  "type" => "array"
                }
              },
              "required" => ["starterPacks"],
              "type" => "object"
            }
          },
          "parameters" => %{
            "properties" => %{
              "cursor" => %{"type" => "string"},
              "limit" => %{
                "default" => 25,
                "maximum" => 100,
                "minimum" => 1,
                "type" => "integer"
              },
              "q" => %{
                "description" =>
                  "Search query string. Syntax, phrase, boolean, and faceting is unspecified, but Lucene query syntax is recommended.",
                "type" => "string"
              }
            },
            "required" => ["q"],
            "type" => "params"
          },
          "type" => "query"
        }
      },
      "id" => "app.bsky.graph.searchStarterPacks",
      "lexicon" => 1
    },
    %{
      "defs" => %{
        "feedItem" => %{
          "properties" => %{"uri" => %{"format" => "at-uri", "type" => "string"}},
          "required" => ["uri"],
          "type" => "object"
        },
        "main" => %{
          "description" => "Record defining a starter pack of actors and feeds for new users.",
          "key" => "tid",
          "record" => %{
            "properties" => %{
              "createdAt" => %{"format" => "datetime", "type" => "string"},
              "description" => %{
                "maxGraphemes" => 300,
                "maxLength" => 3000,
                "type" => "string"
              },
              "descriptionFacets" => %{
                "items" => %{"ref" => "app.bsky.richtext.facet", "type" => "ref"},
                "type" => "array"
              },
              "feeds" => %{
                "items" => %{"ref" => "#feedItem", "type" => "ref"},
                "maxLength" => 3,
                "type" => "array"
              },
              "list" => %{
                "description" => "Reference (AT-URI) to the list record.",
                "format" => "at-uri",
                "type" => "string"
              },
              "name" => %{
                "description" => "Display name for starter pack; can not be empty.",
                "maxGraphemes" => 50,
                "maxLength" => 500,
                "minLength" => 1,
                "type" => "string"
              }
            },
            "required" => ["name", "list", "createdAt"],
            "type" => "object"
          },
          "type" => "record"
        }
      },
      "id" => "app.bsky.graph.starterpack",
      "lexicon" => 1
    },
    %{
      "defs" => %{
        "main" => %{
          "description" => "Unmutes the specified account. Requires auth.",
          "input" => %{
            "encoding" => "application/json",
            "schema" => %{
              "properties" => %{
                "actor" => %{"format" => "at-identifier", "type" => "string"}
              },
              "required" => ["actor"],
              "type" => "object"
            }
          },
          "type" => "procedure"
        }
      },
      "id" => "app.bsky.graph.unmuteActor",
      "lexicon" => 1
    },
    %{
      "defs" => %{
        "main" => %{
          "description" => "Unmutes the specified list of accounts. Requires auth.",
          "input" => %{
            "encoding" => "application/json",
            "schema" => %{
              "properties" => %{
                "list" => %{"format" => "at-uri", "type" => "string"}
              },
              "required" => ["list"],
              "type" => "object"
            }
          },
          "type" => "procedure"
        }
      },
      "id" => "app.bsky.graph.unmuteActorList",
      "lexicon" => 1
    },
    %{
      "defs" => %{
        "main" => %{
          "description" => "Unmutes the specified thread. Requires auth.",
          "input" => %{
            "encoding" => "application/json",
            "schema" => %{
              "properties" => %{
                "root" => %{"format" => "at-uri", "type" => "string"}
              },
              "required" => ["root"],
              "type" => "object"
            }
          },
          "type" => "procedure"
        }
      },
      "id" => "app.bsky.graph.unmuteThread",
      "lexicon" => 1
    },
    %{
      "defs" => %{
        "main" => %{
          "description" =>
            "Record declaring a verification relationship between two accounts. Verifications are only considered valid by an app if issued by an account the app considers trusted.",
          "key" => "tid",
          "record" => %{
            "properties" => %{
              "createdAt" => %{
                "description" => "Date of when the verification was created.",
                "format" => "datetime",
                "type" => "string"
              },
              "displayName" => %{
                "description" =>
                  "Display name of the subject the verification applies to at the moment of verifying, which might not be the same at the time of viewing. The verification is only valid if the current displayName matches the one at the time of verifying.",
                "type" => "string"
              },
              "handle" => %{
                "description" =>
                  "Handle of the subject the verification applies to at the moment of verifying, which might not be the same at the time of viewing. The verification is only valid if the current handle matches the one at the time of verifying.",
                "format" => "handle",
                "type" => "string"
              },
              "subject" => %{
                "description" => "DID of the subject the verification applies to.",
                "format" => "did",
                "type" => "string"
              }
            },
            "required" => ["subject", "handle", "displayName", "createdAt"],
            "type" => "object"
          },
          "type" => "record"
        }
      },
      "id" => "app.bsky.graph.verification",
      "lexicon" => 1
    },
    %{
      "defs" => %{
        "labelerPolicies" => %{
          "properties" => %{
            "labelValueDefinitions" => %{
              "description" =>
                "Label values created by this labeler and scoped exclusively to it. Labels defined here will override global label definitions for this labeler.",
              "items" => %{
                "ref" => "com.atproto.label.defs#labelValueDefinition",
                "type" => "ref"
              },
              "type" => "array"
            },
            "labelValues" => %{
              "description" => "The label values which this labeler publishes. May include global or custom labels.",
              "items" => %{
                "ref" => "com.atproto.label.defs#labelValue",
                "type" => "ref"
              },
              "type" => "array"
            }
          },
          "required" => ["labelValues"],
          "type" => "object"
        },
        "labelerView" => %{
          "properties" => %{
            "cid" => %{"format" => "cid", "type" => "string"},
            "creator" => %{
              "ref" => "app.bsky.actor.defs#profileView",
              "type" => "ref"
            },
            "indexedAt" => %{"format" => "datetime", "type" => "string"},
            "labels" => %{
              "items" => %{
                "ref" => "com.atproto.label.defs#label",
                "type" => "ref"
              },
              "type" => "array"
            },
            "likeCount" => %{"minimum" => 0, "type" => "integer"},
            "uri" => %{"format" => "at-uri", "type" => "string"},
            "viewer" => %{"ref" => "#labelerViewerState", "type" => "ref"}
          },
          "required" => ["uri", "cid", "creator", "indexedAt"],
          "type" => "object"
        },
        "labelerViewDetailed" => %{
          "properties" => %{
            "cid" => %{"format" => "cid", "type" => "string"},
            "creator" => %{
              "ref" => "app.bsky.actor.defs#profileView",
              "type" => "ref"
            },
            "indexedAt" => %{"format" => "datetime", "type" => "string"},
            "labels" => %{
              "items" => %{
                "ref" => "com.atproto.label.defs#label",
                "type" => "ref"
              },
              "type" => "array"
            },
            "likeCount" => %{"minimum" => 0, "type" => "integer"},
            "policies" => %{
              "ref" => "app.bsky.labeler.defs#labelerPolicies",
              "type" => "ref"
            },
            "reasonTypes" => %{
              "description" =>
                "The set of report reason 'codes' which are in-scope for this service to review and action. These usually align to policy categories. If not defined (distinct from empty array), all reason types are allowed.",
              "items" => %{
                "ref" => "com.atproto.moderation.defs#reasonType",
                "type" => "ref"
              },
              "type" => "array"
            },
            "subjectCollections" => %{
              "description" =>
                "Set of record types (collection NSIDs) which can be reported to this service. If not defined (distinct from empty array), default is any record type.",
              "items" => %{"format" => "nsid", "type" => "string"},
              "type" => "array"
            },
            "subjectTypes" => %{
              "description" => "The set of subject types (account, record, etc) this service accepts reports on.",
              "items" => %{
                "ref" => "com.atproto.moderation.defs#subjectType",
                "type" => "ref"
              },
              "type" => "array"
            },
            "uri" => %{"format" => "at-uri", "type" => "string"},
            "viewer" => %{"ref" => "#labelerViewerState", "type" => "ref"}
          },
          "required" => ["uri", "cid", "creator", "policies", "indexedAt"],
          "type" => "object"
        },
        "labelerViewerState" => %{
          "properties" => %{"like" => %{"format" => "at-uri", "type" => "string"}},
          "type" => "object"
        }
      },
      "id" => "app.bsky.labeler.defs",
      "lexicon" => 1
    },
    %{
      "defs" => %{
        "main" => %{
          "description" => "Get information about a list of labeler services.",
          "output" => %{
            "encoding" => "application/json",
            "schema" => %{
              "properties" => %{
                "views" => %{
                  "items" => %{
                    "refs" => ["app.bsky.labeler.defs#labelerView", "app.bsky.labeler.defs#labelerViewDetailed"],
                    "type" => "union"
                  },
                  "type" => "array"
                }
              },
              "required" => ["views"],
              "type" => "object"
            }
          },
          "parameters" => %{
            "properties" => %{
              "detailed" => %{"default" => false, "type" => "boolean"},
              "dids" => %{
                "items" => %{"format" => "did", "type" => "string"},
                "type" => "array"
              }
            },
            "required" => ["dids"],
            "type" => "params"
          },
          "type" => "query"
        }
      },
      "id" => "app.bsky.labeler.getServices",
      "lexicon" => 1
    },
    %{
      "defs" => %{
        "main" => %{
          "description" => "A declaration of the existence of labeler service.",
          "key" => "literal:self",
          "record" => %{
            "properties" => %{
              "createdAt" => %{"format" => "datetime", "type" => "string"},
              "labels" => %{
                "refs" => ["com.atproto.label.defs#selfLabels"],
                "type" => "union"
              },
              "policies" => %{
                "ref" => "app.bsky.labeler.defs#labelerPolicies",
                "type" => "ref"
              },
              "reasonTypes" => %{
                "description" =>
                  "The set of report reason 'codes' which are in-scope for this service to review and action. These usually align to policy categories. If not defined (distinct from empty array), all reason types are allowed.",
                "items" => %{
                  "ref" => "com.atproto.moderation.defs#reasonType",
                  "type" => "ref"
                },
                "type" => "array"
              },
              "subjectCollections" => %{
                "description" =>
                  "Set of record types (collection NSIDs) which can be reported to this service. If not defined (distinct from empty array), default is any record type.",
                "items" => %{"format" => "nsid", "type" => "string"},
                "type" => "array"
              },
              "subjectTypes" => %{
                "description" => "The set of subject types (account, record, etc) this service accepts reports on.",
                "items" => %{
                  "ref" => "com.atproto.moderation.defs#subjectType",
                  "type" => "ref"
                },
                "type" => "array"
              }
            },
            "required" => ["policies", "createdAt"],
            "type" => "object"
          },
          "type" => "record"
        }
      },
      "id" => "app.bsky.labeler.service",
      "lexicon" => 1
    },
    %{
      "defs" => %{
        "main" => %{
          "description" => "A declaration of the user's choices related to notifications that can be produced by them.",
          "key" => "literal:self",
          "record" => %{
            "properties" => %{
              "allowSubscriptions" => %{
                "description" =>
                  "A declaration of the user's preference for allowing activity subscriptions from other users. Absence of a record implies 'followers'.",
                "knownValues" => ["followers", "mutuals", "none"],
                "type" => "string"
              }
            },
            "required" => ["allowSubscriptions"],
            "type" => "object"
          },
          "type" => "record"
        }
      },
      "id" => "app.bsky.notification.declaration",
      "lexicon" => 1
    },
    %{
      "defs" => %{
        "activitySubscription" => %{
          "properties" => %{
            "post" => %{"type" => "boolean"},
            "reply" => %{"type" => "boolean"}
          },
          "required" => ["post", "reply"],
          "type" => "object"
        },
        "chatPreference" => %{
          "properties" => %{
            "include" => %{
              "knownValues" => ["all", "accepted"],
              "type" => "string"
            },
            "push" => %{"type" => "boolean"}
          },
          "required" => ["include", "push"],
          "type" => "object"
        },
        "filterablePreference" => %{
          "properties" => %{
            "include" => %{
              "knownValues" => ["all", "follows"],
              "type" => "string"
            },
            "list" => %{"type" => "boolean"},
            "push" => %{"type" => "boolean"}
          },
          "required" => ["include", "list", "push"],
          "type" => "object"
        },
        "preference" => %{
          "properties" => %{
            "list" => %{"type" => "boolean"},
            "push" => %{"type" => "boolean"}
          },
          "required" => ["list", "push"],
          "type" => "object"
        },
        "preferences" => %{
          "properties" => %{
            "chat" => %{"ref" => "#chatPreference", "type" => "ref"},
            "follow" => %{"ref" => "#filterablePreference", "type" => "ref"},
            "like" => %{"ref" => "#filterablePreference", "type" => "ref"},
            "likeViaRepost" => %{
              "ref" => "#filterablePreference",
              "type" => "ref"
            },
            "mention" => %{"ref" => "#filterablePreference", "type" => "ref"},
            "quote" => %{"ref" => "#filterablePreference", "type" => "ref"},
            "reply" => %{"ref" => "#filterablePreference", "type" => "ref"},
            "repost" => %{"ref" => "#filterablePreference", "type" => "ref"},
            "repostViaRepost" => %{
              "ref" => "#filterablePreference",
              "type" => "ref"
            },
            "starterpackJoined" => %{"ref" => "#preference", "type" => "ref"},
            "subscribedPost" => %{"ref" => "#preference", "type" => "ref"},
            "unverified" => %{"ref" => "#preference", "type" => "ref"},
            "verified" => %{"ref" => "#preference", "type" => "ref"}
          },
          "required" => [
            "chat",
            "follow",
            "like",
            "likeViaRepost",
            "mention",
            "quote",
            "reply",
            "repost",
            "repostViaRepost",
            "starterpackJoined",
            "subscribedPost",
            "unverified",
            "verified"
          ],
          "type" => "object"
        },
        "recordDeleted" => %{"properties" => %{}, "type" => "object"},
        "subjectActivitySubscription" => %{
          "description" => "Object used to store activity subscription data in stash.",
          "properties" => %{
            "activitySubscription" => %{
              "ref" => "#activitySubscription",
              "type" => "ref"
            },
            "subject" => %{"format" => "did", "type" => "string"}
          },
          "required" => ["subject", "activitySubscription"],
          "type" => "object"
        }
      },
      "id" => "app.bsky.notification.defs",
      "lexicon" => 1
    },
    %{
      "defs" => %{
        "main" => %{
          "description" => "Get notification-related preferences for an account. Requires auth.",
          "output" => %{
            "encoding" => "application/json",
            "schema" => %{
              "properties" => %{
                "preferences" => %{
                  "ref" => "app.bsky.notification.defs#preferences",
                  "type" => "ref"
                }
              },
              "required" => ["preferences"],
              "type" => "object"
            }
          },
          "parameters" => %{"properties" => %{}, "type" => "params"},
          "type" => "query"
        }
      },
      "id" => "app.bsky.notification.getPreferences",
      "lexicon" => 1
    },
    %{
      "defs" => %{
        "main" => %{
          "description" => "Count the number of unread notifications for the requesting account. Requires auth.",
          "output" => %{
            "encoding" => "application/json",
            "schema" => %{
              "properties" => %{"count" => %{"type" => "integer"}},
              "required" => ["count"],
              "type" => "object"
            }
          },
          "parameters" => %{
            "properties" => %{
              "priority" => %{"type" => "boolean"},
              "seenAt" => %{"format" => "datetime", "type" => "string"}
            },
            "type" => "params"
          },
          "type" => "query"
        }
      },
      "id" => "app.bsky.notification.getUnreadCount",
      "lexicon" => 1
    },
    %{
      "defs" => %{
        "main" => %{
          "description" =>
            "Enumerate all accounts to which the requesting account is subscribed to receive notifications for. Requires auth.",
          "output" => %{
            "encoding" => "application/json",
            "schema" => %{
              "properties" => %{
                "cursor" => %{"type" => "string"},
                "subscriptions" => %{
                  "items" => %{
                    "ref" => "app.bsky.actor.defs#profileView",
                    "type" => "ref"
                  },
                  "type" => "array"
                }
              },
              "required" => ["subscriptions"],
              "type" => "object"
            }
          },
          "parameters" => %{
            "properties" => %{
              "cursor" => %{"type" => "string"},
              "limit" => %{
                "default" => 50,
                "maximum" => 100,
                "minimum" => 1,
                "type" => "integer"
              }
            },
            "type" => "params"
          },
          "type" => "query"
        }
      },
      "id" => "app.bsky.notification.listActivitySubscriptions",
      "lexicon" => 1
    },
    %{
      "defs" => %{
        "main" => %{
          "description" => "Enumerate notifications for the requesting account. Requires auth.",
          "output" => %{
            "encoding" => "application/json",
            "schema" => %{
              "properties" => %{
                "cursor" => %{"type" => "string"},
                "notifications" => %{
                  "items" => %{"ref" => "#notification", "type" => "ref"},
                  "type" => "array"
                },
                "priority" => %{"type" => "boolean"},
                "seenAt" => %{"format" => "datetime", "type" => "string"}
              },
              "required" => ["notifications"],
              "type" => "object"
            }
          },
          "parameters" => %{
            "properties" => %{
              "cursor" => %{"type" => "string"},
              "limit" => %{
                "default" => 50,
                "maximum" => 100,
                "minimum" => 1,
                "type" => "integer"
              },
              "priority" => %{"type" => "boolean"},
              "reasons" => %{
                "description" => "Notification reasons to include in response.",
                "items" => %{
                  "description" => "A reason that matches the reason property of #notification.",
                  "type" => "string"
                },
                "type" => "array"
              },
              "seenAt" => %{"format" => "datetime", "type" => "string"}
            },
            "type" => "params"
          },
          "type" => "query"
        },
        "notification" => %{
          "properties" => %{
            "author" => %{
              "ref" => "app.bsky.actor.defs#profileView",
              "type" => "ref"
            },
            "cid" => %{"format" => "cid", "type" => "string"},
            "indexedAt" => %{"format" => "datetime", "type" => "string"},
            "isRead" => %{"type" => "boolean"},
            "labels" => %{
              "items" => %{
                "ref" => "com.atproto.label.defs#label",
                "type" => "ref"
              },
              "type" => "array"
            },
            "reason" => %{
              "description" =>
                "The reason why this notification was delivered - e.g. your post was liked, or you received a new follower.",
              "knownValues" => [
                "like",
                "repost",
                "follow",
                "mention",
                "reply",
                "quote",
                "starterpack-joined",
                "verified",
                "unverified",
                "like-via-repost",
                "repost-via-repost",
                "subscribed-post",
                "contact-match"
              ],
              "type" => "string"
            },
            "reasonSubject" => %{"format" => "at-uri", "type" => "string"},
            "record" => %{"type" => "unknown"},
            "uri" => %{"format" => "at-uri", "type" => "string"}
          },
          "required" => ["uri", "cid", "author", "reason", "record", "isRead", "indexedAt"],
          "type" => "object"
        }
      },
      "id" => "app.bsky.notification.listNotifications",
      "lexicon" => 1
    },
    %{
      "defs" => %{
        "main" => %{
          "description" =>
            "Puts an activity subscription entry. The key should be omitted for creation and provided for updates. Requires auth.",
          "input" => %{
            "encoding" => "application/json",
            "schema" => %{
              "properties" => %{
                "activitySubscription" => %{
                  "ref" => "app.bsky.notification.defs#activitySubscription",
                  "type" => "ref"
                },
                "subject" => %{"format" => "did", "type" => "string"}
              },
              "required" => ["subject", "activitySubscription"],
              "type" => "object"
            }
          },
          "output" => %{
            "encoding" => "application/json",
            "schema" => %{
              "properties" => %{
                "activitySubscription" => %{
                  "ref" => "app.bsky.notification.defs#activitySubscription",
                  "type" => "ref"
                },
                "subject" => %{"format" => "did", "type" => "string"}
              },
              "required" => ["subject"],
              "type" => "object"
            }
          },
          "type" => "procedure"
        }
      },
      "id" => "app.bsky.notification.putActivitySubscription",
      "lexicon" => 1
    },
    %{
      "defs" => %{
        "main" => %{
          "description" => "Set notification-related preferences for an account. Requires auth.",
          "input" => %{
            "encoding" => "application/json",
            "schema" => %{
              "properties" => %{"priority" => %{"type" => "boolean"}},
              "required" => ["priority"],
              "type" => "object"
            }
          },
          "type" => "procedure"
        }
      },
      "id" => "app.bsky.notification.putPreferences",
      "lexicon" => 1
    },
    %{
      "defs" => %{
        "main" => %{
          "description" => "Set notification-related preferences for an account. Requires auth.",
          "input" => %{
            "encoding" => "application/json",
            "schema" => %{
              "properties" => %{
                "chat" => %{
                  "ref" => "app.bsky.notification.defs#chatPreference",
                  "type" => "ref"
                },
                "follow" => %{
                  "ref" => "app.bsky.notification.defs#filterablePreference",
                  "type" => "ref"
                },
                "like" => %{
                  "ref" => "app.bsky.notification.defs#filterablePreference",
                  "type" => "ref"
                },
                "likeViaRepost" => %{
                  "ref" => "app.bsky.notification.defs#filterablePreference",
                  "type" => "ref"
                },
                "mention" => %{
                  "ref" => "app.bsky.notification.defs#filterablePreference",
                  "type" => "ref"
                },
                "quote" => %{
                  "ref" => "app.bsky.notification.defs#filterablePreference",
                  "type" => "ref"
                },
                "reply" => %{
                  "ref" => "app.bsky.notification.defs#filterablePreference",
                  "type" => "ref"
                },
                "repost" => %{
                  "ref" => "app.bsky.notification.defs#filterablePreference",
                  "type" => "ref"
                },
                "repostViaRepost" => %{
                  "ref" => "app.bsky.notification.defs#filterablePreference",
                  "type" => "ref"
                },
                "starterpackJoined" => %{
                  "ref" => "app.bsky.notification.defs#preference",
                  "type" => "ref"
                },
                "subscribedPost" => %{
                  "ref" => "app.bsky.notification.defs#preference",
                  "type" => "ref"
                },
                "unverified" => %{
                  "ref" => "app.bsky.notification.defs#preference",
                  "type" => "ref"
                },
                "verified" => %{
                  "ref" => "app.bsky.notification.defs#preference",
                  "type" => "ref"
                }
              },
              "type" => "object"
            }
          },
          "output" => %{
            "encoding" => "application/json",
            "schema" => %{
              "properties" => %{
                "preferences" => %{
                  "ref" => "app.bsky.notification.defs#preferences",
                  "type" => "ref"
                }
              },
              "required" => ["preferences"],
              "type" => "object"
            }
          },
          "type" => "procedure"
        }
      },
      "id" => "app.bsky.notification.putPreferencesV2",
      "lexicon" => 1
    },
    %{
      "defs" => %{
        "main" => %{
          "description" =>
            "Register to receive push notifications, via a specified service, for the requesting account. Requires auth.",
          "input" => %{
            "encoding" => "application/json",
            "schema" => %{
              "properties" => %{
                "ageRestricted" => %{
                  "description" => "Set to true when the actor is age restricted",
                  "type" => "boolean"
                },
                "appId" => %{"type" => "string"},
                "platform" => %{
                  "knownValues" => ["ios", "android", "web"],
                  "type" => "string"
                },
                "serviceDid" => %{"format" => "did", "type" => "string"},
                "token" => %{"type" => "string"}
              },
              "required" => ["serviceDid", "token", "platform", "appId"],
              "type" => "object"
            }
          },
          "type" => "procedure"
        }
      },
      "id" => "app.bsky.notification.registerPush",
      "lexicon" => 1
    },
    %{
      "defs" => %{
        "main" => %{
          "description" =>
            "The inverse of registerPush - inform a specified service that push notifications should no longer be sent to the given token for the requesting account. Requires auth.",
          "input" => %{
            "encoding" => "application/json",
            "schema" => %{
              "properties" => %{
                "appId" => %{"type" => "string"},
                "platform" => %{
                  "knownValues" => ["ios", "android", "web"],
                  "type" => "string"
                },
                "serviceDid" => %{"format" => "did", "type" => "string"},
                "token" => %{"type" => "string"}
              },
              "required" => ["serviceDid", "token", "platform", "appId"],
              "type" => "object"
            }
          },
          "type" => "procedure"
        }
      },
      "id" => "app.bsky.notification.unregisterPush",
      "lexicon" => 1
    },
    %{
      "defs" => %{
        "main" => %{
          "description" => "Notify server that the requesting account has seen notifications. Requires auth.",
          "input" => %{
            "encoding" => "application/json",
            "schema" => %{
              "properties" => %{
                "seenAt" => %{"format" => "datetime", "type" => "string"}
              },
              "required" => ["seenAt"],
              "type" => "object"
            }
          },
          "type" => "procedure"
        }
      },
      "id" => "app.bsky.notification.updateSeen",
      "lexicon" => 1
    },
    %{
      "defs" => %{
        "byteSlice" => %{
          "description" =>
            "Specifies the sub-string range a facet feature applies to. Start index is inclusive, end index is exclusive. Indices are zero-indexed, counting bytes of the UTF-8 encoded text. NOTE: some languages, like Javascript, use UTF-16 or Unicode codepoints for string slice indexing; in these languages, convert to byte arrays before working with facets.",
          "properties" => %{
            "byteEnd" => %{"minimum" => 0, "type" => "integer"},
            "byteStart" => %{"minimum" => 0, "type" => "integer"}
          },
          "required" => ["byteStart", "byteEnd"],
          "type" => "object"
        },
        "link" => %{
          "description" =>
            "Facet feature for a URL. The text URL may have been simplified or truncated, but the facet reference should be a complete URL.",
          "properties" => %{"uri" => %{"format" => "uri", "type" => "string"}},
          "required" => ["uri"],
          "type" => "object"
        },
        "main" => %{
          "description" => "Annotation of a sub-string within rich text.",
          "properties" => %{
            "features" => %{
              "items" => %{
                "refs" => ["#mention", "#link", "#tag"],
                "type" => "union"
              },
              "type" => "array"
            },
            "index" => %{"ref" => "#byteSlice", "type" => "ref"}
          },
          "required" => ["index", "features"],
          "type" => "object"
        },
        "mention" => %{
          "description" =>
            "Facet feature for mention of another account. The text is usually a handle, including a '@' prefix, but the facet reference is a DID.",
          "properties" => %{"did" => %{"format" => "did", "type" => "string"}},
          "required" => ["did"],
          "type" => "object"
        },
        "tag" => %{
          "description" =>
            "Facet feature for a hashtag. The text usually includes a '#' prefix, but the facet reference should not (except in the case of 'double hash tags').",
          "properties" => %{
            "tag" => %{
              "maxGraphemes" => 64,
              "maxLength" => 640,
              "type" => "string"
            }
          },
          "required" => ["tag"],
          "type" => "object"
        }
      },
      "id" => "app.bsky.richtext.facet",
      "lexicon" => 1
    },
    %{
      "defs" => %{
        "ageAssuranceEvent" => %{
          "description" => "Object used to store age assurance data in stash.",
          "properties" => %{
            "attemptId" => %{
              "description" => "The unique identifier for this instance of the age assurance flow, in UUID format.",
              "type" => "string"
            },
            "completeIp" => %{
              "description" => "The IP address used when completing the AA flow.",
              "type" => "string"
            },
            "completeUa" => %{
              "description" => "The user agent used when completing the AA flow.",
              "type" => "string"
            },
            "createdAt" => %{
              "description" => "The date and time of this write operation.",
              "format" => "datetime",
              "type" => "string"
            },
            "email" => %{
              "description" => "The email used for AA.",
              "type" => "string"
            },
            "initIp" => %{
              "description" => "The IP address used when initiating the AA flow.",
              "type" => "string"
            },
            "initUa" => %{
              "description" => "The user agent used when initiating the AA flow.",
              "type" => "string"
            },
            "status" => %{
              "description" => "The status of the age assurance process.",
              "knownValues" => ["unknown", "pending", "assured"],
              "type" => "string"
            }
          },
          "required" => ["createdAt", "status", "attemptId"],
          "type" => "object"
        },
        "ageAssuranceState" => %{
          "description" =>
            "The computed state of the age assurance process, returned to the user in question on certain authenticated requests.",
          "properties" => %{
            "lastInitiatedAt" => %{
              "description" => "The timestamp when this state was last updated.",
              "format" => "datetime",
              "type" => "string"
            },
            "status" => %{
              "description" => "The status of the age assurance process.",
              "knownValues" => ["unknown", "pending", "assured", "blocked"],
              "type" => "string"
            }
          },
          "required" => ["status"],
          "type" => "object"
        },
        "skeletonSearchActor" => %{
          "properties" => %{"did" => %{"format" => "did", "type" => "string"}},
          "required" => ["did"],
          "type" => "object"
        },
        "skeletonSearchPost" => %{
          "properties" => %{"uri" => %{"format" => "at-uri", "type" => "string"}},
          "required" => ["uri"],
          "type" => "object"
        },
        "skeletonSearchStarterPack" => %{
          "properties" => %{"uri" => %{"format" => "at-uri", "type" => "string"}},
          "required" => ["uri"],
          "type" => "object"
        },
        "skeletonTrend" => %{
          "properties" => %{
            "category" => %{"type" => "string"},
            "dids" => %{
              "items" => %{"format" => "did", "type" => "string"},
              "type" => "array"
            },
            "displayName" => %{"type" => "string"},
            "link" => %{"type" => "string"},
            "postCount" => %{"type" => "integer"},
            "startedAt" => %{"format" => "datetime", "type" => "string"},
            "status" => %{"knownValues" => ["hot"], "type" => "string"},
            "topic" => %{"type" => "string"}
          },
          "required" => ["topic", "displayName", "link", "startedAt", "postCount", "dids"],
          "type" => "object"
        },
        "threadItemBlocked" => %{
          "properties" => %{
            "author" => %{
              "ref" => "app.bsky.feed.defs#blockedAuthor",
              "type" => "ref"
            }
          },
          "required" => ["author"],
          "type" => "object"
        },
        "threadItemNoUnauthenticated" => %{
          "properties" => %{},
          "type" => "object"
        },
        "threadItemNotFound" => %{"properties" => %{}, "type" => "object"},
        "threadItemPost" => %{
          "properties" => %{
            "hiddenByThreadgate" => %{
              "description" =>
                "The threadgate created by the author indicates this post as a reply to be hidden for everyone consuming the thread.",
              "type" => "boolean"
            },
            "moreParents" => %{
              "description" =>
                "This post has more parents that were not present in the response. This is just a boolean, without the number of parents.",
              "type" => "boolean"
            },
            "moreReplies" => %{
              "description" =>
                "This post has more replies that were not present in the response. This is a numeric value, which is best-effort and might not be accurate.",
              "type" => "integer"
            },
            "mutedByViewer" => %{
              "description" => "This is by an account muted by the viewer requesting it.",
              "type" => "boolean"
            },
            "opThread" => %{
              "description" =>
                "This post is part of a contiguous thread by the OP from the thread root. Many different OP threads can happen in the same thread.",
              "type" => "boolean"
            },
            "post" => %{"ref" => "app.bsky.feed.defs#postView", "type" => "ref"}
          },
          "required" => ["post", "moreParents", "moreReplies", "opThread", "hiddenByThreadgate", "mutedByViewer"],
          "type" => "object"
        },
        "trendView" => %{
          "properties" => %{
            "actors" => %{
              "items" => %{
                "ref" => "app.bsky.actor.defs#profileViewBasic",
                "type" => "ref"
              },
              "type" => "array"
            },
            "category" => %{"type" => "string"},
            "displayName" => %{"type" => "string"},
            "link" => %{"type" => "string"},
            "postCount" => %{"type" => "integer"},
            "startedAt" => %{"format" => "datetime", "type" => "string"},
            "status" => %{"knownValues" => ["hot"], "type" => "string"},
            "topic" => %{"type" => "string"}
          },
          "required" => ["topic", "displayName", "link", "startedAt", "postCount", "actors"],
          "type" => "object"
        },
        "trendingTopic" => %{
          "properties" => %{
            "description" => %{"type" => "string"},
            "displayName" => %{"type" => "string"},
            "link" => %{"type" => "string"},
            "topic" => %{"type" => "string"}
          },
          "required" => ["topic", "link"],
          "type" => "object"
        }
      },
      "id" => "app.bsky.unspecced.defs",
      "lexicon" => 1
    },
    %{
      "defs" => %{
        "main" => %{
          "description" =>
            "Returns the current state of the age assurance process for an account. This is used to check if the user has completed age assurance or if further action is required.",
          "output" => %{
            "encoding" => "application/json",
            "schema" => %{
              "ref" => "app.bsky.unspecced.defs#ageAssuranceState",
              "type" => "ref"
            }
          },
          "type" => "query"
        }
      },
      "id" => "app.bsky.unspecced.getAgeAssuranceState",
      "lexicon" => 1
    },
    %{
      "defs" => %{
        "liveNowConfig" => %{
          "properties" => %{
            "did" => %{"format" => "did", "type" => "string"},
            "domains" => %{"items" => %{"type" => "string"}, "type" => "array"}
          },
          "required" => ["did", "domains"],
          "type" => "object"
        },
        "main" => %{
          "description" => "Get miscellaneous runtime configuration.",
          "output" => %{
            "encoding" => "application/json",
            "schema" => %{
              "properties" => %{
                "checkEmailConfirmed" => %{"type" => "boolean"},
                "liveNow" => %{
                  "items" => %{"ref" => "#liveNowConfig", "type" => "ref"},
                  "type" => "array"
                }
              },
              "required" => [],
              "type" => "object"
            }
          },
          "type" => "query"
        }
      },
      "id" => "app.bsky.unspecced.getConfig",
      "lexicon" => 1
    },
    %{
      "defs" => %{
        "main" => %{
          "description" => "Get a list of suggested starterpacks for onboarding",
          "output" => %{
            "encoding" => "application/json",
            "schema" => %{
              "properties" => %{
                "starterPacks" => %{
                  "items" => %{
                    "ref" => "app.bsky.graph.defs#starterPackView",
                    "type" => "ref"
                  },
                  "type" => "array"
                }
              },
              "required" => ["starterPacks"],
              "type" => "object"
            }
          },
          "parameters" => %{
            "properties" => %{
              "limit" => %{
                "default" => 10,
                "maximum" => 25,
                "minimum" => 1,
                "type" => "integer"
              }
            },
            "type" => "params"
          },
          "type" => "query"
        }
      },
      "id" => "app.bsky.unspecced.getOnboardingSuggestedStarterPacks",
      "lexicon" => 1
    },
    %{
      "defs" => %{
        "main" => %{
          "description" =>
            "Get a skeleton of suggested starterpacks for onboarding. Intended to be called and hydrated by app.bsky.unspecced.getOnboardingSuggestedStarterPacks",
          "output" => %{
            "encoding" => "application/json",
            "schema" => %{
              "properties" => %{
                "starterPacks" => %{
                  "items" => %{"format" => "at-uri", "type" => "string"},
                  "type" => "array"
                }
              },
              "required" => ["starterPacks"],
              "type" => "object"
            }
          },
          "parameters" => %{
            "properties" => %{
              "limit" => %{
                "default" => 10,
                "maximum" => 25,
                "minimum" => 1,
                "type" => "integer"
              },
              "viewer" => %{
                "description" =>
                  "DID of the account making the request (not included for public/unauthenticated queries).",
                "format" => "did",
                "type" => "string"
              }
            },
            "type" => "params"
          },
          "type" => "query"
        }
      },
      "id" => "app.bsky.unspecced.getOnboardingSuggestedStarterPacksSkeleton",
      "lexicon" => 1
    },
    %{
      "defs" => %{
        "main" => %{
          "description" =>
            "Get a skeleton of suggested users for onboarding. Intended to be called and hydrated by app.bsky.unspecced.getSuggestedOnboardingUsers",
          "output" => %{
            "encoding" => "application/json",
            "schema" => %{
              "properties" => %{
                "dids" => %{
                  "items" => %{"format" => "did", "type" => "string"},
                  "type" => "array"
                },
                "recId" => %{
                  "description" => "DEPRECATED: use recIdStr instead.",
                  "type" => "string"
                },
                "recIdStr" => %{
                  "description" => "Snowflake for this recommendation, use when submitting recommendation events.",
                  "type" => "string"
                }
              },
              "required" => ["dids"],
              "type" => "object"
            }
          },
          "parameters" => %{
            "properties" => %{
              "category" => %{
                "description" => "Category of users to get suggestions for.",
                "type" => "string"
              },
              "limit" => %{
                "default" => 25,
                "maximum" => 50,
                "minimum" => 1,
                "type" => "integer"
              },
              "viewer" => %{
                "description" =>
                  "DID of the account making the request (not included for public/unauthenticated queries).",
                "format" => "did",
                "type" => "string"
              }
            },
            "type" => "params"
          },
          "type" => "query"
        }
      },
      "id" => "app.bsky.unspecced.getOnboardingSuggestedUsersSkeleton",
      "lexicon" => 1
    },
    %{
      "defs" => %{
        "main" => %{
          "description" => "An unspecced view of globally popular feed generators.",
          "output" => %{
            "encoding" => "application/json",
            "schema" => %{
              "properties" => %{
                "cursor" => %{"type" => "string"},
                "feeds" => %{
                  "items" => %{
                    "ref" => "app.bsky.feed.defs#generatorView",
                    "type" => "ref"
                  },
                  "type" => "array"
                }
              },
              "required" => ["feeds"],
              "type" => "object"
            }
          },
          "parameters" => %{
            "properties" => %{
              "cursor" => %{"type" => "string"},
              "limit" => %{
                "default" => 50,
                "maximum" => 100,
                "minimum" => 1,
                "type" => "integer"
              },
              "query" => %{"type" => "string"}
            },
            "type" => "params"
          },
          "type" => "query"
        }
      },
      "id" => "app.bsky.unspecced.getPopularFeedGenerators",
      "lexicon" => 1
    },
    %{
      "defs" => %{
        "main" => %{
          "description" =>
            "(NOTE: this endpoint is under development and WILL change without notice. Don't use it until it is moved out of `unspecced` or your application WILL break) Get additional posts under a thread e.g. replies hidden by threadgate. Based on an anchor post at any depth of the tree, returns top-level replies below that anchor. It does not include ancestors nor the anchor itself. This should be called after exhausting `app.bsky.unspecced.getPostThreadV2`. Does not require auth, but additional metadata and filtering will be applied for authed requests.",
          "output" => %{
            "encoding" => "application/json",
            "schema" => %{
              "properties" => %{
                "thread" => %{
                  "description" =>
                    "A flat list of other thread items. The depth of each item is indicated by the depth property inside the item.",
                  "items" => %{"ref" => "#threadItem", "type" => "ref"},
                  "type" => "array"
                }
              },
              "required" => ["thread"],
              "type" => "object"
            }
          },
          "parameters" => %{
            "properties" => %{
              "anchor" => %{
                "description" => "Reference (AT-URI) to post record. This is the anchor post.",
                "format" => "at-uri",
                "type" => "string"
              }
            },
            "required" => ["anchor"],
            "type" => "params"
          },
          "type" => "query"
        },
        "threadItem" => %{
          "properties" => %{
            "depth" => %{
              "description" =>
                "The nesting level of this item in the thread. Depth 0 means the anchor item. Items above have negative depths, items below have positive depths.",
              "type" => "integer"
            },
            "uri" => %{"format" => "at-uri", "type" => "string"},
            "value" => %{
              "refs" => ["app.bsky.unspecced.defs#threadItemPost"],
              "type" => "union"
            }
          },
          "required" => ["uri", "depth", "value"],
          "type" => "object"
        }
      },
      "id" => "app.bsky.unspecced.getPostThreadOtherV2",
      "lexicon" => 1
    },
    %{
      "defs" => %{
        "main" => %{
          "description" =>
            "(NOTE: this endpoint is under development and WILL change without notice. Don't use it until it is moved out of `unspecced` or your application WILL break) Get posts in a thread. It is based in an anchor post at any depth of the tree, and returns posts above it (recursively resolving the parent, without further branching to their replies) and below it (recursive replies, with branching to their replies). Does not require auth, but additional metadata and filtering will be applied for authed requests.",
          "output" => %{
            "encoding" => "application/json",
            "schema" => %{
              "properties" => %{
                "hasOtherReplies" => %{
                  "description" =>
                    "Whether this thread has additional replies. If true, a call can be made to the `getPostThreadOtherV2` endpoint to retrieve them.",
                  "type" => "boolean"
                },
                "thread" => %{
                  "description" =>
                    "A flat list of thread items. The depth of each item is indicated by the depth property inside the item.",
                  "items" => %{"ref" => "#threadItem", "type" => "ref"},
                  "type" => "array"
                },
                "threadgate" => %{
                  "ref" => "app.bsky.feed.defs#threadgateView",
                  "type" => "ref"
                }
              },
              "required" => ["thread", "hasOtherReplies"],
              "type" => "object"
            }
          },
          "parameters" => %{
            "properties" => %{
              "above" => %{
                "default" => true,
                "description" => "Whether to include parents above the anchor.",
                "type" => "boolean"
              },
              "anchor" => %{
                "description" =>
                  "Reference (AT-URI) to post record. This is the anchor post, and the thread will be built around it. It can be any post in the tree, not necessarily a root post.",
                "format" => "at-uri",
                "type" => "string"
              },
              "below" => %{
                "default" => 6,
                "description" => "How many levels of replies to include below the anchor.",
                "maximum" => 20,
                "minimum" => 0,
                "type" => "integer"
              },
              "branchingFactor" => %{
                "default" => 10,
                "description" =>
                  "Maximum of replies to include at each level of the thread, except for the direct replies to the anchor, which are (NOTE: currently, during unspecced phase) all returned (NOTE: later they might be paginated).",
                "maximum" => 100,
                "minimum" => 0,
                "type" => "integer"
              },
              "sort" => %{
                "default" => "oldest",
                "description" => "Sorting for the thread replies.",
                "knownValues" => ["newest", "oldest", "top"],
                "type" => "string"
              }
            },
            "required" => ["anchor"],
            "type" => "params"
          },
          "type" => "query"
        },
        "threadItem" => %{
          "properties" => %{
            "depth" => %{
              "description" =>
                "The nesting level of this item in the thread. Depth 0 means the anchor item. Items above have negative depths, items below have positive depths.",
              "type" => "integer"
            },
            "uri" => %{"format" => "at-uri", "type" => "string"},
            "value" => %{
              "refs" => [
                "app.bsky.unspecced.defs#threadItemPost",
                "app.bsky.unspecced.defs#threadItemNoUnauthenticated",
                "app.bsky.unspecced.defs#threadItemNotFound",
                "app.bsky.unspecced.defs#threadItemBlocked"
              ],
              "type" => "union"
            }
          },
          "required" => ["uri", "depth", "value"],
          "type" => "object"
        }
      },
      "id" => "app.bsky.unspecced.getPostThreadV2",
      "lexicon" => 1
    },
    %{
      "defs" => %{
        "main" => %{
          "description" => "Get a list of suggested feeds",
          "output" => %{
            "encoding" => "application/json",
            "schema" => %{
              "properties" => %{
                "feeds" => %{
                  "items" => %{
                    "ref" => "app.bsky.feed.defs#generatorView",
                    "type" => "ref"
                  },
                  "type" => "array"
                }
              },
              "required" => ["feeds"],
              "type" => "object"
            }
          },
          "parameters" => %{
            "properties" => %{
              "limit" => %{
                "default" => 10,
                "maximum" => 25,
                "minimum" => 1,
                "type" => "integer"
              }
            },
            "type" => "params"
          },
          "type" => "query"
        }
      },
      "id" => "app.bsky.unspecced.getSuggestedFeeds",
      "lexicon" => 1
    },
    %{
      "defs" => %{
        "main" => %{
          "description" =>
            "Get a skeleton of suggested feeds. Intended to be called and hydrated by app.bsky.unspecced.getSuggestedFeeds",
          "output" => %{
            "encoding" => "application/json",
            "schema" => %{
              "properties" => %{
                "feeds" => %{
                  "items" => %{"format" => "at-uri", "type" => "string"},
                  "type" => "array"
                }
              },
              "required" => ["feeds"],
              "type" => "object"
            }
          },
          "parameters" => %{
            "properties" => %{
              "limit" => %{
                "default" => 10,
                "maximum" => 25,
                "minimum" => 1,
                "type" => "integer"
              },
              "viewer" => %{
                "description" =>
                  "DID of the account making the request (not included for public/unauthenticated queries).",
                "format" => "did",
                "type" => "string"
              }
            },
            "type" => "params"
          },
          "type" => "query"
        }
      },
      "id" => "app.bsky.unspecced.getSuggestedFeedsSkeleton",
      "lexicon" => 1
    },
    %{
      "defs" => %{
        "main" => %{
          "description" => "Get a list of suggested users for onboarding",
          "output" => %{
            "encoding" => "application/json",
            "schema" => %{
              "properties" => %{
                "actors" => %{
                  "items" => %{
                    "ref" => "app.bsky.actor.defs#profileView",
                    "type" => "ref"
                  },
                  "type" => "array"
                },
                "recId" => %{
                  "description" => "DEPRECATED: use recIdStr instead.",
                  "type" => "string"
                },
                "recIdStr" => %{
                  "description" => "Snowflake for this recommendation, use when submitting recommendation events.",
                  "type" => "string"
                }
              },
              "required" => ["actors"],
              "type" => "object"
            }
          },
          "parameters" => %{
            "properties" => %{
              "category" => %{
                "description" => "Category of users to get suggestions for.",
                "type" => "string"
              },
              "limit" => %{
                "default" => 25,
                "maximum" => 50,
                "minimum" => 1,
                "type" => "integer"
              }
            },
            "type" => "params"
          },
          "type" => "query"
        }
      },
      "id" => "app.bsky.unspecced.getSuggestedOnboardingUsers",
      "lexicon" => 1
    },
    %{
      "defs" => %{
        "main" => %{
          "description" => "Get a list of suggested starterpacks",
          "output" => %{
            "encoding" => "application/json",
            "schema" => %{
              "properties" => %{
                "starterPacks" => %{
                  "items" => %{
                    "ref" => "app.bsky.graph.defs#starterPackView",
                    "type" => "ref"
                  },
                  "type" => "array"
                }
              },
              "required" => ["starterPacks"],
              "type" => "object"
            }
          },
          "parameters" => %{
            "properties" => %{
              "limit" => %{
                "default" => 10,
                "maximum" => 25,
                "minimum" => 1,
                "type" => "integer"
              }
            },
            "type" => "params"
          },
          "type" => "query"
        }
      },
      "id" => "app.bsky.unspecced.getSuggestedStarterPacks",
      "lexicon" => 1
    },
    %{
      "defs" => %{
        "main" => %{
          "description" =>
            "Get a skeleton of suggested starterpacks. Intended to be called and hydrated by app.bsky.unspecced.getSuggestedStarterpacks",
          "output" => %{
            "encoding" => "application/json",
            "schema" => %{
              "properties" => %{
                "starterPacks" => %{
                  "items" => %{"format" => "at-uri", "type" => "string"},
                  "type" => "array"
                }
              },
              "required" => ["starterPacks"],
              "type" => "object"
            }
          },
          "parameters" => %{
            "properties" => %{
              "limit" => %{
                "default" => 10,
                "maximum" => 25,
                "minimum" => 1,
                "type" => "integer"
              },
              "viewer" => %{
                "description" =>
                  "DID of the account making the request (not included for public/unauthenticated queries).",
                "format" => "did",
                "type" => "string"
              }
            },
            "type" => "params"
          },
          "type" => "query"
        }
      },
      "id" => "app.bsky.unspecced.getSuggestedStarterPacksSkeleton",
      "lexicon" => 1
    },
    %{
      "defs" => %{
        "main" => %{
          "description" => "Get a list of suggested users",
          "output" => %{
            "encoding" => "application/json",
            "schema" => %{
              "properties" => %{
                "actors" => %{
                  "items" => %{
                    "ref" => "app.bsky.actor.defs#profileView",
                    "type" => "ref"
                  },
                  "type" => "array"
                },
                "recId" => %{
                  "description" => "DEPRECATED: use recIdStr instead.",
                  "type" => "string"
                },
                "recIdStr" => %{
                  "description" => "Snowflake for this recommendation, use when submitting recommendation events.",
                  "type" => "string"
                }
              },
              "required" => ["actors"],
              "type" => "object"
            }
          },
          "parameters" => %{
            "properties" => %{
              "category" => %{
                "description" => "Category of users to get suggestions for.",
                "type" => "string"
              },
              "limit" => %{
                "default" => 25,
                "maximum" => 50,
                "minimum" => 1,
                "type" => "integer"
              }
            },
            "type" => "params"
          },
          "type" => "query"
        }
      },
      "id" => "app.bsky.unspecced.getSuggestedUsers",
      "lexicon" => 1
    },
    %{
      "defs" => %{
        "main" => %{
          "description" => "Get a list of suggested users for the Discover page",
          "output" => %{
            "encoding" => "application/json",
            "schema" => %{
              "properties" => %{
                "actors" => %{
                  "items" => %{
                    "ref" => "app.bsky.actor.defs#profileView",
                    "type" => "ref"
                  },
                  "type" => "array"
                },
                "recIdStr" => %{
                  "description" => "Snowflake for this recommendation, use when submitting recommendation events.",
                  "type" => "string"
                }
              },
              "required" => ["actors"],
              "type" => "object"
            }
          },
          "parameters" => %{
            "properties" => %{
              "limit" => %{
                "default" => 25,
                "maximum" => 50,
                "minimum" => 1,
                "type" => "integer"
              }
            },
            "type" => "params"
          },
          "type" => "query"
        }
      },
      "id" => "app.bsky.unspecced.getSuggestedUsersForDiscover",
      "lexicon" => 1
    },
    %{
      "defs" => %{
        "main" => %{
          "description" =>
            "Get a skeleton of suggested users for the Discover page. Intended to be called and hydrated by app.bsky.unspecced.getSuggestedUsersForDiscover",
          "output" => %{
            "encoding" => "application/json",
            "schema" => %{
              "properties" => %{
                "dids" => %{
                  "items" => %{"format" => "did", "type" => "string"},
                  "type" => "array"
                },
                "recIdStr" => %{
                  "description" => "Snowflake for this recommendation, use when submitting recommendation events.",
                  "type" => "string"
                }
              },
              "required" => ["dids"],
              "type" => "object"
            }
          },
          "parameters" => %{
            "properties" => %{
              "limit" => %{
                "default" => 25,
                "maximum" => 50,
                "minimum" => 1,
                "type" => "integer"
              },
              "viewer" => %{
                "description" =>
                  "DID of the account making the request (not included for public/unauthenticated queries).",
                "format" => "did",
                "type" => "string"
              }
            },
            "type" => "params"
          },
          "type" => "query"
        }
      },
      "id" => "app.bsky.unspecced.getSuggestedUsersForDiscoverSkeleton",
      "lexicon" => 1
    },
    %{
      "defs" => %{
        "main" => %{
          "description" => "Get a list of suggested users for the Explore page",
          "output" => %{
            "encoding" => "application/json",
            "schema" => %{
              "properties" => %{
                "actors" => %{
                  "items" => %{
                    "ref" => "app.bsky.actor.defs#profileView",
                    "type" => "ref"
                  },
                  "type" => "array"
                },
                "recIdStr" => %{
                  "description" => "Snowflake for this recommendation, use when submitting recommendation events.",
                  "type" => "string"
                }
              },
              "required" => ["actors"],
              "type" => "object"
            }
          },
          "parameters" => %{
            "properties" => %{
              "category" => %{
                "description" => "Category of users to get suggestions for.",
                "type" => "string"
              },
              "limit" => %{
                "default" => 25,
                "maximum" => 50,
                "minimum" => 1,
                "type" => "integer"
              }
            },
            "type" => "params"
          },
          "type" => "query"
        }
      },
      "id" => "app.bsky.unspecced.getSuggestedUsersForExplore",
      "lexicon" => 1
    },
    %{
      "defs" => %{
        "main" => %{
          "description" =>
            "Get a skeleton of suggested users for the Explore page. Intended to be called and hydrated by app.bsky.unspecced.getSuggestedUsersForExplore",
          "output" => %{
            "encoding" => "application/json",
            "schema" => %{
              "properties" => %{
                "dids" => %{
                  "items" => %{"format" => "did", "type" => "string"},
                  "type" => "array"
                },
                "recIdStr" => %{
                  "description" => "Snowflake for this recommendation, use when submitting recommendation events.",
                  "type" => "string"
                }
              },
              "required" => ["dids"],
              "type" => "object"
            }
          },
          "parameters" => %{
            "properties" => %{
              "category" => %{
                "description" => "Category of users to get suggestions for.",
                "type" => "string"
              },
              "limit" => %{
                "default" => 25,
                "maximum" => 50,
                "minimum" => 1,
                "type" => "integer"
              },
              "viewer" => %{
                "description" =>
                  "DID of the account making the request (not included for public/unauthenticated queries).",
                "format" => "did",
                "type" => "string"
              }
            },
            "type" => "params"
          },
          "type" => "query"
        }
      },
      "id" => "app.bsky.unspecced.getSuggestedUsersForExploreSkeleton",
      "lexicon" => 1
    },
    %{
      "defs" => %{
        "main" => %{
          "description" => "Get a list of suggested users for the See More page",
          "output" => %{
            "encoding" => "application/json",
            "schema" => %{
              "properties" => %{
                "actors" => %{
                  "items" => %{
                    "ref" => "app.bsky.actor.defs#profileView",
                    "type" => "ref"
                  },
                  "type" => "array"
                },
                "recIdStr" => %{
                  "description" => "Snowflake for this recommendation, use when submitting recommendation events.",
                  "type" => "string"
                }
              },
              "required" => ["actors"],
              "type" => "object"
            }
          },
          "parameters" => %{
            "properties" => %{
              "category" => %{
                "description" => "Category of users to get suggestions for.",
                "type" => "string"
              },
              "limit" => %{
                "default" => 25,
                "maximum" => 50,
                "minimum" => 1,
                "type" => "integer"
              }
            },
            "type" => "params"
          },
          "type" => "query"
        }
      },
      "id" => "app.bsky.unspecced.getSuggestedUsersForSeeMore",
      "lexicon" => 1
    },
    %{
      "defs" => %{
        "main" => %{
          "description" =>
            "Get a skeleton of suggested users for the See More page. Intended to be called and hydrated by app.bsky.unspecced.getSuggestedUsersForSeeMore",
          "output" => %{
            "encoding" => "application/json",
            "schema" => %{
              "properties" => %{
                "dids" => %{
                  "items" => %{"format" => "did", "type" => "string"},
                  "type" => "array"
                },
                "recIdStr" => %{
                  "description" => "Snowflake for this recommendation, use when submitting recommendation events.",
                  "type" => "string"
                }
              },
              "required" => ["dids"],
              "type" => "object"
            }
          },
          "parameters" => %{
            "properties" => %{
              "category" => %{
                "description" => "Category of users to get suggestions for.",
                "type" => "string"
              },
              "limit" => %{
                "default" => 25,
                "maximum" => 50,
                "minimum" => 1,
                "type" => "integer"
              },
              "viewer" => %{
                "description" =>
                  "DID of the account making the request (not included for public/unauthenticated queries).",
                "format" => "did",
                "type" => "string"
              }
            },
            "type" => "params"
          },
          "type" => "query"
        }
      },
      "id" => "app.bsky.unspecced.getSuggestedUsersForSeeMoreSkeleton",
      "lexicon" => 1
    },
    %{
      "defs" => %{
        "main" => %{
          "description" =>
            "Get a skeleton of suggested users. Intended to be called and hydrated by app.bsky.unspecced.getSuggestedUsers",
          "output" => %{
            "encoding" => "application/json",
            "schema" => %{
              "properties" => %{
                "dids" => %{
                  "items" => %{"format" => "did", "type" => "string"},
                  "type" => "array"
                },
                "recId" => %{
                  "description" => "DEPRECATED: use recIdStr instead.",
                  "type" => "string"
                },
                "recIdStr" => %{
                  "description" => "Snowflake for this recommendation, use when submitting recommendation events.",
                  "type" => "string"
                }
              },
              "required" => ["dids"],
              "type" => "object"
            }
          },
          "parameters" => %{
            "properties" => %{
              "category" => %{
                "description" => "Category of users to get suggestions for.",
                "type" => "string"
              },
              "limit" => %{
                "default" => 25,
                "maximum" => 50,
                "minimum" => 1,
                "type" => "integer"
              },
              "viewer" => %{
                "description" =>
                  "DID of the account making the request (not included for public/unauthenticated queries).",
                "format" => "did",
                "type" => "string"
              }
            },
            "type" => "params"
          },
          "type" => "query"
        }
      },
      "id" => "app.bsky.unspecced.getSuggestedUsersSkeleton",
      "lexicon" => 1
    },
    %{
      "defs" => %{
        "main" => %{
          "description" =>
            "Get a skeleton of suggested actors. Intended to be called and then hydrated through app.bsky.actor.getSuggestions",
          "output" => %{
            "encoding" => "application/json",
            "schema" => %{
              "properties" => %{
                "actors" => %{
                  "items" => %{
                    "ref" => "app.bsky.unspecced.defs#skeletonSearchActor",
                    "type" => "ref"
                  },
                  "type" => "array"
                },
                "cursor" => %{"type" => "string"},
                "recId" => %{
                  "description" => "DEPRECATED: use recIdStr instead.",
                  "type" => "integer"
                },
                "recIdStr" => %{
                  "description" => "Snowflake for this recommendation, use when submitting recommendation events.",
                  "type" => "string"
                },
                "relativeToDid" => %{
                  "description" =>
                    "DID of the account these suggestions are relative to. If this is returned undefined, suggestions are based on the viewer.",
                  "format" => "did",
                  "type" => "string"
                }
              },
              "required" => ["actors"],
              "type" => "object"
            }
          },
          "parameters" => %{
            "properties" => %{
              "cursor" => %{"type" => "string"},
              "limit" => %{
                "default" => 50,
                "maximum" => 100,
                "minimum" => 1,
                "type" => "integer"
              },
              "relativeToDid" => %{
                "description" =>
                  "DID of the account to get suggestions relative to. If not provided, suggestions will be based on the viewer.",
                "format" => "did",
                "type" => "string"
              },
              "viewer" => %{
                "description" =>
                  "DID of the account making the request (not included for public/unauthenticated queries). Used to boost followed accounts in ranking.",
                "format" => "did",
                "type" => "string"
              }
            },
            "type" => "params"
          },
          "type" => "query"
        }
      },
      "id" => "app.bsky.unspecced.getSuggestionsSkeleton",
      "lexicon" => 1
    },
    %{
      "defs" => %{
        "main" => %{
          "description" => "Get a list of suggestions (feeds and users) tagged with categories",
          "output" => %{
            "encoding" => "application/json",
            "schema" => %{
              "properties" => %{
                "suggestions" => %{
                  "items" => %{"ref" => "#suggestion", "type" => "ref"},
                  "type" => "array"
                }
              },
              "required" => ["suggestions"],
              "type" => "object"
            }
          },
          "parameters" => %{"properties" => %{}, "type" => "params"},
          "type" => "query"
        },
        "suggestion" => %{
          "properties" => %{
            "subject" => %{"format" => "uri", "type" => "string"},
            "subjectType" => %{
              "knownValues" => ["actor", "feed"],
              "type" => "string"
            },
            "tag" => %{"type" => "string"}
          },
          "required" => ["tag", "subjectType", "subject"],
          "type" => "object"
        }
      },
      "id" => "app.bsky.unspecced.getTaggedSuggestions",
      "lexicon" => 1
    },
    %{
      "defs" => %{
        "main" => %{
          "description" => "Get a list of trending topics",
          "output" => %{
            "encoding" => "application/json",
            "schema" => %{
              "properties" => %{
                "suggested" => %{
                  "items" => %{
                    "ref" => "app.bsky.unspecced.defs#trendingTopic",
                    "type" => "ref"
                  },
                  "type" => "array"
                },
                "topics" => %{
                  "items" => %{
                    "ref" => "app.bsky.unspecced.defs#trendingTopic",
                    "type" => "ref"
                  },
                  "type" => "array"
                }
              },
              "required" => ["topics", "suggested"],
              "type" => "object"
            }
          },
          "parameters" => %{
            "properties" => %{
              "limit" => %{
                "default" => 10,
                "maximum" => 25,
                "minimum" => 1,
                "type" => "integer"
              },
              "viewer" => %{
                "description" =>
                  "DID of the account making the request (not included for public/unauthenticated queries). Used to boost followed accounts in ranking.",
                "format" => "did",
                "type" => "string"
              }
            },
            "type" => "params"
          },
          "type" => "query"
        }
      },
      "id" => "app.bsky.unspecced.getTrendingTopics",
      "lexicon" => 1
    },
    %{
      "defs" => %{
        "main" => %{
          "description" => "Get the current trends on the network",
          "output" => %{
            "encoding" => "application/json",
            "schema" => %{
              "properties" => %{
                "trends" => %{
                  "items" => %{
                    "ref" => "app.bsky.unspecced.defs#trendView",
                    "type" => "ref"
                  },
                  "type" => "array"
                }
              },
              "required" => ["trends"],
              "type" => "object"
            }
          },
          "parameters" => %{
            "properties" => %{
              "limit" => %{
                "default" => 10,
                "maximum" => 25,
                "minimum" => 1,
                "type" => "integer"
              }
            },
            "type" => "params"
          },
          "type" => "query"
        }
      },
      "id" => "app.bsky.unspecced.getTrends",
      "lexicon" => 1
    },
    %{
      "defs" => %{
        "main" => %{
          "description" =>
            "Get the skeleton of trends on the network. Intended to be called and then hydrated through app.bsky.unspecced.getTrends",
          "output" => %{
            "encoding" => "application/json",
            "schema" => %{
              "properties" => %{
                "trends" => %{
                  "items" => %{
                    "ref" => "app.bsky.unspecced.defs#skeletonTrend",
                    "type" => "ref"
                  },
                  "type" => "array"
                }
              },
              "required" => ["trends"],
              "type" => "object"
            }
          },
          "parameters" => %{
            "properties" => %{
              "limit" => %{
                "default" => 10,
                "maximum" => 25,
                "minimum" => 1,
                "type" => "integer"
              },
              "viewer" => %{
                "description" =>
                  "DID of the account making the request (not included for public/unauthenticated queries).",
                "format" => "did",
                "type" => "string"
              }
            },
            "type" => "params"
          },
          "type" => "query"
        }
      },
      "id" => "app.bsky.unspecced.getTrendsSkeleton",
      "lexicon" => 1
    },
    %{
      "defs" => %{
        "main" => %{
          "description" =>
            "Initiate age assurance for an account. This is a one-time action that will start the process of verifying the user's age.",
          "errors" => [
            %{"name" => "InvalidEmail"},
            %{"name" => "DidTooLong"},
            %{"name" => "InvalidInitiation"}
          ],
          "input" => %{
            "encoding" => "application/json",
            "schema" => %{
              "properties" => %{
                "countryCode" => %{
                  "description" => "An ISO 3166-1 alpha-2 code of the user's location.",
                  "type" => "string"
                },
                "email" => %{
                  "description" => "The user's email address to receive assurance instructions.",
                  "type" => "string"
                },
                "language" => %{
                  "description" => "The user's preferred language for communication during the assurance process.",
                  "type" => "string"
                }
              },
              "required" => ["email", "language", "countryCode"],
              "type" => "object"
            }
          },
          "output" => %{
            "encoding" => "application/json",
            "schema" => %{
              "ref" => "app.bsky.unspecced.defs#ageAssuranceState",
              "type" => "ref"
            }
          },
          "type" => "procedure"
        }
      },
      "id" => "app.bsky.unspecced.initAgeAssurance",
      "lexicon" => 1
    },
    %{
      "defs" => %{
        "main" => %{
          "description" => "Backend Actors (profile) search, returns only skeleton.",
          "errors" => [%{"name" => "BadQueryString"}],
          "output" => %{
            "encoding" => "application/json",
            "schema" => %{
              "properties" => %{
                "actors" => %{
                  "items" => %{
                    "ref" => "app.bsky.unspecced.defs#skeletonSearchActor",
                    "type" => "ref"
                  },
                  "type" => "array"
                },
                "cursor" => %{"type" => "string"},
                "hitsTotal" => %{
                  "description" =>
                    "Count of search hits. Optional, may be rounded/truncated, and may not be possible to paginate through all hits.",
                  "type" => "integer"
                }
              },
              "required" => ["actors"],
              "type" => "object"
            }
          },
          "parameters" => %{
            "properties" => %{
              "cursor" => %{
                "description" =>
                  "Optional pagination mechanism; may not necessarily allow scrolling through entire result set.",
                "type" => "string"
              },
              "limit" => %{
                "default" => 25,
                "maximum" => 100,
                "minimum" => 1,
                "type" => "integer"
              },
              "q" => %{
                "description" =>
                  "Search query string; syntax, phrase, boolean, and faceting is unspecified, but Lucene query syntax is recommended. For typeahead search, only simple term match is supported, not full syntax.",
                "type" => "string"
              },
              "typeahead" => %{
                "description" => "If true, acts as fast/simple 'typeahead' query.",
                "type" => "boolean"
              },
              "viewer" => %{
                "description" =>
                  "DID of the account making the request (not included for public/unauthenticated queries). Used to boost followed accounts in ranking.",
                "format" => "did",
                "type" => "string"
              }
            },
            "required" => ["q"],
            "type" => "params"
          },
          "type" => "query"
        }
      },
      "id" => "app.bsky.unspecced.searchActorsSkeleton",
      "lexicon" => 1
    },
    %{
      "defs" => %{
        "main" => %{
          "description" => "Backend Posts search, returns only skeleton",
          "errors" => [%{"name" => "BadQueryString"}],
          "output" => %{
            "encoding" => "application/json",
            "schema" => %{
              "properties" => %{
                "cursor" => %{"type" => "string"},
                "hitsTotal" => %{
                  "description" =>
                    "Count of search hits. Optional, may be rounded/truncated, and may not be possible to paginate through all hits.",
                  "type" => "integer"
                },
                "posts" => %{
                  "items" => %{
                    "ref" => "app.bsky.unspecced.defs#skeletonSearchPost",
                    "type" => "ref"
                  },
                  "type" => "array"
                }
              },
              "required" => ["posts"],
              "type" => "object"
            }
          },
          "parameters" => %{
            "properties" => %{
              "author" => %{
                "description" => "Filter to posts by the given account. Handles are resolved to DID before query-time.",
                "format" => "at-identifier",
                "type" => "string"
              },
              "cursor" => %{
                "description" =>
                  "Optional pagination mechanism; may not necessarily allow scrolling through entire result set.",
                "type" => "string"
              },
              "domain" => %{
                "description" =>
                  "Filter to posts with URLs (facet links or embeds) linking to the given domain (hostname). Server may apply hostname normalization.",
                "type" => "string"
              },
              "lang" => %{
                "description" =>
                  "Filter to posts in the given language. Expected to be based on post language field, though server may override language detection.",
                "format" => "language",
                "type" => "string"
              },
              "limit" => %{
                "default" => 25,
                "maximum" => 100,
                "minimum" => 1,
                "type" => "integer"
              },
              "mentions" => %{
                "description" =>
                  "Filter to posts which mention the given account. Handles are resolved to DID before query-time. Only matches rich-text facet mentions.",
                "format" => "at-identifier",
                "type" => "string"
              },
              "q" => %{
                "description" =>
                  "Search query string; syntax, phrase, boolean, and faceting is unspecified, but Lucene query syntax is recommended.",
                "type" => "string"
              },
              "since" => %{
                "description" =>
                  "Filter results for posts after the indicated datetime (inclusive). Expected to use 'sortAt' timestamp, which may not match 'createdAt'. Can be a datetime, or just an ISO date (YYYY-MM-DD).",
                "type" => "string"
              },
              "sort" => %{
                "default" => "latest",
                "description" => "Specifies the ranking order of results.",
                "knownValues" => ["top", "latest"],
                "type" => "string"
              },
              "tag" => %{
                "description" =>
                  "Filter to posts with the given tag (hashtag), based on rich-text facet or tag field. Do not include the hash (#) prefix. Multiple tags can be specified, with 'AND' matching.",
                "items" => %{
                  "maxGraphemes" => 64,
                  "maxLength" => 640,
                  "type" => "string"
                },
                "type" => "array"
              },
              "until" => %{
                "description" =>
                  "Filter results for posts before the indicated datetime (not inclusive). Expected to use 'sortAt' timestamp, which may not match 'createdAt'. Can be a datetime, or just an ISO date (YYY-MM-DD).",
                "type" => "string"
              },
              "url" => %{
                "description" =>
                  "Filter to posts with links (facet links or embeds) pointing to this URL. Server may apply URL normalization or fuzzy matching.",
                "format" => "uri",
                "type" => "string"
              },
              "viewer" => %{
                "description" =>
                  "DID of the account making the request (not included for public/unauthenticated queries). Used for 'from:me' queries.",
                "format" => "did",
                "type" => "string"
              }
            },
            "required" => ["q"],
            "type" => "params"
          },
          "type" => "query"
        }
      },
      "id" => "app.bsky.unspecced.searchPostsSkeleton",
      "lexicon" => 1
    },
    %{
      "defs" => %{
        "main" => %{
          "description" => "Backend Starter Pack search, returns only skeleton.",
          "errors" => [%{"name" => "BadQueryString"}],
          "output" => %{
            "encoding" => "application/json",
            "schema" => %{
              "properties" => %{
                "cursor" => %{"type" => "string"},
                "hitsTotal" => %{
                  "description" =>
                    "Count of search hits. Optional, may be rounded/truncated, and may not be possible to paginate through all hits.",
                  "type" => "integer"
                },
                "starterPacks" => %{
                  "items" => %{
                    "ref" => "app.bsky.unspecced.defs#skeletonSearchStarterPack",
                    "type" => "ref"
                  },
                  "type" => "array"
                }
              },
              "required" => ["starterPacks"],
              "type" => "object"
            }
          },
          "parameters" => %{
            "properties" => %{
              "cursor" => %{
                "description" =>
                  "Optional pagination mechanism; may not necessarily allow scrolling through entire result set.",
                "type" => "string"
              },
              "limit" => %{
                "default" => 25,
                "maximum" => 100,
                "minimum" => 1,
                "type" => "integer"
              },
              "q" => %{
                "description" =>
                  "Search query string; syntax, phrase, boolean, and faceting is unspecified, but Lucene query syntax is recommended.",
                "type" => "string"
              },
              "viewer" => %{
                "description" =>
                  "DID of the account making the request (not included for public/unauthenticated queries).",
                "format" => "did",
                "type" => "string"
              }
            },
            "required" => ["q"],
            "type" => "params"
          },
          "type" => "query"
        }
      },
      "id" => "app.bsky.unspecced.searchStarterPacksSkeleton",
      "lexicon" => 1
    },
    %{
      "defs" => %{
        "jobStatus" => %{
          "properties" => %{
            "blob" => %{"type" => "blob"},
            "did" => %{"format" => "did", "type" => "string"},
            "error" => %{"type" => "string"},
            "jobId" => %{"type" => "string"},
            "message" => %{"type" => "string"},
            "progress" => %{
              "description" => "Progress within the current processing state.",
              "maximum" => 100,
              "minimum" => 0,
              "type" => "integer"
            },
            "state" => %{
              "description" =>
                "The state of the video processing job. All values not listed as a known value indicate that the job is in process.",
              "knownValues" => ["JOB_STATE_COMPLETED", "JOB_STATE_FAILED"],
              "type" => "string"
            }
          },
          "required" => ["jobId", "did", "state"],
          "type" => "object"
        }
      },
      "id" => "app.bsky.video.defs",
      "lexicon" => 1
    },
    %{
      "defs" => %{
        "main" => %{
          "description" => "Get status details for a video processing job.",
          "output" => %{
            "encoding" => "application/json",
            "schema" => %{
              "properties" => %{
                "jobStatus" => %{
                  "ref" => "app.bsky.video.defs#jobStatus",
                  "type" => "ref"
                }
              },
              "required" => ["jobStatus"],
              "type" => "object"
            }
          },
          "parameters" => %{
            "properties" => %{"jobId" => %{"type" => "string"}},
            "required" => ["jobId"],
            "type" => "params"
          },
          "type" => "query"
        }
      },
      "id" => "app.bsky.video.getJobStatus",
      "lexicon" => 1
    },
    %{
      "defs" => %{
        "main" => %{
          "description" => "Get video upload limits for the authenticated user.",
          "output" => %{
            "encoding" => "application/json",
            "schema" => %{
              "properties" => %{
                "canUpload" => %{"type" => "boolean"},
                "error" => %{"type" => "string"},
                "message" => %{"type" => "string"},
                "remainingDailyBytes" => %{"type" => "integer"},
                "remainingDailyVideos" => %{"type" => "integer"}
              },
              "required" => ["canUpload"],
              "type" => "object"
            }
          },
          "type" => "query"
        }
      },
      "id" => "app.bsky.video.getUploadLimits",
      "lexicon" => 1
    },
    %{
      "defs" => %{
        "main" => %{
          "description" => "Upload a video to be processed then stored on the PDS.",
          "input" => %{"encoding" => "video/mp4"},
          "output" => %{
            "encoding" => "application/json",
            "schema" => %{
              "properties" => %{
                "jobStatus" => %{
                  "ref" => "app.bsky.video.defs#jobStatus",
                  "type" => "ref"
                }
              },
              "required" => ["jobStatus"],
              "type" => "object"
            }
          },
          "type" => "procedure"
        }
      },
      "id" => "app.bsky.video.uploadVideo",
      "lexicon" => 1
    },
    %{
      "defs" => %{
        "main" => %{
          "description" =>
            "Describe the credentials that should be included in the DID doc of an account that is migrating to this service.",
          "output" => %{
            "encoding" => "application/json",
            "schema" => %{
              "properties" => %{
                "alsoKnownAs" => %{
                  "items" => %{"type" => "string"},
                  "type" => "array"
                },
                "rotationKeys" => %{
                  "description" =>
                    "Recommended rotation keys for PLC dids. Should be undefined (or ignored) for did:webs.",
                  "items" => %{"type" => "string"},
                  "type" => "array"
                },
                "services" => %{"type" => "unknown"},
                "verificationMethods" => %{"type" => "unknown"}
              },
              "type" => "object"
            }
          },
          "type" => "query"
        }
      },
      "id" => "com.atproto.identity.getRecommendedDidCredentials",
      "lexicon" => 1
    },
    %{
      "defs" => %{
        "main" => %{
          "description" => "Request an email with a code to in order to request a signed PLC operation. Requires Auth.",
          "type" => "procedure"
        }
      },
      "id" => "com.atproto.identity.requestPlcOperationSignature",
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
          "description" => "Signs a PLC operation to update some value(s) in the requesting DID's document.",
          "input" => %{
            "encoding" => "application/json",
            "schema" => %{
              "properties" => %{
                "alsoKnownAs" => %{
                  "items" => %{"type" => "string"},
                  "type" => "array"
                },
                "rotationKeys" => %{
                  "items" => %{"type" => "string"},
                  "type" => "array"
                },
                "services" => %{"type" => "unknown"},
                "token" => %{
                  "description" => "A token received through com.atproto.identity.requestPlcOperationSignature",
                  "type" => "string"
                },
                "verificationMethods" => %{"type" => "unknown"}
              },
              "type" => "object"
            }
          },
          "output" => %{
            "encoding" => "application/json",
            "schema" => %{
              "properties" => %{
                "operation" => %{
                  "description" => "A signed DID PLC operation.",
                  "type" => "unknown"
                }
              },
              "required" => ["operation"],
              "type" => "object"
            }
          },
          "type" => "procedure"
        }
      },
      "id" => "com.atproto.identity.signPlcOperation",
      "lexicon" => 1
    },
    %{
      "defs" => %{
        "main" => %{
          "description" =>
            "Validates a PLC operation to ensure that it doesn't violate a service's constraints or get the identity into a bad state, then submits it to the PLC registry",
          "input" => %{
            "encoding" => "application/json",
            "schema" => %{
              "properties" => %{"operation" => %{"type" => "unknown"}},
              "required" => ["operation"],
              "type" => "object"
            }
          },
          "type" => "procedure"
        }
      },
      "id" => "com.atproto.identity.submitPlcOperation",
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
        "reasonAppeal" => %{
          "description" => "Appeal a previously taken moderation action",
          "type" => "token"
        },
        "reasonMisleading" => %{
          "description" =>
            "Misleading identity, affiliation, or content. Prefer new lexicon definition `tools.ozone.report.defs#reasonMisleadingOther`.",
          "type" => "token"
        },
        "reasonOther" => %{
          "description" =>
            "Reports not falling under another report category. Prefer new lexicon definition `tools.ozone.report.defs#reasonOther`.",
          "type" => "token"
        },
        "reasonRude" => %{
          "description" =>
            "Rude, harassing, explicit, or otherwise unwelcoming behavior. Prefer new lexicon definition `tools.ozone.report.defs#reasonHarassmentOther`.",
          "type" => "token"
        },
        "reasonSexual" => %{
          "description" =>
            "Unwanted or mislabeled sexual content. Prefer new lexicon definition `tools.ozone.report.defs#reasonSexualUnlabeled`.",
          "type" => "token"
        },
        "reasonSpam" => %{
          "description" =>
            "Spam: frequent unwanted promotion, replies, mentions. Prefer new lexicon definition `tools.ozone.report.defs#reasonMisleadingSpam`.",
          "type" => "token"
        },
        "reasonType" => %{
          "knownValues" => [
            "com.atproto.moderation.defs#reasonSpam",
            "com.atproto.moderation.defs#reasonViolation",
            "com.atproto.moderation.defs#reasonMisleading",
            "com.atproto.moderation.defs#reasonSexual",
            "com.atproto.moderation.defs#reasonRude",
            "com.atproto.moderation.defs#reasonOther",
            "com.atproto.moderation.defs#reasonAppeal",
            "tools.ozone.report.defs#reasonAppeal",
            "tools.ozone.report.defs#reasonOther",
            "tools.ozone.report.defs#reasonViolenceAnimal",
            "tools.ozone.report.defs#reasonViolenceThreats",
            "tools.ozone.report.defs#reasonViolenceGraphicContent",
            "tools.ozone.report.defs#reasonViolenceGlorification",
            "tools.ozone.report.defs#reasonViolenceExtremistContent",
            "tools.ozone.report.defs#reasonViolenceTrafficking",
            "tools.ozone.report.defs#reasonViolenceOther",
            "tools.ozone.report.defs#reasonSexualAbuseContent",
            "tools.ozone.report.defs#reasonSexualNCII",
            "tools.ozone.report.defs#reasonSexualDeepfake",
            "tools.ozone.report.defs#reasonSexualAnimal",
            "tools.ozone.report.defs#reasonSexualUnlabeled",
            "tools.ozone.report.defs#reasonSexualOther",
            "tools.ozone.report.defs#reasonChildSafetyCSAM",
            "tools.ozone.report.defs#reasonChildSafetyGroom",
            "tools.ozone.report.defs#reasonChildSafetyPrivacy",
            "tools.ozone.report.defs#reasonChildSafetyHarassment",
            "tools.ozone.report.defs#reasonChildSafetyOther",
            "tools.ozone.report.defs#reasonHarassmentTroll",
            "tools.ozone.report.defs#reasonHarassmentTargeted",
            "tools.ozone.report.defs#reasonHarassmentHateSpeech",
            "tools.ozone.report.defs#reasonHarassmentDoxxing",
            "tools.ozone.report.defs#reasonHarassmentOther",
            "tools.ozone.report.defs#reasonMisleadingBot",
            "tools.ozone.report.defs#reasonMisleadingImpersonation",
            "tools.ozone.report.defs#reasonMisleadingSpam",
            "tools.ozone.report.defs#reasonMisleadingScam",
            "tools.ozone.report.defs#reasonMisleadingElections",
            "tools.ozone.report.defs#reasonMisleadingOther",
            "tools.ozone.report.defs#reasonRuleSiteSecurity",
            "tools.ozone.report.defs#reasonRuleProhibitedSales",
            "tools.ozone.report.defs#reasonRuleBanEvasion",
            "tools.ozone.report.defs#reasonRuleOther",
            "tools.ozone.report.defs#reasonSelfHarmContent",
            "tools.ozone.report.defs#reasonSelfHarmED",
            "tools.ozone.report.defs#reasonSelfHarmStunts",
            "tools.ozone.report.defs#reasonSelfHarmSubstances",
            "tools.ozone.report.defs#reasonSelfHarmOther"
          ],
          "type" => "string"
        },
        "reasonViolation" => %{
          "description" =>
            "Direct violation of server rules, laws, terms of service. Prefer new lexicon definition `tools.ozone.report.defs#reasonRuleOther`.",
          "type" => "token"
        },
        "subjectType" => %{
          "description" => "Tag describing a type of subject that might be reported.",
          "knownValues" => ["account", "record", "chat"],
          "type" => "string"
        }
      },
      "id" => "com.atproto.moderation.defs",
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
          "description" => "Import a repo in the form of a CAR file. Requires Content-Length HTTP header to be set.",
          "input" => %{"encoding" => "application/vnd.ipld.car"},
          "type" => "procedure"
        }
      },
      "id" => "com.atproto.repo.importRepo",
      "lexicon" => 1
    },
    %{
      "defs" => %{
        "main" => %{
          "description" =>
            "Returns a list of missing blobs for the requesting account. Intended to be used in the account migration flow.",
          "output" => %{
            "encoding" => "application/json",
            "schema" => %{
              "properties" => %{
                "blobs" => %{
                  "items" => %{"ref" => "#recordBlob", "type" => "ref"},
                  "type" => "array"
                },
                "cursor" => %{"type" => "string"}
              },
              "required" => ["blobs"],
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
        "recordBlob" => %{
          "properties" => %{
            "cid" => %{"format" => "cid", "type" => "string"},
            "recordUri" => %{"format" => "at-uri", "type" => "string"}
          },
          "required" => ["cid", "recordUri"],
          "type" => "object"
        }
      },
      "id" => "com.atproto.repo.listMissingBlobs",
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
          "description" =>
            "Activates a currently deactivated account. Used to finalize account migration after the account's repo is imported and identity is setup.",
          "type" => "procedure"
        }
      },
      "id" => "com.atproto.server.activateAccount",
      "lexicon" => 1
    },
    %{
      "defs" => %{
        "main" => %{
          "description" =>
            "Returns the status of an account, especially as pertaining to import or recovery. Can be called many times over the course of an account migration. Requires auth and can only be called pertaining to oneself.",
          "output" => %{
            "encoding" => "application/json",
            "schema" => %{
              "properties" => %{
                "activated" => %{"type" => "boolean"},
                "expectedBlobs" => %{"type" => "integer"},
                "importedBlobs" => %{"type" => "integer"},
                "indexedRecords" => %{"type" => "integer"},
                "privateStateValues" => %{"type" => "integer"},
                "repoBlocks" => %{"type" => "integer"},
                "repoCommit" => %{"format" => "cid", "type" => "string"},
                "repoRev" => %{"type" => "string"},
                "validDid" => %{"type" => "boolean"}
              },
              "required" => [
                "activated",
                "validDid",
                "repoCommit",
                "repoRev",
                "repoBlocks",
                "indexedRecords",
                "privateStateValues",
                "expectedBlobs",
                "importedBlobs"
              ],
              "type" => "object"
            }
          },
          "type" => "query"
        }
      },
      "id" => "com.atproto.server.checkAccountStatus",
      "lexicon" => 1
    },
    %{
      "defs" => %{
        "main" => %{
          "description" => "Confirm an email using a token from com.atproto.server.requestEmailConfirmation.",
          "errors" => [
            %{"name" => "AccountNotFound"},
            %{"name" => "ExpiredToken"},
            %{"name" => "InvalidToken"},
            %{"name" => "InvalidEmail"}
          ],
          "input" => %{
            "encoding" => "application/json",
            "schema" => %{
              "properties" => %{
                "email" => %{"type" => "string"},
                "token" => %{"type" => "string"}
              },
              "required" => ["email", "token"],
              "type" => "object"
            }
          },
          "type" => "procedure"
        }
      },
      "id" => "com.atproto.server.confirmEmail",
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
          "description" => "Create an app password. The secret is returned once.",
          "input" => %{
            "encoding" => "application/json",
            "schema" => %{
              "properties" => %{
                "name" => %{"type" => "string"},
                "scope" => %{"type" => "string"}
              },
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
          "description" =>
            "Deactivates a currently active account. Stops serving of repo, and future writes to repo until reactivated. Used to finalize account migration with the old host after the account has been activated on the new host.",
          "input" => %{
            "encoding" => "application/json",
            "schema" => %{
              "properties" => %{
                "deleteAfter" => %{
                  "description" =>
                    "A recommendation to server as to how long they should hold onto the deactivated account before deleting.",
                  "format" => "datetime",
                  "type" => "string"
                }
              },
              "type" => "object"
            }
          },
          "type" => "procedure"
        }
      },
      "id" => "com.atproto.server.deactivateAccount",
      "lexicon" => 1
    },
    %{
      "defs" => %{
        "main" => %{
          "description" =>
            "Delete an actor's account with a token and password. Can only be called after requesting a deletion token. Requires auth.",
          "errors" => [%{"name" => "ExpiredToken"}, %{"name" => "InvalidToken"}],
          "input" => %{
            "encoding" => "application/json",
            "schema" => %{
              "properties" => %{
                "did" => %{"format" => "did", "type" => "string"},
                "password" => %{"type" => "string"},
                "token" => %{"type" => "string"}
              },
              "required" => ["did", "password", "token"],
              "type" => "object"
            }
          },
          "type" => "procedure"
        }
      },
      "id" => "com.atproto.server.deleteAccount",
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
          "description" => "Get a signed token on behalf of the requesting DID for the requested service.",
          "errors" => [
            %{
              "description" =>
                "Indicates that the requested expiration date is not a valid. May be in the past or may be reliant on the requested scopes.",
              "name" => "BadExpiration"
            }
          ],
          "output" => %{
            "encoding" => "application/json",
            "schema" => %{
              "properties" => %{"token" => %{"type" => "string"}},
              "required" => ["token"],
              "type" => "object"
            }
          },
          "parameters" => %{
            "properties" => %{
              "aud" => %{
                "description" =>
                  "The DID or `did#serviceId` reference of the service that the token will be used to authenticate with.",
                "maxLength" => 2048,
                "type" => "string"
              },
              "exp" => %{
                "description" =>
                  "The time in Unix Epoch seconds that the JWT expires. Defaults to 60 seconds in the future. The service may enforce certain time bounds on tokens depending on the requested scope.",
                "type" => "integer"
              },
              "lxm" => %{
                "description" => "Lexicon (XRPC) method to bind the requested token to",
                "format" => "nsid",
                "type" => "string"
              }
            },
            "required" => ["aud"],
            "type" => "params"
          },
          "type" => "query"
        }
      },
      "id" => "com.atproto.server.getServiceAuth",
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
        "appPassword" => %{
          "properties" => %{
            "createdAt" => %{"format" => "datetime", "type" => "string"},
            "id" => %{"type" => "integer"},
            "lastUsedAt" => %{"format" => "datetime", "type" => "string"},
            "name" => %{"type" => "string"},
            "revoked" => %{"type" => "boolean"},
            "scope" => %{"type" => "string"}
          },
          "required" => ["id", "name", "scope", "createdAt", "revoked"],
          "type" => "object"
        },
        "main" => %{
          "description" => "List app passwords for the authenticated account.",
          "output" => %{
            "encoding" => "application/json",
            "schema" => %{
              "properties" => %{
                "passwords" => %{
                  "items" => %{"ref" => "#appPassword", "type" => "ref"},
                  "type" => "array"
                }
              },
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
          "description" => "Initiate a user account deletion via email.",
          "type" => "procedure"
        }
      },
      "id" => "com.atproto.server.requestAccountDelete",
      "lexicon" => 1
    },
    %{
      "defs" => %{
        "main" => %{
          "description" => "Request an email with a code to confirm ownership of email.",
          "type" => "procedure"
        }
      },
      "id" => "com.atproto.server.requestEmailConfirmation",
      "lexicon" => 1
    },
    %{
      "defs" => %{
        "main" => %{
          "description" => "Request a token in order to update email.",
          "output" => %{
            "encoding" => "application/json",
            "schema" => %{
              "properties" => %{"tokenRequired" => %{"type" => "boolean"}},
              "required" => ["tokenRequired"],
              "type" => "object"
            }
          },
          "type" => "procedure"
        }
      },
      "id" => "com.atproto.server.requestEmailUpdate",
      "lexicon" => 1
    },
    %{
      "defs" => %{
        "main" => %{
          "description" => "Initiate a user account password reset via email.",
          "input" => %{
            "encoding" => "application/json",
            "schema" => %{
              "properties" => %{"email" => %{"type" => "string"}},
              "required" => ["email"],
              "type" => "object"
            }
          },
          "type" => "procedure"
        }
      },
      "id" => "com.atproto.server.requestPasswordReset",
      "lexicon" => 1
    },
    %{
      "defs" => %{
        "main" => %{
          "description" =>
            "Reserve a repo signing key, for use with account creation. Necessary so that a DID PLC update operation can be constructed during an account migraiton. Public and does not require auth; implemented by PDS. NOTE: this endpoint may change when full account migration is implemented.",
          "input" => %{
            "encoding" => "application/json",
            "schema" => %{
              "properties" => %{
                "did" => %{
                  "description" => "The DID to reserve a key for.",
                  "format" => "did",
                  "type" => "string"
                }
              },
              "type" => "object"
            }
          },
          "output" => %{
            "encoding" => "application/json",
            "schema" => %{
              "properties" => %{
                "signingKey" => %{
                  "description" => "The public key for the reserved signing key, in did:key serialization.",
                  "type" => "string"
                }
              },
              "required" => ["signingKey"],
              "type" => "object"
            }
          },
          "type" => "procedure"
        }
      },
      "id" => "com.atproto.server.reserveSigningKey",
      "lexicon" => 1
    },
    %{
      "defs" => %{
        "main" => %{
          "description" => "Reset a user account password using a token.",
          "errors" => [%{"name" => "ExpiredToken"}, %{"name" => "InvalidToken"}],
          "input" => %{
            "encoding" => "application/json",
            "schema" => %{
              "properties" => %{
                "password" => %{"type" => "string"},
                "token" => %{"type" => "string"}
              },
              "required" => ["token", "password"],
              "type" => "object"
            }
          },
          "type" => "procedure"
        }
      },
      "id" => "com.atproto.server.resetPassword",
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
          "output" => %{
            "encoding" => "application/json",
            "schema" => %{"properties" => %{}, "type" => "object"}
          },
          "type" => "procedure"
        }
      },
      "id" => "com.atproto.server.revokeAppPassword",
      "lexicon" => 1
    },
    %{
      "defs" => %{
        "main" => %{
          "description" => "Update an account's email.",
          "errors" => [
            %{"name" => "ExpiredToken"},
            %{"name" => "InvalidToken"},
            %{"name" => "TokenRequired"}
          ],
          "input" => %{
            "encoding" => "application/json",
            "schema" => %{
              "properties" => %{
                "email" => %{"type" => "string"},
                "emailAuthFactor" => %{"type" => "boolean"},
                "token" => %{
                  "description" =>
                    "Requires a token from com.atproto.sever.requestEmailUpdate if the account's email has been confirmed.",
                  "type" => "string"
                }
              },
              "required" => ["email"],
              "type" => "object"
            }
          },
          "type" => "procedure"
        }
      },
      "id" => "com.atproto.server.updateEmail",
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
    }
  ]

  @impl true
  def load(_opts), do: {:ok, @documents, @manifest}

  def documents, do: @documents
  def manifest, do: @manifest
end
