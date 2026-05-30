defmodule Tempest.Security.ExternalMetadataFetcherTest do
  use ExUnit.Case, async: false

  alias Tempest.Security.ExternalMetadataFetcher

  setup context do
    Req.Test.set_req_test_from_context(context)
    Req.Test.verify_on_exit!(context)

    original = Application.get_env(:tempest, ExternalMetadataFetcher, [])

    on_exit(fn ->
      Application.put_env(:tempest, ExternalMetadataFetcher, original)
    end)

    :ok
  end

  test "rejects non-http urls and private addresses" do
    assert {:error, :unsafe_url} = ExternalMetadataFetcher.validate_url("file:///etc/passwd")
    assert {:error, :private_ip} = ExternalMetadataFetcher.validate_url("http://127.0.0.1/client.json")
    assert {:error, :private_ip} = ExternalMetadataFetcher.validate_url("http://[::1]/client.json")
  end

  test "allows resolved public addresses" do
    Application.put_env(:tempest, ExternalMetadataFetcher,
      dns_lookup: fn "client.example" -> {:ok, [{93, 184, 216, 34}]} end
    )

    assert :ok = ExternalMetadataFetcher.validate_url("https://client.example/oauth/client-metadata.json")
  end

  test "fetch_json uses configured Req boundary and decodes JSON" do
    Application.put_env(:tempest, ExternalMetadataFetcher,
      dns_lookup: fn "client.example" -> {:ok, [{93, 184, 216, 34}]} end,
      req_options: [plug: {Req.Test, __MODULE__}]
    )

    Req.Test.stub(__MODULE__, fn conn ->
      Req.Test.json(conn, %{"client_name" => "Example"})
    end)

    assert {:ok, %{"client_name" => "Example"}} =
             ExternalMetadataFetcher.fetch_json("https://client.example/client.json")
  end

  test "rejects redirects" do
    Application.put_env(:tempest, ExternalMetadataFetcher,
      dns_lookup: fn "client.example" -> {:ok, [{93, 184, 216, 34}]} end,
      req_options: [plug: {Req.Test, __MODULE__}]
    )

    Req.Test.stub(__MODULE__, fn conn ->
      Plug.Conn.resp(conn, 302, "")
    end)

    assert {:error, :redirect_rejected} =
             ExternalMetadataFetcher.fetch_text("https://client.example/client.json")
  end

  test "rejects oversized bodies" do
    Application.put_env(:tempest, ExternalMetadataFetcher,
      dns_lookup: fn "client.example" -> {:ok, [{93, 184, 216, 34}]} end,
      req_options: [plug: {Req.Test, __MODULE__}]
    )

    Req.Test.stub(__MODULE__, fn conn ->
      Plug.Conn.resp(conn, 200, "too large")
    end)

    assert {:error, :body_too_large} =
             ExternalMetadataFetcher.fetch_text("https://client.example/client.json", max_body_bytes: 3)
  end
end
