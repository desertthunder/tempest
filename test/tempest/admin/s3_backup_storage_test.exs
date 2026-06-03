defmodule Tempest.Admin.S3BackupStorageTest do
  use Tempest.DataCase

  alias Tempest.Admin.Backup
  alias Tempest.Config

  setup context do
    Req.Test.set_req_test_from_context(context)
    Req.Test.verify_on_exit!(context)

    old_config = Application.get_env(:tempest, Backup)

    Application.put_env(:tempest, Backup,
      store: :s3,
      s3: [
        endpoint_url: "https://objects.example.test",
        bucket: "tempest-backups",
        req_options: [plug: {Req.Test, __MODULE__}],
        headers: [{"authorization", "Bearer backup-token"}],
        key: "backups/test-backup.zip"
      ]
    )

    on_exit(fn ->
      if old_config do
        Application.put_env(:tempest, Backup, old_config)
      else
        Application.delete_env(:tempest, Backup)
      end
    end)

    :ok
  end

  test "backup create can upload a zip archive to S3-compatible storage" do
    config = Config.load!()
    backup_dir = Path.join(System.tmp_dir!(), "tempest-s3-backup-#{System.unique_integer([:positive])}")

    Req.Test.expect(__MODULE__, fn conn ->
      assert conn.method == "PUT"
      assert conn.request_path == "/tempest-backups/backups/test-backup.zip"
      assert Plug.Conn.get_req_header(conn, "authorization") == ["Bearer backup-token"]
      assert {:ok, bytes, conn} = Plug.Conn.read_body(conn)
      assert byte_size(bytes) > 0
      Plug.Conn.send_resp(conn, 200, "")
    end)

    assert {:ok, %{path: ^backup_dir, upload: upload}} = Backup.create(config: config, path: backup_dir, upload?: true)
    assert upload.key == "backups/test-backup.zip"
    assert upload.bytes > 0
    assert File.exists?(upload.archive_path)
  end
end
