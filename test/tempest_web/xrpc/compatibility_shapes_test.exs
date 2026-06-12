defmodule TempestWeb.Xrpc.CompatibilityShapesTest do
  use TempestWeb.ConnCase, async: false

  @password "correct horse battery staple"

  test "core PDS endpoints return Lexicon-compatible success response shapes", %{conn: conn} do
    account = create_account!(conn, "shape-alice.test", "shape-alice@example.com")
    access_jwt = account["accessJwt"]
    did = account["did"]

    assert %{
             "did" => ^did,
             "handle" => "shape-alice.test",
             "email" => "shape-alice@example.com",
             "accessJwt" => ^access_jwt,
             "refreshJwt" => refresh_jwt,
             "active" => true
           } = account

    assert is_binary(access_jwt)
    assert is_binary(refresh_jwt)

    assert %{
             "did" => ^did,
             "handle" => "shape-alice.test",
             "email" => "shape-alice@example.com",
             "accessJwt" => session_access_jwt,
             "refreshJwt" => session_refresh_jwt,
             "active" => true
           } = create_session!(conn, "shape-alice.test")

    assert is_binary(session_access_jwt)
    assert is_binary(session_refresh_jwt)

    assert %{
             "did" => ^did,
             "handle" => "shape-alice.test",
             "email" => "shape-alice@example.com"
           } = authed_get!(conn, access_jwt, ~p"/xrpc/com.atproto.server.getSession")

    assert %{
             "did" => ^did,
             "active" => true,
             "status" => "active",
             "repoCount" => 1,
             "recordCount" => 0,
             "blobCount" => 0,
             "missingBlobCount" => 0,
             "migrationReady" => true
           } = authed_get!(conn, access_jwt, ~p"/xrpc/com.atproto.server.checkAccountStatus")

    assert %{
             "uri" => "at://" <> _,
             "cid" => record_cid,
             "commit" => %{"cid" => commit_cid, "rev" => rev},
             "validationStatus" => "valid"
           } = create_profile!(conn, account, "Alice")

    assert is_binary(record_cid)
    assert is_binary(commit_cid)
    assert is_binary(rev)

    assert %{
             "uri" => "at://" <> _,
             "cid" => ^record_cid,
             "value" => %{"$type" => "app.bsky.actor.profile", "displayName" => "Alice"}
           } =
             get_json!(conn, ~p"/xrpc/com.atproto.repo.getRecord", %{
               "repo" => did,
               "collection" => "app.bsky.actor.profile",
               "rkey" => "self"
             })

    assert %{
             "records" => [
               %{
                 "uri" => "at://" <> _,
                 "cid" => ^record_cid,
                 "value" => %{"displayName" => "Alice"}
               }
             ]
           } =
             get_json!(conn, ~p"/xrpc/com.atproto.repo.listRecords", %{
               "repo" => did,
               "collection" => "app.bsky.actor.profile"
             })

    assert %{
             "did" => ^did,
             "handle" => "shape-alice.test",
             "collections" => ["app.bsky.actor.profile"],
             "handleIsCorrect" => true,
             "didDoc" => %{"id" => ^did}
           } = get_json!(conn, ~p"/xrpc/com.atproto.repo.describeRepo", %{"repo" => did})

    assert %{"cid" => ^commit_cid, "rev" => ^rev} =
             get_json!(conn, ~p"/xrpc/com.atproto.sync.getLatestCommit", %{"did" => did})

    assert %{"did" => ^did, "active" => true, "rev" => ^rev} =
             get_json!(conn, ~p"/xrpc/com.atproto.sync.getRepoStatus", %{"did" => did})

    assert %{"repos" => repos} = get_json!(conn, ~p"/xrpc/com.atproto.sync.listRepos", %{"limit" => "100"})
    assert Enum.any?(repos, &match?(%{"did" => ^did, "head" => ^commit_cid, "rev" => ^rev}, &1))

    assert %{"cids" => []} = get_json!(conn, ~p"/xrpc/com.atproto.sync.listBlobs", %{"did" => did})
  end

  test "core PDS endpoints return protocol error shapes", %{conn: conn} do
    assert_error(
      get(conn, ~p"/xrpc/com.atproto.unknown.method"),
      404,
      "UnknownMethod",
      "com.atproto.unknown.method is not a supported XRPC method"
    )

    assert_error(
      post(conn, ~p"/xrpc/com.atproto.server.describeServer", %{}),
      400,
      "InvalidRequest",
      "com.atproto.server.describeServer is a query method and must use GET, not POST"
    )

    assert_error(
      get(conn, ~p"/xrpc/com.atproto.server.getSession"),
      401,
      "AuthenticationRequired",
      "Bearer token is required"
    )

    assert_error(
      post_json(conn, ~p"/xrpc/com.atproto.server.createSession", %{
        "identifier" => "missing.test",
        "password" => "wrong"
      }),
      401,
      "AuthenticationRequired",
      "Invalid identifier or password"
    )

    assert_error(
      get(conn, ~p"/xrpc/com.atproto.identity.resolveHandle", %{"handle" => "not-a-handle"}),
      400,
      "InvalidRequest",
      "handle is invalid"
    )

    account = create_account!(conn, "shape-errors.test", "shape-errors@example.com")

    assert_error(
      get(conn, ~p"/xrpc/com.atproto.repo.getRecord", %{
        "repo" => account["did"],
        "collection" => "app.bsky.actor.profile",
        "rkey" => "self"
      }),
      400,
      "RecordNotFound",
      "record could not be found"
    )

    assert_error(
      get(conn, ~p"/xrpc/com.atproto.sync.getRepo", %{"did" => "not-a-did"}),
      400,
      "InvalidRequest",
      "did is invalid"
    )
  end

  defp create_account!(conn, handle, email) do
    conn
    |> post_json(~p"/xrpc/com.atproto.server.createAccount", %{
      "handle" => handle,
      "email" => email,
      "password" => @password
    })
    |> json_response(200)
  end

  defp create_session!(conn, identifier) do
    conn
    |> post_json(~p"/xrpc/com.atproto.server.createSession", %{
      "identifier" => identifier,
      "password" => @password
    })
    |> json_response(200)
  end

  defp create_profile!(conn, account, display_name) do
    conn
    |> auth_json(account["accessJwt"])
    |> post(~p"/xrpc/com.atproto.repo.createRecord", %{
      "repo" => account["did"],
      "collection" => "app.bsky.actor.profile",
      "rkey" => "self",
      "record" => %{"$type" => "app.bsky.actor.profile", "displayName" => display_name}
    })
    |> json_response(200)
  end

  defp authed_get!(conn, token, path) do
    conn
    |> recycle()
    |> put_req_header("authorization", "Bearer #{token}")
    |> get(path)
    |> json_response(200)
  end

  defp get_json!(conn, path, params) do
    conn
    |> recycle()
    |> get(path, params)
    |> json_response(200)
  end

  defp post_json(conn, path, params) do
    conn
    |> recycle()
    |> put_req_header("content-type", "application/json")
    |> post(path, params)
  end

  defp auth_json(conn, token) do
    conn
    |> recycle()
    |> put_req_header("authorization", "Bearer #{token}")
    |> put_req_header("content-type", "application/json")
  end

  defp assert_error(conn, status, error, message) do
    response = json_response(conn, status)

    assert get_resp_header(conn, "content-type") == ["application/json; charset=utf-8"]
    assert response == %{"error" => error, "message" => message}
  end
end
