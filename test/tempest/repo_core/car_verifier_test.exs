defmodule Tempest.RepoCore.CarVerifierTest do
  use ExUnit.Case, async: true

  alias Tempest.RepoCore.{Car, CarVerifier, Cid, Commit, Drisl, Mst, Tid}

  @did "did:plc:ewvi7nxzyoun6zhxrhs64oiz"

  test "verifies a complete repo CAR graph rooted at a commit" do
    {car_bytes, commit_cid, record_cid} = fixture_car()

    assert {:ok, verified} = CarVerifier.verify_repo_car(car_bytes, did: @did)
    assert verified.commit_cid == commit_cid
    assert verified.commit.did == @did
    assert Map.fetch!(verified.entries, "app.tempest.note/self") == record_cid
  end

  test "rejects repo CARs missing record blocks referenced by the MST" do
    {_car_bytes, commit_cid, record_cid, commit_bytes, mst_blocks} = fixture_parts()
    assert {:ok, incomplete_car} = Car.encode([commit_cid], mst_blocks ++ [{commit_cid, commit_bytes}])

    assert CarVerifier.verify_repo_car(incomplete_car, did: @did) ==
             {:error, {:missing_block, Cid.to_string(record_cid)}}
  end

  defp fixture_car do
    {car_bytes, commit_cid, record_cid, _commit_bytes, _mst_blocks} = fixture_parts()
    {car_bytes, commit_cid, record_cid}
  end

  defp fixture_parts do
    {_public_key, private_key} = :crypto.generate_key(:ecdh, :secp256k1)

    record = %{"$type" => "app.tempest.note", "text" => "hello"}
    {:ok, record_bytes} = Drisl.encode(record)
    record_cid = Cid.for_drisl(record_bytes)

    mst = Mst.from_entries!([{"app.tempest.note/self", record_cid}])
    {:ok, %{root: root, blocks: mst_blocks}} = Mst.serialize(mst)

    unsigned =
      Commit.new!(%{
        did: @did,
        data: root,
        rev: Tid.new!(1_700_000_000_000_000, 0),
        prev: nil
      })

    {:ok, commit} = Commit.sign(unsigned, private_key)
    commit_bytes = Commit.encode!(commit)
    commit_cid = Commit.cid!(commit)
    blocks = mst_blocks ++ [{record_cid, record_bytes}, {commit_cid, commit_bytes}]

    {:ok, car_bytes} = Car.encode([commit_cid], blocks)
    {car_bytes, commit_cid, record_cid, commit_bytes, mst_blocks}
  end
end
