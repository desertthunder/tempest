defmodule Tempest.PersonalBackupsTest do
  use Tempest.DataCase, async: false

  alias Tempest.Config
  alias Tempest.PersonalBackups
  alias Tempest.PersonalBackups.{Account, Credential, RetentionSetting, Run, Snapshot, SourceClient, Storage}
  alias Tempest.RepoCore.{Car, Cid, Commit, Drisl, Mst, Tid}
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
    old_storage_config = Application.get_env(:tempest, Storage, [])

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
      Application.put_env(:tempest, Storage, old_storage_config)
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

    Req.Test.expect(__MODULE__, 4, fn conn ->
      case conn.request_path do
        "/xrpc/com.atproto.sync.getRepo" ->
          assert conn.query_params["did"] == @did
          Plug.Conn.resp(conn, 200, repo_car)

        "/xrpc/com.atproto.sync.listBlobs" ->
          assert conn.query_params["did"] == @did
          Req.Test.json(conn, %{"cids" => []})

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
    assert File.exists?(Path.join(config.data_dir, snapshot.manifest_path))
    assert File.exists?(Path.join(config.data_dir, snapshot.verification_report_path))
  end

  test "create_repo_snapshot stores merged referenced and listed blobs plus preferences" do
    data_dir =
      Path.join(System.tmp_dir!(), "tempest_personal_backup_blob_snapshot_#{System.unique_integer([:positive])}")

    config = snapshot_test_config(data_dir)
    on_exit(fn -> File.rm_rf(data_dir) end)

    referenced_blob = "referenced blob"
    listed_blob = "listed blob"
    referenced_cid = Cid.for_raw(referenced_blob) |> Cid.to_string()
    listed_cid = Cid.for_raw(listed_blob) |> Cid.to_string()
    {repo_car, _commit, _commit_cid, did_document} = fixture_car(referenced_cid)

    expect_did_document(did_document)
    assert {:ok, account} = PersonalBackups.register_account(%{did: @did, handle: @handle})
    assert {:ok, %{account: account}} = PersonalBackups.rotate_credential(account, "access_token", "access-token")

    Req.Test.expect(__MODULE__, 7, fn conn ->
      case conn.request_path do
        "/xrpc/com.atproto.sync.getRepo" ->
          Plug.Conn.resp(conn, 200, repo_car)

        "/xrpc/com.atproto.sync.listBlobs" ->
          Req.Test.json(conn, %{"cids" => [listed_cid]})

        "/xrpc/com.atproto.sync.getBlob" ->
          case conn.query_params["cid"] do
            ^referenced_cid -> Plug.Conn.resp(conn, 200, referenced_blob)
            ^listed_cid -> Plug.Conn.resp(conn, 200, listed_blob)
          end

        "/xrpc/app.bsky.actor.getPreferences" ->
          assert ["Bearer access-token"] = Plug.Conn.get_req_header(conn, "authorization")
          Req.Test.json(conn, %{"preferences" => [%{"$type" => "app.bsky.actor.defs#adultContentPref"}]})

        "/" <> encoded_did ->
          assert URI.decode(encoded_did) == @did
          Req.Test.json(conn, did_document)
      end
    end)

    assert {:ok, %{snapshot: snapshot}} = PersonalBackups.create_repo_snapshot(account, config: config)

    snapshot = Repo.preload(snapshot, :blobs)
    assert snapshot.status == "complete"
    assert snapshot.verification_status == "ok"
    assert Enum.map(snapshot.blobs, & &1.cid) |> Enum.sort() == Enum.sort([referenced_cid, listed_cid])
    assert Enum.all?(snapshot.blobs, &(&1.status == "stored"))
    assert File.read!(Path.join([config.data_dir, snapshot.storage_key, "blobs", referenced_cid])) == referenced_blob
    assert File.read!(Path.join([config.data_dir, snapshot.storage_key, "preferences.json"])) =~ "adultContentPref"

    manifest = snapshot |> manifest_json(config)
    assert manifest["blobs"]["expected"] == 2
    assert manifest["blobs"]["complete"] == true
    assert manifest["preferences"]["included"] == true
  end

  test "create_repo_snapshot records missing blobs and preference auth warnings separately" do
    data_dir =
      Path.join(System.tmp_dir!(), "tempest_personal_backup_missing_snapshot_#{System.unique_integer([:positive])}")

    config = snapshot_test_config(data_dir)
    on_exit(fn -> File.rm_rf(data_dir) end)

    missing_cid = Cid.for_raw("missing blob") |> Cid.to_string()
    {repo_car, _commit, _commit_cid, did_document} = fixture_car(missing_cid)

    expect_did_document(did_document)
    assert {:ok, account} = PersonalBackups.register_account(%{did: @did, handle: @handle})
    assert {:ok, %{account: account}} = PersonalBackups.rotate_credential(account, "access_token", "bad-token")

    Req.Test.expect(__MODULE__, 6, fn conn ->
      case conn.request_path do
        "/xrpc/com.atproto.sync.getRepo" ->
          Plug.Conn.resp(conn, 200, repo_car)

        "/xrpc/com.atproto.sync.listBlobs" ->
          Req.Test.json(conn, %{"cids" => []})

        "/xrpc/com.atproto.sync.getBlob" ->
          Plug.Conn.resp(conn, 404, "missing")

        "/xrpc/app.bsky.actor.getPreferences" ->
          Plug.Conn.resp(conn, 401, "bad auth")

        "/" <> encoded_did ->
          assert URI.decode(encoded_did) == @did
          Req.Test.json(conn, did_document)
      end
    end)

    assert {:ok, %{snapshot: snapshot}} = PersonalBackups.create_repo_snapshot(account, config: config)

    snapshot = Repo.preload(snapshot, :blobs)
    assert snapshot.status == "incomplete"
    assert snapshot.verification_status == "warning"
    assert [%{cid: ^missing_cid, status: "missing"}] = snapshot.blobs

    manifest = snapshot |> manifest_json(config)
    assert manifest["blobs"]["complete"] == false
    assert manifest["blobs"]["missing"] == [missing_cid]

    report = snapshot |> verification_report_json(config)
    assert "missing_blobs" in report["warnings"]
    assert Enum.any?(report["warnings"], &String.starts_with?(&1, "preferences_auth_or_fetch_failed"))
  end

  test "create_repo_snapshot can upload a snapshot archive through S3-compatible storage" do
    data_dir = Path.join(System.tmp_dir!(), "tempest_personal_backup_s3_snapshot_#{System.unique_integer([:positive])}")
    config = snapshot_test_config(data_dir)
    on_exit(fn -> File.rm_rf(data_dir) end)

    Application.put_env(:tempest, Storage,
      store: :s3,
      s3: [
        endpoint_url: "https://objects.example.test",
        bucket: "tempest-backups",
        req_options: [plug: {Req.Test, __MODULE__}],
        headers: [{"authorization", "Bearer backup-token"}]
      ]
    )

    {repo_car, _commit, _commit_cid, did_document} = fixture_car()
    expect_did_document(did_document)
    assert {:ok, account} = PersonalBackups.register_account(%{did: @did, handle: @handle})

    Req.Test.expect(__MODULE__, 5, fn conn ->
      case conn.request_path do
        "/xrpc/com.atproto.sync.getRepo" ->
          Plug.Conn.resp(conn, 200, repo_car)

        "/xrpc/com.atproto.sync.listBlobs" ->
          Req.Test.json(conn, %{"cids" => []})

        "/tempest-backups/" <> key ->
          assert conn.method == "PUT"
          assert String.ends_with?(URI.decode(key), ".zip")
          assert Plug.Conn.get_req_header(conn, "authorization") == ["Bearer backup-token"]
          assert {:ok, bytes, conn} = Plug.Conn.read_body(conn)
          assert byte_size(bytes) > 0
          Plug.Conn.send_resp(conn, 200, "")

        "/" <> encoded_did ->
          assert URI.decode(encoded_did) == @did
          Req.Test.json(conn, did_document)
      end
    end)

    assert {:ok, %{snapshot: snapshot}} = PersonalBackups.create_repo_snapshot(account, config: config)
    assert File.exists?(Path.join(config.data_dir, snapshot.storage_key))
  end

  test "prune_snapshots applies retention policies without deleting pinned snapshots" do
    expect_did_document()
    assert {:ok, account} = PersonalBackups.register_account(%{did: @did, handle: @handle})

    data_dir = Path.join(System.tmp_dir!(), "tempest_personal_backup_retention_#{System.unique_integer([:positive])}")
    config = snapshot_test_config(data_dir)
    on_exit(fn -> File.rm_rf(data_dir) end)

    old = insert_dummy_snapshot!(account, config, "old", ~U[2026-01-01 00:00:00Z])
    pinned = insert_dummy_snapshot!(account, config, "pinned", ~U[2026-01-02 00:00:00Z], pinned: true)
    recent = insert_dummy_snapshot!(account, config, "recent", ~U[2026-01-03 00:00:00Z])

    assert {:ok, _setting} = PersonalBackups.update_retention_setting(account, %{policy: "keep_last_n", keep_last: 1})
    assert {:ok, pruned} = PersonalBackups.prune_snapshots(account, config: config)

    assert Enum.map(pruned, & &1.id) == [old.id]
    refute Repo.get(Snapshot, old.id)
    assert Repo.get(Snapshot, pinned.id)
    assert Repo.get(Snapshot, recent.id)
    refute File.exists?(Path.join(config.data_dir, old.storage_key))
    assert File.exists?(Path.join(config.data_dir, pinned.storage_key))
  end

  test "export_snapshot_bundle creates a portable zip with snapshot files" do
    data_dir = Path.join(System.tmp_dir!(), "tempest_personal_backup_export_#{System.unique_integer([:positive])}")
    config = snapshot_test_config(data_dir)
    on_exit(fn -> File.rm_rf(data_dir) end)

    {snapshot, _did_document} = create_no_blob_snapshot!(config)
    export_path = Path.join([data_dir, "exports", "snapshot.zip"])

    assert {:ok, %{path: ^export_path, byte_size: byte_size}} =
             PersonalBackups.export_snapshot_bundle(snapshot, config: config, path: export_path)

    assert byte_size > 0
    assert {:ok, entries} = :zip.list_dir(String.to_charlist(export_path))

    names =
      entries
      |> Enum.filter(&match?({:zip_file, _, _, _, _, _}, &1))
      |> Enum.map(fn {:zip_file, name, _, _, _, _} -> List.to_string(name) end)

    assert "manifest.json" in names
    assert "repo.car" in names
    assert "verification.json" in names
  end

  test "verify_snapshot_offline validates manifest files without source PDS access" do
    data_dir = Path.join(System.tmp_dir!(), "tempest_personal_backup_offline_#{System.unique_integer([:positive])}")
    config = snapshot_test_config(data_dir)
    on_exit(fn -> File.rm_rf(data_dir) end)

    {snapshot, _did_document} = create_no_blob_snapshot!(config)

    assert {:ok, %{status: "ok"}} = PersonalBackups.verify_snapshot_offline(snapshot, config: config)

    File.write!(Path.join(config.data_dir, snapshot.repo_car_path), "corrupt")
    assert {:error, :sha256_mismatch} = PersonalBackups.verify_snapshot_offline(snapshot, config: config)
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

  defp create_no_blob_snapshot!(config) do
    {repo_car, _commit, _commit_cid, did_document} = fixture_car()
    expect_did_document(did_document)
    assert {:ok, account} = PersonalBackups.register_account(%{did: @did, handle: @handle})

    Req.Test.expect(__MODULE__, 4, fn conn ->
      case conn.request_path do
        "/xrpc/com.atproto.sync.getRepo" ->
          Plug.Conn.resp(conn, 200, repo_car)

        "/xrpc/com.atproto.sync.listBlobs" ->
          Req.Test.json(conn, %{"cids" => []})

        "/" <> encoded_did ->
          assert URI.decode(encoded_did) == @did
          Req.Test.json(conn, did_document)
      end
    end)

    assert {:ok, %{snapshot: snapshot}} = PersonalBackups.create_repo_snapshot(account, config: config)
    {snapshot, did_document}
  end

  defp insert_dummy_snapshot!(account, config, name, completed_at, opts \\ []) do
    storage_key = Path.join(["personal-backups", account.did |> String.replace(":", "_"), "snapshots", name])
    snapshot_dir = Path.join(config.data_dir, storage_key)
    File.mkdir_p!(snapshot_dir)
    File.write!(Path.join(snapshot_dir, "manifest.json"), "{}")

    %Snapshot{}
    |> Snapshot.changeset(%{
      account_id: account.id,
      status: "complete",
      storage_key: storage_key,
      source_pds_url: account.source_pds_url,
      handle: account.handle,
      did: account.did,
      completed_at: completed_at,
      verification_status: "ok",
      pinned: Keyword.get(opts, :pinned, false)
    })
    |> Repo.insert!()
  end

  defp snapshot_test_config(data_dir) do
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
  end

  defp manifest_json(snapshot, config) do
    config.data_dir
    |> Path.join(snapshot.manifest_path)
    |> File.read!()
    |> Jason.decode!()
  end

  defp verification_report_json(snapshot, config) do
    config.data_dir
    |> Path.join(snapshot.verification_report_path)
    |> File.read!()
    |> Jason.decode!()
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

  defp fixture_car(blob_cid \\ nil) do
    {public_key, private_key} = :crypto.generate_key(:ecdh, :secp256k1)

    record =
      if blob_cid do
        %{
          "$type" => "app.bsky.actor.profile",
          "avatar" => %{
            "$type" => "blob",
            "ref" => %{"$link" => blob_cid},
            "mimeType" => "image/png",
            "size" => 12
          }
        }
      else
        %{"$type" => "app.bsky.feed.post", "text" => "fixture"}
      end

    record_bytes = Drisl.encode!(record)
    record_cid = Cid.for_drisl(record_bytes)
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
      {record_cid, record_bytes} | mst_blocks
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
