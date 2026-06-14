defmodule Tempest.PublicStatsTest do
  use Tempest.DataCase, async: false

  alias Tempest.Accounts
  alias Tempest.Accounts.{Account, AuthContext}
  alias Tempest.Identity.KeyStore
  alias Tempest.RepoCore.Cid
  alias Tempest.{Config, PublicStats, Records, Repo, RepoStorage}

  @password "correct horse battery staple"

  test "summary returns sanitized public aggregate stats" do
    account = create_account!("public-stats-active.test", "public-stats-active@example.com")
    inactive = create_account!("public-stats-inactive.test", "public-stats-inactive@example.com")

    Repo.update_all(from(a in Account, where: a.did == ^inactive.did), set: [active: false, status: "deactivated"])

    auth = %AuthContext{account: account, token_type: :access}

    assert {:ok, _profile} =
             Records.create_record(auth, %{
               "repo" => account.did,
               "collection" => "app.bsky.actor.profile",
               "rkey" => "self",
               "validate" => false,
               "record" => %{"$type" => "app.bsky.actor.profile", "displayName" => "Public"}
             })

    assert {:ok, _post} =
             Records.create_record(auth, %{
               "repo" => account.did,
               "collection" => "app.bsky.feed.post",
               "rkey" => "one",
               "validate" => false,
               "record" => %{"$type" => "app.bsky.feed.post", "text" => "hello"}
             })

    summary = PublicStats.summary()

    assert summary["status"] == "ok"
    assert is_binary(summary["version"])
    assert is_binary(summary["generatedAt"])
    assert is_integer(summary["uptimeSeconds"])
    assert summary["uptimeSeconds"] >= 0

    assert summary["metrics"]["hostedAccountCount"] == 1
    assert summary["metrics"]["totalAccountCount"] == 2
    assert summary["metrics"]["commitCount"] == 3
    assert summary["metrics"]["collectionCount"] == 2
    assert summary["metrics"]["recordCount"] == 2
    assert is_binary(summary["metrics"]["lastIndexedAt"])
    assert is_list(summary["users"])
    assert is_map(summary["latestRecord"])
    assert length(summary["commitWeeks"]) == 8
    assert is_list(summary["collections"])

    encoded = Jason.encode!(summary)
    refute encoded =~ "email"
    refute encoded =~ "token"
    refute encoded =~ "session"
    refute encoded =~ "oauth"
    refute encoded =~ "backup"
    refute encoded =~ Config.load!().data_dir
  end

  test "summary returns bounded public users, latest record, commit weeks, and collections" do
    account = create_account!("public-stats-detail.test", "public-stats-detail@example.com")
    signing_key = KeyStore.active_key_for_account(account)
    avatar_cid = Cid.for_raw("public avatar") |> Cid.to_string()
    banner_cid = Cid.for_raw("public banner") |> Cid.to_string()

    assert {:ok, _profile} =
             RepoStorage.create_record(account, signing_key, %{
               collection: "app.bsky.actor.profile",
               rkey: "self",
               swap_commit: nil,
               record: %{
                 "$type" => "app.bsky.actor.profile",
                 "displayName" => "Public Details",
                 "avatar" => %{"$type" => "blob", "ref" => %{"$link" => avatar_cid}, "mimeType" => "image/png"},
                 "banner" => %{"$type" => "blob", "ref" => %{"$link" => banner_cid}, "mimeType" => "image/png"}
               }
             })

    for index <- 1..11 do
      assert {:ok, _record} =
               RepoStorage.create_record(account, signing_key, %{
                 collection: "app.tempest.collection#{index}",
                 rkey: "one",
                 swap_commit: nil,
                 record: %{"$type" => "app.tempest.collection#{index}", "value" => index}
               })
    end

    summary = PublicStats.summary()

    assert [
             %{
               "did" => did,
               "handle" => "public-stats-detail.test",
               "status" => "active",
               "recordCount" => 12,
               "lastIndexedAt" => last_indexed_at,
               "avatarUrl" => avatar_url,
               "bannerUrl" => banner_url
             }
             | _rest
           ] = Enum.filter(summary["users"], &(&1["did"] == account.did))

    assert did == account.did
    assert is_binary(last_indexed_at)
    assert_blob_url(avatar_url, account.did, avatar_cid)
    assert_blob_url(banner_url, account.did, banner_cid)

    assert %{
             "did" => ^did,
             "handle" => "public-stats-detail.test",
             "collection" => collection,
             "rkey" => rkey,
             "cid" => cid,
             "indexedAt" => indexed_at
           } = summary["latestRecord"]

    assert is_binary(collection)
    assert is_binary(rkey)
    assert is_binary(cid)
    assert is_binary(indexed_at)

    assert length(summary["commitWeeks"]) == 8
    assert Enum.all?(summary["commitWeeks"], &match?(%{"weekStart" => _, "weekEnd" => _, "commitCount" => _}, &1))
    assert Enum.any?(summary["commitWeeks"], &(&1["commitCount"] >= 13))

    assert length(summary["collections"]) == 10
    assert Enum.all?(summary["collections"], &match?(%{"collection" => _, "recordCount" => _}, &1))
    refute Enum.any?(summary["collections"], &(&1["recordCount"] == 0))
  end

  test "health is degraded when a repo scan fails" do
    account = create_account!("public-stats-scan-failure.test", "public-stats-scan-failure@example.com")
    path = Config.load!() |> Config.repo_db_path(account.did)
    File.rm!(path)
    File.mkdir_p!(path)

    summary = PublicStats.summary()

    assert summary["status"] == "degraded"
    assert summary["health"]["status"] == "degraded"
    assert summary["health"]["checks"]["statsScanErrorCount"] == 1

    File.rm_rf!(path)
    RepoStorage.create_repo_database!(Config.load!(), account.did)
    Repo.update_all(from(a in Account, where: a.did == ^account.did), set: [active: false, status: "deactivated"])
  end

  test "health is unhealthy when required storage paths are missing" do
    config = %{
      Config.load!()
      | data_dir: Path.join(System.tmp_dir!(), "missing-tempest-stats-#{System.unique_integer([:positive])}")
    }

    summary = PublicStats.summary(config: config)

    assert summary["status"] == "unhealthy"
    assert summary["health"]["status"] == "unhealthy"
    assert summary["health"]["checks"]["storageWritable"] == false
    assert summary["health"]["checks"]["accountDatabase"] == "missing"
    assert summary["health"]["checks"]["sequencerDatabase"] == "missing"
  end

  defp create_account!(handle, email) do
    assert {:ok, session} =
             Accounts.create_account(%{
               "handle" => handle,
               "email" => email,
               "password" => @password
             })

    Repo.get_by!(Account, did: session["did"])
  end

  defp assert_blob_url(url, did, cid) do
    assert %URI{path: "/xrpc/com.atproto.sync.getBlob", query: query} = URI.parse(url)
    assert %{"did" => ^did, "cid" => ^cid} = URI.decode_query(query)
  end
end
