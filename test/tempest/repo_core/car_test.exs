defmodule Tempest.RepoCore.CarTest do
  use ExUnit.Case, async: true

  alias Tempest.RepoCore.{Car, Cid, Drisl}

  @hello "hello"
  @hello_raw_cid "bafkreibm6jg3ux5qumhcn2b3flc3tyu6dmlb4xa7u5bf44yegnrjhc4yeq"
  @hello_raw_cid_bytes "015512202cf24dba5fb0a30e26e83b2ac5b9e29e1b161e5c1fa7425e73043362938b9824"

  describe "encode/3" do
    test "writes a deterministic DASL-profile CAR v1 byte stream" do
      cid = Cid.parse!(@hello_raw_cid)

      assert {:ok, car} = Car.encode([cid], [{cid, @hello}])

      assert Base.encode16(car, case: :lower) ==
               "3aa265726f6f747381d82a582500" <>
                 @hello_raw_cid_bytes <>
                 "6776657273696f6e0129" <>
                 @hello_raw_cid_bytes <>
                 "68656c6c6f"
    end

    test "writes and reads extra metadata while preserving roots and version" do
      cid = Cid.for_raw("block")

      assert {:ok, bytes} =
               Car.encode([cid], [{cid, "block"}], metadata: %{"name" => "fixture", "roots" => []})

      assert {:ok, car} = Car.decode(bytes)
      assert car.version == 1
      assert car.roots == [cid]
      assert car.metadata["name"] == "fixture"
      assert car.metadata["roots"] == [cid]
      assert [%{cid: ^cid, data: "block", size: 5}] = car.blocks
    end

    test "rejects blocks whose CID digest does not match the data" do
      cid = Cid.for_raw("hello")
      assert Car.encode([cid], [{cid, "world"}]) == {:error, :invalid_block_cid}
    end

    test "requires roots to be present by default but allows callers to opt out" do
      cid = Cid.for_raw("missing")

      assert Car.encode([cid], [], require_roots_present: false) |> elem(0) == :ok
      assert Car.encode([cid], []) == {:error, :root_block_missing}
    end
  end

  describe "decode/2" do
    test "reads CARs with arbitrary block ordering, extras, and duplicate blocks" do
      root = Cid.for_raw("root")
      extra = Cid.for_raw("extra")

      assert {:ok, bytes} =
               Car.encode(
                 [root],
                 [
                   {extra, "extra"},
                   {root, "root"},
                   {root, "root"}
                 ]
               )

      assert {:ok, car} = Car.decode(bytes)
      assert car.roots == [root]
      assert Enum.map(car.blocks, & &1.cid) == [extra, root, root]
      assert Enum.map(car.blocks, & &1.data) == ["extra", "root", "root"]
    end

    test "can parse a header-only CAR when root presence is not required" do
      assert {:ok, bytes} = Car.encode([], [], require_roots_present: false)
      assert {:ok, car} = Car.decode(bytes)
      assert car.roots == []
      assert car.blocks == []
      assert car.metadata == %{"roots" => [], "version" => 1}
    end

    test "rejects invalid headers" do
      assert Car.decode(<<0>>) == {:error, :zero_length_header}

      assert {:ok, bad_version_header} = Drisl.encode(%{"version" => 2, "roots" => []})
      assert Car.decode(varint(byte_size(bad_version_header)) <> bad_version_header) == {:error, :invalid_header}

      assert {:ok, bad_roots_header} = Drisl.encode(%{"version" => 1, "roots" => ["not-a-cid"]})

      assert Car.decode(varint(byte_size(bad_roots_header)) <> bad_roots_header) ==
               {:error, :invalid_roots}
    end

    test "rejects malformed sections and CID mismatches" do
      assert {:ok, header_only} = Car.encode([], [], require_roots_present: false)
      assert Car.decode(header_only <> <<1, 0>>) == {:error, :section_too_short}

      cid = Cid.for_raw("hello")
      section = Cid.to_bytes(cid) <> "world"
      assert Car.decode(header_only <> varint(byte_size(section)) <> section) == {:error, :invalid_block_cid}

      assert Car.decode(header_only <> <<0>>) == {:error, :zero_length_section}
    end

    test "rejects non-minimal and overflowing varints" do
      assert Car.decode(<<0x81, 0x00, 0xF6>>) == {:error, :non_minimal_varint}
      assert Car.decode(:binary.copy(<<0x80>>, 10) <> <<0x00>>) == {:error, :varint_overflow}
    end

    test "enforces CAR decode limits" do
      cid = Cid.for_raw("hello")
      assert {:ok, bytes} = Car.encode([cid], [{cid, "hello"}])

      assert Car.decode(bytes, max_bytes: 0) == {:error, :max_bytes_exceeded}
      assert Car.decode(bytes, max_header_bytes: 0) == {:error, :max_header_bytes_exceeded}
      assert Car.decode(bytes, max_section_bytes: 0) == {:error, :max_section_bytes_exceeded}
      assert Car.decode(bytes, max_block_bytes: 0) == {:error, :max_block_bytes_exceeded}
      assert Car.decode(bytes, max_blocks: 0) == {:error, :max_blocks_exceeded}
      assert Car.decode(bytes, max_roots: 0) == {:error, {:invalid_header_cbor, :max_array_length_exceeded}}
    end
  end

  defp varint(integer) when integer in 0..0x7F, do: <<integer>>

  defp varint(integer) when integer > 0 do
    <<Bitwise.bor(Bitwise.band(integer, 0x7F), 0x80)>> <> varint(Bitwise.bsr(integer, 7))
  end
end
