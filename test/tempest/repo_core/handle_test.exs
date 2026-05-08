defmodule Tempest.RepoCore.HandleTest do
  use ExUnit.Case, async: true

  alias Tempest.RepoCore.Handle

  describe "parse/1" do
    test "accepts and normalizes syntactically valid handles from the official examples" do
      assert Handle.parse("jay.bsky.social") == {:ok, "jay.bsky.social"}
      assert Handle.parse("8.cn") == {:ok, "8.cn"}
      assert Handle.parse("name.t--t") == {:ok, "name.t--t"}
      assert Handle.parse("XX.LCS.MIT.EDU") == {:ok, "xx.lcs.mit.edu"}
      assert Handle.parse("xn--notarealidn.com") == {:ok, "xn--notarealidn.com"}
    end

    test "treats reserved TLDs as syntax-valid parser input" do
      assert Handle.parse("laptop.local") == {:ok, "laptop.local"}
      assert Handle.parse("blah.arpa") == {:ok, "blah.arpa"}
    end

    test "rejects invalid handle syntax" do
      assert Handle.parse("jo@hn.test") == {:error, :invalid_handle_syntax}
      assert Handle.parse(".test") == {:error, :invalid_handle_syntax}
      assert Handle.parse("john..test") == {:error, :invalid_handle_syntax}
      assert Handle.parse("xn--bcher-.tld") == {:error, :invalid_handle_syntax}
      assert Handle.parse("john.0") == {:error, :invalid_handle_syntax}
      assert Handle.parse("cn.8") == {:error, :invalid_handle_syntax}
      assert Handle.parse("www.masełkowski.pl.com") == {:error, :not_ascii}
      assert Handle.parse("org") == {:error, :invalid_handle_syntax}
      assert Handle.parse("name.org.") == {:error, :invalid_handle_syntax}
    end
  end
end
