defmodule Tempest.Sync.EventStreamTest do
  use ExUnit.Case, async: true

  alias Tempest.RepoCore.{Cid, Drisl}
  alias Tempest.Sequencer.Event
  alias Tempest.Sync.EventStream

  test "encodes message frames as header CBOR followed by payload CBOR" do
    {:ok, cid} = Cid.parse("bafyreihdwdcefgh4dqkjv67uzcmw7ojee6xedzdetojuzjevtenxquvyku")

    event = %Event{
      seq: 42,
      did: "did:plc:frame",
      event_type: "#commit",
      rev: "3kframe",
      commit_cid: Cid.to_string(cid),
      created_at: "2026-05-09T00:00:00Z",
      event_cbor: "stored",
      payload: %{
        "$type" => "com.atproto.sync.subscribeRepos#commit",
        "seq" => 42,
        "did" => "did:plc:frame",
        "action" => "create",
        "rev" => "3kframe",
        "commit" => Cid.to_string(cid),
        "ops" => [%{"action" => "create", "path" => "app.tempest.note/a", "cid" => Cid.to_string(cid)}],
        "blocks" => Drisl.bytes("car"),
        "blobs" => [],
        "tooBig" => false,
        "time" => "2026-05-09T00:00:00Z"
      }
    }

    assert {:ok, frame} = EventStream.encode_message(event)
    header = Drisl.encode!(%{"op" => 1, "t" => "#commit"})
    payload = binary_part(frame, byte_size(header), byte_size(frame) - byte_size(header))

    assert binary_part(frame, 0, byte_size(header)) == header
    assert {:ok, decoded} = Drisl.decode(payload)
    assert decoded["repo"] == "did:plc:frame"
    assert decoded["commit"] == cid
    assert [%{"cid" => ^cid}] = decoded["ops"]
    refute Map.has_key?(decoded, "$type")
    refute Map.has_key?(decoded, "did")
  end
end
