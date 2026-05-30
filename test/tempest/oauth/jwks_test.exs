defmodule Tempest.OAuth.JwksTest do
  use ExUnit.Case, async: false

  setup do
    jwks_path = Path.join(System.tmp_dir!(), "tempest-oauth-jwks-#{System.unique_integer([:positive])}.json")
    original = Application.get_env(:tempest, Tempest.OAuth.Jwks, [])
    Application.put_env(:tempest, Tempest.OAuth.Jwks, path: jwks_path)

    on_exit(fn ->
      Application.put_env(:tempest, Tempest.OAuth.Jwks, original)
      File.rm(jwks_path)
    end)

    :ok
  end

  test "creates durable initial public JWKS without private material" do
    assert %{"keys" => [key]} = Tempest.OAuth.Jwks.public_jwks()
    assert File.exists?(Tempest.OAuth.Jwks.path())
    refute Map.has_key?(key, "d")

    assert %{"keys" => [same_key]} = Tempest.OAuth.Jwks.public_jwks()
    assert same_key["kid"] == key["kid"]
  end

  test "rotation creates a new active key and keeps old public key published" do
    %{"keys" => [old_key]} = Tempest.OAuth.Jwks.public_jwks()

    assert {:ok, new_private_key} = Tempest.OAuth.Jwks.rotate_key()
    assert new_private_key["kid"] != old_key["kid"]
    assert Map.has_key?(new_private_key, "d")

    assert %{"keys" => keys} = Tempest.OAuth.Jwks.public_jwks()
    kids = Enum.map(keys, & &1["kid"])

    assert new_private_key["kid"] in kids
    assert old_key["kid"] in kids
  end
end
