defmodule Tempest.RepoCore.DidTest do
  use ExUnit.Case, async: true

  alias Tempest.RepoCore.Did

  describe "parse/1" do
    test "accepts supported DID methods from the official examples" do
      assert Did.parse("did:plc:ewvi7nxzyoun6zhxrhs64oiz") ==
               {:ok, "did:plc:ewvi7nxzyoun6zhxrhs64oiz"}

      assert Did.parse("did:web:user.example.com") == {:ok, "did:web:user.example.com"}
    end

    test "accepts syntactically valid unsupported methods" do
      assert Did.parse("did:method:val:two") == {:ok, "did:method:val:two"}
      assert Did.parse("did:m:v") == {:ok, "did:m:v"}
      assert Did.parse("did:method::::val") == {:ok, "did:method::::val"}
      assert Did.parse("did:method:-:_:.") == {:ok, "did:method:-:_:."}
    end

    test "rejects invalid DID syntax" do
      assert Did.parse("did:METHOD:val") == {:error, :invalid_did_syntax}
      assert Did.parse("did:m123:val") == {:error, :invalid_did_syntax}
      assert Did.parse("DID:method:val") == {:error, :invalid_did_syntax}
      assert Did.parse("did:method:") == {:error, :invalid_did_syntax}
      assert Did.parse("did:method:val/two") == {:error, :invalid_did_syntax}
      assert Did.parse("did:method:val?two") == {:error, :invalid_did_syntax}
      assert Did.parse("did:method:val#two") == {:error, :invalid_did_syntax}
    end
  end

  test "supported_method?/1 identifies current blessed methods only" do
    assert Did.supported_method?("did:plc:ewvi7nxzyoun6zhxrhs64oiz")
    assert Did.supported_method?("did:web:user.example.com")
    refute Did.supported_method?("did:method:val")
  end
end
