defmodule Tempest.SequencerTest do
  use ExUnit.Case, async: false

  alias Tempest.RepoCore.Drisl
  alias Tempest.Sequencer
  alias Tempest.Storage.Timestamp

  test "insert broadcasts only after the durable event exists" do
    did = "did:plc:pubsub#{System.unique_integer([:positive])}"

    :ok = Sequencer.subscribe()

    assert {:ok, event} = Sequencer.insert_identity_event(did, "create", %{"handle" => "pubsub.test"})
    assert_receive {:tempest_firehose_event, ^event}

    assert {:ok, [stored]} = Sequencer.list_after(event.seq - 1, did: did)
    assert stored.seq == event.seq
    assert stored.event_cbor == event.event_cbor
  end

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

  test "sequence continuity survives storage bootstrap restart" do
    did = "did:plc:restart#{System.unique_integer([:positive])}"

    assert {:ok, first} = Sequencer.insert_identity_event(did, "create", %{"handle" => "restart.test"})

    :ok =
      Tempest.Config.load!()
      |> Tempest.Storage.bootstrap!()

    assert {:ok, second} = Sequencer.insert_account_event(did, "activate", %{"active" => true})
    assert second.seq > first.seq

    assert {:ok, events} = Sequencer.list_after(first.seq - 1, did: did)
    assert Enum.map(events, & &1.seq) == [first.seq, second.seq]
  end

  test "durable tail is recoverable when pubsub fanout is missed" do
    did = "did:plc:tail#{System.unique_integer([:positive])}"

    assert {:ok, cursor} = Sequencer.current_seq()
    assert {:ok, event} = Sequencer.insert_identity_event(did, "create", %{"handle" => "tail.test"})

    assert {:ok, [recovered]} = Sequencer.list_after(cursor, did: did)
    assert recovered.seq == event.seq
    assert recovered.event_cbor == event.event_cbor
  end

  test "torn sequencer rows are detected and skipped without reusing sequence numbers" do
    did = "did:plc:torn#{System.unique_integer([:positive])}"

    assert {:ok, before_seq} = Sequencer.current_seq()
    insert_torn_row!(did)

    assert {:ok, torn_count} = Sequencer.torn_write_count()
    assert torn_count >= 1

    assert {:ok, event} = Sequencer.insert_identity_event(did, "create", %{"handle" => "torn.test"})
    assert event.seq > before_seq + 1

    assert {:ok, events} = Sequencer.list_after(before_seq, did: did)
    assert Enum.map(events, & &1.seq) == [event.seq]

    delete_torn_rows!(did)
  end

  defp insert_torn_row!(did) do
    path =
      Tempest.Config.load!()
      |> Tempest.Config.sequencer_db_path()

    {:ok, conn} = Exqlite.Sqlite3.open(path)

    {:ok, statement} =
      Exqlite.Sqlite3.prepare(
        conn,
        "INSERT INTO repo_seq (did, event_type, event_cbor, created_at) VALUES (?1, ?2, ?3, ?4)"
      )

    :ok = Exqlite.Sqlite3.bind(statement, [did, "#identity", "", Timestamp.iso8601_utc()])
    :done = Exqlite.Sqlite3.step(conn, statement)
    :ok = Exqlite.Sqlite3.release(conn, statement)
    :ok = Exqlite.Sqlite3.close(conn)
  end

  defp delete_torn_rows!(did) do
    path =
      Tempest.Config.load!()
      |> Tempest.Config.sequencer_db_path()

    {:ok, conn} = Exqlite.Sqlite3.open(path)

    {:ok, statement} =
      Exqlite.Sqlite3.prepare(conn, "DELETE FROM repo_seq WHERE did = ?1 AND event_cbor = ''")

    :ok = Exqlite.Sqlite3.bind(statement, [did])
    :done = Exqlite.Sqlite3.step(conn, statement)
    :ok = Exqlite.Sqlite3.release(conn, statement)
    :ok = Exqlite.Sqlite3.close(conn)
  end
end
