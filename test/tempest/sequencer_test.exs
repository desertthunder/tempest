defmodule Tempest.SequencerTest do
  use ExUnit.Case, async: false

  alias Tempest.RepoCore.Drisl
  alias Tempest.Sequencer

  test "insert APIs persist monotonic CBOR events for cursor backfill" do
    did = "did:plc:sequencer#{System.unique_integer([:positive])}"

    assert {:ok, identity} = Sequencer.insert_identity_event(did, "create", %{"handle" => "seq.test"})
    assert {:ok, account} = Sequencer.insert_account_event(did, "create", %{"active" => true, "status" => "active"})

    assert {:ok, commit} =
             Sequencer.insert_repo_commit(did, "3kseq", "bafyseq", "create", %{
               "ops" => [%{"action" => "create", "path" => "app.tempest.note/a", "cid" => "bafyrecord"}],
               "blobs" => [],
               "tooBig" => false
             })

    assert identity.seq < account.seq
    assert account.seq < commit.seq
    assert identity.event_type == "#identity"
    assert account.event_type == "#account"
    assert commit.event_type == "#commit"

    assert {:ok, decoded} = Drisl.decode(commit.event_cbor)
    assert decoded["seq"] == commit.seq
    assert decoded["did"] == did
    assert decoded["action"] == "create"
    assert decoded["rev"] == "3kseq"
    assert decoded["commit"] == "bafyseq"

    assert {:ok, events} = Sequencer.list_after(identity.seq - 1, did: did)
    assert Enum.map(events, & &1.seq) == [identity.seq, account.seq, commit.seq]
  end
end
