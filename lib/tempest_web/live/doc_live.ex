defmodule TempestWeb.DocLive do
  use TempestWeb, :live_view

  alias Tempest.{Config, Docs}

  @impl true
  def mount(_params, _session, socket) do
    config = Config.load!()

    {:ok,
     socket
     |> assign(:host, config.hostname)
     |> assign(:app_version, Application.spec(:tempest, :vsn))
     |> assign(:rendered_at, rendered_at())}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    slug = Map.get(params, "slug", "reference")

    case Docs.fetch_document(slug) do
      {:ok, document} ->
        {previous_document, next_document} = Docs.adjacent_documents(document.slug)

        {:noreply,
         assign(socket,
           documents: Docs.list_documents(),
           document: document,
           previous_document: previous_document,
           next_document: next_document,
           current_path: Docs.document_path(document),
           page_title: document.title <> " - Reference Docs"
         )}

      {:error, :not_found} ->
        raise Phoenix.Router.NoRouteError,
          conn: %Plug.Conn{method: "GET", path_info: path_info(slug)},
          router: TempestWeb.Router
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <main id="tempest-docs" class="doc-viewer-page">
      <div class="tempest-home__desktop" aria-label="Tempest desktop">
        <div class="tempest-home__workarea">
          <.desktop_shortcuts />

          <div class="tempest-home__windows doc-viewer-page__windows">
            <section class="doc-browser" aria-labelledby="doc-browser-title">
              <header class="doc-browser__titlebar">
                <div class="doc-browser__titlebar-label">
                  <img src={~p"/images/icons/browser.svg"} alt="" width="22" height="22" />
                  <span id="doc-browser-title">Tempest Navigator 4.0 - Reference Documentation</span>
                </div>
                <span class="win-window__controls" aria-hidden="true">
                  <span></span><span></span><span></span>
                </span>
              </header>

              <nav class="doc-browser__toolbar" aria-label="Browser controls">
                <%= if @previous_document do %>
                  <.link class="doc-browser__tool" navigate={Docs.document_path(@previous_document)}>
                    <img src={~p"/images/icons/arrow-left.svg"} alt="" width="18" height="18" />
                    <span>Back</span>
                  </.link>
                <% else %>
                  <span class="doc-browser__tool doc-browser__tool--disabled" aria-disabled="true">
                    <img src={~p"/images/icons/arrow-left.svg"} alt="" width="18" height="18" />
                    <span>Back</span>
                  </span>
                <% end %>

                <%= if @next_document do %>
                  <.link class="doc-browser__tool" navigate={Docs.document_path(@next_document)}>
                    <img src={~p"/images/icons/arrow-right.svg"} alt="" width="18" height="18" />
                    <span>Forward</span>
                  </.link>
                <% else %>
                  <span class="doc-browser__tool doc-browser__tool--disabled" aria-disabled="true">
                    <img src={~p"/images/icons/arrow-right.svg"} alt="" width="18" height="18" />
                    <span>Forward</span>
                  </span>
                <% end %>

                <.link class="doc-browser__tool" navigate={@current_path}>
                  <img src={~p"/images/icons/stop.svg"} alt="" width="18" height="18" />
                  <span>Stop</span>
                </.link>
                <.link class="doc-browser__tool" navigate={@current_path}>
                  <img src={~p"/images/icons/refresh.svg"} alt="" width="18" height="18" />
                  <span>Reload</span>
                </.link>
                <.link class="doc-browser__tool" navigate={~p"/"}>
                  <img src={~p"/images/icons/home.svg"} alt="" width="18" height="18" />
                  <span>Home</span>
                </.link>
                <.link class="doc-browser__tool" navigate={~p"/docs"}>
                  <img src={~p"/images/icons/search.svg"} alt="" width="18" height="18" />
                  <span>Search</span>
                </.link>
                <button
                  class="doc-browser__tool"
                  id="doc-copy-markdown"
                  type="button"
                  phx-hook=".CopyMarkdownToast"
                  data-doc-source="doc-markdown-source"
                  data-toast-target="doc-copy-toast"
                >
                  <img src={~p"/images/icons/print.svg"} alt="" width="18" height="18" />
                  <span>Print</span>
                </button>
              </nav>

              <div class="doc-browser__location" aria-label="Current document location">
                <span>Location:</span>
                <.link navigate={@current_path}>tempest://navigator{@current_path}</.link>
              </div>

              <div class="doc-browser__workspace">
                <aside id="doc-bookmarks" class="doc-browser__bookmarks" aria-labelledby="doc-bookmarks-title">
                  <div class="doc-browser__pane-title" id="doc-bookmarks-title">Bookmarks</div>
                  <nav aria-label="Reference documents">
                    <ol class="doc-browser__bookmark-list">
                      <li :for={doc <- @documents}>
                        <.link
                          navigate={Docs.document_path(doc)}
                          class={["doc-browser__bookmark", doc.slug == @document.slug && "is-active"]}
                          aria-current={if(doc.slug == @document.slug, do: "page", else: nil)}
                        >
                          <img src={~p"/images/icons/doc.svg"} alt="" width="18" height="18" />
                          <span>{doc.title}</span>
                        </.link>
                      </li>
                    </ol>
                  </nav>
                </aside>

                <article id="doc-content" class="doc-browser__document" aria-labelledby="doc-title">
                  <header class="doc-browser__document-header">
                    <p class="doc-browser__document-kicker">Reference file: {@document.path}</p>
                    <h1 id="doc-title">{@document.title}</h1>
                    <dl class="doc-browser__metadata">
                      <div>
                        <dt>Slug</dt>
                        <dd>{@document.slug}</dd>
                      </div>
                      <div>
                        <dt>Updated</dt>
                        <dd>{@document.updated || "from manifest"}</dd>
                      </div>
                    </dl>
                  </header>

                  <div class="doc-browser__article">
                    {raw(@document.html)}
                  </div>
                  <textarea id="doc-markdown-source" class="sr-only" aria-hidden="true" readonly>{@document.markdown}</textarea>

                  <nav class="doc-browser__pager" aria-label="Adjacent reference documents">
                    <%= if @previous_document do %>
                      <.link class="doc-browser__pager-link" navigate={Docs.document_path(@previous_document)}>
                        <span>Previous</span>
                        <strong>{@previous_document.title}</strong>
                      </.link>
                    <% else %>
                      <span class="doc-browser__pager-link doc-browser__pager-link--disabled" aria-disabled="true">
                        <span>Previous</span>
                        <strong>-</strong>
                      </span>
                    <% end %>

                    <%= if @next_document do %>
                      <.link
                        class="doc-browser__pager-link doc-browser__pager-link--next"
                        navigate={Docs.document_path(@next_document)}
                      >
                        <span>Next</span>
                        <strong>{@next_document.title}</strong>
                      </.link>
                    <% else %>
                      <span
                        class="doc-browser__pager-link doc-browser__pager-link--disabled doc-browser__pager-link--next"
                        aria-disabled="true"
                      >
                        <span>Next</span>
                        <strong>End of manifest</strong>
                      </span>
                    <% end %>
                  </nav>
                </article>
              </div>

              <footer class="doc-browser__footer">
                <span>Best viewed in Tempest Navigator</span>
                <a href={~p"/xrpc/_health"}>/xrpc/_health</a>
                <span>v{@app_version}</span>
              </footer>
              <div id="doc-copy-toast" class="doc-browser__toast" role="status" aria-live="polite" aria-atomic="true"></div>
            </section>
          </div>
        </div>

        <.about_computer_modal app_version={@app_version} host={@host} rendered_at={@rendered_at} />
        <.taskbar app_label="tempest docs" host={@host} rendered_at={@rendered_at} />
      </div>
    </main>

    <script :type={Phoenix.LiveView.ColocatedHook} name=".CopyMarkdownToast">
      export default {
        mounted() {
          const source = document.getElementById(this.el.dataset.docSource)
          this.toast = document.getElementById(this.el.dataset.toastTarget)
          this.toastTimer = null
          this.onCopyClick = async () => {
            const text = source?.value ||
              document.querySelector("#doc-content")?.innerText ||
              ""
            let copied = false
            if (navigator.clipboard?.writeText) {
              try {
                await navigator.clipboard.writeText(text)
                copied = true
              } catch (_error) {
                copied = false
              }
            }

            if (!copied && document.execCommand) {
              const temporaryTextArea = document.createElement("textarea")
              temporaryTextArea.value = text
              temporaryTextArea.style.position = "fixed"
              temporaryTextArea.style.opacity = "0"
              document.body.appendChild(temporaryTextArea)
              temporaryTextArea.focus()
              temporaryTextArea.select()
              try {
                copied = document.execCommand("copy")
              } catch (_error) {
                copied = false
              } finally {
                document.body.removeChild(temporaryTextArea)
              }
            }

            this.showToast(copied ? "Copied markdown to clipboard." : "Could not copy markdown.")
          }

          this.el.addEventListener("click", this.onCopyClick)
        },
        showToast(message) {
          if (!this.toast) {
            return
          }

          clearTimeout(this.toastTimer)
          this.toast.textContent = message
          this.toast.classList.add("is-visible")
          this.toastTimer = window.setTimeout(() => {
            this.toast.classList.remove("is-visible")
          }, 1800)
        },
        destroyed() {
          this.el.removeEventListener("click", this.onCopyClick)
          clearTimeout(this.toastTimer)
        }
      }
    </script>

    <Layouts.flash_group flash={@flash} />
    """
  end

  defp path_info("reference"), do: ["docs"]
  defp path_info(slug), do: ["docs", slug]

  defp rendered_at do
    DateTime.utc_now()
    |> Calendar.strftime("%Y-%m-%d %H:%M:%SZ")
  end
end
