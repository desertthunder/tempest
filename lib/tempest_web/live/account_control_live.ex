defmodule TempestWeb.AccountControlLive do
  use TempestWeb, :live_view

  alias Tempest.{Accounts, Blobs, RepoStorage, Security, Sequencer}

  @page_limit 50

  @impl true
  def mount(_params, _session, socket), do: {:ok, assign(socket, :page_title, "Account Control Panel")}

  @impl true
  def handle_params(params, uri, socket) do
    auth = socket.assigns.account_auth

    socket =
      socket
      |> assign(:current_uri, uri)
      |> assign(:account, auth.account)
      |> assign_action_data(params)

    {:noreply, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      {render_account_page(assigns)}
    </Layouts.app>
    """
  end

  defp assign_action_data(%{assigns: %{live_action: :dashboard, account_auth: auth}} = socket, _params) do
    {:ok, status} = Accounts.check_account_status(auth)

    socket
    |> assign(:status, status)
    |> assign(:page_title, "Account Dashboard")
  end

  defp assign_action_data(%{assigns: %{live_action: :repo, account: account}} = socket, params) do
    {:ok, collections} = RepoStorage.list_collections(account.did)
    {:ok, latest} = RepoStorage.latest_commit(account.did)
    {:ok, records} = RepoStorage.list_recent_records(account.did, limit: @page_limit)

    socket
    |> assign(:collections, collections)
    |> assign(:latest, latest)
    |> assign(:records, records)
    |> assign(:selected_collection, Map.get(params, "collection"))
    |> assign(:page_title, "Account Repo")
  end

  defp assign_action_data(%{assigns: %{live_action: :blobs, account: account}} = socket, _params) do
    {:ok, blobs} = Blobs.list_all(account.did, limit: @page_limit)

    socket
    |> assign(:blobs, blobs)
    |> assign(:blob_summary, blob_summary(blobs))
    |> assign(:page_title, "Account Blobs")
  end

  defp assign_action_data(%{assigns: %{live_action: :access, account: account}} = socket, _params) do
    socket
    |> assign(:inventory, Security.account_security_inventory(account))
    |> assign(:page_title, "Account Access")
  end

  defp assign_action_data(%{assigns: %{live_action: :security, account: account}} = socket, _params) do
    socket
    |> assign(:inventory, Security.account_security_inventory(account))
    |> assign(:page_title, "Account Security")
  end

  defp assign_action_data(%{assigns: %{live_action: :migration, account_auth: auth}} = socket, _params) do
    {:ok, status} = Accounts.check_account_status(auth)

    socket
    |> assign(:status, status)
    |> assign(:page_title, "Account Migration")
  end

  defp assign_action_data(%{assigns: %{live_action: :sequencer, account: account}} = socket, params) do
    cursor = parse_cursor!(Map.get(params, "cursor"))

    {:ok, events} =
      Sequencer.list_after(cursor, limit: @page_limit, did: account.did, type: Map.get(params, "type"))

    socket
    |> assign(:events, events)
    |> assign(:cursor, cursor)
    |> assign(:did_filter, account.did)
    |> assign(:type_filter, Map.get(params, "type"))
    |> assign(:page_title, "Account Sequencer")
  end

  defp assign_action_data(%{assigns: %{live_action: :firehose, account: account}} = socket, _params) do
    {:ok, events} = Sequencer.list_after(0, limit: 20, did: account.did)

    socket
    |> assign(:events, events)
    |> assign(:websocket_url, websocket_url())
    |> assign(:page_title, "Account Firehose")
  end

  defp render_account_page(%{live_action: :dashboard} = assigns) do
    ~H"""
    <main id="account-dashboard" class="operator-account">
      <div class="operator-account__desktop">
        <section class="win-window win-window--hero" aria-labelledby="operator-account-title">
          <header class="win-window__titlebar">
            <span id="operator-account-title" class="win-window__title">Account Control Panel</span>
            <span class="win-window__controls" aria-hidden="true"><span></span><span></span><span></span></span>
          </header>
          <div class="win-window__body operator-account__hero">
            <div>
              <p class="tempest-home__brand" aria-hidden="true">Account</p>
              <h1 class="tempest-home__title">Control Panel</h1>
              <p class="tempest-home__subtitle">Authenticated view for <strong>{@account.handle}</strong></p>
            </div>
          </div>
        </section>

        <.account_nav active={:dashboard} />

        <div class="tempest-home__grid">
          <section class="win-window" aria-labelledby="account-identity-title">
            <header class="win-window__titlebar">
              <span id="account-identity-title" class="win-window__title">Identity</span>
            </header>
            <div class="win-window__body">
              <dl id="account-identity" class="facts-list">
                <dt>DID</dt>
                <dd>{@account.did}</dd>
                <dt>handle</dt>
                <dd>{@account.handle}</dd>
                <dt>email</dt>
                <dd>{@account.email}</dd>
                <dt>status</dt>
                <dd>{@account.status}</dd>
                <dt>active</dt>
                <dd>{inspect(@account.active)}</dd>
              </dl>
            </div>
          </section>

          <section class="win-window" aria-labelledby="account-repository-title">
            <header class="win-window__titlebar">
              <span id="account-repository-title" class="win-window__title">Repository</span>
            </header>
            <div class="win-window__body">
              <dl id="account-status" class="facts-list">
                <dt>records</dt>
                <dd>{@status["recordCount"]}</dd>
                <dt>repos</dt>
                <dd>{@status["repoCount"]}</dd>
                <dt>commit</dt>
                <dd>{present(@status["repoCommit"])}</dd>
                <dt>revision</dt>
                <dd>{present(@status["repoRev"])}</dd>
                <dt>repo blocks</dt>
                <dd>{@status["repoBlocks"]}</dd>
              </dl>
            </div>
          </section>

          <section class="win-window" aria-labelledby="account-blob-title">
            <header class="win-window__titlebar">
              <span id="account-blob-title" class="win-window__title">Blobs</span>
            </header>
            <div class="win-window__body">
              <dl id="account-blob-status" class="facts-list">
                <dt>expected</dt>
                <dd>{@status["expectedBlobs"]}</dd>
                <dt>imported</dt>
                <dd>{@status["importedBlobs"]}</dd>
                <dt>public</dt>
                <dd>{@status["blobCount"]}</dd>
                <dt>missing</dt>
                <dd>{@status["missingBlobCount"]}</dd>
                <dt>migration ready</dt>
                <dd>{inspect(@status["migrationReady"])}</dd>
              </dl>
            </div>
          </section>

          <section class="win-window" aria-labelledby="account-security-title">
            <header class="win-window__titlebar">
              <span id="account-security-title" class="win-window__title">Access and Security</span>
            </header>
            <div class="win-window__body">
              <nav id="account-control-shortcuts" class="resource-strip__links" aria-label="Account management shortcuts">
                <.link navigate={~p"/account/access"}>Access</.link>
                <.link navigate={~p"/account/security"}>Security</.link>
                <.link navigate={~p"/account/migration"}>Migration</.link>
                <.link navigate={~p"/account/sequencer"}>Sequencer</.link>
                <.link navigate={~p"/account/firehose"}>Firehose</.link>
              </nav>
            </div>
          </section>
        </div>
      </div>
    </main>
    """
  end

  defp render_account_page(%{live_action: :repo} = assigns) do
    ~H"""
    <main id="repo-browser" class="operator-account">
      <div class="operator-account__desktop">
        <.account_nav active={:repo} />

        <section class="win-window" aria-labelledby="repo-title">
          <header class="win-window__titlebar">
            <span id="repo-title" class="win-window__title">Repo Browser</span>
          </header>
          <div class="win-window__body">
            <dl id="repo-summary" class="facts-list">
              <dt>DID</dt>
              <dd>{@account.did}</dd>
              <dt>commit</dt>
              <dd>{present(@latest.cid)}</dd>
              <dt>revision</dt>
              <dd>{present(@latest.rev)}</dd>
              <dt>CAR</dt>
              <dd>
                <a id="repo-car-download" href={~p"/xrpc/com.atproto.sync.getRepo?did=#{@account.did}"}>
                  download repo CAR
                </a>
              </dd>
            </dl>
          </div>
        </section>

        <section class="win-window" aria-labelledby="collections-title">
          <header class="win-window__titlebar">
            <span id="collections-title" class="win-window__title">Collections</span>
          </header>
          <div class="win-window__body endpoint-list" id="repo-collections">
            <div class="hidden only:block">No collections yet</div>
            <div :for={collection <- @collections} class="endpoint-list__row">
              <span class="endpoint-list__method">NSID</span>
              <span>{collection}</span>
              <span class="badge badge-info badge-sm endpoint-list__badge">current</span>
            </div>
          </div>
        </section>

        <section class="win-window" aria-labelledby="records-title">
          <header class="win-window__titlebar">
            <span id="records-title" class="win-window__title">Recent Records</span>
          </header>
          <div class="win-window__body operator-account__table-wrap">
            <table id="repo-records" class="operator-account__table">
              <thead>
                <tr>
                  <th>Path</th>
                  <th>CID</th>
                  <th>Updated</th>
                  <th>Record</th>
                </tr>
              </thead>
              <tbody>
                <tr :for={record <- @records}>
                  <td>{record.path}</td>
                  <td>{record.cid}</td>
                  <td>{record.updated_at}</td>
                  <td><pre>{json_pretty(record.value)}</pre></td>
                </tr>
                <tr :if={@records == []}>
                  <td colspan="4">No records yet.</td>
                </tr>
              </tbody>
            </table>
          </div>
        </section>
      </div>
    </main>
    """
  end

  defp render_account_page(%{live_action: :blobs} = assigns) do
    ~H"""
    <main id="blob-browser" class="operator-account">
      <div class="operator-account__desktop">
        <.account_nav active={:blobs} />

        <section class="win-window" aria-labelledby="blob-title">
          <header class="win-window__titlebar">
            <span id="blob-title" class="win-window__title">Blob Browser</span>
          </header>
          <div class="win-window__body">
            <dl id="blob-summary" class="facts-list">
              <dt>DID</dt>
              <dd>{@account.did}</dd>
              <dt>public blobs</dt>
              <dd>{@blob_summary.public}</dd>
              <dt>temporary blobs</dt>
              <dd>{@blob_summary.temp}</dd>
              <dt>total listed</dt>
              <dd>{@blob_summary.total}</dd>
            </dl>
          </div>
        </section>

        <section class="win-window" aria-labelledby="blob-inventory-title">
          <header class="win-window__titlebar">
            <span id="blob-inventory-title" class="win-window__title">Blob Inventory</span>
          </header>
          <div class="win-window__body operator-account__table-wrap">
            <table id="account-blobs" class="operator-account__table">
              <thead>
                <tr>
                  <th>CID</th>
                  <th>State</th>
                  <th>MIME</th>
                  <th>Size</th>
                  <th>Updated</th>
                  <th>Expires</th>
                  <th>Download</th>
                  <th>Headers</th>
                </tr>
              </thead>
              <tbody>
                <tr :for={blob <- @blobs}>
                  <td>{blob.cid}</td>
                  <td><span class="operator-account__pill">{blob.state}</span></td>
                  <td>{blob.mime_type}</td>
                  <td>{blob.size}</td>
                  <td>{blob.updated_at}</td>
                  <td>{present(blob.temp_expires_at)}</td>
                  <td>
                    <a
                      :if={blob.state == "public"}
                      href={~p"/xrpc/com.atproto.sync.getBlob?did=#{@account.did}&cid=#{blob.cid}"}
                    >
                      download
                    </a>
                    <span :if={blob.state != "public"}>temp only</span>
                  </td>
                  <td>Content-Type: {blob.mime_type}; Content-Length: {blob.size}; X-Content-Type-Options: nosniff</td>
                </tr>
                <tr :if={@blobs == []}>
                  <td colspan="8">No blobs yet.</td>
                </tr>
              </tbody>
            </table>
          </div>
        </section>
      </div>
    </main>
    """
  end

  defp render_account_page(%{live_action: :access} = assigns) do
    ~H"""
    <main id="account-access" class="operator-account">
      <div class="operator-account__desktop">
        <.account_nav active={:access} />

        <section class="win-window" aria-labelledby="access-title">
          <header class="win-window__titlebar">
            <span id="access-title" class="win-window__title">Sessions and Delegated Access</span>
          </header>
          <div class="win-window__body">
            <p class="operator-account__note">Access inventory for {@account.did}. Secret values are not displayed.</p>
          </div>
        </section>

        <section class="win-window" aria-labelledby="sessions-title">
          <header class="win-window__titlebar">
            <span id="sessions-title" class="win-window__title">Sessions</span>
          </header>
          <div class="win-window__body operator-account__table-wrap">
            <table id="account-sessions" class="operator-account__table">
              <thead>
                <tr>
                  <th>ID</th>
                  <th>Family</th>
                  <th>Status</th>
                  <th>Expires</th>
                  <th>Created</th>
                </tr>
              </thead>
              <tbody>
                <tr :for={session <- @inventory.sessions}>
                  <td>{session.id}</td>
                  <td>{session.family_id}</td>
                  <td>{status_value(session)}</td>
                  <td>{session.expires_at}</td>
                  <td>{session.inserted_at}</td>
                </tr>
                <tr :if={@inventory.sessions == []}>
                  <td colspan="5">No sessions.</td>
                </tr>
              </tbody>
            </table>
          </div>
        </section>

        <div class="tempest-home__grid">
          <section class="win-window" aria-labelledby="oauth-title">
            <header class="win-window__titlebar">
              <span id="oauth-title" class="win-window__title">OAuth Grants</span>
            </header>
            <div class="win-window__body operator-account__table-wrap">
              <table id="account-oauth-grants" class="operator-account__table operator-account__table--compact">
                <thead>
                  <tr>
                    <th>Client</th>
                    <th>Scope</th>
                    <th>Status</th>
                    <th>Expires</th>
                  </tr>
                </thead>
                <tbody>
                  <tr :for={grant <- @inventory.oauth_grants}>
                    <td>{grant.client_id}</td>
                    <td>{grant.scope}</td>
                    <td>{status_value(grant)}</td>
                    <td>{grant.expires_at}</td>
                  </tr>
                  <tr :if={@inventory.oauth_grants == []}>
                    <td colspan="4">No OAuth grants.</td>
                  </tr>
                </tbody>
              </table>
            </div>
          </section>

          <section class="win-window" aria-labelledby="app-password-title">
            <header class="win-window__titlebar">
              <span id="app-password-title" class="win-window__title">App Passwords</span>
            </header>
            <div class="win-window__body operator-account__table-wrap">
              <table id="account-app-passwords" class="operator-account__table operator-account__table--compact">
                <thead>
                  <tr>
                    <th>Name</th>
                    <th>Scope</th>
                    <th>Status</th>
                    <th>Last used</th>
                  </tr>
                </thead>
                <tbody>
                  <tr :for={password <- @inventory.app_passwords}>
                    <td>{password.name}</td>
                    <td>{password.scope}</td>
                    <td>{status_value(password)}</td>
                    <td>{present(password.last_used_at)}</td>
                  </tr>
                  <tr :if={@inventory.app_passwords == []}>
                    <td colspan="4">No app passwords.</td>
                  </tr>
                </tbody>
              </table>
            </div>
          </section>
        </div>

        <section class="win-window" aria-labelledby="delegated-title">
          <header class="win-window__titlebar">
            <span id="delegated-title" class="win-window__title">Delegated Access</span>
          </header>
          <div class="win-window__body operator-account__table-wrap">
            <table id="account-delegated-access" class="operator-account__table">
              <thead>
                <tr>
                  <th>Delegate DID</th>
                  <th>Scope</th>
                  <th>Status</th>
                  <th>Expires</th>
                  <th>Created</th>
                </tr>
              </thead>
              <tbody>
                <tr :for={grant <- @inventory.delegated_access}>
                  <td>{grant.delegate_did}</td>
                  <td>{grant.scope}</td>
                  <td>{status_value(grant)}</td>
                  <td>{present(grant.expires_at)}</td>
                  <td>{grant.inserted_at}</td>
                </tr>
                <tr :if={@inventory.delegated_access == []}>
                  <td colspan="5">No delegated access grants.</td>
                </tr>
              </tbody>
            </table>
          </div>
        </section>
      </div>
    </main>
    """
  end

  defp render_account_page(%{live_action: :security} = assigns) do
    ~H"""
    <main id="account-security" class="operator-account">
      <div class="operator-account__desktop">
        <.account_nav active={:security} />

        <section class="win-window" aria-labelledby="security-title">
          <header class="win-window__titlebar">
            <span id="security-title" class="win-window__title">Email, Password, MFA, and Devices</span>
          </header>
          <div class="win-window__body">
            <dl id="account-security-summary" class="facts-list">
              <dt>DID</dt>
              <dd>{@account.did}</dd>
              <dt>email</dt>
              <dd>{@account.email}</dd>
              <dt>password</dt>
              <dd>stored as a hash</dd>
              <dt>status</dt>
              <dd>{@account.status}</dd>
            </dl>
          </div>
        </section>

        <div class="tempest-home__grid">
          <section class="win-window" aria-labelledby="mfa-title">
            <header class="win-window__titlebar">
              <span id="mfa-title" class="win-window__title">MFA Credentials</span>
            </header>
            <div class="win-window__body operator-account__table-wrap">
              <table id="account-mfa-credentials" class="operator-account__table operator-account__table--compact">
                <thead>
                  <tr>
                    <th>Type</th>
                    <th>Label</th>
                    <th>Status</th>
                    <th>Last used</th>
                  </tr>
                </thead>
                <tbody>
                  <tr :for={credential <- @inventory.mfa_credentials}>
                    <td>{credential.type}</td>
                    <td>{present(credential.label)}</td>
                    <td>{status_value(credential)}</td>
                    <td>{present(credential.last_used_at)}</td>
                  </tr>
                  <tr :if={@inventory.mfa_credentials == []}>
                    <td colspan="4">No MFA credentials.</td>
                  </tr>
                </tbody>
              </table>
            </div>
          </section>

          <section class="win-window" aria-labelledby="backup-codes-title">
            <header class="win-window__titlebar">
              <span id="backup-codes-title" class="win-window__title">Backup Codes</span>
            </header>
            <div class="win-window__body operator-account__table-wrap">
              <table id="account-backup-codes" class="operator-account__table operator-account__table--compact">
                <thead>
                  <tr>
                    <th>ID</th>
                    <th>Status</th>
                    <th>Created</th>
                    <th>Used</th>
                  </tr>
                </thead>
                <tbody>
                  <tr :for={code <- @inventory.backup_codes}>
                    <td>{code.id}</td>
                    <td>{if code.used?, do: "used", else: "available"}</td>
                    <td>{code.inserted_at}</td>
                    <td>{present(code.used_at)}</td>
                  </tr>
                  <tr :if={@inventory.backup_codes == []}>
                    <td colspan="4">No backup codes.</td>
                  </tr>
                </tbody>
              </table>
            </div>
          </section>
        </div>

        <section class="win-window" aria-labelledby="devices-title">
          <header class="win-window__titlebar">
            <span id="devices-title" class="win-window__title">Trusted Devices</span>
          </header>
          <div class="win-window__body">
            <p class="operator-account__note">
              Trusted devices are represented by MFA credentials of type <code>trusted_device</code>.
            </p>
          </div>
        </section>

        <section class="win-window" aria-labelledby="events-title">
          <header class="win-window__titlebar">
            <span id="events-title" class="win-window__title">Security Event Log</span>
          </header>
          <div class="win-window__body operator-account__table-wrap">
            <table id="account-security-events" class="operator-account__table">
              <thead>
                <tr>
                  <th>Event</th>
                  <th>Metadata</th>
                  <th>Created</th>
                </tr>
              </thead>
              <tbody>
                <tr :for={event <- @inventory.security_events}>
                  <td>{event.event_type}</td>
                  <td><pre>{safe_metadata_json(event.metadata_json)}</pre></td>
                  <td>{event.inserted_at}</td>
                </tr>
                <tr :if={@inventory.security_events == []}>
                  <td colspan="3">No security events.</td>
                </tr>
              </tbody>
            </table>
          </div>
        </section>
      </div>
    </main>
    """
  end

  defp render_account_page(%{live_action: :migration} = assigns) do
    ~H"""
    <main id="account-migration" class="operator-account">
      <div class="operator-account__desktop">
        <.account_nav active={:migration} />

        <section class="win-window" aria-labelledby="migration-title">
          <header class="win-window__titlebar">
            <span id="migration-title" class="win-window__title">Account Migration Status</span>
          </header>
          <div class="win-window__body">
            <dl id="account-migration-status" class="facts-list">
              <dt>DID</dt>
              <dd>{@account.did}</dd>
              <dt>active</dt>
              <dd>{inspect(@status["active"])}</dd>
              <dt>status</dt>
              <dd>{@status["status"]}</dd>
              <dt>records</dt>
              <dd>{@status["recordCount"]}</dd>
              <dt>public blobs</dt>
              <dd>{@status["blobCount"]}</dd>
              <dt>missing blobs</dt>
              <dd>{@status["missingBlobCount"]}</dd>
              <dt>migration ready</dt>
              <dd>{inspect(@status["migrationReady"])}</dd>
            </dl>
          </div>
        </section>
      </div>
    </main>
    """
  end

  defp render_account_page(%{live_action: :sequencer} = assigns) do
    ~H"""
    <main id="sequencer-viewer" class="operator-account">
      <div class="operator-account__desktop">
        <.account_nav active={:sequencer} />

        <section class="win-window" aria-labelledby="seq-title">
          <header class="win-window__titlebar">
            <span id="seq-title" class="win-window__title">Sequencer Viewer</span>
          </header>
          <div class="win-window__body">
            <.form
              for={%{}}
              id="account-sequencer-filter"
              method="get"
              action={~p"/account/sequencer"}
              class="operator-account__form"
            >
              <label>Cursor <input name="cursor" value={@cursor} /></label>
              <label>DID <input name="did" value={@did_filter} readonly /></label>
              <label>Type <input name="type" placeholder="#commit" value={@type_filter || ""} /></label>
              <button type="submit">Filter</button>
            </.form>

            <div class="operator-account__table-wrap">
              <table id="repo-seq-events" class="operator-account__table">
                <thead>
                  <tr>
                    <th>Seq</th>
                    <th>DID</th>
                    <th>Type</th>
                    <th>Rev</th>
                    <th>Commit</th>
                    <th>Payload</th>
                  </tr>
                </thead>
                <tbody>
                  <tr :for={event <- @events}>
                    <td>{event.seq}</td>
                    <td>{event.did}</td>
                    <td>{event.event_type}</td>
                    <td>{event.rev}</td>
                    <td>{event.commit_cid}</td>
                    <td><pre>{json_pretty(event.payload)}</pre></td>
                  </tr>
                  <tr :if={@events == []}>
                    <td colspan="6">No sequencer events.</td>
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

  defp render_account_page(%{live_action: :firehose} = assigns) do
    ~H"""
    <main id="firehose-viewer" class="operator-account">
      <div class="operator-account__desktop">
        <.account_nav active={:firehose} />

        <section class="win-window" aria-labelledby="firehose-title">
          <header class="win-window__titlebar">
            <span id="firehose-title" class="win-window__title">Firehose Viewer</span>
          </header>
          <div class="win-window__body">
            <dl id="account-firehose-status" class="facts-list">
              <dt>subscribe</dt>
              <dd id="firehose-url">{@websocket_url}</dd>
              <dt>display</dt>
              <dd id="firehose-status">Recent durable frames decoded for inspection.</dd>
            </dl>
          </div>
        </section>

        <section class="win-window" aria-labelledby="firehose-events-title">
          <header class="win-window__titlebar">
            <span id="firehose-events-title" class="win-window__title">Recent decoded frames</span>
          </header>
          <div class="win-window__body operator-account__table-wrap">
            <table id="firehose-events" class="operator-account__table">
              <thead>
                <tr>
                  <th>Seq</th>
                  <th>Type</th>
                  <th>DID</th>
                  <th>Payload</th>
                </tr>
              </thead>
              <tbody>
                <tr :for={event <- @events}>
                  <td>{event.seq}</td>
                  <td>{event.event_type}</td>
                  <td>{event.did}</td>
                  <td><pre>{json_pretty(event.payload)}</pre></td>
                </tr>
                <tr :if={@events == []}>
                  <td colspan="4">No firehose events.</td>
                </tr>
              </tbody>
            </table>
          </div>
        </section>
      </div>
    </main>
    """
  end

  defp parse_cursor!(nil), do: 0

  defp parse_cursor!(cursor) do
    case Integer.parse(cursor) do
      {value, ""} when value >= 0 -> value
      _other -> 0
    end
  end

  defp websocket_url do
    config = Tempest.Config.load!()
    uri = URI.parse(config.public_url)
    scheme = if uri.scheme == "https", do: "wss", else: "ws"
    scheme <> "://" <> uri.authority <> "/xrpc/com.atproto.sync.subscribeRepos?cursor=0"
  end

  defp account_nav(assigns) do
    ~H"""
    <nav class="resource-strip operator-account__nav" aria-label="Account Control Panel sections">
      <.link navigate={~p"/account"} aria-current={if(@active == :dashboard, do: "page", else: false)}>Dashboard</.link>
      <.link navigate={~p"/account/repo"} aria-current={if(@active == :repo, do: "page", else: false)}>Repo</.link>
      <.link navigate={~p"/account/blobs"} aria-current={if(@active == :blobs, do: "page", else: false)}>Blobs</.link>
      <.link navigate={~p"/account/access"} aria-current={if(@active == :access, do: "page", else: false)}>Access</.link>
      <.link navigate={~p"/account/security"} aria-current={if(@active == :security, do: "page", else: false)}>
        Security
      </.link>
      <.link navigate={~p"/account/migration"} aria-current={if(@active == :migration, do: "page", else: false)}>
        Migration
      </.link>
      <.link navigate={~p"/account/sequencer"} aria-current={if(@active == :sequencer, do: "page", else: false)}>
        Sequencer
      </.link>
      <.link navigate={~p"/account/firehose"} aria-current={if(@active == :firehose, do: "page", else: false)}>
        Firehose
      </.link>
      <.link id="account-control-home" class="operator-account__home-link" navigate={~p"/"}>Home</.link>
    </nav>
    """
  end

  defp blob_summary(blobs) do
    counts = Enum.frequencies_by(blobs, & &1.state)

    %{
      public: Map.get(counts, "public", 0),
      temp: Map.get(counts, "temp", 0),
      total: length(blobs)
    }
  end

  defp json_pretty(value), do: value |> json_safe() |> Jason.encode!(pretty: true)

  defp json_safe(%Tempest.RepoCore.Drisl.Bytes{bytes: bytes}), do: %{"$bytes" => Base.encode64(bytes)}
  defp json_safe(value) when is_map(value), do: Map.new(value, fn {key, value} -> {key, json_safe(value)} end)
  defp json_safe(value) when is_list(value), do: Enum.map(value, &json_safe/1)
  defp json_safe(value), do: value

  defp safe_metadata_json(nil), do: "{}"

  defp safe_metadata_json(value) when is_binary(value) do
    case Jason.decode(value) do
      {:ok, decoded} -> safe_metadata_json(decoded)
      {:error, _reason} -> "{}"
    end
  end

  defp safe_metadata_json(value) do
    value
    |> redact_sensitive_metadata()
    |> Jason.encode!(pretty: true)
  end

  defp redact_sensitive_metadata(value) when is_map(value) do
    Map.new(value, fn {key, value} ->
      string_key = to_string(key)

      if sensitive_metadata_key?(string_key) do
        {key, "[redacted]"}
      else
        {key, redact_sensitive_metadata(value)}
      end
    end)
  end

  defp redact_sensitive_metadata(value) when is_list(value), do: Enum.map(value, &redact_sensitive_metadata/1)
  defp redact_sensitive_metadata(value), do: value

  defp sensitive_metadata_key?(key) do
    String.contains?(String.downcase(key), ["token", "secret", "password", "code", "hash", "ciphertext"])
  end

  defp status_value(nil), do: "active"
  defp status_value(%{revoked_at: revoked}) when not is_nil(revoked), do: "revoked"
  defp status_value(%{rotated_at: rotated}) when not is_nil(rotated), do: "rotated"
  defp status_value(%{disabled_at: disabled}) when not is_nil(disabled), do: "disabled"
  defp status_value(%{confirmed_at: nil}), do: "pending"
  defp status_value(_record), do: "active"

  defp present(nil), do: "—"
  defp present(""), do: "—"
  defp present(value), do: to_string(value)
end
