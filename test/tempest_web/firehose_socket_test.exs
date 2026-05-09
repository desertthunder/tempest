defmodule TempestWeb.FirehoseSocketTest do
  use TempestWeb.ConnCase, async: false

  alias Tempest.RepoCore.{Cid, Drisl}
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

    header = Drisl.encode!(%{"op" => 1, "t" => "#identity"})
    payload = binary_part(frame, byte_size(header), byte_size(frame) - byte_size(header))

    assert last_seq >= event.seq
    assert binary_part(frame, 0, byte_size(header)) == header
    assert {:ok, decoded} = Drisl.decode(payload)
    assert decoded["seq"] == event.seq
    assert decoded["did"] == did
  end

  test "omitted cursor starts after the current durable tail and receives live events" do
    assert {:ok, current_seq} = Sequencer.current_seq()
    assert {:ok, %FirehoseSocket{last_seq: ^current_seq} = state} = FirehoseSocket.init(%{cursor: nil})

    did = "did:plc:socketlive#{System.unique_integer([:positive])}"
    assert {:ok, event} = Sequencer.insert_identity_event(did, "create", %{"handle" => "socket-live.test"})

    assert {:push, {:binary, frame}, %FirehoseSocket{last_seq: last_seq}} =
             FirehoseSocket.handle_info({:tempest_firehose_event, event}, state)

    header = Drisl.encode!(%{"op" => 1, "t" => "#identity"})

    assert last_seq == event.seq
    assert binary_part(frame, 0, byte_size(header)) == header
  end

  test "subscriber receives a commit event after a record write", %{conn: conn} do
    account = create_account!(conn, "firehose-live.test", "firehose-live@example.com")

    assert {:ok, current_seq} = Sequencer.current_seq()
    assert {:ok, %FirehoseSocket{last_seq: ^current_seq} = state} = FirehoseSocket.init(%{cursor: nil})

    create_note!(conn, account, "live", "sent over the firehose")

    assert_receive {:tempest_firehose_event, %Sequencer.Event{event_type: "#commit"} = event}

    assert {:push, {:binary, frame}, %FirehoseSocket{last_seq: last_seq}} =
             FirehoseSocket.handle_info({:tempest_firehose_event, event}, state)

    header = Drisl.encode!(%{"op" => 1, "t" => "#commit"})
    payload = binary_part(frame, byte_size(header), byte_size(frame) - byte_size(header))

    assert binary_part(frame, 0, byte_size(header)) == header
    assert last_seq == event.seq
    assert {:ok, decoded} = Drisl.decode(payload)
    assert decoded["seq"] == event.seq
    assert decoded["repo"] == account["did"]
    assert decoded["commit"] == Cid.parse!(event.commit_cid)
    assert [%{"action" => "create", "path" => "app.tempest.note/live"}] = decoded["ops"]
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
end
