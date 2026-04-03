defmodule IndrajaalWeb.Live.Hooks.ThemeHook do
  @moduledoc """
  LiveView on_mount hook for theme management.

  WHAT: Attaches theme to LiveView socket and handles theme change events.
  WHY: Provides real-time theme switching without page reload.
  CONSTRAINTS: SC-HMI-001 (Dark Cockpit), SC-HMI-008 (contrast ratio).

  ## Usage in router.ex

      live_session :default, on_mount: [IndrajaalWeb.Live.Hooks.ThemeHook] do
        live "/cockpit", PrajnaLive, :index
        # ...
      end

  ## Events

  - Receives `theme_changed` from client JS hook
  - Persists theme to user preferences asynchronously
  """

  import Phoenix.LiveView
  import Phoenix.Component, only: [assign: 3]

  alias IndrajaalWeb.Contexts.ThemeContext

  @doc """
  Attach theme to socket on mount.
  """
  def on_mount(:default, _params, session, socket) do
    user = session["current_user"]
    path = get_path(socket)

    theme = ThemeContext.get_theme(user, path)
    theme_class = ThemeContext.theme_to_class(theme)
    theme_js = ThemeContext.theme_to_js(theme)

    socket =
      socket
      |> assign(:theme, theme)
      |> assign(:theme_class, theme_class)
      |> assign(:theme_js, theme_js)
      |> assign(:current_user, user)
      |> attach_hook(:theme_events, :handle_event, &handle_theme_event/3)

    {:cont, socket}
  end

  # Handle theme_changed event from JavaScript ThemeHook
  defp handle_theme_event("theme_changed", %{"theme" => theme_string}, socket) do
    case ThemeContext.validate_theme(theme_string) do
      {:ok, theme} ->
        theme_class = ThemeContext.theme_to_class(theme)
        theme_js = ThemeContext.theme_to_js(theme)

        socket =
          socket
          |> assign(:theme, theme)
          |> assign(:theme_class, theme_class)
          |> assign(:theme_js, theme_js)

        # Persist asynchronously if user is authenticated
        if socket.assigns[:current_user] do
          Task.start(fn ->
            persist_theme(socket.assigns.current_user, theme)
          end)
        end

        {:halt, socket}

      {:error, _} ->
        # Invalid theme, ignore
        {:cont, socket}
    end
  end

  # Pass through other events
  defp handle_theme_event(_event, _params, socket) do
    {:cont, socket}
  end

  # Persist theme to user preferences
  defp persist_theme(user, theme) when is_map(user) do
    try do
      user_id = Map.get(user, :id) || Map.get(user, "id")

      if user_id do
        # Update user preferences with new theme
        preferences = Map.get(user, :preferences, %{}) || %{}
        new_preferences = Map.put(preferences, "theme", Atom.to_string(theme))

        # Use Ash to update - this is a fire-and-forget operation
        Indrajaal.Accounts.User
        |> Ash.get!(user_id, authorize?: false)
        |> Ash.Changeset.for_update(:update_profile, %{preferences: new_preferences},
          authorize?: false
        )
        |> Ash.update!(authorize?: false)
      end
    rescue
      _error ->
        # Theme persistence is non-critical, log and continue
        :ok
    end
  end

  defp persist_theme(_, _), do: :ok

  defp get_path(socket) do
    case socket.assigns do
      %{__changed__: _} ->
        # Connected socket
        socket.assigns[:current_path] || "/"

      _ ->
        "/"
    end
  end
end
