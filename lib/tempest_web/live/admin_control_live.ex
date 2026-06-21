defmodule TempestWeb.AdminControlLive do
  use TempestWeb, :live_view

  alias Tempest.Admin

  @impl true
  def mount(_params, _session, socket), do: {:ok, assign(socket, :page_title, "Admin Control Panel")}

  @impl true
  def handle_params(params, _uri, socket) do
    {:noreply, assign_action_data(socket, params)}
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
      <.link navigate={~p"/admin/storage"} aria-current={if(@active == :storage, do: "page", else: false)}>Storage</.link>
      <.link navigate={~p"/admin/compatibility"} aria-current={if(@active == :compatibility, do: "page", else: false)}>
        Compatibility
      </.link>
    </nav>
    """
  end

  defp present(nil), do: "—"
  defp present(value) when is_boolean(value), do: inspect(value)
  defp present(value), do: to_string(value)

  defp sum_field(items, key), do: Enum.reduce(items, 0, &(&2 + (&1[key] || 0)))

  defp backup_store do
    :tempest
    |> Application.get_env(Tempest.Admin.Backup, [])
    |> Keyword.get(:store, :local)
    |> present()
  end
end
