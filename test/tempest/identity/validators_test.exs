defmodule Tempest.Identity.ValidatorsTest do
  use ExUnit.Case, async: true

  alias Tempest.Identity.Validators

  test "validates supported DID syntax" do
    assert Validators.validate_did("did:plc:abcdefghijklmnopqrstuvwxyz234567") == :ok
    assert Validators.validate_did("did:web:alice.example.com") == :ok
  end

  test "distinguishes invalid DID syntax from unsupported methods" do
    assert Validators.validate_did("did:plc:ABC") == {:error, :invalid_did_syntax}
    assert Validators.validate_did("did:example:alice") == {:error, :unsupported_did_method}
  end

  test "validates handle syntax" do
    assert Validators.validate_handle("alice.example.com") == :ok

    assert Validators.validate_handle("-alice.example.com") == {:error, :invalid_handle_syntax}
    assert Validators.validate_handle("alice") == {:error, :invalid_handle_syntax}
    assert Validators.validate_handle("alice.example.123") == {:error, :invalid_handle_syntax}
  end
end
