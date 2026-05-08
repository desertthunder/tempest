defmodule Tempest.RepoCore.FixtureImporterTest do
  use ExUnit.Case, async: true

  alias Tempest.RepoCore.{Car, Cid, Commit, FixtureImporter, Mst, Tid}

  @did "did:plc:ewvi7nxzyoun6zhxrhs64oiz"

  test "imports an official-shape repo CAR fixture rooted at a signed commit" do
    {public_key, private_key} = :crypto.generate_key(:ecdh, :secp256k1)
    {car_bytes, commit, commit_cid, did_document} = fixture_car(private_key, public_key)

    assert {:ok, imported} = FixtureImporter.import_car(car_bytes, did_document: did_document)
    assert imported.commit == commit
    assert imported.commit_cid == commit_cid
    assert imported.car.roots == [commit_cid]
    assert Map.fetch!(imported.blocks_by_cid, Cid.to_string(commit_cid)) == Commit.encode!(commit)
  end

  test "rejects fixture CARs with invalid commit signatures" do
    {public_key, private_key} = :crypto.generate_key(:ecdh, :secp256k1)
    {car_bytes, _commit, _commit_cid, did_document} = fixture_car(private_key, public_key)

    bad_document =
      put_in(
        did_document,
        ["verificationMethod", Access.at(0), "publicKeyMultibase"],
        "u" <> Base.url_encode64(:binary.copy(<<0>>, 65), padding: false)
      )

    assert FixtureImporter.import_car(car_bytes, did_document: bad_document) ==
             {:error, {:commit_error, :invalid_public_key}}
  end

  test "rejects fixtures without commit roots" do
    assert {:ok, car_bytes} = Car.encode([], [], require_roots_present: false)
    assert FixtureImporter.import_car(car_bytes, require_roots_present: false) == {:error, :missing_commit_root}
  end

  defp fixture_car(private_key, public_key) do
    record_cid = Cid.for_raw(~s({"$type":"app.bsky.feed.post","text":"fixture"}))
    mst = Mst.from_entries!([{"app.bsky.feed.post/3jui7kd54zh2y", record_cid}])
    {:ok, %{root: mst_root, blocks: mst_blocks}} = Mst.serialize(mst)

    unsigned =
      Commit.new!(%{
        did: @did,
        data: mst_root,
        rev: Tid.new!(1_700_000_000_000_000, 0),
        prev: nil
      })

    {:ok, commit} = Commit.sign(unsigned, private_key)
    commit_bytes = Commit.encode!(commit)
    commit_cid = Cid.for_drisl(commit_bytes)

    blocks = [
      {commit_cid, commit_bytes},
      {record_cid, ~s({"$type":"app.bsky.feed.post","text":"fixture"})} | mst_blocks
    ]

    {:ok, car_bytes} = Car.encode([commit_cid], blocks)

    did_document = %{
      "verificationMethod" => [
        %{
          "id" => @did <> "#atproto",
          "publicKeyMultibase" => "u" <> Base.url_encode64(public_key, padding: false)
        }
      ]
    }

    {car_bytes, commit, commit_cid, did_document}
  end
end
