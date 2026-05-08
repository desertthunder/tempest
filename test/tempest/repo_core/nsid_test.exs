defmodule Tempest.RepoCore.NsidTest do
  use ExUnit.Case, async: true

  alias Tempest.RepoCore.Nsid

  describe "parse/1" do
    test "accepts official valid examples" do
      assert {:ok, nsid} = Nsid.parse("com.example.fooBar")
      assert nsid.value == "com.example.fooBar"
      assert nsid.authority == "example.com"
      assert nsid.name == "fooBar"

      assert Nsid.valid?("net.users.bob.ping")
      assert Nsid.valid?("a-0.b-1.c")
      assert Nsid.valid?("a.b.c")
      assert Nsid.valid?("com.example.fooBarV2")
      assert Nsid.valid?("cn.8.lex.stuff")
    end

    test "normalizes only the domain authority segments" do
      assert {:ok, nsid} = Nsid.parse("COM.Example.fooBar")
      assert nsid.value == "com.example.fooBar"
      assert nsid.authority == "example.com"
      assert nsid.name == "fooBar"
    end

    test "rejects invalid official examples" do
      assert Nsid.parse("com.example") == {:error, :invalid_nsid_syntax}
      assert Nsid.parse("com.example.3") == {:error, :invalid_nsid_syntax}
    end

    test "rejects empty segments, bad hyphen placement, and oversized names" do
      assert Nsid.parse("com..example.foo") == {:error, :invalid_nsid_syntax}
      assert Nsid.parse("-com.example.foo") == {:error, :invalid_nsid_syntax}
      assert Nsid.parse("com.example.foo-bar") == {:error, :invalid_nsid_syntax}
      assert Nsid.parse("0com.example.foo") == {:error, :invalid_nsid_syntax}
      assert Nsid.parse("com.example.#{String.duplicate("a", 64)}") == {:error, :invalid_nsid_syntax}
    end
  end
end
