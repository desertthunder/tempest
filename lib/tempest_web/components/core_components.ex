defmodule TempestWeb.CoreComponents do
  @moduledoc """
  Core UI components styled by the vanilla CSS system in `assets/css`.
  """
  use Phoenix.Component
  use Gettext, backend: TempestWeb.Gettext

  alias Phoenix.LiveView.JS

  use Phoenix.VerifiedRoutes,
    endpoint: TempestWeb.Endpoint,
    router: TempestWeb.Router,
    statics: TempestWeb.static_paths()

  @doc """
  Renders the shared desktop shortcut column.
  """
  def desktop_shortcuts(assigns) do
    ~H"""
    <nav class="desktop-icons" aria-label="Desktop shortcuts">
      <.link class="desktop-icon" href="https://github.com/desertthunder/tempest" target="_blank">
        <img src={~p"/images/icons/github.svg"} alt="" width="40" height="40" />
        <span>GitHub</span>
      </.link>
      <.link class="desktop-icon" href="https://desertthunder.dev" target="_blank">
        <img src={~p"/images/icons/vim.svg"} alt="" width="40" height="40" />
        <span>Developer</span>
      </.link>
      <.link class="desktop-icon" navigate={~p"/stats"}>
        <img src={~p"/images/icons/db.svg"} alt="" width="40" height="40" />
        <span>Stats</span>
      </.link>
      <.link class="desktop-icon" navigate={~p"/docs"}>
        <img src={~p"/images/icons/browser.svg"} alt="" width="40" height="40" />
        <span>Docs</span>
      </.link>
      <a class="desktop-icon" href="#about-computer">
        <img src={~p"/images/icons/computer.svg"} alt="" width="40" height="40" />
        <span>My Computer</span>
      </a>
    </nav>
    """
  end

  attr :app_version, :any, required: true
  attr :host, :string, required: true
  attr :rendered_at, :string, required: true

  def about_computer_modal(assigns) do
    ~H"""
    <section id="about-computer" class="modal" role="dialog" aria-modal="true" aria-labelledby="about-computer-title">
      <a href="#" class="modal__backdrop" aria-label="Close About this Computer"></a>
      <div class="win-window modal__window">
        <header class="win-window__titlebar">
          <span id="about-computer-title" class="win-window__title">About this Computer</span>
          <a href="#" class="win-window__close" aria-label="Close">x</a>
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
    """
  end

  attr :app_label, :string, required: true
  attr :host, :string, required: true
  attr :rendered_at, :string, required: true

  def taskbar(assigns) do
    ~H"""
    <footer class="taskbar">
      <.link class="taskbar__start" navigate={~p"/"}>
        <img src={~p"/images/icons/at.svg"} alt="" width="18" height="18" /> Start
      </.link>
      <span class="taskbar__app">{@app_label} / {@host}</span>
      <span class="taskbar__tray" aria-label="Current UTC time">{@rendered_at}</span>
    </footer>
    """
  end

  @doc """
  Renders flash notices.
  """
  attr :id, :string, doc: "the optional id of flash container"
  attr :flash, :map, default: %{}, doc: "the map of flash messages to display"
  attr :title, :string, default: nil
  attr :kind, :atom, values: [:info, :error], doc: "used for styling and flash lookup"
  attr :rest, :global, doc: "the arbitrary HTML attributes to add to the flash container"
  slot :inner_block, doc: "the optional inner block that renders the flash message"

  def flash(assigns) do
    assigns = assign_new(assigns, :id, fn -> "flash-#{assigns.kind}" end)

    ~H"""
    <div
      :if={msg = render_slot(@inner_block) || Phoenix.Flash.get(@flash, @kind)}
      id={@id}
      phx-click={JS.push("lv:clear-flash", value: %{key: @kind}) |> hide("##{@id}")}
      role="alert"
      class={["flash", @kind == :info && "flash--info", @kind == :error && "flash--error"]}
      {@rest}
    >
      <div class="flash__body">
        <.icon :if={@kind == :info} name="info" />
        <.icon :if={@kind == :error} name="warning" />
        <div>
          <p :if={@title} class="flash__title">{@title}</p>
          <p>{msg}</p>
        </div>
        <button type="button" class="flash__close" aria-label={gettext("close")}>
          <.icon name="close" />
        </button>
      </div>
    </div>
    """
  end

  @doc """
  Renders a button with navigation support.
  """
  attr :rest, :global, include: ~w(href navigate patch method download name value disabled)
  attr :class, :any
  attr :variant, :string, values: ~w(primary)
  slot :inner_block, required: true

  def button(%{rest: rest} = assigns) do
    variants = %{"primary" => "button button--primary", nil => "button"}
    assigns = assign_new(assigns, :class, fn -> Map.fetch!(variants, assigns[:variant]) end)

    if rest[:href] || rest[:navigate] || rest[:patch] do
      ~H"""
      <.link class={@class} {@rest}>{render_slot(@inner_block)}</.link>
      """
    else
      ~H"""
      <button class={@class} {@rest}>{render_slot(@inner_block)}</button>
      """
    end
  end

  attr :id, :any, default: nil
  attr :name, :any
  attr :label, :string, default: nil
  attr :value, :any

  attr :type, :string,
    default: "text",
    values: ~w(checkbox color date datetime-local email file month number password
               search select tel text textarea time url week hidden)

  attr :field, Phoenix.HTML.FormField, doc: "a form field struct retrieved from the form, for example: @form[:email]"
  attr :errors, :list, default: []
  attr :checked, :boolean, doc: "the checked flag for checkbox inputs"
  attr :prompt, :string, default: nil, doc: "the prompt for select inputs"
  attr :options, :list, doc: "the options to pass to Phoenix.HTML.Form.options_for_select/2"
  attr :multiple, :boolean, default: false, doc: "the multiple flag for select inputs"
  attr :class, :any, default: nil, doc: "the input class to use over defaults"
  attr :error_class, :any, default: nil, doc: "the input error class to use over defaults"

  attr :rest, :global, include: ~w(accept autocomplete capture cols disabled form list max maxlength min minlength
                multiple pattern placeholder readonly required rows size step)

  def input(%{field: %Phoenix.HTML.FormField{} = field} = assigns) do
    errors = if Phoenix.Component.used_input?(field), do: field.errors, else: []

    assigns
    |> assign(field: nil, id: assigns.id || field.id)
    |> assign(:errors, Enum.map(errors, &translate_error(&1)))
    |> assign_new(:name, fn -> if assigns.multiple, do: field.name <> "[]", else: field.name end)
    |> assign_new(:value, fn -> field.value end)
    |> input()
  end

  def input(%{type: "hidden"} = assigns) do
    ~H"""
    <input type="hidden" id={@id} name={@name} value={@value} {@rest} />
    """
  end

  def input(%{type: "checkbox"} = assigns) do
    assigns = assign_new(assigns, :checked, fn -> Phoenix.HTML.Form.normalize_value("checkbox", assigns[:value]) end)

    ~H"""
    <div class="form-field">
      <label for={@id}>
        <input type="hidden" name={@name} value="false" disabled={@rest[:disabled]} form={@rest[:form]} />
        <span class="checkbox-row">
          <input type="checkbox" id={@id} name={@name} value="true" checked={@checked} class={@class || "checkbox"} {@rest} />
          {@label}
        </span>
      </label>
      <.error :for={msg <- @errors}>{msg}</.error>
    </div>
    """
  end

  def input(%{type: "select"} = assigns) do
    ~H"""
    <div class="form-field">
      <label for={@id}>
        <span :if={@label} class="form-label">{@label}</span>
        <select
          id={@id}
          name={@name}
          class={[@class || "select", @errors != [] && (@error_class || "select--error")]}
          multiple={@multiple}
          {@rest}
        >
          <option :if={@prompt} value="">{@prompt}</option>
          {Phoenix.HTML.Form.options_for_select(@options, @value)}
        </select>
      </label>
      <.error :for={msg <- @errors}>{msg}</.error>
    </div>
    """
  end

  def input(%{type: "textarea"} = assigns) do
    ~H"""
    <div class="form-field">
      <label for={@id}>
        <span :if={@label} class="form-label">{@label}</span>
        <textarea
          id={@id}
          name={@name}
          class={[@class || "textarea", @errors != [] && (@error_class || "textarea--error")]}
          {@rest}
        >{Phoenix.HTML.Form.normalize_value("textarea", @value)}</textarea>
      </label>
      <.error :for={msg <- @errors}>{msg}</.error>
    </div>
    """
  end

  def input(assigns) do
    ~H"""
    <div class="form-field">
      <label for={@id}>
        <span :if={@label} class="form-label">{@label}</span>
        <input
          type={@type}
          name={@name}
          id={@id}
          value={Phoenix.HTML.Form.normalize_value(@type, @value)}
          class={[@class || "input", @errors != [] && (@error_class || "input--error")]}
          {@rest}
        />
      </label>
      <.error :for={msg <- @errors}>{msg}</.error>
    </div>
    """
  end

  defp error(assigns) do
    ~H"""
    <p class="form-error"><.icon name="warning" /> {render_slot(@inner_block)}</p>
    """
  end

  @doc """
  Renders a header with title.
  """
  slot :inner_block, required: true
  slot :subtitle
  slot :actions

  def header(assigns) do
    ~H"""
    <header class="section-header">
      <div>
        <h1 class="section-header__title">{render_slot(@inner_block)}</h1>
        <p :if={@subtitle != []} class="section-header__subtitle">{render_slot(@subtitle)}</p>
      </div>
      <div>{render_slot(@actions)}</div>
    </header>
    """
  end

  @doc """
  Renders a table with generic styling.
  """
  attr :id, :string, required: true
  attr :rows, :list, required: true
  attr :row_id, :any, default: nil, doc: "the function for generating the row id"
  attr :row_click, :any, default: nil, doc: "the function for handling phx-click on each row"

  attr :row_item, :any,
    default: &Function.identity/1,
    doc: "the function for mapping each row before calling the :col and :action slots"

  slot :col, required: true do
    attr :label, :string
  end

  slot :action, doc: "the slot for showing user actions in the last table column"

  def table(assigns) do
    assigns =
      with %{rows: %Phoenix.LiveView.LiveStream{}} <- assigns do
        assign(assigns, row_id: assigns.row_id || fn {id, _item} -> id end)
      end

    ~H"""
    <table class="data-table">
      <thead>
        <tr>
          <th :for={col <- @col}>{col[:label]}</th>
          <th :if={@action != []}><span class="sr-only">{gettext("Actions")}</span></th>
        </tr>
      </thead>
      <tbody id={@id} phx-update={is_struct(@rows, Phoenix.LiveView.LiveStream) && "stream"}>
        <tr :for={row <- @rows} id={@row_id && @row_id.(row)}>
          <td :for={col <- @col} phx-click={@row_click && @row_click.(row)} class={@row_click && "data-table__clickable"}>
            {render_slot(col, @row_item.(row))}
          </td>
          <td :if={@action != []}>
            <div class="data-table__actions">
              <%= for action <- @action do %>
                {render_slot(action, @row_item.(row))}
              <% end %>
            </div>
          </td>
        </tr>
      </tbody>
    </table>
    """
  end

  @doc """
  Renders a data list.
  """
  slot :item, required: true do
    attr :title, :string, required: true
  end

  def list(assigns) do
    ~H"""
    <ul class="data-list">
      <li :for={item <- @item} class="data-list__item">
        <div class="data-list__title">{item.title}</div>
        <div>{render_slot(item)}</div>
      </li>
    </ul>
    """
  end

  @doc """
  Renders an SVG icon from `priv/static/images/icons`.

  Pass the file basename without `.svg`, for example `<.icon name="close" />`.
  """
  attr :name, :string, required: true
  attr :class, :any, default: nil

  def icon(assigns) do
    ~H"""
    <img class={["icon", @class]} src={"/images/icons/#{@name}.svg"} alt="" aria-hidden="true" />
    """
  end

  ## JS Commands

  def show(js \\ %JS{}, selector) do
    JS.show(js,
      to: selector,
      time: 300,
      transition: {"transition", "opacity-0", "opacity-100"}
    )
  end

  def hide(js \\ %JS{}, selector) do
    JS.hide(js,
      to: selector,
      time: 200,
      transition: {"transition", "opacity-100", "opacity-0"}
    )
  end

  @doc """
  Translates an error message using gettext.
  """
  def translate_error({msg, opts}) do
    if count = opts[:count] do
      Gettext.dngettext(TempestWeb.Gettext, "errors", msg, msg, count, opts)
    else
      Gettext.dgettext(TempestWeb.Gettext, "errors", msg, opts)
    end
  end

  @doc """
  Translates the errors for a field from a keyword list of errors.
  """
  def translate_errors(errors, field) when is_list(errors) do
    for {^field, {msg, opts}} <- errors, do: translate_error({msg, opts})
  end
end
