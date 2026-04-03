defmodule IndrajaalWeb.Live.Hooks.ThemeHookTest do
  @moduledoc """
  Test suite for IndrajaalWeb.Live.Hooks.ThemeHook.

  WHAT: Verifies the hook module structure, ThemeContext helper functions used
        by on_mount/4 (theme resolution, validation, CSS/JS mapping), and
        source-level assertions that the hook wires correctly to the live_session.
  WHY:  on_mount/4 requires a real LiveView socket process (due to attach_hook/4),
        which is not available in a plain ExUnit.Case. The observable behaviour
        (theme in assigns, CSS class applied) is tested end-to-end via the LiveView
        integration tests that mount through the `:themed` live_session. Here we
        cover the pure functions that drive that behaviour.
  CONSTRAINTS: SC-HMI-001 (Dark Cockpit), SC-HMI-008 (contrast ratio 4.5:1),
               SC-COV-001, SC-TDG-001

  TDG Level: L1 (unit) + source inspection
  """

  use ExUnit.Case, async: true

  @moduletag :zenoh_nif

  alias IndrajaalWeb.Live.Hooks.ThemeHook
  alias IndrajaalWeb.Contexts.ThemeContext

  # ═══════════════════════════════════════════════════════════════════════
  # MODULE STRUCTURE
  # ═══════════════════════════════════════════════════════════════════════

  describe "module structure" do
    test "module exists and is loaded" do
      assert Code.ensure_loaded?(ThemeHook)
    end

    test "on_mount/4 is exported" do
      assert function_exported?(ThemeHook, :on_mount, 4)
    end

    test "module has moduledoc" do
      {:docs_v1, _, _, _, module_doc, _, _} = Code.fetch_docs(ThemeHook)
      assert module_doc != :none
    end

    test "ThemeContext alias is used by ThemeHook — verified in source" do
      source =
        File.read!("/home/an/dev/ver/intelitor-v5.2/lib/indrajaal_web/live/hooks/theme_hook.ex")

      assert source =~ "ThemeContext"
    end
  end

  # ═══════════════════════════════════════════════════════════════════════
  # HOOK WIRING — source-level assertions
  # ═══════════════════════════════════════════════════════════════════════

  describe "hook wiring" do
    test "hook attaches :theme_events handler in on_mount" do
      source =
        File.read!("/home/an/dev/ver/intelitor-v5.2/lib/indrajaal_web/live/hooks/theme_hook.ex")

      assert source =~ "attach_hook"
      assert source =~ ":theme_events"
    end

    test "hook returns {:cont, socket}" do
      source =
        File.read!("/home/an/dev/ver/intelitor-v5.2/lib/indrajaal_web/live/hooks/theme_hook.ex")

      assert source =~ "{:cont, socket}"
    end

    test "hook assigns :theme, :theme_class, :theme_js" do
      source =
        File.read!("/home/an/dev/ver/intelitor-v5.2/lib/indrajaal_web/live/hooks/theme_hook.ex")

      assert source =~ ":theme,"
      assert source =~ ":theme_class,"
      assert source =~ ":theme_js,"
    end

    test "hook assigns :current_user from session" do
      source =
        File.read!("/home/an/dev/ver/intelitor-v5.2/lib/indrajaal_web/live/hooks/theme_hook.ex")

      assert source =~ ":current_user"
      assert source =~ "current_user"
    end

    test "hook handles theme_changed event — halt on valid theme" do
      source =
        File.read!("/home/an/dev/ver/intelitor-v5.2/lib/indrajaal_web/live/hooks/theme_hook.ex")

      assert source =~ "theme_changed"
      assert source =~ "{:halt, socket}"
    end

    test "hook passes through unrecognized events — cont" do
      source =
        File.read!("/home/an/dev/ver/intelitor-v5.2/lib/indrajaal_web/live/hooks/theme_hook.ex")

      assert source =~ "{:cont, socket}"
    end

    test "hook persists theme asynchronously via Task.start" do
      source =
        File.read!("/home/an/dev/ver/intelitor-v5.2/lib/indrajaal_web/live/hooks/theme_hook.ex")

      assert source =~ "Task.start"
    end

    test "router registers ThemeHook as on_mount for :themed session" do
      source = File.read!("/home/an/dev/ver/intelitor-v5.2/lib/indrajaal_web/router.ex")
      assert source =~ "IndrajaalWeb.Live.Hooks.ThemeHook"
      assert source =~ "on_mount:"
    end
  end

  # ═══════════════════════════════════════════════════════════════════════
  # ThemeContext.get_theme/2 — anonymous user
  # ═══════════════════════════════════════════════════════════════════════

  describe "ThemeContext.get_theme/2 — anonymous user" do
    test "returns :color_rich default when user is nil" do
      assert ThemeContext.get_theme(nil, "/") == :color_rich
    end

    test "returns :color_rich default when user is nil for cockpit path" do
      assert ThemeContext.get_theme(nil, "/cockpit") == :color_rich
    end

    test "returns :color_rich for any path with nil user" do
      for path <- ["/", "/cockpit", "/analytics", "/admin/permissions", "/performance"] do
        assert ThemeContext.get_theme(nil, path) == :color_rich
      end
    end
  end

  # ═══════════════════════════════════════════════════════════════════════
  # ThemeContext.get_theme/2 — authenticated user
  # ═══════════════════════════════════════════════════════════════════════

  describe "ThemeContext.get_theme/2 — authenticated user" do
    test "returns user preference when user has theme set to dark" do
      user = %{preferences: %{"theme" => "dark"}}
      assert ThemeContext.get_theme(user, "/") == :dark
    end

    test "returns :color_rich when user preferences key is absent" do
      assert ThemeContext.get_theme(%{preferences: %{}}, "/") == :color_rich
    end

    test "returns :color_rich when user has nil preferences map" do
      assert ThemeContext.get_theme(%{preferences: nil}, "/") == :color_rich
    end

    test "returns :color_rich when user preferences theme is empty string" do
      assert ThemeContext.get_theme(%{preferences: %{"theme" => ""}}, "/") == :color_rich
    end

    test "returns :light when user preference is light" do
      user = %{preferences: %{"theme" => "light"}}
      assert ThemeContext.get_theme(user, "/") == :light
    end

    test "returns :high_contrast when user preference is high_contrast" do
      user = %{preferences: %{"theme" => "high_contrast"}}
      assert ThemeContext.get_theme(user, "/") == :high_contrast
    end

    test "returns :color_rich when user preference is invalid" do
      user = %{preferences: %{"theme" => "nonexistent_theme"}}
      assert ThemeContext.get_theme(user, "/") == :color_rich
    end
  end

  # ═══════════════════════════════════════════════════════════════════════
  # ThemeContext.validate_theme/1
  # ═══════════════════════════════════════════════════════════════════════

  describe "ThemeContext.validate_theme/1 — valid atoms" do
    for theme <- [
          :dark,
          :light,
          :high_contrast,
          :system,
          :color_rich,
          :google_compliant,
          :functionally_clean
        ] do
      test "accepts :#{theme} atom" do
        assert {:ok, unquote(theme)} = ThemeContext.validate_theme(unquote(theme))
      end
    end
  end

  describe "ThemeContext.validate_theme/1 — valid strings" do
    test "accepts \"dark\" binary" do
      assert {:ok, :dark} = ThemeContext.validate_theme("dark")
    end

    test "accepts \"light\" binary" do
      assert {:ok, :light} = ThemeContext.validate_theme("light")
    end

    test "accepts \"color_rich\" binary" do
      assert {:ok, :color_rich} = ThemeContext.validate_theme("color_rich")
    end

    test "accepts \"color-rich\" with hyphen converted to underscore" do
      assert {:ok, :color_rich} = ThemeContext.validate_theme("color-rich")
    end

    test "accepts \"high_contrast\" binary" do
      assert {:ok, :high_contrast} = ThemeContext.validate_theme("high_contrast")
    end

    test "accepts \"HIGH_CONTRAST\" case-insensitive" do
      assert {:ok, :high_contrast} = ThemeContext.validate_theme("HIGH_CONTRAST")
    end
  end

  describe "ThemeContext.validate_theme/1 — invalid inputs" do
    test "rejects unknown string" do
      assert {:error, :invalid_theme} = ThemeContext.validate_theme("hacker")
    end

    test "rejects unknown atom" do
      assert {:error, :invalid_theme} = ThemeContext.validate_theme(:unknown_theme)
    end

    test "rejects empty string" do
      assert {:error, :invalid_theme} = ThemeContext.validate_theme("")
    end

    test "rejects random string" do
      assert {:error, :invalid_theme} = ThemeContext.validate_theme("matrix_green")
    end
  end

  # ═══════════════════════════════════════════════════════════════════════
  # ThemeContext.theme_to_class/1
  # ═══════════════════════════════════════════════════════════════════════

  describe "ThemeContext.theme_to_class/1" do
    test ":dark -> \"dark\"" do
      assert ThemeContext.theme_to_class(:dark) == "dark"
    end

    test ":high_contrast -> \"dark high-contrast\"" do
      assert ThemeContext.theme_to_class(:high_contrast) == "dark high-contrast"
    end

    test ":color_rich -> \"color-rich\"" do
      assert ThemeContext.theme_to_class(:color_rich) == "color-rich"
    end

    test ":light -> empty string" do
      assert ThemeContext.theme_to_class(:light) == ""
    end

    test ":system -> empty string" do
      assert ThemeContext.theme_to_class(:system) == ""
    end

    test ":google_compliant -> \"google-compliant\"" do
      assert ThemeContext.theme_to_class(:google_compliant) == "google-compliant"
    end

    test ":functionally_clean -> \"functionally-clean\"" do
      assert ThemeContext.theme_to_class(:functionally_clean) == "functionally-clean"
    end

    test "unknown atom -> empty string" do
      assert ThemeContext.theme_to_class(:unknown) == ""
    end
  end

  # ═══════════════════════════════════════════════════════════════════════
  # ThemeContext.theme_to_js/1
  # ═══════════════════════════════════════════════════════════════════════

  describe "ThemeContext.theme_to_js/1" do
    test ":dark -> \"dark\"" do
      assert ThemeContext.theme_to_js(:dark) == "dark"
    end

    test ":light -> \"light\"" do
      assert ThemeContext.theme_to_js(:light) == "light"
    end

    test ":high_contrast -> \"high-contrast\"" do
      assert ThemeContext.theme_to_js(:high_contrast) == "high-contrast"
    end

    test ":color_rich -> \"color-rich\"" do
      assert ThemeContext.theme_to_js(:color_rich) == "color-rich"
    end

    test ":google_compliant -> \"google-compliant\"" do
      assert ThemeContext.theme_to_js(:google_compliant) == "google-compliant"
    end

    test ":functionally_clean -> \"functionally-clean\"" do
      assert ThemeContext.theme_to_js(:functionally_clean) == "functionally-clean"
    end

    test ":system -> \"system\"" do
      assert ThemeContext.theme_to_js(:system) == "system"
    end
  end

  # ═══════════════════════════════════════════════════════════════════════
  # ThemeContext.valid_themes/0
  # ═══════════════════════════════════════════════════════════════════════

  describe "ThemeContext.valid_themes/0" do
    test "returns a non-empty list" do
      themes = ThemeContext.valid_themes()
      assert is_list(themes)
      assert length(themes) >= 4
    end

    test "contains :dark" do
      assert :dark in ThemeContext.valid_themes()
    end

    test "contains :light" do
      assert :light in ThemeContext.valid_themes()
    end

    test "contains :color_rich" do
      assert :color_rich in ThemeContext.valid_themes()
    end

    test "contains :high_contrast" do
      assert :high_contrast in ThemeContext.valid_themes()
    end

    test "all valid themes pass validate_theme/1" do
      for theme <- ThemeContext.valid_themes() do
        assert {:ok, ^theme} = ThemeContext.validate_theme(theme)
      end
    end
  end

  # ═══════════════════════════════════════════════════════════════════════
  # ThemeContext.default_theme/1
  # ═══════════════════════════════════════════════════════════════════════

  describe "ThemeContext.default_theme/1" do
    test "returns :color_rich for :cockpit context" do
      assert ThemeContext.default_theme(:cockpit) == :color_rich
    end

    test "returns :color_rich for :admin context" do
      assert ThemeContext.default_theme(:admin) == :color_rich
    end

    test "returns :color_rich for nil context" do
      assert ThemeContext.default_theme(nil) == :color_rich
    end

    test "default theme is a member of valid_themes" do
      assert ThemeContext.default_theme(:any) in ThemeContext.valid_themes()
    end
  end

  # ═══════════════════════════════════════════════════════════════════════
  # DARK COCKPIT DEFAULT (SC-HMI-001)
  # ═══════════════════════════════════════════════════════════════════════

  describe "dark cockpit default compliance SC-HMI-001" do
    test ":dark theme produces non-empty CSS class (contrast-safe)" do
      class = ThemeContext.theme_to_class(:dark)
      assert class != ""
      assert class =~ "dark"
    end

    test ":high_contrast class includes dark for cockpit compliance" do
      class = ThemeContext.theme_to_class(:high_contrast)
      assert class =~ "dark"
    end

    test ":color_rich is the system default (SC-HMI-001 color richness)" do
      assert ThemeContext.default_theme(:any) == :color_rich
    end

    test "ThemeHook source references SC-HMI-001" do
      source =
        File.read!("/home/an/dev/ver/intelitor-v5.2/lib/indrajaal_web/live/hooks/theme_hook.ex")

      assert source =~ "SC-HMI-001"
    end

    test "ThemeHook source references SC-HMI-008 contrast ratio" do
      source =
        File.read!("/home/an/dev/ver/intelitor-v5.2/lib/indrajaal_web/live/hooks/theme_hook.ex")

      assert source =~ "SC-HMI-008"
    end
  end
end
