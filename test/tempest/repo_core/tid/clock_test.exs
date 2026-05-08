defmodule Tempest.RepoCore.Tid.ClockTest do
  use ExUnit.Case, async: true

  alias Tempest.RepoCore.Tid
  alias Tempest.RepoCore.Tid.Clock

  @alice "did:plc:ewvi7nxzyoun6zhxrhs64oiz"
  @bob "did:plc:vwzwgnygau7ed7b7wt5ux7y2"

  test "generates monotonically increasing TIDs per DID" do
    clock = start_supervised!({Clock, clock_id: 5})

    assert {:ok, first} = Clock.next(clock, @alice, now_unix_microseconds: 1_000)
    assert {:ok, second} = Clock.next(clock, @alice, now_unix_microseconds: 1_000)
    assert {:ok, third} = Clock.next(clock, @alice, now_unix_microseconds: 999)
    assert {:ok, bob_first} = Clock.next(clock, @bob, now_unix_microseconds: 999)

    assert first.unix_microseconds == 1_000
    assert second.unix_microseconds == 1_001
    assert third.unix_microseconds == 1_002
    assert bob_first.unix_microseconds == 999

    assert first.clock_id == 5
    assert second.clock_id == 5
    assert third.clock_id == 5
    assert bob_first.clock_id == 5

    assert first.value < second.value
    assert second.value < third.value
  end

  test "rejects invalid DIDs and invalid clock settings" do
    clock = start_supervised!({Clock, clock_id: 0})

    assert Clock.next(clock, "not-a-did", now_unix_microseconds: 1) ==
             {:error, {:invalid_did, :invalid_did_syntax}}

    assert Clock.next(clock, @alice, now_unix_microseconds: -1) == {:error, :timestamp_out_of_range}
    assert {:error, _reason} = start_supervised({Clock, clock_id: 1024})
  end

  test "generates random clock IDs in the TID clock range" do
    for _ <- 1..100 do
      assert Clock.random_clock_id() in 0..Tid.max_clock_id()
    end
  end

  test "fails instead of overflowing the per-DID monotonic guard" do
    clock = start_supervised!({Clock, clock_id: 0})

    assert {:ok, max_tid} =
             Clock.next(clock, @alice, now_unix_microseconds: Tid.max_unix_microseconds())

    assert max_tid.unix_microseconds == Tid.max_unix_microseconds()

    assert Clock.next(clock, @alice, now_unix_microseconds: Tid.max_unix_microseconds()) ==
             {:error, :timestamp_out_of_range}
  end
end
