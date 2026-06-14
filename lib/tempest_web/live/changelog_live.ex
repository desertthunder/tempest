defmodule TempestWeb.ChangelogLive do
  use TempestWeb, :live_view

  alias Tempest.{Config, Docs}

  @impl true
  def mount(_params, _session, socket) do
    config = Config.load!()

    case Docs.fetch_desktop_document("changelog") do
      {:ok, document} ->
        {:ok,
         assign(socket,
           document: document,
           host: config.hostname,
           app_version: Application.spec(:tempest, :vsn),
           rendered_at: rendered_at(),
           page_title: document.title
         )}

      {:error, :not_found} ->
        raise Phoenix.Router.NoRouteError,
          conn: %Plug.Conn{method: "GET", path_info: ["changelog"]},
          router: TempestWeb.Router
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <main id="tempest-changelog" class="doc-viewer-page changelog-page">
      <div class="tempest-home__desktop" aria-label="Tempest desktop">
        <div class="tempest-home__workarea">
          <.desktop_shortcuts />

          <div class="tempest-home__windows doc-viewer-page__windows changelog-page__windows">
            <section class="word-processor" aria-labelledby="changelog-title">
              <header class="word-processor__titlebar">
                <div class="word-processor__titlebar-label">
                  <img src={~p"/images/icons/page.svg"} alt="" width="22" height="22" />
                  <span>Tempest Write - CHANGELOG.md</span>
                </div>
                <span class="win-window__controls" aria-hidden="true">
                  <span></span><span></span><span></span>
                </span>
              </header>

              <div class="word-processor__toolbar" role="toolbar" aria-label="Read-only formatting controls">
                <button class="word-processor__tool" type="button" disabled aria-label="Bold">
                  <img src={~p"/images/icons/bold.svg"} alt="" width="18" height="18" />
                  <span class="sr-only">B</span>
                </button>
                <button class="word-processor__tool" type="button" disabled aria-label="Italic">
                  <img src={~p"/images/icons/italic.svg"} alt="" width="18" height="18" />
                  <span class="sr-only"><em>I</em></span>
                </button>
                <button class="word-processor__tool" type="button" disabled aria-label="Underline">
                  <img src={~p"/images/icons/underline.svg"} alt="" width="18" height="18" />
                  <span class="sr-only"><u>U</u></span>
                </button>
                <button class="word-processor__tool" type="button" disabled aria-label="Align left">
                  <img src={~p"/images/icons/align-left.svg"} alt="" width="18" height="18" />
                  <span class="sr-only">Left</span>
                </button>
                <button class="word-processor__tool" type="button" disabled aria-label="Bulleted list">
                  <img src={~p"/images/icons/list.svg"} alt="" width="18" height="18" />
                  <span class="sr-only">List</span>
                </button>
                <button class="word-processor__tool" type="button" disabled aria-label="Highlight">
                  <img src={~p"/images/icons/highlight.svg"} alt="" width="18" height="18" />
                  <span class="sr-only">Mark</span>
                </button>
              </div>

              <div class="word-processor__ruler" aria-hidden="true">
                <span></span><span></span><span></span><span></span><span></span>
              </div>

              <article id="changelog-document" class="word-processor__workspace" aria-labelledby="changelog-title">
                <div class="word-processor__page">
                  <header class="word-processor__document-header">
                    <p>Local document: {@document.path}</p>
                    <h1 id="changelog-title">{@document.title}</h1>
                    <dl>
                      <div>
                        <dt>Mode</dt>
                        <dd>Read only</dd>
                      </div>
                      <div>
                        <dt>Updated</dt>
                        <dd>{@document.updated || "from source"}</dd>
                      </div>
                    </dl>
                  </header>

                  <div class="word-processor__article">
                    {raw(@document.html)}
                  </div>

                  <details id="changelog-source" class="word-processor__source">
                    <summary>Raw Markdown</summary>
                    <pre><code>{@document.markdown}</code></pre>
                  </details>
                </div>
              </article>

              <footer class="word-processor__statusbar">
                <span>CHANGELOG.md</span>
                <span>v{@app_version}</span>
                <span>{@rendered_at}</span>
              </footer>
            </section>
          </div>
        </div>

        <.about_computer_modal app_version={@app_version} host={@host} rendered_at={@rendered_at} />
        <.taskbar app_label="tempest write" host={@host} rendered_at={@rendered_at} />
      </div>
    </main>

    <Layouts.flash_group flash={@flash} />
    """
  end

  defp rendered_at do
    DateTime.utc_now()
    |> Calendar.strftime("%Y-%m-%d %H:%M:%SZ")
  end
end
