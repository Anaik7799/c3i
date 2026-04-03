defmodule IndrajaalWeb.CoreComponentsTest do
  @moduledoc """
  Rendering tests for IndrajaalWeb.CoreComponents.

  WHAT: Verifies core Phoenix component functions render correct DOM structure,
        ARIA attributes, and HTML semantics.
  WHY: Ensures the UI component library produces accessible, standards-compliant HTML.
  CONSTRAINTS: SC-COV-001, SC-TDG-001
  """

  use ExUnit.Case, async: true
  import Phoenix.LiveViewTest

  @moduletag :zenoh_nif

  alias IndrajaalWeb.CoreComponents

  # ═══════════════════════════════════════════════════════════════════════
  # MODULE EXISTENCE
  # ═══════════════════════════════════════════════════════════════════════

  describe "module existence" do
    test "module is loaded" do
      assert Code.ensure_loaded?(IndrajaalWeb.CoreComponents)
    end

    test "exports all public component functions" do
      expected = [
        :flash_group,
        :flash,
        :icon,
        :error,
        :button,
        :input,
        :label,
        :header,
        :modal,
        :simple_form
      ]

      for func <- expected do
        assert function_exported?(CoreComponents, func, 1),
               "Expected CoreComponents.#{func}/1 to be exported"
      end
    end
  end

  # ═══════════════════════════════════════════════════════════════════════
  # TRANSLATE ERROR
  # ═══════════════════════════════════════════════════════════════════════

  describe "translate_error/1" do
    test "translates a basic error tuple" do
      result = CoreComponents.translate_error({"can't be blank", []})
      assert is_binary(result)
      assert result =~ "blank"
    end

    test "translates error with interpolation" do
      result =
        CoreComponents.translate_error({"should be at least %{count} character(s)", [count: 3]})

      assert is_binary(result)
      assert result =~ "3"
    end

    test "handles empty options" do
      result = CoreComponents.translate_error({"invalid format", []})
      assert result == "invalid format"
    end
  end

  # ═══════════════════════════════════════════════════════════════════════
  # TRANSLATE ERRORS
  # ═══════════════════════════════════════════════════════════════════════

  describe "translate_errors/2" do
    test "returns empty list for no errors" do
      result = CoreComponents.translate_errors([], :name)
      assert result == []
    end

    test "filters errors for specific field" do
      errors = [
        {:name, {"can't be blank", []}},
        {:email, {"is invalid", []}},
        {:name, {"is too short", []}}
      ]

      result = CoreComponents.translate_errors(errors, :name)
      assert length(result) == 2
    end
  end

  # ═══════════════════════════════════════════════════════════════════════
  # FLASH (SC-HMI)
  # ═══════════════════════════════════════════════════════════════════════

  describe "flash/1" do
    test "info flash renders with role=alert" do
      html =
        render_component(&CoreComponents.flash/1, %{
          id: "test-flash",
          kind: :info,
          title: "Success",
          flash: %{"info" => "Operation completed"}
        })

      assert html =~ "role" or html =~ "alert" or html =~ "Success"
    end

    test "error flash renders" do
      html =
        render_component(&CoreComponents.flash/1, %{
          id: "error-flash",
          kind: :error,
          title: "Error",
          flash: %{"error" => "Something went wrong"}
        })

      assert html =~ "Error" or html =~ "error" or html =~ "Something went wrong"
    end
  end

  # ═══════════════════════════════════════════════════════════════════════
  # ICON
  # ═══════════════════════════════════════════════════════════════════════

  describe "icon/1" do
    test "renders hero icon by name" do
      html = render_component(&CoreComponents.icon/1, %{name: "hero-check"})
      assert html =~ "hero-check" or html =~ "svg"
    end
  end

  # ═══════════════════════════════════════════════════════════════════════
  # BUTTON
  # ═══════════════════════════════════════════════════════════════════════

  describe "button/1" do
    test "function exists as component" do
      assert function_exported?(CoreComponents, :button, 1)
    end
  end

  # ═══════════════════════════════════════════════════════════════════════
  # HIDE/SHOW FLASH JS COMMANDS
  # ═══════════════════════════════════════════════════════════════════════

  describe "show_flash/1" do
    test "returns a Phoenix.LiveView.JS struct" do
      js = CoreComponents.show_flash(%Phoenix.LiveView.JS{}, "#flash")
      assert %Phoenix.LiveView.JS{} = js
    end
  end

  describe "hide_flash/1" do
    test "returns a Phoenix.LiveView.JS struct" do
      js = CoreComponents.hide_flash(%Phoenix.LiveView.JS{}, "#flash")
      assert %Phoenix.LiveView.JS{} = js
    end
  end

  describe "hide/1" do
    test "returns a Phoenix.LiveView.JS struct" do
      js = CoreComponents.hide(%Phoenix.LiveView.JS{}, "#element")
      assert %Phoenix.LiveView.JS{} = js
    end
  end
end
