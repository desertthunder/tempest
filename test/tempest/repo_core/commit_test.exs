defmodule Tempest.RepoCore.CommitTest do
  use ExUnit.Case, async: true

  alias Tempest.RepoCore.{Cid, Commit, Drisl, Mst, Tid}
  alias Tempest.RepoCore.Drisl.Bytes

  @did "did:plc:ewvi7nxzyoun6zhxrhs64oiz"

  describe "new/1" do
    test "builds unsigned v3 commits with required prev field" do
      data = mst_root()
      rev = Tid.new!(1_700_000_000_000_000, 0)

      assert {:ok, commit} = Commit.new(%{did: @did, data: data, rev: rev, prev: nil})
      assert commit.did == @did
      assert commit.version == 3
      assert commit.data == data
      assert commit.rev == rev.value
      assert commit.prev == nil
      assert commit.sig == nil
    end

    test "rejects missing prev and non-DRISL links" do
      data = mst_root()
      raw = Cid.for_raw("raw")
      rev = Tid.new!(1_700_000_000_000_000, 0)

      assert Commit.new(%{did: @did, data: data, rev: rev}) == {:error, :invalid_prev}
      assert Commit.new(%{did: @did, data: raw, rev: rev, prev: nil}) == {:error, :invalid_data}
      assert Commit.new(%{did: @did, data: data, rev: rev, prev: raw}) == {:error, :invalid_prev}
      assert Commit.new(%{did: "not-a-did", data: data, rev: rev, prev: nil}) == {:error, :invalid_did}
      assert Commit.new(%{did: @did, data: data, rev: "not-a-tid", prev: nil}) == {:error, :invalid_rev}
    end
  end

  describe "encoding" do
    test "encodes unsigned commits without sig and signed commits with sig bytes" do
      %Commit{} = commit = unsigned_commit()

      assert {:ok, unsigned_bytes} = Commit.encode_unsigned(commit)
      assert {:ok, unsigned_map} = Drisl.decode(unsigned_bytes)
      assert Map.keys(unsigned_map) |> Enum.sort() == ["data", "did", "prev", "rev", "version"]

      signed = %Commit{commit | sig: :binary.copy(<<1>>, 64)}
      assert {:ok, signed_bytes} = Commit.encode(signed)
      assert {:ok, %{"sig" => %Bytes{bytes: sig}}} = Drisl.decode(signed_bytes)
      assert sig == :binary.copy(<<1>>, 64)
    end
  end

  describe "signing and verification" do
    test "signs with compact low-S secp256k1 signatures and verifies with public key" do
      {public_key, private_key} = :crypto.generate_key(:ecdh, :secp256k1)
      commit = unsigned_commit()

      assert {:ok, signed} = Commit.sign(commit, private_key)
      assert byte_size(signed.sig) == 64
      assert {:ok, true} = Commit.verify(signed, public_key)

      assert {:ok, cid} = Commit.cid(signed)
      assert cid == signed |> Commit.encode!() |> Cid.for_drisl()
    end

    test "decodes signed commits and rejects tampering" do
      {public_key, private_key} = :crypto.generate_key(:ecdh, :secp256k1)
      assert {:ok, signed} = Commit.sign(unsigned_commit(), private_key)

      assert {:ok, %Commit{} = decoded} = signed |> Commit.encode!() |> Commit.decode()
      assert decoded == signed
      assert {:ok, true} = Commit.verify(decoded, public_key)

      tampered = %Commit{decoded | rev: Tid.new!(1_700_000_000_000_001, 0).value}
      assert {:ok, false} = Commit.verify(tampered, public_key)
    end

    test "verifies with hosted DID document publicKeyMultibase shape" do
      {public_key, private_key} = :crypto.generate_key(:ecdh, :secp256k1)
      assert {:ok, signed} = Commit.sign(unsigned_commit(), private_key)

      document = %{
        "verificationMethod" => [
          %{
            "id" => @did <> "#atproto",
            "type" => "Multikey",
            "controller" => @did,
            "publicKeyMultibase" => "u" <> Base.url_encode64(public_key, padding: false)
          }
        ]
      }

      assert Commit.verify_with_did_document(signed, document) == {:ok, true}
    end

    test "rejects unsigned commits and invalid key material" do
      commit = unsigned_commit()
      assert Commit.encode(commit) == {:error, :unsigned_commit}
      assert Commit.verify(commit, <<4, 0::size(64 * 8)>>) == {:error, :unsigned_commit}
      assert Commit.sign(commit, "too-short") == {:error, :invalid_private_key}
    end
  end

  defp unsigned_commit do
    Commit.new!(%{
      did: @did,
      data: mst_root(),
      rev: Tid.new!(1_700_000_000_000_000, 0),
      prev: nil
    })
  end

  defp mst_root do
    mst =
      Mst.from_entries!([
        {"app.bsky.feed.post/self", Cid.for_raw("record")}
      ])

    {:ok, root} = Mst.root_cid(mst)
    root
  end
end
