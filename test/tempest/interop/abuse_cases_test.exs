defmodule Tempest.Interop.AbuseCasesTest do
  use ExUnit.Case, async: true

  alias Tempest.RepoCore.{Car, Cid, Drisl}
  alias Tempest.Sequencer.Event
  alias Tempest.Sync.EventStream

  test "deep CBOR and malformed CAR inputs are rejected without raising" do
    assert Drisl.decode(<<0x81, 0x81, 0x81, 0x00>>, max_depth: 2) == {:error, :max_depth_exceeded}
    assert Car.decode(<<0x81>>) == {:error, :invalid_varint}
  end

  test "invalid CIDs and oversized firehose frames are rejected" do
    assert Cid.parse("not-a-cid") == {:error, :unsupported_multibase}

    event = %Event{
      seq: 1,
      did: "did:plc:abcdefghijklmnopqrstuvwxyz",
      event_type: "#identity",
      payload: %{"did" => "did:plc:abcdefghijklmnopqrstuvwxyz", "action" => :binary.copy("x", 5_000_001)},
      event_cbor: <<>>,
      created_at: "2026-05-29T00:00:00Z"
    }

    assert EventStream.encode_message(event) == {:error, :frame_too_large}
  end
end
