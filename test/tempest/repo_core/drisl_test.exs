defmodule Tempest.RepoCore.DrislTest do
  use ExUnit.Case, async: true

  alias Tempest.RepoCore.{Cid, Drisl}
  alias Tempest.RepoCore.Drisl.Bytes

  @official_cid "bafyreidfayvfuwqa7qlnopdjiqrxzs6blmoeu4rujcjtnci5beludirz2a"
  @official_cid_bytes "0171122065062a5a5a00fc16d73c6944237ccbc15b1c4a7234489336891d091741a239d0"

  describe "encode/1" do
    test "encodes atproto scalar values using shortest-form CBOR" do
      assert_hex(nil, "f6")
      assert_hex(false, "f4")
      assert_hex(true, "f5")
      assert_hex(0, "00")
      assert_hex(23, "17")
      assert_hex(24, "1818")
      assert_hex(1_000, "1903e8")
      assert_hex(-1, "20")
      assert_hex(-1_000, "3903e7")
      assert_hex("IETF", "6449455446")
      assert_hex(Drisl.bytes(<<1, 2, 3, 4>>), "4401020304")
    end

    test "encodes arrays and maps with deterministic encoded-key ordering" do
      assert_hex([1, 2, 3], "83010203")
      assert_hex(%{"b" => 1, "a" => 2}, "a2616102616201")
      assert_hex(%{"aa" => 1, "z" => 2}, "a2617a0262616101")
    end

    test "encodes CID links as tag 42 byte strings" do
      cid = Cid.parse!(@official_cid)

      assert_hex(
        %{"ref" => cid},
        "a163726566d82a582500" <> @official_cid_bytes
      )
    end

    test "rejects values outside the atproto data model" do
      assert Drisl.encode(1.5) == {:error, :unsupported_type}
      assert Drisl.encode(9_223_372_036_854_775_808) == {:error, :invalid_integer_range}
      assert Drisl.encode(<<0xFF>>) == {:error, :invalid_string}
      assert Drisl.encode(%{1 => "nope"}) == {:error, :invalid_map_key}
    end
  end

  describe "decode/2" do
    test "decodes scalars, bytes, arrays, and maps" do
      assert Drisl.decode!(hex("f6")) == nil
      assert Drisl.decode!(hex("f4")) == false
      assert Drisl.decode!(hex("f5")) == true
      assert Drisl.decode!(hex("1903e8")) == 1_000
      assert Drisl.decode!(hex("3903e7")) == -1_000
      assert Drisl.decode!(hex("6449455446")) == "IETF"
      assert Drisl.decode!(hex("4401020304")) == %Bytes{bytes: <<1, 2, 3, 4>>}
      assert Drisl.decode!(hex("83010203")) == [1, 2, 3]
      assert Drisl.decode!(hex("a2616102616201")) == %{"a" => 2, "b" => 1}
    end

    test "decodes CID links from tag 42 byte strings" do
      assert {:ok, cid} = Drisl.decode(hex("d82a582500" <> @official_cid_bytes))
      assert cid == Cid.parse!(@official_cid)
    end

    test "rejects non-DRISL or non-canonical CBOR" do
      assert Drisl.decode(hex("1817")) == {:error, :non_minimal_integer}
      assert Drisl.decode(hex("9fff")) == {:error, :indefinite_length}
      assert Drisl.decode(hex("f6f6")) == {:error, :trailing_bytes}
      assert Drisl.decode(hex("c0f6")) == {:error, :unsupported_tag}
      assert Drisl.decode(hex("a10102")) == {:error, :invalid_map_key}
      assert Drisl.decode(hex("a2616101616102")) == {:error, :duplicate_map_key}
      assert Drisl.decode(hex("a2616201616102")) == {:error, :non_canonical_map_order}
      assert Drisl.decode(hex("fb3ff199999999999a")) == {:error, :unsupported_float}
      assert Drisl.decode(hex("f7")) == {:error, :unsupported_simple_value}
      assert Drisl.decode(hex("61ff")) == {:error, :invalid_string}
    end

    test "rejects malformed CID links" do
      assert Drisl.decode(hex("d82a4100")) == {:error, {:invalid_cid, :invalid_binary_cid}}
      assert Drisl.decode(hex("d82a00")) == {:error, :invalid_cid_link}
    end
  end

  describe "decode limits" do
    test "enforces byte, depth, item, collection, and leaf-size limits" do
      assert Drisl.decode(hex("00"), max_bytes: 0) == {:error, :max_bytes_exceeded}
      assert Drisl.decode(hex("8100"), max_depth: 0) == {:error, :max_depth_exceeded}
      assert Drisl.decode(hex("8100"), max_items: 1) == {:error, :max_items_exceeded}
      assert Drisl.decode(hex("8100"), max_array_length: 0) == {:error, :max_array_length_exceeded}
      assert Drisl.decode(hex("a0"), max_map_length: 0) == {:ok, %{}}
      assert Drisl.decode(hex("a1616101"), max_map_length: 0) == {:error, :max_map_length_exceeded}
      assert Drisl.decode(hex("6161"), max_string_bytes: 0) == {:error, :max_string_bytes_exceeded}
      assert Drisl.decode(hex("4100"), max_bytestring_bytes: 0) == {:error, :max_bytestring_bytes_exceeded}
    end
  end

  test "computes DRISL block CIDs from encoded bytes" do
    value = %{"hello" => "world"}
    assert {:ok, cid} = Drisl.cid(value)
    assert cid == value |> Drisl.encode!() |> Cid.for_drisl()
  end

  defp assert_hex(value, expected_hex) do
    assert {:ok, encoded} = Drisl.encode(value)
    assert Base.encode16(encoded, case: :lower) == expected_hex
  end

  defp hex(value), do: Base.decode16!(value, case: :mixed)
end
