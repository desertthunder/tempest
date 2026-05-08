defmodule Tempest.RepoCore.TidTest do
  use ExUnit.Case, async: true

  alias Tempest.RepoCore.Tid

  describe "parse/1" do
    test "accepts official valid examples" do
      assert {:ok, tid} = Tid.parse("3jzfcijpj2z2a")
      assert tid.value == "3jzfcijpj2z2a"
      assert tid.integer == 1_728_652_679_052_295_174
      assert tid.unix_microseconds == 1_688_137_381_887_007
      assert tid.clock_id == 6

      assert Tid.valid?("7777777777777")
      assert Tid.valid?("3zzzzzzzzzzzz")
      assert Tid.valid?("2222222222222")
    end

    test "rejects official invalid examples" do
      for tid <- [
            "3jzfcijpj2z21",
            "0000000000000",
            "3JZFCIJPJ2Z2A",
            "3jzfcijpj2z2aa",
            "3jzfcijpj2z2",
            "222",
            "3jzf-cij-pj2z-2a",
            "zzzzzzzzzzzzz",
            "kjzfcijpj2z2a"
          ] do
        assert Tid.parse(tid) == {:error, :invalid_tid_syntax}
      end
    end

    test "rejects non-ascii input distinctly" do
      assert Tid.parse("3jzfcijpj2zéa") == {:error, :not_ascii}
    end
  end

  describe "construction" do
    test "builds known values from integer and timestamp parts" do
      assert Tid.from_integer!(0).value == "2222222222222"
      assert Tid.from_integer!(1).value == "2222222222223"
      assert Tid.from_integer!(1023).value == "22222222222zz"
      assert Tid.new!(0, 0).value == "2222222222222"
      assert Tid.new!(1, 5).value == "2222222222327"
      assert Tid.new!(1_700_000_000_000_000, 5).value == "3ke6kg3wk2227"
    end

    test "rejects out-of-range timestamp and clock id parts" do
      assert Tid.new(-1, 0) == {:error, :timestamp_out_of_range}
      assert Tid.new(Tid.max_unix_microseconds() + 1, 0) == {:error, :timestamp_out_of_range}
      assert Tid.new(0, -1) == {:error, :clock_id_out_of_range}
      assert Tid.new(0, 1024) == {:error, :clock_id_out_of_range}
      assert Tid.from_integer(0x8000_0000_0000_0000) == {:error, :integer_out_of_range}
    end
  end
end
