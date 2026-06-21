defmodule TempestWeb.AdminControlLiveTest do
  use TempestWeb.ConnCase, async: false

  import Ecto.Query
  import Phoenix.LiveViewTest

  alias Tempest.Accounts
  alias Tempest.PersonalBackups
  alias Tempest.PersonalBackups.{Account, Snapshot, SourceClient}
  alias Tempest.Repo
  alias Tempest.RepoCore.{Car, Cid, Commit, Drisl, Mst, Tid}

  @password "correct horse battery staple"
  @did "did:plc:cccccccccccccccccccccccc"
  @handle "admin-backup-live.test"
  @source_pds "https://source.example.com"

  setup context do
    Req.Test.set_req_test_from_context(context)
    Req.Test.verify_on_exit!(context)

    old_config = Application.get_env(:tempest, Tempest.Config)
    old_identity_config = Application.get_env(:tempest, Tempest.Identity)
    old_source_client_config = Application.get_env(:tempest, SourceClient, [])

    Application.put_env(:tempest, Tempest.Identity,
      plc_directory_url: "https://plc.test",
      http_req_options: [plug: {Req.Test, __MODULE__}],
      dns_lookup: fn _host -> {:ok, [{93, 184, 216, 34}]} end,
      dns_txt_lookup: fn "_atproto." <> @handle -> ["did=#{@did}"] end
    )

    Application.put_env(:tempest, SourceClient, req_options: [plug: {Req.Test, __MODULE__}])

    on_exit(fn ->
      Application.put_env(:tempest, Tempest.Config, old_config)

      if old_identity_config do
        Application.put_env(:tempest, Tempest.Identity, old_identity_config)
      else
        Application.delete_env(:tempest, Tempest.Identity)
      end

      Application.put_env(:tempest, SourceClient, old_source_client_config)
    end)

    :ok
  end

  test "external backup LiveView route auth requires an admin browser session", %{conn: conn} do
    redirected = get(conn, ~p"/admin/personal-backups")
    assert redirected_to(redirected) == ~p"/admin/login?#{[return_to: "/admin/personal-backups"]}"

    {:ok, user} = create_account!("admin-backup-user.test", "admin-backup-user@example.com")

    account_conn =
      conn
      |> recycle()
      |> post(~p"/account/login", %{
        "account" => %{"identifier" => user["handle"], "password" => @password}
      })

    rejected =
      account_conn
      |> recycle()
      |> get(~p"/admin/personal-backups")

    assert redirected_to(rejected) == ~p"/admin/login?#{[return_to: "/admin/personal-backups"]}"
  end

  test "external backup create edit and delete forms mutate through LiveView", %{conn: conn} do
    admin_conn = admin_login_conn(conn)

    expect_did_document()

    {:ok, view, _html} = live(admin_conn, ~p"/admin/personal-backups/new")
    assert has_element?(view, ~s(a#admin-control-home[href="/"]))

    view
    |> form("#personal-backup-create-form",
      backup_account: %{
        did: @did,
        handle: @handle,
        label: "Primary external backup",
        pinned_source_pds_url: ""
      }
    )
    |> render_submit()

    account = Repo.get_by!(Account, did: @did)
    assert_redirect(view, ~p"/admin/personal-backups/#{account.id}")

    {:ok, edit_view, _html} = live(admin_conn, ~p"/admin/personal-backups/#{account.id}/edit")

    edit_view
    |> form("#personal-backup-edit-form",
      backup_account: %{label: "Renamed backup", pinned_source_pds_url: @source_pds}
    )
    |> render_submit()

    assert_redirect(edit_view, ~p"/admin/personal-backups/#{account.id}")
    assert Repo.get!(Account, account.id).label == "Renamed backup"

    {:ok, delete_view, _html} = live(admin_conn, ~p"/admin/personal-backups/#{account.id}/delete")

    delete_view
    |> form("#personal-backup-delete-form", %{})
    |> render_submit()

    assert_redirect(delete_view, ~p"/admin/personal-backups")
    refute Repo.get(Account, account.id)
  end

  test "external backup operation forms run backup verify export and prune", %{conn: conn} do
    admin_conn = admin_login_conn(conn)
    {repo_car, _commit, _commit_cid, did_document} = fixture_car()
    account = registered_backup_account!(did_document)

    old = insert_dummy_snapshot!(account, "old", ~U[2026-01-01 00:00:00Z])

    Req.Test.expect(__MODULE__, 4, fn req_conn ->
      case req_conn.request_path do
        "/xrpc/com.atproto.sync.getRepo" ->
          Plug.Conn.resp(req_conn, 200, repo_car)

        "/xrpc/com.atproto.sync.listBlobs" ->
          Req.Test.json(req_conn, %{"cids" => []})

        "/" <> encoded_did ->
          assert URI.decode(encoded_did) == @did
          Req.Test.json(req_conn, did_document)
      end
    end)

    {:ok, view, _html} = live(admin_conn, ~p"/admin/personal-backups/#{account.id}")

    view
    |> form("#personal-backup-now-form", %{})
    |> render_submit()

    snapshot =
      Snapshot
      |> where([snapshot], snapshot.account_id == ^account.id and snapshot.id != ^old.id)
      |> order_by([snapshot], desc: snapshot.id)
      |> Repo.one!()

    view
    |> form("#personal-backup-verify-form", snapshot: %{snapshot_id: snapshot.id})
    |> render_submit()

    export_path = Path.join(System.tmp_dir!(), "tempest-admin-live-export-#{System.unique_integer([:positive])}.zip")
    on_exit(fn -> File.rm(export_path) end)

    view
    |> form("#personal-backup-export-form", snapshot: %{snapshot_id: snapshot.id, path: export_path})
    |> render_submit()

    assert File.exists?(export_path)

    account
    |> PersonalBackups.update_retention_setting(%{policy: "keep_last_n", keep_last: 1})
    |> then(fn {:ok, _setting} -> :ok end)

    view
    |> form("#personal-backup-prune-form", %{})
    |> render_submit()

    refute Repo.get(Snapshot, old.id)
    assert Repo.get(Snapshot, snapshot.id)
  end

  defp admin_login_conn(conn) do
    {:ok, account} = create_account!("admin-backup-live-admin.test", "admin-backup-live-admin@example.com")
    configure_admin_did(account["did"])

    conn
    |> recycle()
    |> post(~p"/admin/login", %{
      "admin" => %{"identifier" => account["handle"], "password" => @password}
    })
  end

  defp create_account!(handle, email) do
    Accounts.create_account(%{
      "handle" => handle,
      "email" => email,
      "password" => @password
    })
  end

  defp configure_admin_did(did) do
    config =
      :tempest
      |> Application.fetch_env!(Tempest.Config)
      |> Keyword.put(:admin_did, did)

    Application.put_env(:tempest, Tempest.Config, config)
  end

  defp registered_backup_account!(did_document) do
    expect_did_document(did_document)

    assert {:ok, account} =
             PersonalBackups.register_account(%{
               did: @did,
               handle: @handle,
               label: "External backup"
             })

    account
  end

  defp insert_dummy_snapshot!(account, name, completed_at) do
    config = Tempest.Config.load!()
    storage_key = Path.join(["personal-backups", String.replace(account.did, ":", "_"), "snapshots", name])
    File.mkdir_p!(Path.join(config.data_dir, storage_key))

    %Snapshot{}
    |> Snapshot.changeset(%{
      account_id: account.id,
      status: "complete",
      storage_key: storage_key,
      source_pds_url: account.source_pds_url,
      handle: account.handle,
      did: account.did,
      completed_at: completed_at,
      verification_status: "ok"
    })
    |> Repo.insert!()
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

    record_bytes = Drisl.encode!(%{"$type" => "app.bsky.feed.post", "text" => "fixture"})
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
    {:ok, car_bytes} = Car.encode([commit_cid], [{commit_cid, commit_bytes}, {record_cid, record_bytes} | mst_blocks])

    did_document = %{
      "@context" => ["https://www.w3.org/ns/did/v1"],
      "id" => @did,
      "alsoKnownAs" => ["at://#{@handle}"],
      "service" => [
        %{
          "id" => "#atproto_pds",
          "type" => "AtprotoPersonalDataServer",
          "serviceEndpoint" => @source_pds
        }
      ],
      "verificationMethod" => [
        %{
          "id" => @did <> "#atproto",
          "publicKeyMultibase" => "u" <> Base.url_encode64(public_key, padding: false)
        }
      ]
    }

    {car_bytes, commit, commit_cid, did_document}
  end
end
