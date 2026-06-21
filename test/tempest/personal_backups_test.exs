defmodule Tempest.PersonalBackupsTest do
  use Tempest.DataCase, async: false

  alias Tempest.Config
  alias Tempest.PersonalBackups
  alias Tempest.PersonalBackups.{Account, Credential, RetentionSetting, Run, Snapshot, SourceClient}
  alias Tempest.RepoCore.{Car, Cid, Commit, Mst, Tid}
  alias Tempest.Repo

  import Ecto.Query

  @did "did:plc:aaaaaaaaaaaaaaaaaaaaaaaa"
  @handle "backup.example.com"
  @source_pds "https://source.example.com"

  setup context do
    Req.Test.set_req_test_from_context(context)
    Req.Test.verify_on_exit!(context)

    old_identity_config = Application.get_env(:tempest, Tempest.Identity, [])
    old_source_client_config = Application.get_env(:tempest, SourceClient, [])

    Application.put_env(:tempest, Tempest.Identity,
      plc_directory_url: "https://plc.test",
      http_req_options: [plug: {Req.Test, __MODULE__}],
      dns_lookup: fn _host -> {:ok, [{93, 184, 216, 34}]} end,
      dns_txt_lookup: fn "_atproto." <> @handle -> ["did=#{@did}"] end
    )

    Application.put_env(:tempest, SourceClient, req_options: [plug: {Req.Test, __MODULE__}])

    on_exit(fn ->
      Application.put_env(:tempest, Tempest.Identity, old_identity_config)
      Application.put_env(:tempest, SourceClient, old_source_client_config)
    end)

    :ok
  end

  test "register_account resolves the source PDS from the DID document" do
    expect_did_document()

    assert {:ok, %Account{} = account} =
             PersonalBackups.register_account(%{
               did: @did,
               handle: @handle,
               label: "Primary backup"
             })

    assert account.label == "Primary backup"
    assert account.did == @did
    assert account.handle == @handle
    assert account.source_pds_url == @source_pds
    assert account.pinned_source_pds_url == nil
    assert account.credential_state == "none"
    assert account.status == "verified"
    assert %Credential{mode: "none", secret_ciphertext: nil} = account.credential
    assert %RetentionSetting{policy: "keep_last_n", keep_last: 3} = account.retention_setting
  end

  test "register_account accepts a pinned source PDS only when it matches the DID document" do
    expect_did_document()

    assert {:ok, account} =
             PersonalBackups.register_account(%{
               "did" => @did,
               "handle" => @handle,
               "pinned_source_pds_url" => @source_pds <> "/"
             })

    assert account.source_pds_url == @source_pds
    assert account.pinned_source_pds_url == @source_pds
  end

  test "register_account fails closed when the pinned source PDS mismatches" do
    expect_did_document()

    assert {:error, :pinned_source_pds_mismatch} =
             PersonalBackups.register_account(%{
               did: @did,
               handle: @handle,
               pinned_source_pds_url: "https://other.example.com"
             })

    refute Repo.exists?(from account in Account, where: account.did == ^@did)
  end

  test "register_account rejects handle DID mismatches" do
    other_did = "did:plc:bbbbbbbbbbbbbbbbbbbbbbbb"

    Application.put_env(:tempest, Tempest.Identity,
      plc_directory_url: "https://plc.test",
      http_req_options: [plug: {Req.Test, __MODULE__}],
      dns_lookup: fn _host -> {:ok, [{93, 184, 216, 34}]} end,
      dns_txt_lookup: fn "_atproto." <> @handle -> ["did=#{other_did}"] end
    )

    assert {:error, :handle_did_mismatch} =
             PersonalBackups.register_account(%{did: @did, handle: @handle})
  end

  test "register_account requires #atproto_pds in the DID document" do
    expect_did_document(%{"service" => []})

    assert {:error, :missing_atproto_pds} =
             PersonalBackups.register_account(%{did: @did, handle: @handle})
  end

  test "verify_account_source refreshes handle and source fields" do
    expect_did_document()

    assert {:ok, account} = PersonalBackups.register_account(%{did: @did, handle: @handle})

    expect_did_document(%{
      "service" => [
        %{
          "id" => "#atproto_pds",
          "type" => "AtprotoPersonalDataServer",
          "serviceEndpoint" => "https://source.example.com/"
        }
      ]
    })

    assert {:ok, verified} = PersonalBackups.verify_account_source(account)
    assert verified.status == "verified"
    assert verified.source_pds_url == @source_pds
    assert verified.last_checked_at
  end

  test "credential rotation stores encrypted secrets and exposes only redacted state" do
    expect_did_document()

    assert {:ok, account} = PersonalBackups.register_account(%{did: @did, handle: @handle})

    assert {:ok, %{account: account, credential: credential}} =
             PersonalBackups.rotate_credential(account, "app_password", "abcd-efgh-secret")

    assert account.credential_state == "app_password"
    assert credential.mode == "app_password"
    assert credential.secret_ciphertext
    refute credential.secret_ciphertext == "abcd-efgh-secret"
    assert credential.secret_hint == "...cret"
    refute inspect(PersonalBackups.credential_public_state(account)) =~ "abcd-efgh-secret"
    assert {:ok, "abcd-efgh-secret"} = PersonalBackups.decrypted_credential_secret(account)

    assert {:ok, %{account: account, credential: credential}} = PersonalBackups.delete_credential(account)
    assert account.credential_state == "none"
    assert credential.secret_ciphertext == nil
    assert credential.deleted_at
    assert {:ok, nil} = PersonalBackups.decrypted_credential_secret(account)
  end

  test "source client reads repo blobs and preferences through XRPC" do
    Req.Test.expect(__MODULE__, 4, fn conn ->
      case conn.request_path do
        "/xrpc/com.atproto.sync.getRepo" ->
          assert conn.query_params["did"] == @did
          Plug.Conn.resp(conn, 200, "repo car bytes")

        "/xrpc/com.atproto.sync.listBlobs" ->
          assert conn.query_params["did"] == @did
          Req.Test.json(conn, %{"cids" => ["bafk"], "cursor" => "next"})

        "/xrpc/com.atproto.sync.getBlob" ->
          assert conn.query_params["did"] == @did
          assert conn.query_params["cid"] == "bafk"
          Plug.Conn.resp(conn, 200, "blob bytes")

        "/xrpc/app.bsky.actor.getPreferences" ->
          assert ["Bearer access-token"] = Plug.Conn.get_req_header(conn, "authorization")
          Req.Test.json(conn, %{"preferences" => [%{"$type" => "app.bsky.actor.defs#adultContentPref"}]})
      end
    end)

    assert {:ok, "repo car bytes"} = SourceClient.get_repo(@source_pds, @did)
    assert {:ok, %{"cids" => ["bafk"]}} = SourceClient.list_blobs(@source_pds, @did)
    assert {:ok, "blob bytes"} = SourceClient.get_blob(@source_pds, @did, "bafk")
    assert {:ok, %{"preferences" => [_pref]}} = SourceClient.get_preferences(@source_pds, "access-token")
  end

  test "create_repo_snapshot fetches verifies stores and records a repo CAR" do
    data_dir = Path.join(System.tmp_dir!(), "tempest_personal_backup_snapshot_#{System.unique_integer([:positive])}")

    config =
      Config.validate!(
        [
          hostname: "localhost",
          public_url: "http://localhost:4002",
          data_dir: data_dir,
          blob_max_bytes: 10_000_000
        ],
        env: :test,
        endpoint_config: Application.fetch_env!(:tempest, TempestWeb.Endpoint)
      )

    on_exit(fn -> File.rm_rf(data_dir) end)

    {repo_car, commit, commit_cid, did_document} = fixture_car()

    expect_did_document(did_document)
    assert {:ok, account} = PersonalBackups.register_account(%{did: @did, handle: @handle})

    Req.Test.expect(__MODULE__, 3, fn conn ->
      case conn.request_path do
        "/xrpc/com.atproto.sync.getRepo" ->
          assert conn.query_params["did"] == @did
          Plug.Conn.resp(conn, 200, repo_car)

        "/" <> encoded_did ->
          assert URI.decode(encoded_did) == @did
          Req.Test.json(conn, did_document)
      end
    end)

    assert {:ok,
            %{snapshot: %Snapshot{} = snapshot, run: %Run{} = run, account: updated_account, verification: verification}} =
             PersonalBackups.create_repo_snapshot(account, config: config)

    assert snapshot.status == "complete"
    assert snapshot.verification_status == "ok"
    assert snapshot.did == @did
    assert snapshot.handle == @handle
    assert snapshot.source_pds_url == @source_pds
    assert snapshot.commit_cid == Cid.to_string(commit_cid)
    assert snapshot.rev == commit.rev
    assert snapshot.byte_size == byte_size(repo_car)
    assert snapshot.sha256 == Base.encode16(:crypto.hash(:sha256, repo_car), case: :lower)
    assert run.status == "succeeded"
    assert updated_account.last_snapshot_id == snapshot.id
    assert verification.record_count == 1

    assert File.read!(Path.join(config.data_dir, snapshot.repo_car_path)) == repo_car
  end

  test "create_repo_snapshot rejects invalid commit signatures" do
    data_dir =
      Path.join(System.tmp_dir!(), "tempest_personal_backup_bad_snapshot_#{System.unique_integer([:positive])}")

    config =
      Config.validate!(
        [
          hostname: "localhost",
          public_url: "http://localhost:4002",
          data_dir: data_dir,
          blob_max_bytes: 10_000_000
        ],
        env: :test,
        endpoint_config: Application.fetch_env!(:tempest, TempestWeb.Endpoint)
      )

    on_exit(fn -> File.rm_rf(data_dir) end)

    {repo_car, _commit, _commit_cid, did_document} = fixture_car()

    bad_document =
      put_in(
        did_document,
        ["verificationMethod", Access.at(0), "publicKeyMultibase"],
        "u" <> Base.url_encode64(:binary.copy(<<0>>, 65), padding: false)
      )

    expect_did_document(did_document)
    assert {:ok, account} = PersonalBackups.register_account(%{did: @did, handle: @handle})

    Req.Test.expect(__MODULE__, 3, fn conn ->
      case conn.request_path do
        "/xrpc/com.atproto.sync.getRepo" ->
          Plug.Conn.resp(conn, 200, repo_car)

        "/" <> encoded_did ->
          assert URI.decode(encoded_did) == @did
          Req.Test.json(conn, bad_document)
      end
    end)

    assert {:error, :invalid_public_key} = PersonalBackups.create_repo_snapshot(account, config: config)
    refute Repo.exists?(from snapshot in Snapshot, where: snapshot.account_id == ^account.id)
  end

  defp expect_did_document(overrides \\ %{}) do
    Req.Test.expect(__MODULE__, fn conn ->
      assert conn.request_path == "/" <> URI.encode(@did)

      document =
        Map.merge(
          %{
            "@context" => ["https://www.w3.org/ns/did/v1"],
            "id" => @did,
            "alsoKnownAs" => ["at://#{@handle}"],
            "service" => [
              %{
                "id" => "#atproto_pds",
                "type" => "AtprotoPersonalDataServer",
                "serviceEndpoint" => @source_pds
              }
            ]
          },
          overrides
        )

      Req.Test.json(conn, document)
    end)
  end

  defp fixture_car do
    {public_key, private_key} = :crypto.generate_key(:ecdh, :secp256k1)
    record_cid = Cid.for_raw(~s({"$type":"app.bsky.feed.post","text":"fixture"}))
    mst = Mst.from_entries!([{"app.bsky.feed.post/3jui7kd54zh2y", record_cid}])
    {:ok, %{root: mst_root, blocks: mst_blocks}} = Mst.serialize(mst)

    unsigned =
      Commit.new!(%{
        did: @did,
        data: mst_root,
        rev: Tid.new!(1_700_000_000_000_000, 0),
        prev: nil
      })

    {:ok, commit} = Commit.sign(unsigned, private_key)
    commit_bytes = Commit.encode!(commit)
    commit_cid = Cid.for_drisl(commit_bytes)

    blocks = [
      {commit_cid, commit_bytes},
      {record_cid, ~s({"$type":"app.bsky.feed.post","text":"fixture"})} | mst_blocks
    ]

    {:ok, car_bytes} = Car.encode([commit_cid], blocks)

    did_document =
      did_document(%{
        "verificationMethod" => [
          %{
            "id" => @did <> "#atproto",
            "publicKeyMultibase" => "u" <> Base.url_encode64(public_key, padding: false)
          }
        ]
      })

    {car_bytes, commit, commit_cid, did_document}
  end

  defp did_document(overrides) do
    Map.merge(
      %{
        "@context" => ["https://www.w3.org/ns/did/v1"],
        "id" => @did,
        "alsoKnownAs" => ["at://#{@handle}"],
        "service" => [
          %{
            "id" => "#atproto_pds",
            "type" => "AtprotoPersonalDataServer",
            "serviceEndpoint" => @source_pds
          }
        ]
      },
      overrides
    )
  end
end
