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
          <nav class="desktop-icons" aria-label="Desktop shortcuts">
            <a class="desktop-icon" href="https://github.com/desertthunder/tempest" target="_blank">
              <img src={~p"/images/icons/github.svg"} alt="" width="40" height="40" />
              <span>GitHub</span>
            </a>
            <a class="desktop-icon" href={~p"/stats"}>
              <img src={~p"/images/icons/db.svg"} alt="" width="40" height="40" />
              <span>Stats</span>
            </a>
            <a class="desktop-icon" href={~p"/docs"}>
              <img src={~p"/images/icons/browser.svg"} alt="" width="40" height="40" />
              <span>Docs</span>
            </a>
            <a class="desktop-icon" href="#about-computer">
              <img src={~p"/images/icons/computer.svg"} alt="" width="40" height="40" />
              <span>My Computer</span>
            </a>
          </nav>

          <div class="tempest-home__windows">
            <div class="tempest-home__top-grid">
              <section :if={@live_action == :home} class="win-window win-window--hero" aria-labelledby="tempest-title">
                <header class="win-window__titlebar">
                  <span class="win-window__title">LIVE_STATS.EXE</span>
                  <span class="win-window__controls" aria-hidden="true">
                    <span></span><span></span><span></span>
                  </span>
                </header>

                <div class="win-window__body tempest-home__hero">
                  <div class="tempest-home__intro">
                    <p class="tempest-home__brand" aria-hidden="true">Tempest PDS</p>
                    <h1 id="tempest-title" class="tempest-home__title">Personal Data Server</h1>
                    <p class="tempest-home__subtitle">Live node snapshot for <strong>{@host}</strong></p>
                    <p class="stats-dashboard__muted">Refreshed {@rendered_at} · every 15s while connected</p>
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
              </section>

              <section class="win-window" aria-labelledby="center-cards-title">
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

        <section id="about-computer" class="modal" role="dialog" aria-modal="true" aria-labelledby="about-computer-title">
          <a href="#" class="modal__backdrop" aria-label="Close About this Computer"></a>
          <div class="win-window modal__window">
            <header class="win-window__titlebar">
              <span id="about-computer-title" class="win-window__title">About this Computer</span>
              <a href="#" class="win-window__close" aria-label="Close">×</a>
            </header>
            <div class="win-window__body about-computer">
              <img src={~p"/images/icons/computer.svg"} alt="" width="56" height="56" />
              <div>
                <h2>Tempest PDS</h2>
                <p>A Personal Data Server on the BEAM.</p>
                <dl class="facts-list about-computer__facts">
                  <dt>version</dt>
                  <dd>v{@app_version}</dd>
                  <dt>host</dt>
                  <dd>{@host}</dd>
                  <dt>rendered</dt>
                  <dd>{@rendered_at}</dd>
                  <dt>source</dt>
                  <dd><a href="https://github.com/desertthunder/tempest">github.com/desertthunder/tempest</a></dd>
                </dl>
              </div>
            </div>
          </div>
        </section>

        <footer class="taskbar">
          <.link class="taskbar__start" navigate={~p"/"}>
            <img src={~p"/images/icons/at.svg"} alt="" width="18" height="18" /> Start
          </.link>
          <span class="taskbar__app">tempest pds / {@host}</span>
          <span class="taskbar__tray" aria-label="Current UTC time">{@rendered_at}</span>
        </footer>
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
        note: "Live account totals come from the public stats pipeline, not placeholder copy.",
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

  defp rendered_at do
    DateTime.utc_now()
    |> Calendar.strftime("%Y-%m-%d %H:%M:%SZ")
  end

  defp schedule_refresh do
    Process.send_after(self(), :refresh_dashboard, @refresh_interval)
  end
end
