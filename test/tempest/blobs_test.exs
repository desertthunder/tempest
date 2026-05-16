defmodule Tempest.BlobsTest do
  use ExUnit.Case, async: true

  alias Tempest.Blobs
  alias Tempest.RepoCore.Cid

  setup do
    config =
      Tempest.Config.validate!(
        [
          hostname: "localhost",
          public_url: "http://localhost:4000",
          data_dir: Path.join(System.tmp_dir!(), "tempest_blobs_test_#{System.unique_integer([:positive])}"),
          blob_max_bytes: 12
        ],
        env: :test
      )

    %{config: config}
  end

  test "calculates raw CIDv1 sha-256 CIDs" do
    bytes = "hello blob"

    assert Blobs.cid_for(bytes) == bytes |> Cid.for_raw() |> Cid.to_string()
    assert {:ok, %{codec: :raw, digest: digest}} = Blobs.cid_for(bytes) |> Cid.parse()
    assert digest == :crypto.hash(:sha256, bytes)
  end

  test "validates upload size, MIME, and CID metadata", %{config: config} do
    assert {:ok,
            %{
              cid: cid,
              size: 10,
              mime_type: "text/plain",
              sniffed_mime_type: "text/plain"
            }} = Blobs.validate_upload("hello blob", "10", "text/plain; charset=utf-8", config)

    assert Cid.valid?(cid)
  end

  test "rejects content-length mismatches", %{config: config} do
    assert {:error, :content_length_mismatch} = Blobs.validate_upload("hello blob", 9, "text/plain", config)
  end

  test "rejects blobs over the configured size limit", %{config: config} do
    assert {:error, :blob_too_large} = Blobs.validate_upload("hello blob!!!", 13, "text/plain", config)
  end

  test "rejects invalid MIME declarations", %{config: config} do
    assert {:error, :missing_mime_type} = Blobs.validate_upload("hello blob", 10, nil, config)
    assert {:error, :invalid_mime_type} = Blobs.validate_upload("hello blob", 10, "text plain", config)
  end

  test "sniffs known MIME types and rejects declared mismatches", %{config: config} do
    png = <<0x89, "PNG", 0x0D, 0x0A, 0x1A, 0x0A, 0, 0>>

    assert Blobs.sniff_mime_type(png) == "image/png"
    assert {:ok, %{mime_type: "image/png"}} = Blobs.validate_upload(png, byte_size(png), "image/png", config)
    assert {:error, :mime_type_mismatch} = Blobs.validate_upload(png, byte_size(png), "text/plain", config)
  end

  test "allows opaque binary when sniffing cannot identify a narrower MIME", %{config: config} do
    bytes = <<0, 1, 2, 3>>

    assert Blobs.sniff_mime_type(bytes) == "application/octet-stream"

    assert {:ok, %{mime_type: "application/octet-stream"}} =
             Blobs.validate_upload(bytes, byte_size(bytes), "application/octet-stream", config)
  end
end
