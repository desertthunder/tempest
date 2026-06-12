defmodule Tempest.Interop.LocalServerSdkTest do
  use ExUnit.Case, async: false

  import Bitwise

  alias Tempest.AtprotoSdkClient
  alias Tempest.OAuth.Dpop
  alias Tempest.RepoCore.{Car, Cid, Drisl}

  @base_url "http://localhost:4002"
  @password "correct horse battery staple"
  @client_id "did:web:local-sdk-client.example.com"
  @redirect_uri "https://local-sdk-client.example.com/cb"

  setup do
    Tempest.DataCase.setup_sandbox(%{async: false})

    start_supervised!({Bandit, plug: TempestWeb.Endpoint, scheme: :http, ip: {127, 0, 0, 1}, port: 4002})

    {:ok, client: AtprotoSdkClient.new(@base_url)}
  end

  test "SDK-style local client can login, write, read, upload blobs, export CAR, and observe firehose", %{
    client: client
  } do
    suffix = System.unique_integer([:positive])
    handle = "sdk-#{suffix}.test"
    email = "sdk-#{suffix}@example.com"

    {:ok, firehose_cursor} = Tempest.Sequencer.current_seq()

    assert %{status: 200, body: account} =
             AtprotoSdkClient.create_account(client, %{
               "handle" => handle,
               "email" => email,
               "password" => @password
             })

    assert %{"did" => did, "accessJwt" => access_jwt} = account

    assert %{status: 200, body: %{"did" => ^did, "accessJwt" => login_access_jwt}} =
             AtprotoSdkClient.create_session(client, handle, @password)

    assert is_binary(login_access_jwt)

    assert %{status: 200, body: created} =
             AtprotoSdkClient.create_record(client, access_jwt, %{
               "repo" => did,
               "collection" => "app.tempest.note",
               "rkey" => "sdk-note",
               "validate" => false,
               "record" => %{"$type" => "app.tempest.note", "text" => "written by local SDK client"}
             })

    assert %{"uri" => "at://" <> _, "cid" => record_cid, "commit" => %{"cid" => commit_cid}} = created

    assert %{status: 200, body: record} =
             AtprotoSdkClient.get_record(client, %{
               "repo" => did,
               "collection" => "app.tempest.note",
               "rkey" => "sdk-note"
             })

    assert record["cid"] == record_cid
    assert record["value"]["text"] == "written by local SDK client"

    assert %{status: 200, body: upload} = AtprotoSdkClient.upload_blob(client, access_jwt, "blob bytes")
    blob_cid = upload["blob"]["ref"]["$link"]

    assert %{status: 200} =
             AtprotoSdkClient.create_record(client, access_jwt, %{
               "repo" => did,
               "collection" => "app.tempest.blob",
               "rkey" => "sdk-blob",
               "validate" => false,
               "record" => %{
                 "$type" => "app.tempest.blob",
                 "image" => %{
                   "$type" => "blob",
                   "ref" => %{"$link" => blob_cid},
                   "mimeType" => "text/plain",
                   "size" => byte_size("blob bytes")
                 }
               }
             })

    assert %{status: 200, body: "blob bytes"} = AtprotoSdkClient.get_blob(client, did, blob_cid)

    repo_response = AtprotoSdkClient.get_repo(client, did)
    assert repo_response.status == 200
    assert get_header(repo_response.headers, "content-type") =~ "application/vnd.ipld.car"
    assert {:ok, car} = Car.decode(repo_response.body)
    assert Enum.any?(car.blocks, &(Cid.to_string(&1.cid) == record_cid))
    assert Enum.any?(car.blocks, &(Cid.to_string(&1.cid) == commit_cid))

    frames = websocket_backfill_frames("/xrpc/com.atproto.sync.subscribeRepos?cursor=#{firehose_cursor}", 10)
    assert Enum.any?(frames, &commit_frame?(&1, did))
  end

  test "OAuth and app-password compatibility flows work through public HTTP", %{client: client} do
    suffix = System.unique_integer([:positive])
    handle = "sdk-auth-#{suffix}.test"

    %{status: 200, body: account} =
      AtprotoSdkClient.create_account(client, %{
        "handle" => handle,
        "email" => "sdk-auth-#{suffix}@example.com",
        "password" => @password
      })

    access_jwt = account["accessJwt"]
    did = account["did"]

    assert %{status: 200, body: app_password} =
             AtprotoSdkClient.create_app_password(client, access_jwt, %{
               "name" => "local-sdk",
               "scope" => "atproto"
             })

    app_secret = app_password["password"]

    assert %{status: 200, body: app_write} =
             AtprotoSdkClient.create_record(client, app_secret, %{
               "repo" => did,
               "collection" => "app.tempest.note",
               "rkey" => "app-password",
               "validate" => false,
               "record" => %{"$type" => "app.tempest.note", "text" => "app password write"}
             })

    assert app_write["uri"] == "at://#{did}/app.tempest.note/app-password"

    oauth_access = issue_oauth_access_token!(client, handle)

    dpop = dpop("POST", "http://localhost:4000/xrpc/com.atproto.repo.createRecord", Dpop.issue_nonce())

    assert %{status: 200, body: oauth_write} =
             AtprotoSdkClient.create_record(
               client,
               oauth_access,
               %{
                 "repo" => did,
                 "collection" => "app.tempest.note",
                 "rkey" => "oauth",
                 "validate" => false,
                 "record" => %{"$type" => "app.tempest.note", "text" => "oauth write"}
               },
               [{"dpop", dpop}]
             )

    assert oauth_write["uri"] == "at://#{did}/app.tempest.note/oauth"

    assert %{status: 401, body: %{"error" => "InvalidToken"}} =
             AtprotoSdkClient.create_record(client, oauth_access, %{
               "repo" => did,
               "collection" => "app.tempest.note",
               "rkey" => "oauth-missing-dpop",
               "validate" => false,
               "record" => %{"$type" => "app.tempest.note", "text" => "missing dpop"}
             })

    assert %{status: 200, body: ""} =
             AtprotoSdkClient.oauth_revoke(client, %{"token" => oauth_access, "client_id" => @client_id})
  end

  defp issue_oauth_access_token!(client, handle) do
    assert %{status: 200, body: %{"request_uri" => request_uri}} =
             AtprotoSdkClient.oauth_par(
               client,
               %{
                 "client_id" => @client_id,
                 "redirect_uri" => @redirect_uri,
                 "scope" => "atproto",
                 "response_type" => "code",
                 "code_challenge" => code_challenge("verifier"),
                 "code_challenge_method" => "S256"
               },
               dpop("POST", @base_url <> "/oauth/par", Dpop.issue_nonce())
             )

    authorize_response =
      AtprotoSdkClient.oauth_authorize(client, %{
        "request_uri" => request_uri,
        "identifier" => handle,
        "password" => @password
      })

    assert authorize_response.status == 302

    code =
      authorize_response.headers
      |> get_header("location")
      |> URI.parse()
      |> Map.fetch!(:query)
      |> URI.decode_query()
      |> Map.fetch!("code")

    assert %{status: 200, body: %{"access_token" => access_token, "token_type" => "DPoP", "scope" => "atproto"}} =
             AtprotoSdkClient.oauth_token(
               client,
               %{
                 "grant_type" => "authorization_code",
                 "client_id" => @client_id,
                 "redirect_uri" => @redirect_uri,
                 "code" => code,
                 "code_verifier" => "verifier"
               },
               dpop("POST", @base_url <> "/oauth/token", Dpop.issue_nonce())
             )

    access_token
  end

  defp websocket_backfill_frames(path, max_frames) do
    key = :crypto.strong_rand_bytes(16) |> Base.encode64()

    request = [
      "GET #{path} HTTP/1.1\r\n",
      "Host: localhost:4002\r\n",
      "Upgrade: websocket\r\n",
      "Connection: Upgrade\r\n",
      "Sec-WebSocket-Key: #{key}\r\n",
      "Sec-WebSocket-Version: 13\r\n",
      "\r\n"
    ]

    {:ok, socket} = :gen_tcp.connect(~c"localhost", 4002, [:binary, active: false], 1_000)
    :ok = :gen_tcp.send(socket, request)
    {:ok, response, rest} = recv_until(socket, "\r\n\r\n", "")
    assert response =~ " 101 "

    {frames, _rest} = read_ws_frames(socket, rest, max_frames, [])
    :gen_tcp.close(socket)
    frames
  end

  defp recv_until(socket, delimiter, acc) do
    case :binary.split(acc, delimiter) do
      [headers, rest] ->
        {:ok, headers <> delimiter, rest}

      [_incomplete] ->
        case :gen_tcp.recv(socket, 0, 2_000) do
          {:ok, chunk} -> recv_until(socket, delimiter, acc <> chunk)
          other -> other
        end
    end
  end

  defp read_ws_frames(_socket, buffer, 0, frames), do: {Enum.reverse(frames), buffer}

  defp read_ws_frames(socket, buffer, remaining, frames) do
    case read_ws_frame(socket, buffer) do
      {:ok, payload, rest} -> read_ws_frames(socket, rest, remaining - 1, [payload | frames])
      :timeout -> {Enum.reverse(frames), buffer}
    end
  end

  defp read_ws_frame(socket, buffer) do
    with {:ok, <<0x82, length_code, rest::binary>>} <- ensure_bytes(socket, buffer, 2),
         {:ok, length, rest} <- ws_payload_length(socket, rest, length_code &&& 0x7F),
         {:ok, payload_and_rest} <- ensure_bytes(socket, rest, length) do
      <<payload::binary-size(^length), remaining::binary>> = payload_and_rest
      {:ok, payload, remaining}
    else
      :timeout -> :timeout
    end
  end

  defp ensure_bytes(_socket, buffer, size) when byte_size(buffer) >= size, do: {:ok, buffer}

  defp ensure_bytes(socket, buffer, size) do
    case :gen_tcp.recv(socket, 0, 2_000) do
      {:ok, chunk} -> ensure_bytes(socket, buffer <> chunk, size)
      {:error, :timeout} -> :timeout
      {:error, reason} -> {:error, reason}
    end
  end

  defp ws_payload_length(_socket, rest, length) when length < 126, do: {:ok, length, rest}

  defp ws_payload_length(socket, rest, 126) do
    with {:ok, <<length::16, remaining::binary>>} <- ensure_bytes(socket, rest, 2) do
      {:ok, length, remaining}
    end
  end

  defp ws_payload_length(socket, rest, 127) do
    with {:ok, <<length::64, remaining::binary>>} <- ensure_bytes(socket, rest, 8) do
      {:ok, length, remaining}
    end
  end

  defp commit_frame?(frame, did) do
    header = Drisl.encode!(%{"op" => 1, "t" => "#commit"})

    if String.starts_with?(frame, header) do
      payload = binary_part(frame, byte_size(header), byte_size(frame) - byte_size(header))

      case Drisl.decode(payload) do
        {:ok, %{"repo" => ^did}} -> true
        _other -> false
      end
    else
      false
    end
  end

  defp dpop(method, url, nonce), do: Tempest.DpopProof.proof(method, url, nonce)

  defp code_challenge(verifier), do: :crypto.hash(:sha256, verifier) |> Base.url_encode64(padding: false)

  defp get_header(headers, name) do
    headers
    |> Map.fetch!(String.downcase(name))
    |> List.first()
  end
end
