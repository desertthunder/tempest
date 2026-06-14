defmodule TempestWeb.FirehoseSocketTest do
  use TempestWeb.ConnCase, async: false

  alias Tempest.RepoCore.{Car, CarVerifier, Cid, Commit, Drisl}
  alias Tempest.Sequencer
  alias TempestWeb.FirehoseSocket

  @password "correct horse battery staple"

  setup context do
    Tempest.LexiconFixtures.install!(context)
  end

  test "cursor backfill pushes existing sequencer events and tracks last seq" do
    did = "did:plc:socket#{System.unique_integer([:positive])}"

    assert {:ok, event} = Sequencer.insert_identity_event(did, "create", %{"handle" => "socket.test"})

    assert {:push, [{:binary, frame}], %FirehoseSocket{last_seq: last_seq}} =
             FirehoseSocket.init(%{cursor: event.seq - 1})

    assert last_seq >= event.seq
    assert {header, decoded} = decode_frame!(frame, "#identity")
    assert header == %{"op" => 1, "t" => "#identity"}
    assert decoded["seq"] == event.seq
    assert decoded["did"] == did
    assert decoded["handle"] == "socket.test"
    refute Map.has_key?(decoded, "$type")
  end

  test "omitted cursor starts after the current durable tail and receives live events" do
    assert {:ok, current_seq} = Sequencer.current_seq()
    assert {:ok, %FirehoseSocket{last_seq: ^current_seq} = state} = FirehoseSocket.init(%{cursor: nil})

    did = "did:plc:socketlive#{System.unique_integer([:positive])}"
    assert {:ok, event} = Sequencer.insert_identity_event(did, "create", %{"handle" => "socket-live.test"})

    assert {:push, {:binary, frame}, %FirehoseSocket{last_seq: last_seq}} =
             FirehoseSocket.handle_info({:tempest_firehose_event, event}, state)

    assert last_seq == event.seq
    assert {%{"op" => 1, "t" => "#identity"}, decoded} = decode_frame!(frame, "#identity")
    assert decoded["seq"] == event.seq
    assert decoded["did"] == did
  end

  test "subscriber receives a commit event after a record write", %{conn: conn} do
    account = create_account!(conn, "firehose-live.test", "firehose-live@example.com")

    assert {:ok, current_seq} = Sequencer.current_seq()
    assert {:ok, %FirehoseSocket{last_seq: ^current_seq} = state} = FirehoseSocket.init(%{cursor: nil})

    create_note!(conn, account, "live", "sent over the firehose")

    assert_receive {:tempest_firehose_event, %Sequencer.Event{event_type: "#commit"} = event}

    assert {:push, {:binary, frame}, %FirehoseSocket{last_seq: last_seq}} =
             FirehoseSocket.handle_info({:tempest_firehose_event, event}, state)

    assert last_seq == event.seq
    assert {%{"op" => 1, "t" => "#commit"}, decoded} = decode_frame!(frame, "#commit")
    assert decoded["seq"] == event.seq
    assert decoded["repo"] == account["did"]
    assert decoded["commit"] == Cid.parse!(event.commit_cid)
    assert %Drisl.Bytes{bytes: blocks} = decoded["blocks"]
    assert byte_size(blocks) > 0
    assert [%{"action" => "create", "path" => "app.tempest.note/live", "cid" => %Cid{}}] = decoded["ops"]
    assert decoded["blobs"] == []
    assert decoded["rebase"] == false
    assert decoded["tooBig"] == false
    assert_valid_commit_frame!(decoded, account["did"], event.commit_cid, event.rev)
    refute Map.has_key?(decoded, "$type")
    refute Map.has_key?(decoded, "did")
  end

  test "commit frames carry a coherent since and prevData chain", %{conn: conn} do
    account = create_account!(conn, "firehose-chain.test", "firehose-chain@example.com")

    assert {:ok, current_seq} = Sequencer.current_seq()
    assert {:ok, %FirehoseSocket{last_seq: ^current_seq} = state} = FirehoseSocket.init(%{cursor: nil})

    first = create_note!(conn, account, "first", "first post")
    first_event = receive_commit_event!()
    {first_state, first_frame} = push_commit_event!(state, first_event)
    first_commit = commit_from_frame!(first_frame)

    second = create_note!(conn, account, "second", "second post")
    second_event = receive_commit_event!()
    {_second_state, second_frame} = push_commit_event!(first_state, second_event)

    assert second_frame["since"] == first["commit"]["rev"]
    assert second_frame["prevData"] == first_commit.data
    assert_valid_commit_frame!(first_frame, account["did"], first["commit"]["cid"], first["commit"]["rev"])
    assert_valid_commit_frame!(second_frame, account["did"], second["commit"]["cid"], second["commit"]["rev"])
  end

  test "update and delete commit ops include the previous record CID", %{conn: conn} do
    account = create_account!(conn, "firehose-prev.test", "firehose-prev@example.com")

    assert {:ok, current_seq} = Sequencer.current_seq()
    assert {:ok, %FirehoseSocket{last_seq: ^current_seq} = state} = FirehoseSocket.init(%{cursor: nil})

    created = create_note!(conn, account, "mutable", "before")
    create_event = receive_commit_event!()
    {state, _create_frame} = push_commit_event!(state, create_event)

    updated = put_note!(conn, account, "mutable", "after", created)
    update_event = receive_commit_event!()
    {state, update_frame} = push_commit_event!(state, update_event)

    assert [update_op] = update_frame["ops"]
    assert update_op["action"] == "update"
    assert update_op["path"] == "app.tempest.note/mutable"
    assert Cid.to_string(update_op["cid"]) == updated["cid"]
    assert Cid.to_string(update_op["prev"]) == created["cid"]
    assert update_frame["since"] == created["commit"]["rev"]
    assert_valid_commit_frame!(update_frame, account["did"], updated["commit"]["cid"], updated["commit"]["rev"])

    deleted = delete_note!(conn, account, "mutable", updated)
    delete_event = receive_commit_event!()
    {_state, delete_frame} = push_commit_event!(state, delete_event)

    assert [delete_op] = delete_frame["ops"]
    assert delete_op["action"] == "delete"
    assert delete_op["path"] == "app.tempest.note/mutable"
    assert delete_op["cid"] == nil
    assert Cid.to_string(delete_op["prev"]) == updated["cid"]
    assert delete_frame["since"] == updated["commit"]["rev"]
    assert deleted["commit"]["cid"] == delete_event.commit_cid
    assert_valid_commit_frame!(delete_frame, account["did"], deleted["commit"]["cid"], deleted["commit"]["rev"])
  end

  test "bsky post and like writes produce valid commit frames", %{conn: conn} do
    account = create_account!(conn, "firehose-bsky.test", "firehose-bsky@example.com")

    assert {:ok, current_seq} = Sequencer.current_seq()
    assert {:ok, %FirehoseSocket{last_seq: ^current_seq} = state} = FirehoseSocket.init(%{cursor: nil})

    post = create_bsky_post!(conn, account, "3mo7hac7efyou", "firehose-visible post")
    post_event = receive_commit_event!()
    {state, post_frame} = push_commit_event!(state, post_event)

    assert [%{"action" => "create", "path" => "app.bsky.feed.post/3mo7hac7efyou", "cid" => post_cid}] =
             post_frame["ops"]

    assert Cid.to_string(post_cid) == post["cid"]
    assert_valid_commit_frame!(post_frame, account["did"], post["commit"]["cid"], post["commit"]["rev"])

    like = create_bsky_like!(conn, account, "3mo7hac7egabc", post)
    like_event = receive_commit_event!()
    {_state, like_frame} = push_commit_event!(state, like_event)

    assert [%{"action" => "create", "path" => "app.bsky.feed.like/3mo7hac7egabc", "cid" => like_cid}] =
             like_frame["ops"]

    assert Cid.to_string(like_cid) == like["cid"]
    assert like_frame["since"] == post["commit"]["rev"]
    assert_valid_commit_frame!(like_frame, account["did"], like["commit"]["cid"], like["commit"]["rev"])
  end

  test "deactivated accounts emit account frames with no repo content", %{conn: conn} do
    account = create_account!(conn, "firehose-deactivated.test", "firehose-deactivated@example.com")

    assert {:ok, current_seq} = Sequencer.current_seq()
    assert {:ok, %FirehoseSocket{last_seq: ^current_seq} = state} = FirehoseSocket.init(%{cursor: nil})

    conn
    |> auth_json(account)
    |> post(~p"/xrpc/com.atproto.server.deactivateAccount", %{})
    |> json_response(200)

    assert_receive {:tempest_firehose_event, %Sequencer.Event{event_type: "#account"} = event}

    assert {:push, {:binary, frame}, %FirehoseSocket{last_seq: last_seq}} =
             FirehoseSocket.handle_info({:tempest_firehose_event, event}, state)

    assert last_seq == event.seq
    assert {%{"op" => 1, "t" => "#account"}, decoded} = decode_frame!(frame, "#account")
    assert decoded["seq"] == event.seq
    assert decoded["did"] == account["did"]
    assert decoded["active"] == false
    assert decoded["status"] == "deactivated"
    refute Map.has_key?(decoded, "blocks")
    refute Map.has_key?(decoded, "ops")
  end

  defp decode_frame!(frame, type) do
    header_bytes = Drisl.encode!(%{"op" => 1, "t" => type})
    payload_bytes = binary_part(frame, byte_size(header_bytes), byte_size(frame) - byte_size(header_bytes))

    assert binary_part(frame, 0, byte_size(header_bytes)) == header_bytes
    assert {:ok, header} = Drisl.decode(header_bytes)
    assert {:ok, payload} = Drisl.decode(payload_bytes)

    {header, payload}
  end

  defp push_commit_event!(%FirehoseSocket{} = state, %Sequencer.Event{event_type: "#commit"} = event) do
    assert {:push, {:binary, frame}, %FirehoseSocket{} = state} =
             FirehoseSocket.handle_info({:tempest_firehose_event, event}, state)

    assert {%{"op" => 1, "t" => "#commit"}, decoded} = decode_frame!(frame, "#commit")
    {state, decoded}
  end

  defp receive_commit_event! do
    assert_receive {:tempest_firehose_event, %Sequencer.Event{event_type: "#commit"} = event}
    event
  end

  defp assert_valid_commit_frame!(payload, did, commit_cid, rev) do
    assert payload["repo"] == did
    assert payload["commit"] == Cid.parse!(commit_cid)
    assert payload["rev"] == rev
    assert payload["rebase"] == false
    assert payload["tooBig"] == false
    assert is_list(payload["ops"])
    assert is_list(payload["blobs"])

    verifier_payload = Map.merge(payload, %{"did" => did, "commit" => commit_cid, "rev" => rev})
    assert :ok = CarVerifier.verify_commit_event(verifier_payload)

    assert {:ok, car} = Car.decode(payload["blocks"].bytes)
    commit = payload["commit"]
    assert [^commit | _rest] = car.roots
    assert Enum.any?(car.blocks, &(&1.cid == commit))
  end

  defp commit_from_frame!(payload) do
    assert {:ok, car} = Car.decode(payload["blocks"].bytes)
    assert [commit_cid | _rest] = car.roots
    assert %{data: commit_bytes} = Enum.find(car.blocks, &(&1.cid == commit_cid))
    assert {:ok, commit} = Commit.decode(commit_bytes)
    commit
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

  defp put_note!(conn, account, rkey, text, previous) do
    conn
    |> auth_json(account)
    |> post(~p"/xrpc/com.atproto.repo.putRecord", %{
      "repo" => account["did"],
      "collection" => "app.tempest.note",
      "rkey" => rkey,
      "validate" => false,
      "swapRecord" => previous["cid"],
      "swapCommit" => previous["commit"]["cid"],
      "record" => %{
        "$type" => "app.tempest.note",
        "text" => text
      }
    })
    |> json_response(200)
  end

  defp delete_note!(conn, account, rkey, previous) do
    conn
    |> auth_json(account)
    |> post(~p"/xrpc/com.atproto.repo.deleteRecord", %{
      "repo" => account["did"],
      "collection" => "app.tempest.note",
      "rkey" => rkey,
      "swapRecord" => previous["cid"],
      "swapCommit" => previous["commit"]["cid"]
    })
    |> json_response(200)
  end

  defp create_bsky_post!(conn, account, rkey, text) do
    conn
    |> auth_json(account)
    |> post(~p"/xrpc/com.atproto.repo.createRecord", %{
      "repo" => account["did"],
      "collection" => "app.bsky.feed.post",
      "rkey" => rkey,
      "validate" => true,
      "record" => %{
        "$type" => "app.bsky.feed.post",
        "text" => text,
        "createdAt" => "2026-06-14T00:00:00.000Z"
      }
    })
    |> json_response(200)
  end

  defp create_bsky_like!(conn, account, rkey, post) do
    conn
    |> auth_json(account)
    |> post(~p"/xrpc/com.atproto.repo.createRecord", %{
      "repo" => account["did"],
      "collection" => "app.bsky.feed.like",
      "rkey" => rkey,
      "validate" => true,
      "record" => %{
        "$type" => "app.bsky.feed.like",
        "subject" => %{
          "uri" => post["uri"],
          "cid" => post["cid"]
        },
        "createdAt" => "2026-06-14T00:00:01.000Z"
      }
    })
    |> json_response(200)
  end
end
