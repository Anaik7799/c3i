defmodule IndrajaalWeb.Contexts.ThemeContext do
  @moduledoc """
  Theme management context for the Indrajaal platform.

  WHAT: Provides theme preference retrieval, validation, and defaults.
  WHY: Centralizes theme logic for consistent behavior across web/LiveView.
  CONSTRAINTS: SC-HMI-001 (Dark Cockpit), SC-HMI-008 (4.5:1 contrast).

  ## Themes

  - `:light` - Default light theme for main application
  - `:dark` - Dark theme, default for cockpit paths (NASA-STD-3000)
  - `:high_contrast` - High contrast for accessibility (SC-HMI-008)
  - `:system` - Follow OS preference
  - `:color_rich` - Rich color theme (default, verified 2026-03-28)
  - `:google_compliant` - Standards-based theme
  - `:functionally_clean` - Minimalist theme

  ## Verification
  See `docs/journal/20260328-1030-ui-color-rich-verification.md` for details on the verification of the `.color-rich` class application.

  ## Usage

      theme = ThemeContext.get_theme(user, path)
      ThemeContext.validate_theme("dark")  # => {:ok, :dark}
  """

  @valid_themes [
    :light,
    :dark,
    :high_contrast,
    :system,
    :color_rich,
    :google_compliant,
    :functionally_clean
  ]
  @default_theme :color_rich

  @doc """
  Get the effective theme for a user and path.

  ## Priority
  1. User preference (if authenticated and set)
  2. System default (color_rich)
  """
  @spec get_theme(map() | nil, String.t()) :: atom()
  def get_theme(user, _path) do
    cond do
      # User has explicit preference
      user && has_theme_preference?(user) ->
        user_theme(user)

      # Default to color_rich
      true ->
        @default_theme
    end
  end

  @doc """
  Validate a theme string or atom.

  Returns `{:ok, theme_atom}` or `{:error, :invalid_theme}`.
  """
  @spec validate_theme(String.t() | atom()) :: {:ok, atom()} | {:error, :invalid_theme}
  def validate_theme(theme) when is_binary(theme) do
    theme
    |> String.downcase()
    |> String.replace("-", "_")
    |> String.to_existing_atom()
    |> validate_theme()
  rescue
    ArgumentError -> {:error, :invalid_theme}
  end

  def validate_theme(theme) when theme in @valid_themes do
    {:ok, theme}
  end

  def validate_theme(_), do: {:error, :invalid_theme}

  @doc """
  Get list of valid themes.
  """
  @spec valid_themes() :: [atom()]
  def valid_themes, do: @valid_themes

  @doc """
  Get the default theme for a given context.
  """
  @spec default_theme(atom()) :: atom()
  def default_theme(_), do: @default_theme

  @doc """
  Convert theme atom to CSS class string.
  """
  @spec theme_to_class(atom()) :: String.t()
  def theme_to_class(:dark), do: "dark"
  def theme_to_class(:high_contrast), do: "dark high-contrast"
  def theme_to_class(:color_rich), do: "color-rich"
  def theme_to_class(:google_compliant), do: "google-compliant"
  def theme_to_class(:functionally_clean), do: "functionally-clean"
  def theme_to_class(:light), do: ""
  def theme_to_class(:system), do: ""
  def theme_to_class(_), do: ""

  @doc """
  Convert theme atom to JavaScript-compatible string.
  """
  @spec theme_to_js(atom()) :: String.t()
  def theme_to_js(:high_contrast), do: "high-contrast"
  def theme_to_js(:color_rich), do: "color-rich"
  def theme_to_js(:google_compliant), do: "google-compliant"
  def theme_to_js(:functionally_clean), do: "functionally-clean"
  def theme_to_js(theme), do: Atom.to_string(theme)

  # Private helpers

  defp has_theme_preference?(user) do
    case get_in(user, [Access.key(:preferences, %{}), "theme"]) do
      nil -> false
      "" -> false
      _ -> true
    end
  end

  defp user_theme(user) do
    theme_string = get_in(user, [Access.key(:preferences, %{}), "theme"]) || "system"

    case validate_theme(theme_string) do
      {:ok, theme} -> theme
      {:error, _} -> @default_theme
    end
  end
end
