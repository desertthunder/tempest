defmodule TempestWeb.AdminControlLive do
  use TempestWeb, :live_view

  alias Tempest.Admin
  alias Tempest.PersonalBackups
  alias Tempest.PersonalBackups.Account

  @impl true
  def mount(_params, _session, socket), do: {:ok, assign(socket, :page_title, "Admin Control Panel")}

  @impl true
  def handle_params(params, _uri, socket) do
    {:noreply, assign_action_data(socket, params)}
  end

  @impl true
  def handle_event("create_backup_account", %{"backup_account" => params}, socket) do
    case PersonalBackups.register_account(params) do
      {:ok, %Account{} = account} ->
        {:noreply,
         socket
         |> put_flash(:info, "External backup account registered.")
         |> push_navigate(to: ~p"/admin/personal-backups/#{account.id}")}

      {:error, reason} ->
        {:noreply,
         socket
         |> put_flash(:error, "Could not register account: #{present(reason)}")
         |> assign_new_backup_forms(params)}
    end
  end

  def handle_event("update_backup_account", %{"backup_account" => params}, socket) do
    account = socket.assigns.backup_account

    case PersonalBackups.update_account_profile(account, params) do
      {:ok, account} ->
        {:noreply,
         socket
         |> put_flash(:info, "External backup account updated.")
         |> push_navigate(to: ~p"/admin/personal-backups/#{account.id}")}

      {:error, changeset} ->
        {:noreply,
         socket
         |> put_flash(:error, "Could not update account.")
         |> assign(:account_form, to_form(changeset))}
    end
  end

  def handle_event("delete_backup_account", _params, socket) do
    case PersonalBackups.delete_account(socket.assigns.backup_account) do
      {:ok, _account} ->
        {:noreply,
         socket
         |> put_flash(:info, "External backup account deleted.")
         |> push_navigate(to: ~p"/admin/personal-backups")}

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, "Could not delete account: #{inspect(reason)}")}
    end
  end

  def handle_event("rotate_backup_credential", %{"credential" => params}, socket) do
    account = socket.assigns.backup_account
    mode = params["mode"] || "none"
    secret = params["secret"]

    case PersonalBackups.rotate_credential(account, mode, secret) do
      {:ok, %{account: account}} ->
        {:noreply,
         socket
         |> put_flash(:info, "Credential state updated.")
         |> assign_backup_detail(account)}

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, "Could not update credential: #{inspect(reason)}")}
    end
  end

  def handle_event("update_backup_retention", %{"retention" => params}, socket) do
    account = socket.assigns.backup_account

    case PersonalBackups.update_retention_setting(account, params) do
      {:ok, _setting} ->
        {:noreply,
         socket
         |> put_flash(:info, "Retention policy updated.")
         |> assign_backup_detail(account)}

      {:error, changeset} ->
        {:noreply,
         socket
         |> put_flash(:error, "Could not update retention policy.")
         |> assign(:retention_form, to_form(changeset, as: :retention))}
    end
  end

  def handle_event("update_backup_schedule", %{"schedule" => params}, socket) do
    account = socket.assigns.backup_account

    case PersonalBackups.update_backup_schedule(account, params) do
      {:ok, account} ->
        {:noreply,
         socket
         |> put_flash(:info, "Backup schedule updated.")
         |> assign_backup_detail(account)}

      {:error, changeset} ->
        {:noreply,
         socket
         |> put_flash(:error, "Could not update schedule.")
         |> assign(:schedule_form, to_form(changeset, as: :schedule))}
    end
  end

  def handle_event("backup_now", _params, socket) do
    account = socket.assigns.backup_account

    case PersonalBackups.run_manual_backup(account) do
      {:ok, %{account: account}} ->
        {:noreply,
         socket
         |> put_flash(:info, "Backup completed.")
         |> assign_backup_detail(account)}

      {:error, :backup_already_running} ->
        {:noreply, put_flash(socket, :error, "A backup is already running for this account.")}

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, "Backup failed: #{inspect(reason)}")}
    end
  end

  def handle_event("verify_snapshot", %{"snapshot" => %{"snapshot_id" => snapshot_id}}, socket) do
    with {:ok, snapshot} <- snapshot_from_id(snapshot_id),
         {:ok, _result} <- PersonalBackups.verify_snapshot_offline(snapshot) do
      {:noreply, put_flash(socket, :info, "Snapshot verified offline.")}
    else
      {:error, :missing_snapshot} ->
        {:noreply, put_flash(socket, :error, "Choose a snapshot first.")}

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, "Snapshot verification failed: #{inspect(reason)}")}
    end
  end

  def handle_event("prune_backup_snapshots", _params, socket) do
    account = socket.assigns.backup_account

    case PersonalBackups.prune_snapshots(account) do
      {:ok, pruned} ->
        {:noreply,
         socket
         |> put_flash(:info, "Pruned #{length(pruned)} snapshots.")
         |> assign_backup_detail(account)}

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, "Prune failed: #{inspect(reason)}")}
    end
  end

  def handle_event("export_snapshot", %{"snapshot" => %{"snapshot_id" => snapshot_id, "path" => path}}, socket) do
    opts = if blank?(path), do: [], else: [path: path]

    with {:ok, snapshot} <- snapshot_from_id(snapshot_id),
         {:ok, result} <- PersonalBackups.export_snapshot_bundle(snapshot, opts) do
      {:noreply, put_flash(socket, :info, "Exported bundle to #{result.path}.")}
    else
      {:error, :missing_snapshot} ->
        {:noreply, put_flash(socket, :error, "Choose a snapshot first.")}

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, "Export failed: #{inspect(reason)}")}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      {render_admin_page(assigns)}
    </Layouts.app>
    """
  end

  defp assign_action_data(%{assigns: %{live_action: :dashboard}} = socket, _params) do
    socket
    |> assign(:status, Admin.status())
    |> assign(:compatibility, Admin.compatibility_status())
    |> assign(:page_title, "Admin Dashboard")
  end

  defp assign_action_data(%{assigns: %{live_action: :accounts}} = socket, _params) do
    socket
    |> assign(:status, Admin.status())
    |> assign(:page_title, "Admin Accounts")
  end

  defp assign_action_data(%{assigns: %{live_action: :account_detail}} = socket, %{"did" => did}) do
    status = Admin.status()

    socket
    |> assign(:status, status)
    |> assign(:account_detail, Enum.find(status["accounts"], &(&1["did"] == did)))
    |> assign(:page_title, "Admin Account")
  end

  defp assign_action_data(%{assigns: %{live_action: :invites}} = socket, _params) do
    socket
    |> assign(:status, Admin.status())
    |> assign(:page_title, "Admin Invites")
  end

  defp assign_action_data(%{assigns: %{live_action: :repo}} = socket, _params) do
    socket
    |> assign(:result, nil)
    |> assign(:page_title, "Admin Repo")
  end

  defp assign_action_data(%{assigns: %{live_action: :backups}} = socket, _params) do
    socket
    |> assign(:result, nil)
    |> assign(:page_title, "Admin Backups")
  end

  defp assign_action_data(%{assigns: %{live_action: :storage}} = socket, _params) do
    socket
    |> assign(:status, Admin.status())
    |> assign(:page_title, "Admin Storage")
  end

  defp assign_action_data(%{assigns: %{live_action: :compatibility}} = socket, _params) do
    socket
    |> assign(:status, Admin.compatibility_status())
    |> assign(:page_title, "Admin Compatibility")
  end

  defp assign_action_data(%{assigns: %{live_action: :backup_accounts}} = socket, _params) do
    socket
    |> assign(:backup_accounts, PersonalBackups.list_accounts())
    |> assign(:page_title, "External Account Backups")
  end

  defp assign_action_data(%{assigns: %{live_action: :backup_new}} = socket, _params) do
    socket
    |> assign_new_backup_forms()
    |> assign(:page_title, "Register External Backup")
  end

  defp assign_action_data(%{assigns: %{live_action: action}} = socket, %{"id" => id})
       when action in [
              :backup_detail,
              :backup_edit,
              :backup_delete,
              :backup_now,
              :backup_verify,
              :backup_prune,
              :backup_export
            ] do
    account = PersonalBackups.get_account_with_backup_state!(id)

    socket
    |> assign_backup_detail(account)
    |> assign(:page_title, "External Backup")
  end

  defp render_admin_page(%{live_action: :dashboard} = assigns) do
    ~H"""
    <main id="admin-dashboard" class="operator-account">
      <div class="operator-account__desktop">
        <.admin_nav active={:dashboard} />

        <section class="win-window win-window--hero" aria-labelledby="admin-title">
          <header class="win-window__titlebar">
            <span id="admin-title" class="win-window__title">Admin Dashboard</span>
          </header>
          <div class="win-window__body operator-account__hero">
            <h1 class="tempest-home__title">Control Panel</h1>
            <p class="tempest-home__subtitle">
              Admin-only view for service, hosted accounts, sequencer, storage, and compatibility state.
            </p>
          </div>
        </section>

        <div class="tempest-home__grid">
          <section class="win-window" aria-labelledby="admin-service-title">
            <header class="win-window__titlebar">
              <span id="admin-service-title" class="win-window__title">Service</span>
            </header>
            <div class="win-window__body">
              <dl id="admin-service-status" class="facts-list">
                <dt>status</dt>
                <dd>{@status["status"]}</dd>
                <dt>version</dt>
                <dd>{@status["version"]}</dd>
                <dt>admin DID</dt>
                <dd>{present(@status["admin"]["did"])}</dd>
                <dt>auth method</dt>
                <dd>{@status["admin"]["authMethod"]}</dd>
                <dt>admin token</dt>
                <dd>{present(@status["admin"]["tokenConfigured"])}</dd>
              </dl>
            </div>
          </section>

          <section class="win-window" aria-labelledby="admin-accounts-summary-title">
            <header class="win-window__titlebar">
              <span id="admin-accounts-summary-title" class="win-window__title">Hosted Accounts</span>
            </header>
            <div class="win-window__body">
              <dl id="admin-account-summary" class="facts-list">
                <dt>accounts</dt>
                <dd>{length(@status["accounts"])}</dd>
                <dt>active</dt>
                <dd>{Enum.count(@status["accounts"], & &1["active"])}</dd>
                <dt>records</dt>
                <dd>{sum_field(@status["accounts"], "recordCount")}</dd>
                <dt>public blobs</dt>
                <dd>{sum_field(@status["accounts"], "blobCount")}</dd>
              </dl>
            </div>
          </section>

          <section class="win-window" aria-labelledby="admin-seq-title">
            <header class="win-window__titlebar">
              <span id="admin-seq-title" class="win-window__title">Sequencer</span>
            </header>
            <div class="win-window__body">
              <dl id="admin-sequencer-status" class="facts-list">
                <dt>current seq</dt>
                <dd>{@status["sequencer"]["currentSeq"]}</dd>
                <dt>torn writes</dt>
                <dd>{@status["sequencer"]["tornWriteCount"]}</dd>
                <dt>relay crawl</dt>
                <dd>requestCrawl endpoint enabled</dd>
              </dl>
            </div>
          </section>

          <section class="win-window" aria-labelledby="admin-storage-summary-title">
            <header class="win-window__titlebar">
              <span id="admin-storage-summary-title" class="win-window__title">Storage</span>
            </header>
            <div class="win-window__body">
              <dl id="admin-storage-summary" class="facts-list">
                <dt>account DB</dt>
                <dd>{present(@status["database"]["accountDb"]["exists"])}</dd>
                <dt>sequencer DB</dt>
                <dd>{present(@status["database"]["sequencerDb"]["exists"])}</dd>
                <dt>blob adapter</dt>
                <dd>{@status["blobStore"]["adapter"]}</dd>
                <dt>blob count</dt>
                <dd>{@status["blobStore"]["publicBlobCount"]}</dd>
              </dl>
            </div>
          </section>

          <section class="win-window" aria-labelledby="admin-compat-summary-title">
            <header class="win-window__titlebar">
              <span id="admin-compat-summary-title" class="win-window__title">Compatibility Warnings</span>
            </header>
            <div class="win-window__body">
              <dl id="admin-compatibility-summary" class="facts-list">
                <dt>partial</dt>
                <dd>{Map.get(@compatibility.summary, "partial", 0)}</dd>
                <dt>planned</dt>
                <dd>{Map.get(@compatibility.summary, "planned", 0)}</dd>
                <dt>deferred</dt>
                <dd>{Map.get(@compatibility.summary, "deferred", 0)}</dd>
                <dt>implemented</dt>
                <dd>{Map.get(@compatibility.summary, "implemented", 0)}</dd>
              </dl>
            </div>
          </section>
        </div>
      </div>
    </main>
    """
  end

  defp render_admin_page(%{live_action: :accounts} = assigns) do
    ~H"""
    <main id="admin-accounts" class="operator-account">
      <div class="operator-account__desktop">
        <.admin_nav active={:accounts} />

        <section class="win-window" aria-labelledby="admin-accounts-title">
          <header class="win-window__titlebar">
            <span id="admin-accounts-title" class="win-window__title">Hosted Accounts</span>
          </header>
          <div class="win-window__body operator-account__table-wrap">
            <table id="admin-account-table" class="operator-account__table">
              <thead>
                <tr>
                  <th>DID</th>
                  <th>Handle</th>
                  <th>Status</th>
                  <th>Records</th>
                  <th>Blobs</th>
                  <th>Missing blobs</th>
                </tr>
              </thead>
              <tbody>
                <tr :for={account <- @status["accounts"]}>
                  <td><.link navigate={~p"/admin/accounts/#{account["did"]}"}>{account["did"]}</.link></td>
                  <td>{account["handle"]}</td>
                  <td>{account["status"]}</td>
                  <td>{account["recordCount"]}</td>
                  <td>{account["blobCount"]}</td>
                  <td>{account["missingBlobCount"]}</td>
                </tr>
                <tr :if={@status["accounts"] == []}>
                  <td colspan="6">No hosted accounts.</td>
                </tr>
              </tbody>
            </table>
          </div>
        </section>
      </div>
    </main>
    """
  end

  defp render_admin_page(%{live_action: :account_detail} = assigns) do
    ~H"""
    <main id="admin-account-detail" class="operator-account">
      <div class="operator-account__desktop">
        <.admin_nav active={:accounts} />

        <section class="win-window" aria-labelledby="admin-account-detail-title">
          <header class="win-window__titlebar">
            <span id="admin-account-detail-title" class="win-window__title">Hosted Account</span>
          </header>
          <div class="win-window__body">
            <dl :if={@account_detail} id="admin-account-facts" class="facts-list">
              <dt>DID</dt>
              <dd>{@account_detail["did"]}</dd>
              <dt>handle</dt>
              <dd>{@account_detail["handle"]}</dd>
              <dt>active</dt>
              <dd>{present(@account_detail["active"])}</dd>
              <dt>status</dt>
              <dd>{@account_detail["status"]}</dd>
              <dt>repo count</dt>
              <dd>{@account_detail["repoCount"]}</dd>
              <dt>records</dt>
              <dd>{@account_detail["recordCount"]}</dd>
              <dt>commits</dt>
              <dd>{@account_detail["commitCount"]}</dd>
              <dt>public blobs</dt>
              <dd>{@account_detail["blobCount"]}</dd>
              <dt>missing blobs</dt>
              <dd>{@account_detail["missingBlobCount"]}</dd>
            </dl>
            <p :if={!@account_detail} id="admin-account-not-found" class="operator-account__note">
              Account not found.
            </p>
          </div>
        </section>
      </div>
    </main>
    """
  end

  defp render_admin_page(%{live_action: :invites} = assigns) do
    ~H"""
    <main id="admin-invites" class="operator-account">
      <div class="operator-account__desktop">
        <.admin_nav active={:invites} />

        <section class="win-window" aria-labelledby="invite-title">
          <header class="win-window__titlebar">
            <span id="invite-title" class="win-window__title">Invite Code Management</span>
          </header>
          <div class="win-window__body">
            <dl id="admin-invite-status" class="facts-list">
              <dt>invite requirement</dt>
              <dd>{@status["describeServerInviteRequired"] || "disabled"}</dd>
              <dt>configured account creation</dt>
              <dd>open</dd>
            </dl>
            <p class="operator-account__note">
              Invite-code storage is not enabled in this profile. This view keeps the operator status visible without accepting normal account credentials.
            </p>
          </div>
        </section>
      </div>
    </main>
    """
  end

  defp render_admin_page(%{live_action: :repo} = assigns) do
    ~H"""
    <main id="admin-repo-ops" class="operator-account">
      <div class="operator-account__desktop">
        <.admin_nav active={:repo} />

        <section class="win-window" aria-labelledby="repo-ops-title">
          <header class="win-window__titlebar">
            <span id="repo-ops-title" class="win-window__title">Repo Verify, Export, and Import</span>
          </header>
          <div class="win-window__body">
            <.form for={%{}} id="admin-repo-form" class="operator-account__form" method="post" action={~p"/admin/repo"}>
              <input type="hidden" name="_csrf_token" value={Plug.CSRFProtection.get_csrf_token()} />
              <label>DID <input name="did" /></label>
              <label>Path <input name="path" /></label>
              <button name="op" value="verify" data-confirm="Verify this repository with the current local context?">
                Verify
              </button>
              <button name="op" value="export" data-confirm="Export this repository CAR to the requested path?">
                Export
              </button>
              <button name="op" value="import" data-confirm="Import this repository CAR and update local account storage?">
                Import
              </button>
            </.form>
            <pre :if={@result} class="operator-account__note">{inspect(@result, pretty: true)}</pre>
          </div>
        </section>
      </div>
    </main>
    """
  end

  defp render_admin_page(%{live_action: :backups} = assigns) do
    ~H"""
    <main id="admin-backups" class="operator-account">
      <div class="operator-account__desktop">
        <.admin_nav active={:backups} />

        <section class="win-window" aria-labelledby="backup-title">
          <header class="win-window__titlebar">
            <span id="backup-title" class="win-window__title">Backup Create and Restore Dry Run</span>
          </header>
          <div class="win-window__body">
            <.form
              for={%{}}
              id="admin-backup-create-form"
              class="operator-account__form"
              method="post"
              action={~p"/admin/backups"}
            >
              <input type="hidden" name="_csrf_token" value={Plug.CSRFProtection.get_csrf_token()} />
              <label>Backup path <input name="path" /></label>
              <button name="op" value="create" data-confirm="Create a service backup now?">Create backup</button>
            </.form>
            <.form
              for={%{}}
              id="admin-backup-restore-form"
              class="operator-account__form"
              method="post"
              action={~p"/admin/backups"}
            >
              <input type="hidden" name="_csrf_token" value={Plug.CSRFProtection.get_csrf_token()} />
              <label>Backup path <input name="path" /></label>
              <label>Target path <input name="target" /></label>
              <button name="op" value="restore_dry_run" data-confirm="Run a restore dry-run against the selected target?">
                Restore dry run
              </button>
            </.form>
            <pre :if={@result} class="operator-account__note">{inspect(@result, pretty: true)}</pre>
          </div>
        </section>
      </div>
    </main>
    """
  end

  defp render_admin_page(%{live_action: :backup_accounts} = assigns) do
    ~H"""
    <main id="admin-personal-backups" class="operator-account">
      <div class="operator-account__desktop">
        <.admin_nav active={:personal_backups} />

        <section class="win-window" aria-labelledby="personal-backups-title">
          <header class="win-window__titlebar">
            <span id="personal-backups-title" class="win-window__title">External Account Backups</span>
            <.link class="win-button win-window__title-action" navigate={~p"/admin/personal-backups/new"}>
              New
            </.link>
          </header>
          <div class="win-window__body operator-account__table-wrap">
            <table id="personal-backup-account-table" class="operator-account__table">
              <thead>
                <tr>
                  <th>Label</th>
                  <th>DID</th>
                  <th>Handle</th>
                  <th>Credential</th>
                  <th>Status</th>
                  <th>Latest success</th>
                  <th>Schedule</th>
                </tr>
              </thead>
              <tbody>
                <tr :for={account <- @backup_accounts}>
                  <td><.link navigate={~p"/admin/personal-backups/#{account.id}"}>{account.label}</.link></td>
                  <td>{account.did}</td>
                  <td>{account.handle}</td>
                  <td>{account.credential_state}</td>
                  <td>{account.status}</td>
                  <td>{format_time(account.last_success_at)}</td>
                  <td>{schedule_state(account)}</td>
                </tr>
                <tr :if={@backup_accounts == []}>
                  <td colspan="7">No external backup accounts.</td>
                </tr>
              </tbody>
            </table>
          </div>
        </section>
      </div>
    </main>
    """
  end

  defp render_admin_page(%{live_action: :backup_new} = assigns) do
    ~H"""
    <main id="admin-personal-backup-new" class="operator-account">
      <div class="operator-account__desktop">
        <.admin_nav active={:personal_backups} />

        <section class="win-window" aria-labelledby="personal-backup-new-title">
          <header class="win-window__titlebar">
            <span id="personal-backup-new-title" class="win-window__title">Register External Backup Account</span>
          </header>
          <div class="win-window__body">
            <.form
              for={@account_form}
              id="personal-backup-create-form"
              class="operator-account__form operator-account__form--grid"
              phx-submit="create_backup_account"
            >
              <.input field={@account_form[:did]} label="DID" />
              <.input field={@account_form[:handle]} label="Handle" />
              <.input field={@account_form[:label]} label="Label" />
              <.input field={@account_form[:pinned_source_pds_url]} label="Pinned source PDS" />
              <button
                class="win-button"
                data-confirm="Register this external backup account after DID and handle verification?"
              >
                Register
              </button>
            </.form>
          </div>
        </section>
      </div>
    </main>
    """
  end

  defp render_admin_page(%{live_action: :backup_edit} = assigns) do
    ~H"""
    <main id="admin-personal-backup-edit" class="operator-account">
      <div class="operator-account__desktop">
        <.admin_nav active={:personal_backups} />

        <section class="win-window" aria-labelledby="personal-backup-edit-title">
          <header class="win-window__titlebar">
            <span id="personal-backup-edit-title" class="win-window__title">Edit External Backup Account</span>
          </header>
          <div class="win-window__body">
            <.form
              for={@account_form}
              id="personal-backup-edit-form"
              class="operator-account__form operator-account__form--grid"
              phx-submit="update_backup_account"
            >
              <.input field={@account_form[:label]} label="Label" />
              <.input field={@account_form[:pinned_source_pds_url]} label="Pinned source PDS" />
              <button class="win-button" data-confirm="Save backup account changes?">Save</button>
            </.form>
          </div>
        </section>
      </div>
    </main>
    """
  end

  defp render_admin_page(%{live_action: :backup_delete} = assigns) do
    ~H"""
    <main id="admin-personal-backup-delete" class="operator-account">
      <div class="operator-account__desktop">
        <.admin_nav active={:personal_backups} />

        <section class="win-window" aria-labelledby="personal-backup-delete-title">
          <header class="win-window__titlebar">
            <span id="personal-backup-delete-title" class="win-window__title">Delete External Backup Account</span>
          </header>
          <div class="win-window__body">
            <dl id="personal-backup-delete-facts" class="facts-list">
              <dt>DID</dt>
              <dd>{@backup_account.did}</dd>
              <dt>handle</dt>
              <dd>{@backup_account.handle}</dd>
              <dt>snapshots</dt>
              <dd>{length(@backup_account.snapshots)}</dd>
            </dl>
            <.form for={%{}} id="personal-backup-delete-form" phx-submit="delete_backup_account">
              <button class="win-button" data-confirm="Delete this external backup account and its local rows?">
                Delete account
              </button>
            </.form>
          </div>
        </section>
      </div>
    </main>
    """
  end

  defp render_admin_page(%{live_action: action} = assigns)
       when action in [:backup_detail, :backup_now, :backup_verify, :backup_prune, :backup_export] do
    ~H"""
    <main id="admin-personal-backup-detail" class="operator-account">
      <div class="operator-account__desktop">
        <.admin_nav active={:personal_backups} />

        <section class="win-window" aria-labelledby="personal-backup-detail-title">
          <header class="win-window__titlebar">
            <span id="personal-backup-detail-title" class="win-window__title">External Backup Account</span>
            <span class="win-window__title-actions">
              <.link class="win-button" navigate={~p"/admin/personal-backups/#{@backup_account.id}/edit"}>Edit</.link>
              <.link class="win-button" navigate={~p"/admin/personal-backups/#{@backup_account.id}/delete"}>Delete</.link>
            </span>
          </header>
          <div class="win-window__body">
            <dl id="personal-backup-account-facts" class="facts-list">
              <dt>label</dt>
              <dd>{@backup_account.label}</dd>
              <dt>DID</dt>
              <dd>{@backup_account.did}</dd>
              <dt>handle</dt>
              <dd>{@backup_account.handle}</dd>
              <dt>source PDS</dt>
              <dd>{@backup_account.source_pds_url}</dd>
              <dt>pinned source</dt>
              <dd>{present(@backup_account.pinned_source_pds_url)}</dd>
              <dt>credential</dt>
              <dd>{@backup_account.credential_state}</dd>
              <dt>latest backup</dt>
              <dd>{latest_snapshot_status(@backup_account)}</dd>
              <dt>schedule</dt>
              <dd>{schedule_state(@backup_account)}</dd>
              <dt>identity warning</dt>
              <dd>{present(@backup_account.status_reason || identity_warning(@backup_account))}</dd>
            </dl>
          </div>
        </section>

        <section class="win-window" aria-labelledby="personal-backup-actions-title">
          <header class="win-window__titlebar">
            <span id="personal-backup-actions-title" class="win-window__title">Operations</span>
          </header>
          <div class="win-window__body personal-backup-actions">
            <.form for={%{}} id="personal-backup-now-form" phx-submit="backup_now">
              <button class="win-button" data-confirm="Run a manual backup for this external account now?">
                Backup now
              </button>
            </.form>

            <.form for={@snapshot_form} id="personal-backup-verify-form" phx-submit="verify_snapshot">
              <.input
                field={@snapshot_form[:snapshot_id]}
                id="personal-backup-verify-snapshot-id"
                type="select"
                label="Snapshot"
                options={snapshot_options(@backup_account)}
              />
              <button class="win-button" data-confirm="Verify this snapshot offline from local files?">Verify</button>
            </.form>

            <.form for={%{}} id="personal-backup-prune-form" phx-submit="prune_backup_snapshots">
              <button class="win-button" data-confirm="Prune snapshots according to this account retention policy?">
                Prune
              </button>
            </.form>

            <.form for={@export_form} id="personal-backup-export-form" phx-submit="export_snapshot">
              <.input
                field={@export_form[:snapshot_id]}
                id="personal-backup-export-snapshot-id"
                type="select"
                label="Snapshot"
                options={snapshot_options(@backup_account)}
              />
              <.input field={@export_form[:path]} label="Output path" />
              <button class="win-button" data-confirm="Export this snapshot as a portable bundle?">Export</button>
            </.form>
          </div>
        </section>

        <div class="tempest-home__grid">
          <section class="win-window" aria-labelledby="personal-backup-credential-title">
            <header class="win-window__titlebar">
              <span id="personal-backup-credential-title" class="win-window__title">Credential State</span>
            </header>
            <div class="win-window__body">
              <dl id="personal-backup-credential-facts" class="facts-list">
                <dt>mode</dt>
                <dd>{@credential_state.mode}</dd>
                <dt>secret</dt>
                <dd>{present(@credential_state.secret_hint)}</dd>
                <dt>verified</dt>
                <dd>{format_time(@credential_state.verified_at)}</dd>
              </dl>
              <.form
                for={@credential_form}
                id="personal-backup-credential-form"
                class="operator-account__form"
                phx-submit="rotate_backup_credential"
              >
                <.input
                  field={@credential_form[:mode]}
                  type="select"
                  label="Mode"
                  options={[{"No auth", "none"}, {"App password", "app_password"}, {"Access token", "access_token"}]}
                />
                <.input field={@credential_form[:secret]} type="password" label="Secret" />
                <button class="win-button" data-confirm="Rotate backup credential state?">Save credential</button>
              </.form>
            </div>
          </section>

          <section class="win-window" aria-labelledby="personal-backup-retention-title">
            <header class="win-window__titlebar">
              <span id="personal-backup-retention-title" class="win-window__title">Retention and Schedule</span>
            </header>
            <div class="win-window__body">
              <.form
                for={@retention_form}
                id="personal-backup-retention-form"
                class="operator-account__form"
                phx-submit="update_backup_retention"
              >
                <.input
                  field={@retention_form[:policy]}
                  type="select"
                  label="Policy"
                  options={[{"Keep all", "keep_all"}, {"Keep last N", "keep_last_n"}, {"Keep for days", "keep_for_days"}]}
                />
                <.input field={@retention_form[:keep_last]} type="number" label="Keep last" />
                <.input field={@retention_form[:keep_days]} type="number" label="Keep days" />
                <button class="win-button" data-confirm="Update retention policy?">Save retention</button>
              </.form>

              <.form
                for={@schedule_form}
                id="personal-backup-schedule-form"
                class="operator-account__form"
                phx-submit="update_backup_schedule"
              >
                <.input field={@schedule_form[:scheduled_backup_enabled]} type="checkbox" label="Scheduled backups" />
                <.input field={@schedule_form[:scheduled_backup_interval_hours]} type="number" label="Every hours" />
                <button class="win-button" data-confirm="Update scheduled backup state?">Save schedule</button>
              </.form>
            </div>
          </section>
        </div>

        <section class="win-window" aria-labelledby="personal-backup-snapshots-title">
          <header class="win-window__titlebar">
            <span id="personal-backup-snapshots-title" class="win-window__title">Snapshot History</span>
          </header>
          <div class="win-window__body operator-account__table-wrap">
            <table id="personal-backup-snapshot-table" class="operator-account__table">
              <thead>
                <tr>
                  <th>ID</th>
                  <th>Status</th>
                  <th>Verification</th>
                  <th>Rev</th>
                  <th>Bytes</th>
                  <th>Missing blobs</th>
                  <th>Completed</th>
                </tr>
              </thead>
              <tbody>
                <tr :for={snapshot <- @backup_account.snapshots}>
                  <td>{snapshot.id}</td>
                  <td>{snapshot.status}</td>
                  <td>{snapshot.verification_status}</td>
                  <td>{present(snapshot.rev)}</td>
                  <td>{snapshot.byte_size}</td>
                  <td>{missing_blob_count(snapshot)}</td>
                  <td>{format_time(snapshot.completed_at)}</td>
                </tr>
                <tr :if={@backup_account.snapshots == []}>
                  <td colspan="7">No snapshots yet.</td>
                </tr>
              </tbody>
            </table>
          </div>
        </section>

        <section class="win-window" aria-labelledby="personal-backup-storage-title">
          <header class="win-window__titlebar">
            <span id="personal-backup-storage-title" class="win-window__title">Storage Totals and Missing Blobs</span>
          </header>
          <div class="win-window__body">
            <dl id="personal-backup-storage-facts" class="facts-list">
              <dt>snapshots</dt>
              <dd>{length(@backup_account.snapshots)}</dd>
              <dt>repo bytes</dt>
              <dd>{sum_snapshots(@backup_account.snapshots, :byte_size)}</dd>
              <dt>stored blobs</dt>
              <dd>{stored_blob_count(@backup_account.snapshots)}</dd>
              <dt>missing blobs</dt>
              <dd>{total_missing_blob_count(@backup_account.snapshots)}</dd>
              <dt>next scheduled</dt>
              <dd>{format_time(@backup_account.next_scheduled_backup_at)}</dd>
            </dl>

            <div id="personal-backup-missing-blobs" class="operator-account__table-wrap">
              <table class="operator-account__table">
                <thead>
                  <tr>
                    <th>Snapshot</th>
                    <th>CID</th>
                    <th>Status</th>
                    <th>Reason</th>
                  </tr>
                </thead>
                <tbody>
                  <tr :for={{snapshot, blob} <- missing_blobs(@backup_account.snapshots)}>
                    <td>{snapshot.id}</td>
                    <td>{blob.cid}</td>
                    <td>{blob.status}</td>
                    <td>{present(blob.error_reason)}</td>
                  </tr>
                  <tr :if={missing_blobs(@backup_account.snapshots) == []}>
                    <td colspan="4">No missing blobs recorded.</td>
                  </tr>
                </tbody>
              </table>
            </div>
          </div>
        </section>
      </div>
    </main>
    """
  end

  defp render_admin_page(%{live_action: :storage} = assigns) do
    ~H"""
    <main id="admin-storage" class="operator-account">
      <div class="operator-account__desktop">
        <.admin_nav active={:storage} />

        <section class="win-window" aria-labelledby="storage-title">
          <header class="win-window__titlebar">
            <span id="storage-title" class="win-window__title">Storage Status</span>
          </header>
          <div class="win-window__body operator-account__table-wrap">
            <table id="admin-storage-table" class="operator-account__table">
              <thead>
                <tr>
                  <th>Name</th>
                  <th>Path</th>
                  <th>Type</th>
                  <th>Exists</th>
                  <th>Bytes</th>
                </tr>
              </thead>
              <tbody>
                <tr :for={{name, item} <- @status["database"]}>
                  <td>{name}</td>
                  <td>{item["path"]}</td>
                  <td>{item["type"]}</td>
                  <td>{present(item["exists"])}</td>
                  <td>{present(item["bytes"])}</td>
                </tr>
              </tbody>
            </table>
          </div>
        </section>

        <section class="win-window" aria-labelledby="blob-storage-title">
          <header class="win-window__titlebar">
            <span id="blob-storage-title" class="win-window__title">Blobs and Backups</span>
          </header>
          <div class="win-window__body">
            <dl id="admin-blob-storage" class="facts-list">
              <dt>blob adapter</dt>
              <dd>{@status["blobStore"]["adapter"]}</dd>
              <dt>blob path</dt>
              <dd>{@status["blobStore"]["path"]}</dd>
              <dt>public blobs</dt>
              <dd>{@status["blobStore"]["publicBlobCount"]}</dd>
              <dt>backup store</dt>
              <dd>{backup_store()}</dd>
            </dl>
          </div>
        </section>
      </div>
    </main>
    """
  end

  defp render_admin_page(%{live_action: :compatibility} = assigns) do
    ~H"""
    <main id="admin-compatibility" class="operator-account">
      <div class="operator-account__desktop">
        <.admin_nav active={:compatibility} />

        <section class="win-window" aria-labelledby="compat-title">
          <header class="win-window__titlebar">
            <span id="compat-title" class="win-window__title">Compatibility Status</span>
          </header>
          <div class="win-window__body">
            <dl id="admin-compatibility-counts" class="facts-list">
              <dt>implemented</dt>
              <dd>{Map.get(@status.summary, "implemented", 0)}</dd>
              <dt>partial</dt>
              <dd>{Map.get(@status.summary, "partial", 0)}</dd>
              <dt>planned</dt>
              <dd>{Map.get(@status.summary, "planned", 0)}</dd>
              <dt>deferred</dt>
              <dd>{Map.get(@status.summary, "deferred", 0)}</dd>
            </dl>
          </div>
        </section>

        <section class="win-window" aria-labelledby="compat-matrix-title">
          <header class="win-window__titlebar">
            <span id="compat-matrix-title" class="win-window__title">Reference Endpoint Matrix</span>
          </header>
          <div class="win-window__body operator-account__table-wrap">
            <table id="admin-compatibility-matrix" class="operator-account__table">
              <thead>
                <tr>
                  <th>Method</th>
                  <th>Status</th>
                  <th>Route</th>
                </tr>
              </thead>
              <tbody>
                <tr :for={endpoint <- @status.endpoints}>
                  <td>{endpoint.method}</td>
                  <td>{endpoint.status}</td>
                  <td>{endpoint.route}</td>
                </tr>
              </tbody>
            </table>
          </div>
        </section>
      </div>
    </main>
    """
  end

  defp admin_nav(assigns) do
    ~H"""
    <nav class="resource-strip operator-account__nav" aria-label="Admin tools">
      <.link navigate={~p"/admin"} aria-current={if(@active == :dashboard, do: "page", else: false)}>Dashboard</.link>
      <.link navigate={~p"/admin/accounts"} aria-current={if(@active == :accounts, do: "page", else: false)}>
        Accounts
      </.link>
      <.link navigate={~p"/admin/invites"} aria-current={if(@active == :invites, do: "page", else: false)}>Invites</.link>
      <.link navigate={~p"/admin/repo"} aria-current={if(@active == :repo, do: "page", else: false)}>Repo Ops</.link>
      <.link navigate={~p"/admin/backups"} aria-current={if(@active == :backups, do: "page", else: false)}>Backups</.link>
      <.link
        navigate={~p"/admin/personal-backups"}
        aria-current={if(@active == :personal_backups, do: "page", else: false)}
      >
        External Backups
      </.link>
      <.link navigate={~p"/admin/storage"} aria-current={if(@active == :storage, do: "page", else: false)}>Storage</.link>
      <.link navigate={~p"/admin/compatibility"} aria-current={if(@active == :compatibility, do: "page", else: false)}>
        Compatibility
      </.link>
      <.link id="admin-control-home" class="operator-account__home-link" navigate={~p"/"}>Home</.link>
    </nav>
    """
  end

  defp present(nil), do: "—"
  defp present(""), do: "—"
  defp present(value) when is_boolean(value), do: inspect(value)
  defp present(value) when is_atom(value), do: Atom.to_string(value)
  defp present(value), do: to_string(value)

  defp sum_field(items, key), do: Enum.reduce(items, 0, &(&2 + (&1[key] || 0)))

  defp assign_new_backup_forms(socket, params \\ %{}) do
    params =
      Map.merge(
        %{
          "did" => "",
          "handle" => "",
          "label" => "",
          "pinned_source_pds_url" => ""
        },
        params
      )

    assign(socket, :account_form, to_form(params, as: :backup_account))
  end

  defp assign_backup_detail(socket, %Account{} = account) do
    account = PersonalBackups.preload_backup_state(account)

    latest_snapshot_id =
      account.snapshots
      |> List.first()
      |> case do
        nil -> nil
        snapshot -> snapshot.id
      end

    socket
    |> assign(:backup_account, account)
    |> assign(:credential_state, PersonalBackups.credential_public_state(account))
    |> assign(:account_form, account_form(account))
    |> assign(:credential_form, to_form(%{"mode" => account.credential_state, "secret" => ""}, as: :credential))
    |> assign(:retention_form, retention_form(account))
    |> assign(:schedule_form, schedule_form(account))
    |> assign(:snapshot_form, to_form(%{"snapshot_id" => latest_snapshot_id}, as: :snapshot))
    |> assign(:export_form, to_form(%{"snapshot_id" => latest_snapshot_id, "path" => ""}, as: :snapshot))
  end

  defp account_form(%Account{} = account) do
    to_form(
      %{
        "label" => account.label,
        "pinned_source_pds_url" => account.pinned_source_pds_url || ""
      },
      as: :backup_account
    )
  end

  defp retention_form(%Account{retention_setting: setting}) do
    to_form(
      %{
        "policy" => setting.policy,
        "keep_last" => setting.keep_last,
        "keep_days" => setting.keep_days
      },
      as: :retention
    )
  end

  defp schedule_form(%Account{} = account) do
    to_form(
      %{
        "scheduled_backup_enabled" => account.scheduled_backup_enabled,
        "scheduled_backup_interval_hours" => account.scheduled_backup_interval_hours || 24
      },
      as: :schedule
    )
  end

  defp snapshot_options(%Account{snapshots: []}), do: [{"No snapshots", ""}]

  defp snapshot_options(%Account{snapshots: snapshots}) do
    Enum.map(snapshots, fn snapshot ->
      label = "##{snapshot.id} #{snapshot.status} #{format_time(snapshot.completed_at)}"
      {label, snapshot.id}
    end)
  end

  defp snapshot_from_id(snapshot_id) when snapshot_id in [nil, ""], do: {:error, :missing_snapshot}

  defp snapshot_from_id(snapshot_id) do
    {:ok, PersonalBackups.get_snapshot!(String.to_integer(to_string(snapshot_id)))}
  rescue
    _error -> {:error, :missing_snapshot}
  end

  defp latest_snapshot_status(%Account{snapshots: [snapshot | _]}) do
    "#{snapshot.status} / #{snapshot.verification_status}"
  end

  defp latest_snapshot_status(%Account{}), do: "none"

  defp schedule_state(%Account{scheduled_backup_enabled: true, scheduled_backup_interval_hours: hours}) do
    "every #{hours || 24}h"
  end

  defp schedule_state(%Account{}), do: "off"

  defp identity_warning(%Account{pinned_source_pds_url: pinned, source_pds_url: source})
       when is_binary(pinned) and pinned != source do
    "pinned source does not match resolved source"
  end

  defp identity_warning(%Account{status: status}) when status in ["warning", "failed"], do: status
  defp identity_warning(%Account{}), do: nil

  defp format_time(nil), do: "—"
  defp format_time(%DateTime{} = time), do: DateTime.to_iso8601(time)

  defp sum_snapshots(snapshots, field), do: Enum.reduce(snapshots, 0, &(&2 + (Map.get(&1, field) || 0)))

  defp stored_blob_count(snapshots) do
    snapshots
    |> Enum.flat_map(& &1.blobs)
    |> Enum.count(&(&1.status == "stored"))
  end

  defp missing_blob_count(snapshot), do: Enum.count(snapshot.blobs, &(&1.status in ["missing", "failed"]))

  defp total_missing_blob_count(snapshots) do
    snapshots
    |> Enum.map(&missing_blob_count/1)
    |> Enum.sum()
  end

  defp missing_blobs(snapshots) do
    Enum.flat_map(snapshots, fn snapshot ->
      snapshot.blobs
      |> Enum.filter(&(&1.status in ["missing", "failed"]))
      |> Enum.map(&{snapshot, &1})
    end)
  end

  defp blank?(value), do: is_nil(value) or String.trim(to_string(value)) == ""

  defp backup_store do
    :tempest
    |> Application.get_env(Tempest.Admin.Backup, [])
    |> Keyword.get(:store, :local)
    |> present()
  end
end
