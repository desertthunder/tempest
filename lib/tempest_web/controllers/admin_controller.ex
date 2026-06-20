defmodule TempestWeb.AdminController do
  use TempestWeb, :controller

  alias Tempest.{Admin, AdminAuth}
  alias TempestWeb.XrpcErrorJSON

  def status(conn, _params) do
    with_admin(conn, fn conn -> json(conn, Admin.status()) end)
  end

  def dashboard(conn, _params) do
    with_admin(conn, fn conn -> render(conn, :dashboard, status: Admin.status()) end)
  end

  def invites(conn, _params) do
    with_admin(conn, fn conn -> render(conn, :invites, status: Admin.status()) end)
  end

  def repo(conn, _params) do
    with_admin(conn, fn conn -> render(conn, :repo, result: nil) end)
  end

  def repo_action(conn, %{"op" => op} = params) do
    with_admin(conn, fn conn -> render(conn, :repo, result: run_repo_op(op, params)) end)
  end

  def backups(conn, _params) do
    with_admin(conn, fn conn -> render(conn, :backups, result: nil) end)
  end

  def backup_action(conn, %{"op" => op} = params) do
    with_admin(conn, fn conn -> render(conn, :backups, result: run_backup_op(op, params)) end)
  end

  def storage(conn, _params) do
    with_admin(conn, fn conn -> render(conn, :storage, status: Admin.status()) end)
  end

  def compatibility(conn, _params) do
    with_admin(conn, fn conn -> render(conn, :compatibility, status: Admin.compatibility_status()) end)
  end

  defp with_admin(conn, fun) do
    cond do
      conn.assigns[:admin_auth] ->
        fun.(conn)

      true ->
        case AdminAuth.verify_authorization_header(conn.req_headers) do
          :ok ->
            fun.(conn)

          {:error, :missing_admin_token} ->
            reject(conn, 401, "AuthenticationRequired", "Admin bearer token is required")

          {:error, :admin_token_not_configured} ->
            reject(conn, 503, "AdminAuthNotConfigured", "Admin token hash is not configured")

          {:error, _reason} ->
            reject(conn, 401, "InvalidToken", "Admin bearer token is invalid")
        end
    end
  end

  defp run_repo_op("verify", %{"did" => did}), do: Admin.RepoOps.verify(did)
  defp run_repo_op("export", %{"did" => did, "path" => path}), do: Admin.RepoOps.export(did, path)
  defp run_repo_op("import", %{"did" => did, "path" => path}), do: Admin.RepoOps.import(did, path)
  defp run_repo_op(_op, _params), do: {:error, :invalid_repo_operation}

  defp run_backup_op("create", params) do
    opts = if blank?(params["path"]), do: [], else: [path: params["path"]]
    Admin.Backup.create(opts)
  end

  defp run_backup_op("restore_dry_run", %{"path" => path} = params) do
    target = if blank?(params["target"]), do: Tempest.Config.load!().data_dir, else: params["target"]
    manifest = Path.join(path, "manifest.json")

    cond do
      not File.dir?(path) ->
        {:error, :backup_not_found}

      not File.exists?(manifest) ->
        {:error, :backup_manifest_missing}

      File.exists?(Path.join(target, "account.sqlite")) or File.exists?(Path.join(target, "sequencer.sqlite")) ->
        {:ok, %{dry_run: true, refused: :target_not_empty, target: target}}

      true ->
        {:ok, %{dry_run: true, would_restore: true, target: target}}
    end
  end

  defp run_backup_op(_op, _params), do: {:error, :invalid_backup_operation}

  defp blank?(value), do: is_nil(value) or String.trim(to_string(value)) == ""

  defp reject(conn, status, error, message) do
    XrpcErrorJSON.render(conn, status, error, message)
  end
end
