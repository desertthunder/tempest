defmodule TempestWeb.EmailTokenLive do
  @moduledoc """
  Public browser pages for entering security email tokens.

  These pages are unauthenticated — they let a user complete a password reset,
  email confirmation, or email update directly in the browser when an action
  URL from an email is followed.
  """

  use TempestWeb, :live_view

  alias Tempest.Security

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Email Token")
     |> assign(:current_scope, nil)}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    token = Map.get(params, "token")

    socket =
      socket
      |> assign(:token, token)
      |> assign_form()

    {:noreply, socket}
  end

  defp assign_form(%{assigns: %{live_action: :password_reset}} = socket) do
    assign(socket, :form, to_form(%{"token" => socket.assigns.token || ""}, as: :password_reset))
  end

  defp assign_form(%{assigns: %{live_action: :confirm_email}} = socket) do
    assign(socket, :form, to_form(%{"token" => socket.assigns.token || ""}, as: :confirm_email))
  end

  defp assign_form(%{assigns: %{live_action: :update_email}} = socket) do
    assign(socket, :form, to_form(%{"token" => socket.assigns.token || ""}, as: :update_email))
  end

  @impl true
  def handle_event("validate", _params, socket) do
    {:noreply, socket}
  end

  def handle_event("submit", %{"password_reset" => params}, socket) do
    token = Map.get(params, "token")
    password = Map.get(params, "password")

    case Security.reset_password(token, password) do
      {:ok, _account} ->
        {:noreply,
         socket
         |> put_flash(:info, "Your password has been reset. You can now log in.")
         |> redirect(to: ~p"/account/login")}

      {:error, :invalid_token} ->
        {:noreply, put_flash(socket, :error, "Token is invalid or expired.")}

      {:error, message} when is_binary(message) ->
        {:noreply, put_flash(socket, :error, message)}

      {:error, _reason} ->
        {:noreply, put_flash(socket, :error, "Password reset failed. Please try again.")}
    end
  end

  def handle_event("submit", %{"confirm_email" => params}, socket) do
    token = Map.get(params, "token")
    email = normalize_optional(Map.get(params, "email"))

    case Security.confirm_email(token, email) do
      {:ok, _account} ->
        {:noreply,
         socket
         |> put_flash(:info, "Your email has been confirmed.")
         |> redirect(to: ~p"/")}

      {:error, :invalid_token} ->
        {:noreply, put_flash(socket, :error, "Token is invalid or expired.")}

      {:error, _reason} ->
        {:noreply, put_flash(socket, :error, "Email confirmation failed. Please try again.")}
    end
  end

  def handle_event("submit", %{"update_email" => params}, socket) do
    token = Map.get(params, "token")
    email = normalize_optional(Map.get(params, "email"))

    case Security.update_email(token, email) do
      {:ok, _account} ->
        {:noreply,
         socket
         |> put_flash(:info, "Your email has been updated.")
         |> redirect(to: ~p"/")}

      {:error, :invalid_token} ->
        {:noreply, put_flash(socket, :error, "Token is invalid or expired.")}

      {:error, _reason} ->
        {:noreply, put_flash(socket, :error, "Email update failed. Please try again.")}
    end
  end

  # Normalizes empty/blank strings to nil so optional email fields that are
  # left blank are treated as token-only calls rather than failing the email
  # match check in consume_email_token.
  defp normalize_optional(""), do: nil
  defp normalize_optional(value), do: value

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="email-token-page">
        <%= case @live_action do %>
          <% :password_reset -> %>
            <h1>Reset your password</h1>
            <p>Enter your reset token and choose a new password.</p>

            <.form for={@form} id="password-reset-form" phx-submit="submit" phx-change="validate" autocomplete="off">
              <.input field={@form[:token]} type="text" label="Token" placeholder="Paste your reset token" required />
              <.input
                field={@form[:password]}
                type="password"
                label="New password"
                placeholder="Enter new password"
                required
              />
              <button type="submit" class="button button--primary">Reset password</button>
            </.form>
          <% :confirm_email -> %>
            <h1>Confirm your email</h1>
            <p>Enter your confirmation token to verify your email address.</p>

            <.form for={@form} id="confirm-email-form" phx-submit="submit" phx-change="validate" autocomplete="off">
              <.input field={@form[:token]} type="text" label="Token" placeholder="Paste your confirmation token" required />
              <.input field={@form[:email]} type="email" label="Email (optional)" placeholder="Your account email" />
              <button type="submit" class="button button--primary">Confirm email</button>
            </.form>
          <% :update_email -> %>
            <h1>Confirm your new email</h1>
            <p>Enter your update token and the new email address to confirm the change.</p>

            <.form for={@form} id="update-email-form" phx-submit="submit" phx-change="validate" autocomplete="off">
              <.input field={@form[:token]} type="text" label="Token" placeholder="Paste your update token" required />
              <.input
                field={@form[:email]}
                type="email"
                label="New email"
                placeholder="Enter the new email address"
                required
              />
              <button type="submit" class="button button--primary">Update email</button>
            </.form>
        <% end %>
      </div>
    </Layouts.app>
    """
  end
end
