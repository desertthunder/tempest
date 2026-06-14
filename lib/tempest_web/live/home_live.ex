defmodule TempestWeb.HomeLive do
  use TempestWeb, :live_view

  alias Tempest.{Config, PublicStats}
  alias Tempest.Xrpc.Registry

  @refresh_interval :timer.seconds(15)

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket), do: schedule_refresh()

    {:ok, assign_dashboard(socket)}
  end

  @impl true
  def handle_params(_params, _uri, socket) do
    page_title =
      case socket.assigns.live_action do
        :stats -> "Tempest Public Stats"
        _ -> "Tempest PDS"
      end

    {:noreply, assign(socket, :page_title, page_title)}
  end

  @impl true
  def handle_info(:refresh_dashboard, socket) do
    schedule_refresh()
    {:noreply, assign_dashboard(socket)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <main id="tempest-home" class="tempest-home">
      <div class="tempest-home__desktop" aria-label="Tempest desktop">
        <div class="tempest-home__workarea">
          <.desktop_shortcuts />

          <div class="tempest-home__windows">
            <div class="tempest-home__top-grid">
              <section :if={@live_action == :home} class="win-window win-window--hero" aria-labelledby="tempest-title">
                <header class="win-window__titlebar">
                  <span class="win-window__title">WELCOME.EXE</span>
                  <span class="win-window__controls" aria-hidden="true">
                    <span></span><span></span><span></span>
                  </span>
                </header>

                <div class="win-window__body tempest-home__hero">
                  <div class="tempest-home__hero-main">
                    <div class="tempest-home__intro">
                      <p class="tempest-home__brand" aria-hidden="true">Tempest PDS</p>
                      <h1 id="tempest-title" class="tempest-home__title">Personal Data Server</h1>
                      <p class="tempest-home__subtitle">Live node snapshot for <strong>{@host}</strong></p>
                      <p class="stats-dashboard__muted">Refreshed {@rendered_at}</p>
                    </div>

                    <aside id="server-facts" class="tempest-home__server-card" aria-label="Server configuration">
                      <dl class="facts-list facts-list--compact">
                        <dt>status</dt>
                        <dd>{@health_status}</dd>
                        <dt>host</dt>
                        <dd>{@host}</dd>
                        <dt>version</dt>
                        <dd>v{@app_version}</dd>
                        <dt>uptime</dt>
                        <dd>{@summary["uptimeSeconds"]}s</dd>
                        <dt>surface</dt>
                        <dd>{@public_endpoint_count} public / {@endpoint_count} total</dd>
                        <dt>updated</dt>
                        <dd>{@summary["generatedAt"]}</dd>
                      </dl>
                    </aside>
                  </div>

                  <div id="home-status-cards" class="status-grid tempest-home__status-grid" aria-label="Node metrics">
                    <article :for={card <- @center_cards} id={card.id} class="status-card">
                      <h2 class="status-card__label">{card.label}</h2>
                      <p class="status-card__state">
                        <span class={["status-light", card.light_class]}></span>
                        {card.state}
                      </p>
                      <p class="status-card__value">{card.value}</p>
                      <p>{card.note}</p>
                    </article>
                  </div>
                </div>
              </section>

              <section :if={@live_action == :stats} class="win-window" aria-labelledby="center-cards-title">
                <header class="win-window__titlebar">
                  <span id="center-cards-title" class="win-window__title">{@center_title}</span>
                </header>
                <div class="win-window__body">
                  <div class="status-grid">
                    <article :for={card <- @center_cards} id={card.id} class="status-card">
                      <h2 class="status-card__label">{card.label}</h2>
                      <p class="status-card__state">
                        <span class={["status-light", card.light_class]}></span>
                        {card.state}
                      </p>
                      <p class="status-card__value">{card.value}</p>
                      <p>{card.note}</p>
                    </article>
                  </div>
                </div>
              </section>
            </div>

            <div :if={@live_action == :stats} class="tempest-home__grid">
              <section class="win-window" aria-labelledby="users-title">
                <header class="win-window__titlebar">
                  <span id="users-title" class="win-window__title">Users</span>
                </header>
                <div class="win-window__body public-users" id="public-users">
                  <div :if={@users == []} class="stats-dashboard__empty">No active hosted users yet.</div>
                  <article :for={user <- @users} id={"public-user-#{user["did"]}"} class="public-user-card">
                    <div class={[
                      "public-user-card__banner",
                      is_nil(user["bannerUrl"]) && "public-user-card__banner--fallback"
                    ]}>
                      <img :if={user["bannerUrl"]} src={user["bannerUrl"]} alt="" loading="lazy" />
                    </div>
                    <div class="public-user-card__body">
                      <div
                        class={[
                          "public-user-card__avatar",
                          is_nil(user["avatarUrl"]) && "public-user-card__avatar--fallback"
                        ]}
                        aria-hidden="true"
                      >
                        <img :if={user["avatarUrl"]} src={user["avatarUrl"]} alt="" loading="lazy" />
                        <span :if={is_nil(user["avatarUrl"])}>{user_initial(user)}</span>
                      </div>
                      <h2 class="public-user-card__handle">{user["handle"]}</h2>
                      <p class="public-user-card__did">{user["did"]}</p>
                      <dl class="public-user-card__facts">
                        <dt>Status</dt>
                        <dd>{user["status"] || "unknown"}</dd>
                        <dt>Records</dt>
                        <dd>{user["recordCount"] || 0}</dd>
                      </dl>
                    </div>
                  </article>
                </div>
              </section>

              <section class="win-window" aria-labelledby="latest-record-title">
                <header class="win-window__titlebar">
                  <span id="latest-record-title" class="win-window__title">Latest Indexed Record</span>
                </header>
                <div class="win-window__body" id="latest-indexed-record">
                  <div :if={is_nil(@latest_record)} class="stats-dashboard__empty">No current records indexed yet.</div>
                  <dl :if={@latest_record} class="facts-list public-record-facts">
                    <dt>User</dt>
                    <dd>{@latest_record["handle"] || @latest_record["did"]}</dd>
                    <dt>Collection</dt>
                    <dd>{@latest_record["collection"]}</dd>
                    <dt>RKey</dt>
                    <dd>{@latest_record["rkey"]}</dd>
                    <dt>CID</dt>
                    <dd>{@latest_record["cid"]}</dd>
                    <dt>Indexed</dt>
                    <dd>{@latest_record["indexedAt"]}</dd>
                  </dl>
                </div>
              </section>

              <section class="win-window" aria-labelledby="commit-weeks-title">
                <header class="win-window__titlebar">
                  <span id="commit-weeks-title" class="win-window__title">Weekly Commits</span>
                </header>
                <div class="win-window__body" id="commit-weeks">
                  <div class="commit-histogram">
                    <div :for={week <- @commit_weeks} class="commit-histogram__bar">
                      <div
                        class="commit-histogram__fill"
                        style={"height: #{commit_bar_height(week, @max_commit_week_count)}%"}
                      >
                      </div>
                      <p>{week_label(week)}</p>
                      <strong>{week["commitCount"] || 0}</strong>
                    </div>
                  </div>
                </div>
              </section>

              <section class="win-window" aria-labelledby="collections-title">
                <header class="win-window__titlebar">
                  <span id="collections-title" class="win-window__title">Collections</span>
                </header>
                <div class="win-window__body collection-summary" id="collection-summaries">
                  <div :if={@collections == []} class="stats-dashboard__empty">No collection records yet.</div>
                  <div :for={collection <- @collections} class="collection-summary__row">
                    <span class="collection-summary__name">{collection["collection"]}</span>
                    <span class="collection-summary__count">{collection["recordCount"]}</span>
                    <span class="collection-summary__track" aria-hidden="true">
                      <span style={"width: #{collection_bar_width(collection, @max_collection_record_count)}%"}></span>
                    </span>
                  </div>
                </div>
              </section>

              <section class="win-window" aria-labelledby="health-title">
                <header class="win-window__titlebar">
                  <span id="health-title" class="win-window__title">Health Checks</span>
                  <span class={["stats-dashboard__status-chip", "stats-dashboard__status-chip--#{@health_status}"]}>
                    {@health_status}
                  </span>
                </header>
                <div class="win-window__body stats-dashboard__health">
                  <p class="stats-dashboard__subtitle">
                    Public checks cover storage, databases, directories, and scan consistency.
                  </p>
                  <div class="stats-dashboard__checks">
                    <p :for={
                      {label, value} <- [
                        {"Storage writable", @checks["storageWritable"]},
                        {"Account DB", @checks["accountDatabase"]},
                        {"Sequencer DB", @checks["sequencerDatabase"]},
                        {"Repo dir", @checks["repoDirectory"]},
                        {"Blob dir", @checks["blobDirectory"]},
                        {"Sequencer readable", @checks["sequencerReadable"]},
                        {"Torn write count", @checks["tornWriteCount"]},
                        {"Stats scan errors", @checks["statsScanErrorCount"]}
                      ]
                    }>
                      <span class="stats-dashboard__check-label">{label}</span>
                      <span class="stats-dashboard__check-value">{inspect(value)}</span>
                    </p>
                  </div>
                </div>
              </section>
            </div>

            <section class="resource-strip" aria-labelledby="resources-title">
              <h2 id="resources-title" class="resource-strip__title">Internet Shortcuts</h2>
              <nav id="resource-links" class="resource-strip__links" aria-label="AT Protocol resources">
                <a href="https://atproto.com">AT Protocol</a>
                <a href="https://atproto.com/guides/self-hosting">Self-hosting Guide</a>
                <a href="https://github.com/bluesky-social/atproto">ATProto Source</a>
                <a href="https://bsky.app">Bluesky</a>
              </nav>
            </section>
          </div>
        </div>

        <.about_computer_modal app_version={@app_version} host={@host} rendered_at={@rendered_at} />
        <.taskbar app_label="tempest pds" host={@host} rendered_at={@rendered_at} />
      </div>
    </main>

    <Layouts.flash_group flash={@flash} />
    """
  end

  defp assign_dashboard(socket) do
    config = Config.load!()
    summary = PublicStats.summary(config: config)
    health = summary["health"] || %{}
    checks = health["checks"] || %{}
    metrics = summary["metrics"] || %{}
    methods = Registry.all()
    center_cards = build_center_cards(socket.assigns.live_action, metrics, health, methods, summary)

    socket
    |> assign(:host, config.hostname)
    |> assign(:app_version, Application.spec(:tempest, :vsn))
    |> assign(:summary, summary)
    |> assign(:health, health)
    |> assign(:checks, checks)
    |> assign(:metrics, metrics)
    |> assign(:users, summary["users"] || [])
    |> assign(:latest_record, summary["latestRecord"])
    |> assign(:commit_weeks, summary["commitWeeks"] || [])
    |> assign(:collections, summary["collections"] || [])
    |> assign(:max_commit_week_count, max_count(summary["commitWeeks"] || [], "commitCount"))
    |> assign(:max_collection_record_count, max_count(summary["collections"] || [], "recordCount"))
    |> assign(:health_status, health["status"] || "unknown")
    |> assign(:rendered_at, summary["generatedAt"] || rendered_at())
    |> assign(:center_title, center_title(socket.assigns.live_action))
    |> assign(:center_cards, center_cards)
    |> assign(:endpoint_count, length(methods))
    |> assign(:public_endpoint_count, Enum.count(methods, &(&1.auth == :none)))
  end

  defp center_title(:stats), do: "Public Stats"
  defp center_title(_live_action), do: "Live Status"

  defp build_center_cards(:stats, metrics, health, _methods, summary) do
    health_status = health["status"] || "unknown"

    [
      %{
        id: "hosted-account-count",
        label: "Hosted Accounts",
        state: "#{metrics["hostedAccountCount"] || 0}",
        value: "active accounts",
        note: "Accounts currently active and hosted on this node.",
        light_class: "status-light--ok"
      },
      %{
        id: "commit-count",
        label: "Commits",
        state: "#{metrics["commitCount"] || 0}",
        value: "repo commits",
        note: "Repository commit rows accumulated across hosted repos.",
        light_class: "status-light--ready"
      },
      %{
        id: "collection-count",
        label: "Collections",
        state: "#{metrics["collectionCount"] || 0}",
        value: "current collections",
        note: "Collections present in currently hosted repos.",
        light_class: "status-light--ready"
      },
      %{
        id: "record-count",
        label: "Records",
        state: "#{metrics["recordCount"] || 0}",
        value: "visible records",
        note: "Current records counted by the public stats scanner.",
        light_class: "status-light--ready"
      },
      %{
        id: "last-indexed-at",
        label: "Last Indexed",
        state: metrics["lastIndexedAt"] || "n/a",
        value: "local activity",
        note: "Local repo, commit, or sequencer activity observed by this PDS.",
        light_class: "status-light--ready"
      },
      %{
        id: "uptime-seconds",
        label: "Uptime",
        state: "#{summary["uptimeSeconds"] || 0}s",
        value: "since app start",
        note: "Based on monotonic time recorded when the application booted.",
        light_class: "status-light--ok"
      },
      %{
        id: "health-status",
        label: "Health",
        state: health_status,
        value: "#{stats_scan_error_count(health)} scan errors",
        note: "Derived from storage, database, directory, and sequencer checks.",
        light_class: health_light_class(health_status)
      }
    ]
  end

  defp build_center_cards(_live_action, metrics, health, methods, _summary) do
    hosted = metrics["hostedAccountCount"] || 0
    total = metrics["totalAccountCount"] || 0
    record_count = metrics["recordCount"] || 0
    collection_count = metrics["collectionCount"] || 0
    commit_count = metrics["commitCount"] || 0
    health_status = health["status"] || "unknown"
    sync_count = Enum.count(methods, &String.starts_with?(&1.nsid, "com.atproto.sync."))
    repo_count = Enum.count(methods, &String.starts_with?(&1.nsid, "com.atproto.repo."))
    public_methods = Enum.count(methods, &(&1.auth == :none))
    protected_methods = length(methods) - public_methods

    [
      %{
        id: "status-accounts",
        label: "Accounts",
        state: "#{hosted} active",
        value: "#{total} known account rows",
        note: "Live account totals come from the an aggregator pipeline.",
        light_class: "status-light--ok"
      },
      %{
        id: "status-repos",
        label: "Repo Data",
        state: "#{record_count} records",
        value: "#{collection_count} collections · #{commit_count} commits",
        note: "Repository totals are scanned from hosted repos and sequencer activity.",
        light_class: if(record_count > 0, do: "status-light--ready", else: nil)
      },
      %{
        id: "status-surface",
        label: "Protocol Surface",
        state: "#{length(methods)} XRPC methods",
        value: "#{public_methods} public · #{protected_methods} protected",
        note: "#{repo_count} repo methods and #{sync_count} sync methods are registered right now.",
        light_class: "status-light--ready"
      },
      %{
        id: "status-health",
        label: "Node Health",
        state: health_status,
        value: "#{stats_scan_error_count(health)} scan errors",
        note: "Status derives from storage, database, directory, and sequencer checks.",
        light_class: health_light_class(health_status)
      }
    ]
  end

  defp health_light_class("ok"), do: "status-light--ok"
  defp health_light_class("degraded"), do: "status-light--ready"
  defp health_light_class(_status), do: nil

  defp stats_scan_error_count(%{"checks" => %{} = checks}), do: checks["statsScanErrorCount"] || 0
  defp stats_scan_error_count(_health), do: 0

  defp max_count(items, key) do
    items
    |> Enum.map(&(&1[key] || 0))
    |> Enum.max(fn -> 0 end)
  end

  defp commit_bar_height(_week, 0), do: 4
  defp commit_bar_height(%{"commitCount" => count}, max_count), do: max(round(count / max_count * 100), 4)
  defp commit_bar_height(_week, _max_count), do: 4

  defp collection_bar_width(_collection, 0), do: 0

  defp collection_bar_width(%{"recordCount" => count}, max_count) do
    max(round(count / max_count * 100), 4)
  end

  defp collection_bar_width(_collection, _max_count), do: 0

  defp week_label(%{"weekStart" => week_start}) when is_binary(week_start), do: String.slice(week_start, 5, 5)
  defp week_label(_week), do: "n/a"

  defp user_initial(%{"handle" => <<first::binary-size(1), _rest::binary>>}), do: String.upcase(first)
  defp user_initial(_user), do: "?"

  defp rendered_at do
    DateTime.utc_now()
    |> Calendar.strftime("%Y-%m-%d %H:%M:%SZ")
  end

  defp schedule_refresh do
    Process.send_after(self(), :refresh_dashboard, @refresh_interval)
  end
end
