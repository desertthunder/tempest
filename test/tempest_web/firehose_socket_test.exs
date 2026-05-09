defmodule TempestWeb.FirehoseSocketTest do
  use ExUnit.Case, async: false

  alias Tempest.RepoCore.Drisl
  alias Tempest.Sequencer
  alias TempestWeb.FirehoseSocket

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
end
