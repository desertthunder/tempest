defmodule Tempest.RepoCore.CidTest do
  use ExUnit.Case, async: true

  alias Tempest.RepoCore.Cid

  @official_link "bafyreidfayvfuwqa7qlnopdjiqrxzs6blmoeu4rujcjtnci5beludirz2a"
  @official_bytes_hex "0171122065062a5a5a00fc16d73c6944237ccbc15b1c4a7234489336891d091741a239d0"

  describe "parse/1" do
    test "decodes the official JSON link example to known binary bytes" do
      assert {:ok, cid} = Cid.parse(@official_link)
      assert cid.version == 1
      assert cid.codec == :drisl
      assert cid.hash_code == 0x12
      assert byte_size(cid.digest) == 32
      assert Base.encode16(Cid.to_bytes(cid), case: :lower) == @official_bytes_hex
      assert Cid.to_string(cid) == @official_link
    end

    test "rejects unsupported multibase and non-canonical base32" do
      assert Cid.parse(String.upcase(@official_link)) == {:error, :unsupported_multibase}

      non_canonical = String.slice(@official_link, 0, byte_size(@official_link) - 1) <> "b"
      assert Cid.parse(non_canonical) == {:error, :non_canonical_base32}

      assert Cid.parse("bafyreid!") == {:error, :invalid_base32}
      assert Cid.parse("bafyréidf") == {:error, :not_ascii}
    end
  end

  describe "construction" do
    test "builds known raw CIDs from SHA-256 digests" do
      empty = Cid.for_raw("")
      assert empty.value == "bafkreihdwdcefgh4dqkjv67uzcmw7ojee6xedzdetojuzjevtenxquvyku"

      assert Base.encode16(Cid.to_bytes(empty), case: :lower) ==
               "01551220e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"

      hello = Cid.for_raw("hello world")
      assert hello.value == "bafkreifzjut3te2nhyekklss27nh3k72ysco7y32koao5eei66wof36n5e"
      assert hello.codec == :raw
      assert Cid.codec_code(hello) == 0x55
    end

    test "round-trips DRISL CIDs and CBOR link payload bytes" do
      cid = Cid.for_drisl("example block")

      assert cid.codec == :drisl
      assert Cid.codec_code(cid) == 0x71
      assert {:ok, ^cid} = Cid.parse(cid.value)
      assert {:ok, ^cid} = Cid.from_bytes(Cid.to_bytes(cid))
      assert {:ok, ^cid} = Cid.from_cbor_link(Cid.to_cbor_link(cid))
    end

    test "rejects unsupported binary CID components" do
      digest = :crypto.hash(:sha256, "hello")

      assert Cid.from_bytes(<<0x00, 0x55, 0x12, 0x20, digest::binary>>) ==
               {:error, :unsupported_cid_version}

      assert Cid.from_bytes(<<0x01, 0x70, 0x12, 0x20, digest::binary>>) == {:error, :unsupported_codec}
      assert Cid.from_bytes(<<0x01, 0x55, 0x13, 0x20, digest::binary>>) == {:error, :unsupported_hash_type}

      assert Cid.from_bytes(<<0x01, 0x55, 0x12, 0x1F, binary_part(digest, 0, 31)::binary>>) ==
               {:error, :unsupported_hash_size}

      assert Cid.from_bytes(<<0x01, 0x55, 0x12, 0x20, binary_part(digest, 0, 31)::binary>>) ==
               {:error, :digest_size_mismatch}

      assert Cid.from_cbor_link(Cid.to_bytes(Cid.for_raw("hello"))) == {:error, :invalid_binary_cid}
    end
  end
end
