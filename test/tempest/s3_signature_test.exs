defmodule Tempest.S3SignatureTest do
  use ExUnit.Case, async: true

  test "adds AWS SigV4 headers when access keys are configured" do
    signed =
      Tempest.S3Signature.sign(
        [
          method: :put,
          url: "https://example.r2.cloudflarestorage.com/bucket/backups/a.zip",
          body: "bytes",
          headers: []
        ],
        access_key_id: "access-key",
        secret_access_key: "secret-key",
        region: "auto",
        signing_time: ~U[2026-06-02 12:00:00Z]
      )

    headers = Map.new(signed[:headers])

    assert headers["host"] == "example.r2.cloudflarestorage.com"
    assert headers["x-amz-date"] == "20260602T120000Z"
    assert headers["x-amz-content-sha256"] == :crypto.hash(:sha256, "bytes") |> Base.encode16(case: :lower)
    assert headers["authorization"] =~ "AWS4-HMAC-SHA256 Credential=access-key/20260602/auto/s3/aws4_request"
    assert headers["authorization"] =~ "SignedHeaders=host;x-amz-content-sha256;x-amz-date"
  end

  test "leaves request unchanged when access keys are absent" do
    request = [
      method: :get,
      url: "https://objects.example.test/bucket/key",
      headers: [{"authorization", "Bearer token"}]
    ]

    assert Tempest.S3Signature.sign(request, []) == request
  end
end
