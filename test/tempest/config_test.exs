defmodule Tempest.ConfigTest do
  use ExUnit.Case, async: false

  @valid_config [
    hostname: "localhost",
    public_url: "http://localhost:4000",
    data_dir: "/tmp/tempest-test",
    blob_max_bytes: 10_000_000
  ]

  @default_dev_secret "+uUQkQUThGq4zX4Vl0a0Jfn8JGPw6ZlqzIJ2FRI+qzdG6VLTMlZN0Pyq7xKGQBRH"

  test "validates and normalizes Tempest config" do
    assert %Tempest.Config{
             hostname: "localhost",
             public_url: "http://localhost:4000",
             data_dir: "/tmp/tempest-test",
             blob_max_bytes: 10_000_000
           } = Tempest.Config.validate!(@valid_config, env: :test)
  end

  test "rejects invalid config before boot" do
    original_config = Application.get_env(:tempest, Tempest.Config)

    on_exit(fn ->
      Application.put_env(:tempest, Tempest.Config, original_config)
    end)

    Application.put_env(
      :tempest,
      Tempest.Config,
      Keyword.put(@valid_config, :hostname, "https://localhost")
    )

    assert_raise RuntimeError, ~r/hostname must be a bare host/, fn ->
      Tempest.Application.start(:normal, [])
    end
  end

  test "rejects default secrets in production config" do
    assert_raise RuntimeError, ~r/production secret_key_base cannot use a default/, fn ->
      Tempest.Config.validate!(@valid_config,
        env: :prod,
        endpoint_config: [secret_key_base: @default_dev_secret]
      )
    end
  end

  test "rejects public URLs that do not match the hostname" do
    assert_raise RuntimeError, ~r/public_url host must match hostname/, fn ->
      Tempest.Config.validate!(
        Keyword.merge(@valid_config,
          hostname: "tempest.example.com",
          public_url: "https://other.example.com"
        ),
        env: :test
      )
    end
  end

  test "validates optional admin DID config" do
    assert %Tempest.Config{admin_did: "did:plc:abcdefghijklmnopqrstuvwxyz"} =
             Tempest.Config.validate!(
               Keyword.put(@valid_config, :admin_did, "did:plc:abcdefghijklmnopqrstuvwxyz"),
               env: :test
             )

    assert_raise RuntimeError, ~r/admin_did must be a supported DID/, fn ->
      Tempest.Config.validate!(Keyword.put(@valid_config, :admin_did, "not-a-did"), env: :test)
    end
  end
end
