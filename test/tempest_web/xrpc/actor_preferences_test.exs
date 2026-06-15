defmodule TempestWeb.Xrpc.ActorPreferencesTest do
  use TempestWeb.ConnCase, async: false

  alias Tempest.OAuth.Dpop
  alias Tempest.Security.ExternalMetadataFetcher

  @password "correct horse battery staple"
  @client_id "https://prefs-client.example.com/oauth/client-metadata.json"
  @redirect_uri "https://prefs-client.example.com/cb"

  setup context do
    Req.Test.set_req_test_from_context(context)
    Req.Test.verify_on_exit!(context)

    original_fetcher_config = Application.get_env(:tempest, ExternalMetadataFetcher, [])

    Application.put_env(:tempest, ExternalMetadataFetcher,
      dns_lookup: fn "prefs-client.example.com" -> {:ok, [{93, 184, 216, 34}]} end,
      req_options: [plug: {Req.Test, __MODULE__}]
    )

    Req.Test.stub(__MODULE__, fn conn ->
      Req.Test.json(conn, client_metadata())
    end)

    on_exit(fn ->
      Application.put_env(:tempest, ExternalMetadataFetcher, original_fetcher_config)
    end)

    :ok
  end

  test "getPreferences and putPreferences round-trip private account preferences", %{conn: conn} do
    account = create_account!(conn, "prefs-alice.test", "prefs-alice@example.com")

    empty_conn =
      conn
      |> auth(account)
      |> get(~p"/xrpc/app.bsky.actor.getPreferences")

    assert json_response(empty_conn, 200) == %{"preferences" => []}

    preferences = [
      %{"$type" => "app.bsky.actor.defs#adultContentPref", "enabled" => true},
      %{"$type" => "app.bsky.actor.defs#savedFeedsPrefV2", "items" => []}
    ]

    put_conn =
      conn
      |> auth_json(account)
      |> post(~p"/xrpc/app.bsky.actor.putPreferences", %{"preferences" => preferences})

    assert json_response(put_conn, 200) == %{}

    get_conn =
      conn
      |> auth(account)
      |> get(~p"/xrpc/app.bsky.actor.getPreferences")

    assert json_response(get_conn, 200) == %{"preferences" => preferences}
  end

  test "putPreferences rejects non-array payloads", %{conn: conn} do
    account = create_account!(conn, "prefs-bob.test", "prefs-bob@example.com")

    rejected_conn =
      conn
      |> auth_json(account)
      |> post(~p"/xrpc/app.bsky.actor.putPreferences", %{"preferences" => %{}})

    assert %{"error" => "InvalidRequest"} = json_response(rejected_conn, 400)
  end

  test "preferences round-trip through delegated credentials", %{conn: conn} do
    account = create_account!(conn, "prefs-delegated.test", "prefs-delegated@example.com")
    app_password = create_app_password!(conn, account["accessJwt"])

    app_password_preferences = [
      %{"$type" => "app.bsky.actor.defs#savedFeedsPrefV2", "items" => []}
    ]

    app_password_put_conn =
      conn
      |> bearer_json(app_password)
      |> post(~p"/xrpc/app.bsky.actor.putPreferences", %{"preferences" => app_password_preferences})

    assert json_response(app_password_put_conn, 200) == %{}

    app_password_get_conn =
      conn
      |> bearer(app_password)
      |> get(~p"/xrpc/app.bsky.actor.getPreferences")

    assert json_response(app_password_get_conn, 200) == %{"preferences" => app_password_preferences}

    oauth_access = issue_oauth_access_token!(conn, account)

    oauth_preferences = [
      %{
        "$type" => "app.bsky.actor.defs#savedFeedsPrefV2",
        "items" => [
          %{
            "id" => "feedgen|did:plc:example|app.bsky.feed.generator/whats-hot",
            "type" => "feed",
            "value" => "at://did:plc:example/app.bsky.feed.generator/whats-hot",
            "pinned" => true
          }
        ]
      }
    ]

    oauth_put_conn =
      conn
      |> oauth_bearer_json(oauth_access, "POST", "https://tempest.desertthunder.dev/xrpc/app.bsky.actor.putPreferences")
      |> post(~p"/xrpc/app.bsky.actor.putPreferences", %{"preferences" => oauth_preferences})

    assert json_response(oauth_put_conn, 200) == %{}

    oauth_get_conn =
      conn
      |> oauth_bearer(oauth_access, "GET", "https://tempest.desertthunder.dev/xrpc/app.bsky.actor.getPreferences")
      |> get(~p"/xrpc/app.bsky.actor.getPreferences")

    assert json_response(oauth_get_conn, 200) == %{"preferences" => oauth_preferences}
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

  defp create_app_password!(conn, access_jwt) do
    conn
    |> auth_json(%{"accessJwt" => access_jwt})
    |> post(~p"/xrpc/com.atproto.server.createAppPassword", %{"name" => "prefs", "scope" => "atproto"})
    |> json_response(200)
    |> Map.fetch!("password")
  end

  defp issue_oauth_access_token!(conn, account) do
    par_conn =
      conn
      |> recycle()
      |> put_req_header("dpop", dpop("POST", "http://localhost:4002/oauth/par"))
      |> post(~p"/oauth/par", %{
        "client_id" => @client_id,
        "redirect_uri" => @redirect_uri,
        "scope" => "atproto",
        "response_type" => "code",
        "code_challenge" => code_challenge("verifier"),
        "code_challenge_method" => "S256"
      })

    %{"request_uri" => request_uri} = json_response(par_conn, 200)

    authorize_conn =
      conn
      |> recycle()
      |> post(~p"/oauth/authorize", %{
        "request_uri" => request_uri,
        "identifier" => account["handle"],
        "password" => @password
      })

    [location] = get_resp_header(authorize_conn, "location")
    code = location |> URI.parse() |> Map.fetch!(:query) |> URI.decode_query() |> Map.fetch!("code")

    token_conn =
      conn
      |> recycle()
      |> put_req_header("dpop", dpop("POST", "http://localhost:4002/oauth/token"))
      |> post(~p"/oauth/token", %{
        "grant_type" => "authorization_code",
        "client_id" => @client_id,
        "redirect_uri" => @redirect_uri,
        "code" => code,
        "code_verifier" => "verifier"
      })

    token_conn
    |> json_response(200)
    |> Map.fetch!("access_token")
  end

  defp auth(conn, account) do
    conn
    |> recycle()
    |> put_req_header("authorization", "Bearer #{account["accessJwt"]}")
  end

  defp bearer(conn, token) do
    conn
    |> recycle()
    |> put_req_header("authorization", "Bearer #{token}")
  end

  defp bearer_json(conn, token) do
    conn
    |> bearer(token)
    |> put_req_header("content-type", "application/json")
  end

  defp auth_json(conn, account) do
    conn
    |> auth(account)
    |> put_req_header("content-type", "application/json")
  end

  defp oauth_bearer(conn, token, method, url) do
    conn
    |> bearer(token)
    |> put_req_header("dpop", dpop(method, url))
    |> put_req_header("x-forwarded-proto", "https")
    |> put_req_header("x-forwarded-host", "tempest.desertthunder.dev")
  end

  defp oauth_bearer_json(conn, token, method, url) do
    conn
    |> oauth_bearer(token, method, url)
    |> put_req_header("content-type", "application/json")
  end

  defp dpop(method, url), do: Tempest.DpopProof.proof(method, url, Dpop.issue_nonce())

  defp code_challenge(verifier) do
    :crypto.hash(:sha256, verifier)
    |> Base.url_encode64(padding: false)
  end

  defp client_metadata do
    %{
      "client_id" => @client_id,
      "client_name" => "Preferences Test Client",
      "redirect_uris" => [@redirect_uri],
      "grant_types" => ["authorization_code", "refresh_token"],
      "response_types" => ["code"],
      "scope" => "atproto",
      "token_endpoint_auth_method" => "none",
      "application_type" => "web",
      "dpop_bound_access_tokens" => true
    }
  end
end
