defmodule Tempest.PublicStatsTest do
  use Tempest.DataCase, async: false

  alias Tempest.Accounts
  alias Tempest.Accounts.{Account, AuthContext}
  alias Tempest.{Config, PublicStats, Records, Repo}

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

    encoded = Jason.encode!(summary)
    refute encoded =~ "email"
    refute encoded =~ "token"
    refute encoded =~ "session"
    refute encoded =~ "oauth"
    refute encoded =~ "backup"
    refute encoded =~ Config.load!().data_dir
  end

  test "health is degraded when a repo scan fails" do
    account = create_account!("public-stats-scan-failure.test", "public-stats-scan-failure@example.com")
    path = Config.load!() |> Config.repo_db_path(account.did)
    File.rm!(path)
    File.mkdir_p!(path)
    on_exit(fn -> File.rm_rf(path) end)

    summary = PublicStats.summary()

    assert summary["status"] == "degraded"
    assert summary["health"]["status"] == "degraded"
    assert summary["health"]["checks"]["statsScanErrorCount"] == 1
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
end
