defmodule IndrajaalWeb.Contexts.ThemeContextTest do
  @moduledoc """
  TDG test suite for IndrajaalWeb.Contexts.ThemeContext.

  ## SOPv5.11+AEE+GDE Framework Integration
  - TDG Compliance: Tests written BEFORE implementation
  - Module: Theme management context for web layer

  ## STAMP Safety Integration
  - SC-HMI-001: Dark Cockpit defaults
  - SC-HMI-008: 4.5:1 contrast ratio for high contrast theme

  ## TPS 5-Level RCA Context
  - L1 Symptom: Wrong theme applied for cockpit paths
  - L5 Root Cause: Missing cockpit path detection logic
  """

  use ExUnit.Case, async: true

  @moduletag :zenoh_nif

  alias IndrajaalWeb.Contexts.ThemeContext

  describe "ThemeContext module structure" do
    test "module exists and is loaded" do
      assert Code.ensure_loaded?(ThemeContext)
    end

    test "get_theme/2 is exported" do
      assert function_exported?(ThemeContext, :get_theme, 2)
    end

    test "validate_theme/1 is exported" do
      assert function_exported?(ThemeContext, :validate_theme, 1)
    end

    test "valid_themes/0 is exported" do
      assert function_exported?(ThemeContext, :valid_themes, 0)
    end

    test "default_theme/1 is exported" do
      assert function_exported?(ThemeContext, :default_theme, 1)
    end

    test "theme_to_class/1 is exported" do
      assert function_exported?(ThemeContext, :theme_to_class, 1)
    end

    test "theme_to_js/1 is exported" do
      assert function_exported?(ThemeContext, :theme_to_js, 1)
    end
  end

  describe "valid_themes/0" do
    test "returns a list of atoms" do
      themes = ThemeContext.valid_themes()
      assert is_list(themes)
      assert Enum.all?(themes, &is_atom/1)
    end

    test "contains :light, :dark, :high_contrast, :system" do
      themes = ThemeContext.valid_themes()
      assert :light in themes
      assert :dark in themes
      assert :high_contrast in themes
      assert :system in themes
    end
  end

  describe "validate_theme/1" do
    test "validates :dark atom" do
      assert {:ok, :dark} = ThemeContext.validate_theme(:dark)
    end

    test "validates :light atom" do
      assert {:ok, :light} = ThemeContext.validate_theme(:light)
    end

    test "validates :high_contrast atom" do
      assert {:ok, :high_contrast} = ThemeContext.validate_theme(:high_contrast)
    end

    test "validates :system atom" do
      assert {:ok, :system} = ThemeContext.validate_theme(:system)
    end

    test "validates 'dark' string" do
      assert {:ok, :dark} = ThemeContext.validate_theme("dark")
    end

    test "validates 'light' string" do
      assert {:ok, :light} = ThemeContext.validate_theme("light")
    end

    test "validates 'high_contrast' string" do
      assert {:ok, :high_contrast} = ThemeContext.validate_theme("high_contrast")
    end

    test "rejects invalid theme string" do
      assert {:error, :invalid_theme} = ThemeContext.validate_theme("invalid_theme_xyz")
    end

    test "rejects invalid theme atom" do
      assert {:error, :invalid_theme} = ThemeContext.validate_theme(:neon)
    end
  end

  describe "default_theme/1" do
    test "cockpit defaults to :dark (SC-HMI-001)" do
      assert ThemeContext.default_theme(:cockpit) == :dark
    end

    test "app defaults to :system" do
      assert ThemeContext.default_theme(:app) == :system
    end

    test "unknown context defaults to :system" do
      assert ThemeContext.default_theme(:other) == :system
    end
  end

  describe "theme_to_class/1" do
    test ":dark returns 'dark'" do
      assert ThemeContext.theme_to_class(:dark) == "dark"
    end

    test ":high_contrast returns 'dark high-contrast'" do
      assert ThemeContext.theme_to_class(:high_contrast) == "dark high-contrast"
    end

    test ":light returns empty string" do
      assert ThemeContext.theme_to_class(:light) == ""
    end

    test ":system returns empty string" do
      assert ThemeContext.theme_to_class(:system) == ""
    end

    test "returns a string for any input" do
      assert is_binary(ThemeContext.theme_to_class(:unknown))
    end
  end

  describe "theme_to_js/1" do
    test ":high_contrast returns 'high-contrast'" do
      assert ThemeContext.theme_to_js(:high_contrast) == "high-contrast"
    end

    test ":dark returns 'dark'" do
      assert ThemeContext.theme_to_js(:dark) == "dark"
    end

    test ":light returns 'light'" do
      assert ThemeContext.theme_to_js(:light) == "light"
    end

    test ":system returns 'system'" do
      assert ThemeContext.theme_to_js(:system) == "system"
    end
  end

  describe "get_theme/2" do
    test "nil user on app path returns :system" do
      result = ThemeContext.get_theme(nil, "/dashboard")
      assert result == :system
    end

    test "nil user on cockpit path returns :dark (SC-HMI-001)" do
      result = ThemeContext.get_theme(nil, "/cockpit/prajna")
      assert result == :dark
    end

    test "returns an atom" do
      result = ThemeContext.get_theme(nil, "/any/path")
      assert is_atom(result)
    end

    test "user with theme preference returns that theme" do
      user = %{preferences: %{"theme" => "light"}}
      result = ThemeContext.get_theme(user, "/dashboard")
      assert result == :light
    end
  end
end
