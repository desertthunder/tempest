defmodule Tempest.TelemetryTest do
  use TempestWeb.ConnCase

  @password "correct horse battery staple"

  test "emits XRPC repo blob and email telemetry", %{conn: conn} do
    parent = self()
    ref = make_ref()

    events = [
      [:tempest, :xrpc, :request],
      [:tempest, :repo, :write],
      [:tempest, :repo, :commit],
      [:tempest, :blob, :upload],
      [:tempest, :email, :deliver]
    ]

    :telemetry.attach_many(
      "tempest-test-#{inspect(ref)}",
      events,
      fn event, measurements, metadata, _config -> send(parent, {ref, event, measurements, metadata}) end,
      nil
    )

    on_exit(fn -> :telemetry.detach("tempest-test-#{inspect(ref)}") end)

    account = create_account!(conn)
    blob = upload_blob!(conn, account, "telemetry blob")["blob"]

    conn
    |> auth_json(account)
    |> post(~p"/xrpc/com.atproto.repo.createRecord", %{
      "repo" => account["did"],
      "collection" => "app.tempest.blob",
      "rkey" => "telemetry",
      "validate" => false,
      "record" => %{"$type" => "app.tempest.blob", "image" => blob}
    })
    |> json_response(200)

    conn
    |> recycle()
    |> put_req_header("content-type", "application/json")
    |> post(~p"/xrpc/com.atproto.server.requestPasswordReset", %{"email" => account["email"]})
    |> json_response(200)

    assert_receive {^ref, [:tempest, :blob, :upload], %{bytes: 14}, %{mime_type: "text/plain"}}
    assert_receive {^ref, [:tempest, :repo, :write], %{count: 1}, %{action: "create"}}
    assert_receive {^ref, [:tempest, :repo, :commit], %{count: 1}, %{did: _did}}
    assert_receive {^ref, [:tempest, :email, :deliver], %{count: 1}, %{purpose: "reset_password", status: :ok}}
    assert_received {^ref, [:tempest, :xrpc, :request], %{count: 1, duration: _duration}, %{nsid: _, status: _}}
  end

  defp create_account!(conn) do
    unique = System.unique_integer([:positive])

    conn
    |> put_req_header("content-type", "application/json")
    |> post(~p"/xrpc/com.atproto.server.createAccount", %{
      "handle" => "telemetry-#{unique}.test",
      "email" => "telemetry-#{unique}@example.com",
      "password" => @password
    })
    |> json_response(200)
  end

  defp upload_blob!(conn, account, bytes) do
    conn
    |> recycle()
    |> put_req_header("authorization", "Bearer #{account["accessJwt"]}")
    |> put_req_header("content-type", "text/plain")
    |> put_req_header("content-length", Integer.to_string(byte_size(bytes)))
    |> post(~p"/xrpc/com.atproto.repo.uploadBlob", bytes)
    |> json_response(200)
  end

  defp auth_json(conn, account) do
    conn
    |> recycle()
    |> put_req_header("authorization", "Bearer #{account["accessJwt"]}")
    |> put_req_header("content-type", "application/json")
  end
end
