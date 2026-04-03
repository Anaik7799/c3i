defmodule IndrajaalWeb.Plugs.ThemePlug do
  @moduledoc """
  Plug to inject theme preference into connection assigns.

  WHAT: Injects theme into conn.assigns for use in layouts/templates.
  WHY: Ensures consistent theme availability across all rendered pages.
  CONSTRAINTS: SC-HMI-001 (Dark Cockpit default), SC-HMI-008 (contrast).

  ## Usage in router.ex

      pipeline :browser do
        plug :accepts, ["html"]
        # ... other plugs
        plug IndrajaalWeb.Plugs.ThemePlug
      end

  ## Available Assigns

  - `conn.assigns.theme` - Theme atom (:light, :dark, :high_contrast, :system)
  - `conn.assigns.theme_class` - CSS class string for <html> element
  - `conn.assigns.theme_js` - JavaScript-compatible theme string
  """

  import Plug.Conn
  alias IndrajaalWeb.Contexts.ThemeContext

  @behaviour Plug

  @impl Plug
  def init(opts), do: opts

  @impl Plug
  def call(conn, _opts) do
    user = get_current_user(conn)
    path = conn.request_path

    theme = ThemeContext.get_theme(user, path)
    theme_class = ThemeContext.theme_to_class(theme)
    theme_js = ThemeContext.theme_to_js(theme)

    conn
    |> assign(:theme, theme)
    |> assign(:theme_class, theme_class)
    |> assign(:theme_js, theme_js)
  end

  @spec get_current_user(Plug.Conn.t()) :: map() | nil
  defp get_current_user(conn) do
    # Try multiple places where user might be stored
    conn.assigns[:current_user] ||
      conn.assigns[:user] ||
      get_session(conn, :current_user)
  end
end
