defmodule TempestWeb.Xrpc.RecordsTest do
  use TempestWeb.ConnCase, async: false

  alias Tempest.RepoCore.{Car, CarVerifier, Drisl, Tid}

  @password "correct horse battery staple"

  setup context do
    Tempest.LexiconFixtures.install!(context)
  end

  test "createRecord persists a profile record and advances repo commit", %{conn: conn} do
    account = create_account!(conn, "records-alice.test", "records-alice@example.com")

    create_conn =
      conn
      |> recycle()
      |> put_req_header("authorization", "Bearer #{account["accessJwt"]}")
      |> put_req_header("content-type", "application/json")
      |> post(~p"/xrpc/com.atproto.repo.createRecord", %{
        "repo" => "records-alice.test",
        "collection" => "app.bsky.actor.profile",
        "rkey" => "self",
        "record" => %{
          "$type" => "app.bsky.actor.profile",
          "displayName" => "Alice"
        }
      })

    response = json_response(create_conn, 200)

    assert response["uri"] == "at://#{account["did"]}/app.bsky.actor.profile/self"
    assert response["cid"] =~ "b"
    assert %{"cid" => commit_cid, "rev" => rev} = response["commit"]
    assert response["validationStatus"] == "valid"

    repo_db = repo_db(account["did"])
    assert scalar(repo_db, "SELECT COUNT(*) FROM records") == 1
    assert scalar(repo_db, "SELECT COUNT(*) FROM commits") == 2
    assert metadata(repo_db)["current_commit_cid"] == commit_cid
    assert metadata(repo_db)["current_rev"] == rev
    assert sequencer_event_count(account["did"], "#commit", "create") == 1
    assert_commit_event_car_slice(account["did"], commit_cid, response["cid"])

    get_conn =
      conn
      |> recycle()
      |> get(~p"/xrpc/com.atproto.repo.getRecord", %{
        "repo" => "records-alice.test",
        "collection" => "app.bsky.actor.profile",
        "rkey" => "self"
      })

    get_response = json_response(get_conn, 200)
    assert get_response["uri"] == response["uri"]
    assert get_response["cid"] == response["cid"]
    assert get_response["value"]["displayName"] == "Alice"

    list_conn =
      conn
      |> recycle()
      |> get(~p"/xrpc/com.atproto.repo.listRecords", %{
        "repo" => account["did"],
        "collection" => "app.bsky.actor.profile"
      })

    list_response = json_response(list_conn, 200)
    assert [listed] = list_response["records"]
    assert listed["uri"] == response["uri"]
    assert listed["cid"] == response["cid"]
    assert listed["value"]["displayName"] == "Alice"

    describe_conn =
      conn
      |> recycle()
      |> get(~p"/xrpc/com.atproto.repo.describeRepo", %{"repo" => account["did"]})

    describe_response = json_response(describe_conn, 200)
    assert describe_response["did"] == account["did"]
    assert describe_response["handle"] == "records-alice.test"
    assert describe_response["didDoc"]["id"] == account["did"]
    assert describe_response["collections"] == ["app.bsky.actor.profile"]
    assert describe_response["handleIsCorrect"] == true
  end

  test "createRecord rejects duplicate rkey with conflict", %{conn: conn} do
    account = create_account!(conn, "records-bob.test", "records-bob@example.com")
    params = profile_params("records-bob.test", "Bob")

    first_conn =
      conn
      |> recycle()
      |> put_req_header("authorization", "Bearer #{account["accessJwt"]}")
      |> put_req_header("content-type", "application/json")
      |> post(~p"/xrpc/com.atproto.repo.createRecord", params)

    assert json_response(first_conn, 200)

    duplicate_conn =
      conn
      |> recycle()
      |> put_req_header("authorization", "Bearer #{account["accessJwt"]}")
      |> put_req_header("content-type", "application/json")
      |> post(~p"/xrpc/com.atproto.repo.createRecord", params)

    response = json_response(duplicate_conn, 409)

    assert response["error"] == "InvalidRequest"
    assert response["message"] =~ "already exists"
    assert scalar(repo_db(account["did"]), "SELECT COUNT(*) FROM records") == 1
  end

  test "createRecord enforces record validation boundary", %{conn: conn} do
    account = create_account!(conn, "records-cara.test", "records-cara@example.com")

    bad_conn =
      conn
      |> recycle()
      |> put_req_header("authorization", "Bearer #{account["accessJwt"]}")
      |> put_req_header("content-type", "application/json")
      |> post(~p"/xrpc/com.atproto.repo.createRecord", %{
        "repo" => account["did"],
        "collection" => "app.bsky.actor.profile",
        "rkey" => "self",
        "record" => %{
          "$type" => "app.bsky.actor.profile",
          "displayName" => 123
        }
      })

    response = json_response(bad_conn, 400)

    assert response["error"] == "InvalidRequest"
    assert response["message"] =~ "displayName"
  end

  test "createRecord rejects oversized schema-constrained records", %{conn: conn} do
    account = create_account!(conn, "records-oversized.test", "records-oversized@example.com")

    rejected_conn =
      conn
      |> auth_json(account)
      |> post(~p"/xrpc/com.atproto.repo.createRecord", profile_params(account["did"], String.duplicate("A", 641)))

    response = json_response(rejected_conn, 400)
    assert response["error"] == "InvalidRequest"
    assert response["message"] =~ "displayName"
    assert scalar(repo_db(account["did"]), "SELECT COUNT(*) FROM records") == 0
  end

  test "createRecord rejects writes to another repo", %{conn: conn} do
    account = create_account!(conn, "records-dana.test", "records-dana@example.com")

    denied_conn =
      conn
      |> recycle()
      |> put_req_header("authorization", "Bearer #{account["accessJwt"]}")
      |> put_req_header("content-type", "application/json")
      |> post(~p"/xrpc/com.atproto.repo.createRecord", profile_params("other.test", "Dana"))

    assert %{"error" => "InvalidRequest"} = json_response(denied_conn, 400)
  end

  test "createRecord validates and persists Bluesky post records", %{conn: conn} do
    account = create_account!(conn, "records-bsky-post.test", "records-bsky-post@example.com")

    created =
      conn
      |> auth_json(account)
      |> post(~p"/xrpc/com.atproto.repo.createRecord", %{
        "repo" => account["did"],
        "collection" => "app.bsky.feed.post",
        "rkey" => "3mo7hac7efyou",
        "validate" => true,
        "record" => %{
          "$type" => "app.bsky.feed.post",
          "text" => "hello from bsky-shaped post",
          "createdAt" => "2026-06-13T19:45:00.000Z"
        }
      })
      |> json_response(200)

    assert created["uri"] == "at://#{account["did"]}/app.bsky.feed.post/3mo7hac7efyou"
    assert created["validationStatus"] == "valid"
    assert scalar(repo_db(account["did"]), "SELECT COUNT(*) FROM records") == 1

    response =
      conn
      |> recycle()
      |> get(~p"/xrpc/com.atproto.repo.getRecord", %{
        "repo" => account["did"],
        "collection" => "app.bsky.feed.post",
        "rkey" => "3mo7hac7efyou"
      })
      |> json_response(200)

    assert response["cid"] == created["cid"]
    assert response["value"]["text"] == "hello from bsky-shaped post"
  end

  test "createRecord validates and persists Bluesky like records", %{conn: conn} do
    account = create_account!(conn, "records-bsky-like.test", "records-bsky-like@example.com")

    post =
      conn
      |> auth_json(account)
      |> post(~p"/xrpc/com.atproto.repo.createRecord", %{
        "repo" => account["did"],
        "collection" => "app.bsky.feed.post",
        "rkey" => "3mo7hac7efyou",
        "validate" => true,
        "record" => %{
          "$type" => "app.bsky.feed.post",
          "text" => "liked post",
          "createdAt" => "2026-06-13T19:45:00.000Z"
        }
      })
      |> json_response(200)

    liked_uri = "at://#{account["did"]}/app.bsky.feed.post/3mo7hac7efyou"

    liked =
      conn
      |> auth_json(account)
      |> post(~p"/xrpc/com.atproto.repo.createRecord", %{
        "repo" => account["did"],
        "collection" => "app.bsky.feed.like",
        "rkey" => "3mo7hac7egabc",
        "validate" => true,
        "record" => %{
          "$type" => "app.bsky.feed.like",
          "subject" => %{"uri" => liked_uri, "cid" => post["cid"]},
          "createdAt" => "2026-06-13T19:46:00.000Z"
        }
      })
      |> json_response(200)

    assert liked["uri"] == "at://#{account["did"]}/app.bsky.feed.like/3mo7hac7egabc"
    assert liked["validationStatus"] == "valid"
    assert scalar(repo_db(account["did"]), "SELECT COUNT(*) FROM records") == 2

    response =
      conn
      |> recycle()
      |> get(~p"/xrpc/com.atproto.repo.getRecord", %{
        "repo" => account["did"],
        "collection" => "app.bsky.feed.like",
        "rkey" => "3mo7hac7egabc"
      })
      |> json_response(200)

    assert response["cid"] == liked["cid"]
    assert response["value"]["subject"]["uri"] == liked_uri
    assert response["value"]["subject"]["cid"] == post["cid"]
  end

  test "putRecord enforces swapRecord and swapCommit before replacing a record", %{conn: conn} do
    account = create_account!(conn, "records-erin.test", "records-erin@example.com")
    created = create_profile!(conn, account, "Erin")

    wrong_swap_conn =
      conn
      |> auth_json(account)
      |> post(~p"/xrpc/com.atproto.repo.putRecord", %{
        "repo" => account["did"],
        "collection" => "app.bsky.actor.profile",
        "rkey" => "self",
        "swapRecord" => created["commit"]["cid"],
        "record" => %{
          "$type" => "app.bsky.actor.profile",
          "displayName" => "Erin Updated"
        }
      })

    assert %{"error" => "InvalidSwap"} = json_response(wrong_swap_conn, 409)

    put_conn =
      conn
      |> auth_json(account)
      |> post(~p"/xrpc/com.atproto.repo.putRecord", %{
        "repo" => account["did"],
        "collection" => "app.bsky.actor.profile",
        "rkey" => "self",
        "swapRecord" => created["cid"],
        "swapCommit" => created["commit"]["cid"],
        "record" => %{
          "$type" => "app.bsky.actor.profile",
          "displayName" => "Erin Updated"
        }
      })

    updated = json_response(put_conn, 200)
    assert updated["uri"] == created["uri"]
    assert updated["cid"] != created["cid"]
    assert updated["commit"]["cid"] != created["commit"]["cid"]
    assert updated["validationStatus"] == "valid"

    get_conn =
      conn
      |> recycle()
      |> get(~p"/xrpc/com.atproto.repo.getRecord", %{
        "repo" => account["did"],
        "collection" => "app.bsky.actor.profile",
        "rkey" => "self"
      })

    assert json_response(get_conn, 200)["value"]["displayName"] == "Erin Updated"
    assert sequencer_event_count(account["did"], "#commit", "update") == 1
  end

  test "applyWrites batches creates updates and deletes with commit metadata", %{conn: conn} do
    account = create_account!(conn, "records-apply.test", "records-apply@example.com")

    created =
      conn
      |> auth_json(account)
      |> post(~p"/xrpc/com.atproto.repo.applyWrites", %{
        "repo" => account["did"],
        "validate" => false,
        "writes" => [
          %{
            "$type" => "com.atproto.repo.applyWrites#create",
            "collection" => "app.tempest.note",
            "rkey" => "one",
            "value" => %{"$type" => "app.tempest.note", "text" => "first"}
          },
          %{
            "$type" => "com.atproto.repo.applyWrites#create",
            "collection" => "app.tempest.note",
            "rkey" => "two",
            "value" => %{"$type" => "app.tempest.note", "text" => "second"}
          }
        ]
      })
      |> json_response(200)

    assert %{"cid" => first_commit} = created["commit"]

    assert Enum.map(created["results"], & &1["uri"]) == [
             "at://#{account["did"]}/app.tempest.note/one",
             "at://#{account["did"]}/app.tempest.note/two"
           ]

    updated =
      conn
      |> auth_json(account)
      |> post(~p"/xrpc/com.atproto.repo.applyWrites", %{
        "repo" => account["did"],
        "swapCommit" => first_commit,
        "validate" => false,
        "writes" => [
          %{
            "$type" => "com.atproto.repo.applyWrites#update",
            "collection" => "app.tempest.note",
            "rkey" => "one",
            "value" => %{"$type" => "app.tempest.note", "text" => "updated"}
          },
          %{
            "$type" => "com.atproto.repo.applyWrites#delete",
            "collection" => "app.tempest.note",
            "rkey" => "two"
          }
        ]
      })
      |> json_response(200)

    assert updated["commit"]["cid"] != first_commit

    assert Enum.map(updated["results"], & &1["$type"]) == [
             "com.atproto.repo.applyWrites#updateResult",
             "com.atproto.repo.applyWrites#deleteResult"
           ]

    list_conn =
      conn
      |> recycle()
      |> get(~p"/xrpc/com.atproto.repo.listRecords", %{
        "repo" => account["did"],
        "collection" => "app.tempest.note"
      })

    assert [%{"value" => %{"text" => "updated"}}] = json_response(list_conn, 200)["records"]
  end

  test "applyWrites rejects duplicate create writes for the same collection and rkey before mutating", %{conn: conn} do
    account = create_account!(conn, "records-apply-dupe.test", "records-apply-dupe@example.com")

    rejected_conn =
      conn
      |> auth_json(account)
      |> post(~p"/xrpc/com.atproto.repo.applyWrites", %{
        "repo" => account["did"],
        "validate" => false,
        "writes" => [
          %{
            "$type" => "com.atproto.repo.applyWrites#create",
            "collection" => "app.tempest.note",
            "rkey" => "same",
            "value" => %{"$type" => "app.tempest.note", "text" => "a"}
          },
          %{
            "$type" => "com.atproto.repo.applyWrites#create",
            "collection" => "app.tempest.note",
            "rkey" => "same",
            "value" => %{"$type" => "app.tempest.note", "text" => "b"}
          }
        ]
      })

    response = json_response(rejected_conn, 400)
    assert response["error"] == "InvalidRequest"
    assert response["message"] =~ "same collection and rkey"
    assert scalar(repo_db(account["did"]), "SELECT COUNT(*) FROM records") == 0
  end

  test "applyWrites rolls back the whole batch when a later operation fails", %{conn: conn} do
    account = create_account!(conn, "records-apply-atomic.test", "records-apply-atomic@example.com")

    rejected_conn =
      conn
      |> auth_json(account)
      |> post(~p"/xrpc/com.atproto.repo.applyWrites", %{
        "repo" => account["did"],
        "validate" => false,
        "writes" => [
          %{
            "$type" => "com.atproto.repo.applyWrites#create",
            "collection" => "app.tempest.note",
            "rkey" => "created-before-failure",
            "value" => %{"$type" => "app.tempest.note", "text" => "must rollback"}
          },
          %{
            "$type" => "com.atproto.repo.applyWrites#update",
            "collection" => "app.tempest.note",
            "rkey" => "missing-record",
            "value" => %{"$type" => "app.tempest.note", "text" => "cannot update"}
          }
        ]
      })

    assert %{"error" => "RecordNotFound"} = json_response(rejected_conn, 400)
    assert scalar(repo_db(account["did"]), "SELECT COUNT(*) FROM records") == 0
    assert scalar(repo_db(account["did"]), "SELECT COUNT(*) FROM commits") == 1
    assert sequencer_event_count(account["did"], "#commit", "applyWrites") == 0
  end

  test "deleteRecord removes current record from getRecord and listRecords", %{conn: conn} do
    account = create_account!(conn, "records-finn.test", "records-finn@example.com")
    created = create_profile!(conn, account, "Finn")

    delete_conn =
      conn
      |> auth_json(account)
      |> post(~p"/xrpc/com.atproto.repo.deleteRecord", %{
        "repo" => account["did"],
        "collection" => "app.bsky.actor.profile",
        "rkey" => "self",
        "swapRecord" => created["cid"],
        "swapCommit" => created["commit"]["cid"]
      })

    deleted = json_response(delete_conn, 200)
    assert deleted["commit"]["cid"] != created["commit"]["cid"]

    get_conn =
      conn
      |> recycle()
      |> get(~p"/xrpc/com.atproto.repo.getRecord", %{
        "repo" => account["did"],
        "collection" => "app.bsky.actor.profile",
        "rkey" => "self"
      })

    assert %{"error" => "RecordNotFound"} = json_response(get_conn, 400)

    list_conn =
      conn
      |> recycle()
      |> get(~p"/xrpc/com.atproto.repo.listRecords", %{
        "repo" => account["did"],
        "collection" => "app.bsky.actor.profile"
      })

    assert json_response(list_conn, 200)["records"] == []
    assert scalar(repo_db(account["did"]), "SELECT COUNT(*) FROM records") == 0
    assert sequencer_event_count(account["did"], "#commit", "delete") == 1

    absent_delete_conn =
      conn
      |> auth_json(account)
      |> post(~p"/xrpc/com.atproto.repo.deleteRecord", %{
        "repo" => account["did"],
        "collection" => "app.bsky.actor.profile",
        "rkey" => "self",
        "swapRecord" => created["cid"],
        "swapCommit" => created["commit"]["cid"]
      })

    refute Map.has_key?(json_response(absent_delete_conn, 200), "commit")
    assert sequencer_event_count(account["did"], "#commit", "delete") == 1
  end

  test "listRecords paginates within a collection", %{conn: conn} do
    account = create_account!(conn, "records-gia.test", "records-gia@example.com")

    create_note!(conn, account, "a", "first")
    create_note!(conn, account, "b", "second")
    create_note!(conn, account, "c", "third")

    first_page_conn =
      conn
      |> recycle()
      |> get(~p"/xrpc/com.atproto.repo.listRecords", %{
        "repo" => account["did"],
        "collection" => "app.tempest.note",
        "limit" => "2"
      })

    first_page = json_response(first_page_conn, 200)

    assert Enum.map(first_page["records"], & &1["uri"]) == [
             "at://#{account["did"]}/app.tempest.note/a",
             "at://#{account["did"]}/app.tempest.note/b"
           ]

    assert first_page["cursor"] == "b"

    second_page_conn =
      conn
      |> recycle()
      |> get(~p"/xrpc/com.atproto.repo.listRecords", %{
        "repo" => account["did"],
        "collection" => "app.tempest.note",
        "limit" => "2",
        "cursor" => first_page["cursor"]
      })

    second_page = json_response(second_page_conn, 200)
    assert Enum.map(second_page["records"], & &1["uri"]) == ["at://#{account["did"]}/app.tempest.note/c"]
    refute Map.has_key?(second_page, "cursor")

    reverse_conn =
      conn
      |> recycle()
      |> get(~p"/xrpc/com.atproto.repo.listRecords", %{
        "repo" => account["did"],
        "collection" => "app.tempest.note",
        "limit" => "2",
        "reverse" => "true"
      })

    reverse_page = json_response(reverse_conn, 200)

    assert Enum.map(reverse_page["records"], & &1["uri"]) == [
             "at://#{account["did"]}/app.tempest.note/c",
             "at://#{account["did"]}/app.tempest.note/b"
           ]
  end

  test "records survive storage bootstrap and repository reopen", %{conn: conn} do
    account = create_account!(conn, "records-hana.test", "records-hana@example.com")
    created = create_profile!(conn, account, "Hana")

    :ok =
      Tempest.Config.load!()
      |> Tempest.Storage.bootstrap!()

    get_conn =
      conn
      |> recycle()
      |> get(~p"/xrpc/com.atproto.repo.getRecord", %{
        "repo" => account["did"],
        "collection" => "app.bsky.actor.profile",
        "rkey" => "self"
      })

    response = json_response(get_conn, 200)
    assert response["uri"] == created["uri"]
    assert response["cid"] == created["cid"]
    assert response["value"]["displayName"] == "Hana"
  end

  test "uploadBlob stores temp metadata and createRecord promotes referenced blobs", %{conn: conn} do
    account = create_account!(conn, "records-blob.test", "records-blob@example.com")
    uploaded = upload_blob!(conn, account, "hello blob", "text/plain")
    blob = uploaded["blob"]
    cid = blob["ref"]["$link"]

    assert blob == %{
             "$type" => "blob",
             "ref" => %{"$link" => cid},
             "mimeType" => "text/plain",
             "size" => 10
           }

    assert blob_metadata(account["did"], cid).state == "temp"
    assert File.exists?(Path.join([Tempest.Config.load!().data_dir, "tmp", "blobs", path_did(account["did"]), cid]))

    created =
      conn
      |> auth_json(account)
      |> post(~p"/xrpc/com.atproto.repo.createRecord", blob_record_params(account["did"], "avatar", blob))
      |> json_response(200)

    assert created["uri"] == "at://#{account["did"]}/app.tempest.blob/avatar"
    assert blob_metadata(account["did"], cid).state == "public"
    assert File.exists?(Path.join([Tempest.Config.load!().data_dir, "blobs", path_did(account["did"]), cid]))
  end

  test "putRecord updates Bluesky profile avatar and banner blobs", %{conn: conn} do
    account = create_account!(conn, "records-profile-images.test", "records-profile-images@example.com")
    created = create_profile!(conn, account, "Profile Images")

    avatar = upload_blob!(conn, account, png_bytes(), "image/png")["blob"]
    banner = upload_blob!(conn, account, jpeg_bytes(), "image/jpeg")["blob"]
    avatar_cid = avatar["ref"]["$link"]
    banner_cid = banner["ref"]["$link"]

    assert blob_metadata(account["did"], avatar_cid).state == "temp"
    assert blob_metadata(account["did"], banner_cid).state == "temp"

    updated =
      conn
      |> auth_json(account)
      |> put_req_header("atproto-proxy", "did:web:api.bsky.app#bsky_appview")
      |> put_req_header("atproto-accept-labelers", "did:plc:ar7c4by46qjdydhdevvrndac;redact")
      |> post(~p"/xrpc/com.atproto.repo.putRecord", %{
        "repo" => account["did"],
        "collection" => "app.bsky.actor.profile",
        "rkey" => "self",
        "swapRecord" => created["cid"],
        "record" => %{
          "$type" => "app.bsky.actor.profile",
          "avatar" => avatar,
          "banner" => banner,
          "createdAt" => "2026-06-13T20:20:43.434Z",
          "description" => "tempest.desertthunder.dev",
          "displayName" => "Tempest"
        }
      })
      |> json_response(200)

    assert updated["uri"] == "at://#{account["did"]}/app.bsky.actor.profile/self"
    assert updated["cid"] != created["cid"]
    assert updated["validationStatus"] == "valid"
    assert blob_metadata(account["did"], avatar_cid).state == "public"
    assert blob_metadata(account["did"], banner_cid).state == "public"

    profile =
      conn
      |> recycle()
      |> get(~p"/xrpc/com.atproto.repo.getRecord", %{
        "repo" => account["did"],
        "collection" => "app.bsky.actor.profile",
        "rkey" => "self"
      })
      |> json_response(200)

    assert profile["value"]["avatar"]["ref"]["$link"] == avatar_cid
    assert profile["value"]["banner"]["ref"]["$link"] == banner_cid
  end

  test "putRecord rejects malformed blob references with a client error", %{conn: conn} do
    account = create_account!(conn, "records-profile-bad-blob.test", "records-profile-bad-blob@example.com")
    created = create_profile!(conn, account, "Bad Blob")
    uploaded = upload_blob!(conn, account, png_bytes(), "image/png")["blob"]

    rejected_conn =
      conn
      |> auth_json(account)
      |> post(~p"/xrpc/com.atproto.repo.putRecord", %{
        "repo" => account["did"],
        "collection" => "app.bsky.actor.profile",
        "rkey" => "self",
        "swapRecord" => created["cid"],
        "record" => %{
          "$type" => "app.bsky.actor.profile",
          "avatar" => Map.delete(uploaded, "ref"),
          "displayName" => "Bad Blob"
        }
      })

    response = json_response(rejected_conn, 400)
    assert response["error"] == "InvalidRequest"
    assert response["message"] =~ "avatar"
  end

  test "importRepo verifies CARs atomically and keeps post-import revisions monotonic", %{conn: conn} do
    account = create_account!(conn, "records-import.test", "records-import@example.com")
    profile = create_profile!(conn, account, "Imported")

    car_bytes =
      conn
      |> recycle()
      |> get(~p"/xrpc/com.atproto.sync.getRepo", %{"did" => account["did"]})
      |> response(200)

    _extra = create_note!(conn, account, "extra", "not in imported car")
    assert scalar(repo_db(account["did"]), "SELECT COUNT(*) FROM records") == 2

    imported =
      conn
      |> recycle()
      |> put_req_header("authorization", "Bearer #{account["accessJwt"]}")
      |> put_req_header("content-type", "application/vnd.ipld.car")
      |> post(~p"/xrpc/com.atproto.repo.importRepo", car_bytes)
      |> json_response(200)

    assert imported["cid"] == profile["commit"]["cid"]
    assert imported["rev"] == profile["commit"]["rev"]
    assert imported["recordCount"] == 1
    assert metadata(repo_db(account["did"]))["current_rev"] == imported["rev"]
    assert scalar(repo_db(account["did"]), "SELECT COUNT(*) FROM records") == 1

    missing_note =
      conn
      |> recycle()
      |> get(~p"/xrpc/com.atproto.repo.getRecord", %{
        "repo" => account["did"],
        "collection" => "app.tempest.note",
        "rkey" => "extra"
      })

    assert %{"error" => "RecordNotFound"} = json_response(missing_note, 400)

    bad_import =
      conn
      |> recycle()
      |> put_req_header("authorization", "Bearer #{account["accessJwt"]}")
      |> put_req_header("content-type", "application/vnd.ipld.car")
      |> post(~p"/xrpc/com.atproto.repo.importRepo", <<0, 1, 2, 3>>)

    assert %{"error" => "InvalidRequest"} = json_response(bad_import, 400)
    assert metadata(repo_db(account["did"]))["current_rev"] == imported["rev"]
    assert scalar(repo_db(account["did"]), "SELECT COUNT(*) FROM records") == 1

    after_import = create_note!(conn, account, "after", "after import")

    assert Tid.parse!(after_import["commit"]["rev"]).integer > Tid.parse!(imported["rev"]).integer
  end

  test "listMissingBlobs reports referenced blobs absent from local metadata", %{conn: conn} do
    account = create_account!(conn, "records-list-missing-blobs.test", "records-list-missing-blobs@example.com")
    blob = upload_blob!(conn, account, "blob bytes", "text/plain")["blob"]
    cid = blob["ref"]["$link"]

    _created =
      conn
      |> auth_json(account)
      |> post(~p"/xrpc/com.atproto.repo.createRecord", blob_record_params(account["did"], "missing", blob))
      |> json_response(200)

    :ok = Tempest.Blobs.delete_metadata(account["did"], [cid])

    response =
      conn
      |> recycle()
      |> put_req_header("authorization", "Bearer #{account["accessJwt"]}")
      |> get(~p"/xrpc/com.atproto.repo.listMissingBlobs")
      |> json_response(200)

    assert response == %{"blobs" => [%{"cid" => cid}]}

    status =
      conn
      |> recycle()
      |> put_req_header("authorization", "Bearer #{account["accessJwt"]}")
      |> get(~p"/xrpc/com.atproto.server.checkAccountStatus")
      |> json_response(200)

    assert status["missingBlobCount"] == 1
    assert status["migrationReady"] == false
  end

  test "record writes reject missing blob references", %{conn: conn} do
    account = create_account!(conn, "records-missing-blob.test", "records-missing-blob@example.com")
    cid = Tempest.Blobs.cid_for("not uploaded")

    rejected_conn =
      conn
      |> auth_json(account)
      |> post(
        ~p"/xrpc/com.atproto.repo.createRecord",
        blob_record_params(account["did"], "avatar", %{
          "$type" => "blob",
          "ref" => %{"$link" => cid},
          "mimeType" => "text/plain",
          "size" => 12
        })
      )

    response = json_response(rejected_conn, 400)
    assert response["error"] == "InvalidRequest"
    assert response["message"] =~ "missing blob"
    assert scalar(repo_db(account["did"]), "SELECT COUNT(*) FROM records") == 0
  end

  defp create_account!(conn, handle, email) do
    conn
    |> put_req_header("content-type", "application/json")
    |> post(~p"/xrpc/com.atproto.server.createAccount", %{
      "handle" => handle,
      "email" => email,
      "password" => @password
    })
    |> json_response(200)
  end

  defp auth_json(conn, account) do
    conn
    |> recycle()
    |> put_req_header("authorization", "Bearer #{account["accessJwt"]}")
    |> put_req_header("content-type", "application/json")
  end

  defp create_profile!(conn, account, display_name) do
    conn
    |> auth_json(account)
    |> post(~p"/xrpc/com.atproto.repo.createRecord", profile_params(account["did"], display_name))
    |> json_response(200)
  end

  defp create_note!(conn, account, rkey, text) do
    conn
    |> auth_json(account)
    |> post(~p"/xrpc/com.atproto.repo.createRecord", %{
      "repo" => account["did"],
      "collection" => "app.tempest.note",
      "rkey" => rkey,
      "validate" => false,
      "record" => %{
        "$type" => "app.tempest.note",
        "text" => text
      }
    })
    |> json_response(200)
  end

  defp upload_blob!(conn, account, bytes, mime_type) do
    conn
    |> recycle()
    |> put_req_header("authorization", "Bearer #{account["accessJwt"]}")
    |> put_req_header("content-type", mime_type)
    |> put_req_header("content-length", Integer.to_string(byte_size(bytes)))
    |> post(~p"/xrpc/com.atproto.repo.uploadBlob", bytes)
    |> json_response(200)
  end

  defp png_bytes do
    <<0x89, "PNG", 0x0D, 0x0A, 0x1A, 0x0A, "tempest-test-png">>
  end

  defp jpeg_bytes do
    <<0xFF, 0xD8, 0xFF, "tempest-test-jpeg">>
  end

  defp blob_record_params(repo, rkey, blob) do
    %{
      "repo" => repo,
      "collection" => "app.tempest.blob",
      "rkey" => rkey,
      "validate" => false,
      "record" => %{
        "$type" => "app.tempest.blob",
        "image" => blob
      }
    }
  end

  defp profile_params(repo, display_name) do
    %{
      "repo" => repo,
      "collection" => "app.bsky.actor.profile",
      "rkey" => "self",
      "record" => %{
        "$type" => "app.bsky.actor.profile",
        "displayName" => display_name
      }
    }
  end

  defp repo_db(did) do
    Tempest.Config.load!()
    |> Tempest.Config.repo_db_path(did)
  end

  defp metadata(path) do
    path
    |> fetch_all("SELECT key, value FROM repo_metadata")
    |> Map.new(fn [key, value] -> {key, value} end)
  end

  defp scalar(path, sql) do
    [[value]] = fetch_all(path, sql)
    value
  end

  defp blob_metadata(did, cid) do
    {:ok, metadata} = Tempest.Blobs.get_metadata(did, cid)
    metadata
  end

  defp path_did(did), do: String.replace(did, ~r/[^A-Za-z0-9._-]/, "_")

  defp sequencer_event_count(did, event_type, action) do
    {:ok, events} = Tempest.Sequencer.list_after(0, did: did)

    Enum.count(events, fn event ->
      event.did == did and event.event_type == event_type and event.payload["action"] == action
    end)
  end

  defp assert_commit_event_car_slice(did, commit_cid, record_cid) do
    {:ok, events} = Tempest.Sequencer.list_after(0, did: did)

    event =
      Enum.find(events, fn event ->
        event.event_type == "#commit" and event.commit_cid == commit_cid
      end)

    assert %Drisl.Bytes{bytes: car_bytes} = event.payload["blocks"]
    assert :ok = CarVerifier.verify_commit_event(event.payload)
    assert {:ok, car} = Car.decode(car_bytes)
    assert Enum.map(car.roots, &Tempest.RepoCore.Cid.to_string/1) == [commit_cid]
    assert Enum.any?(car.blocks, &(Tempest.RepoCore.Cid.to_string(&1.cid) == record_cid))
  end

  defp fetch_all(path, sql) do
    {:ok, conn} = Exqlite.Sqlite3.open(path)
    {:ok, statement} = Exqlite.Sqlite3.prepare(conn, sql)
    {:ok, rows} = Exqlite.Sqlite3.fetch_all(conn, statement)
    :ok = Exqlite.Sqlite3.release(conn, statement)
    :ok = Exqlite.Sqlite3.close(conn)
    rows
  end
end
