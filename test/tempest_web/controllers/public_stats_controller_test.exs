defmodule TempestWeb.PublicStatsControllerTest do
  use TempestWeb.ConnCase

  import Ecto.Query

  alias Tempest.Accounts
  alias Tempest.Accounts.{Account, AuthContext}
  alias Tempest.{AdminAuth, Records, Repo}

  @password "correct horse battery staple"

  setup do
    old_hash = Application.get_env(:tempest, :admin_token_hash)

    on_exit(fn ->
      if old_hash do
        Application.put_env(:tempest, :admin_token_hash, old_hash)
      else
        Application.delete_env(:tempest, :admin_token_hash)
      end
    end)

    :ok
  end

  test "public stats endpoints work without admin authorization while admin status stays protected", %{conn: conn} do
    Application.put_env(:tempest, :admin_token_hash, AdminAuth.hash_token("admin-secret-token"))

    html =
      conn
      |> get(~p"/stats")
      |> html_response(200)

    assert html =~ ~s(id="tempest-home")
    assert html =~ "Tempest Public Stats"
    assert html =~ "Hosted Accounts"
    assert html =~ "Last Indexed"
    assert html =~ ~s(id="public-users")
    assert html =~ "Latest Indexed Record"
    assert html =~ ~s(id="commit-weeks")
    assert html =~ ~s(id="collection-summaries")

    stats =
      conn
      |> recycle()
      |> get(~p"/xrpc/_stats")
      |> json_response(200)

    assert stats["status"] in ["ok", "degraded", "unhealthy"]
    assert is_binary(stats["generatedAt"])
    assert is_integer(stats["uptimeSeconds"])
    assert is_map(stats["metrics"])
    assert is_list(stats["users"])
    assert Map.has_key?(stats, "latestRecord")
    assert is_list(stats["commitWeeks"])
    assert is_list(stats["collections"])
    assert is_map(stats["health"])

    rejected =
      conn
      |> recycle()
      |> get(~p"/xrpc/_admin/status")

    assert json_response(rejected, 401)["error"] == "AuthenticationRequired"
  end

  test "public stats counts created accounts and repo writes without leaking private fields", %{conn: conn} do
    account = create_account!("stats-public.test", "stats-public@example.com")
    inactive = create_account!("stats-inactive.test", "stats-inactive@example.com")

    Repo.update_all(from(a in Account, where: a.did == ^inactive.did), set: [active: false, status: "deactivated"])

    auth = %AuthContext{account: account, token_type: :access}

    create_record!(auth, account.did, "app.bsky.actor.profile", "self", %{
      "$type" => "app.bsky.actor.profile",
      "displayName" => "Stats Public"
    })

    create_record!(auth, account.did, "app.bsky.feed.post", "one", %{
      "$type" => "app.bsky.feed.post",
      "text" => "public stats"
    })

    response =
      conn
      |> get(~p"/xrpc/_stats")
      |> json_response(200)

    assert response["metrics"]["hostedAccountCount"] == 1
    assert response["metrics"]["totalAccountCount"] == 2
    assert response["metrics"]["commitCount"] == 3
    assert response["metrics"]["collectionCount"] == 2
    assert response["metrics"]["recordCount"] == 2
    assert is_binary(response["metrics"]["lastIndexedAt"])

    assert [%{"handle" => "stats-public.test", "avatarUrl" => nil, "bannerUrl" => nil} | _rest] =
             Enum.filter(response["users"], &(&1["did"] == account.did))

    assert response["latestRecord"]["did"] == account.did
    assert length(response["commitWeeks"]) == 8
    assert %{"collection" => "app.bsky.actor.profile", "recordCount" => 1} in response["collections"]
    assert %{"collection" => "app.bsky.feed.post", "recordCount" => 1} in response["collections"]

    encoded = response |> Jason.encode!() |> String.downcase()

    for sensitive <- [
          "email",
          "token",
          "session",
          "oauth",
          "backup",
          "admin",
          "password",
          "secret",
          "filesystem",
          "stats-public@example.com",
          Tempest.Config.load!().data_dir |> String.downcase()
        ] do
      refute encoded =~ sensitive
    end
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

  defp create_record!(auth, did, collection, rkey, record) do
    assert {:ok, _record} =
             Records.create_record(auth, %{
               "repo" => did,
               "collection" => collection,
               "rkey" => rkey,
               "validate" => false,
               "record" => record
             })
  end
end
