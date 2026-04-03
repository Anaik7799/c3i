defmodule IndrajaalWeb.Prajna.SettingsLivePropTest do
  @moduledoc """
  L1 Property tests for SettingsLive.

  WHAT: Verifies that SettingsLive maintains invariants across all valid
        inputs — theme values come from a closed set, numeric thresholds
        remain in the 0-100 range, refresh rates are from valid discrete
        values, and the two-key safety envelope auth state machine progresses
        correctly (step 0 → 1 → 2).

  WHY: SettingsLive mutates 4 distinct state maps (display_prefs,
       alarm_thresholds, ai_settings, safety_envelope). Incorrect merging
       of arbitrary params could corrupt state. Property tests verify all
       state merge paths remain valid.

  CONSTRAINTS: SC-COV-001, SC-TDG-001, SC-CONFIG-001, SC-CONFIG-002,
               SC-VDP-008, EP-GEN-014

  TDG Level: L1 (Property-Based Testing)
  """

  use IndrajaalWeb.ConnCase, async: true
  use PropCheck
  import ExUnitProperties, except: [property: 2, property: 3, check: 2]

  alias PropCheck.BasicTypes, as: PC
  alias StreamData, as: SD

  import Phoenix.LiveViewTest

  @moduletag :property
  @moduletag :zenoh_nif

  @valid_themes ["dark", "light", "high_contrast", "system"]
  @valid_refresh_rates ["500", "1000", "2000", "5000"]
  @valid_sparkline_lengths ["10", "20", "30"]
  @valid_timezones ["Europe/Berlin", "UTC", "America/New_York"]
  @valid_providers ["openrouter", "anthropic", "openai"]
  @valid_models ["claude-3.5-sonnet", "claude-3-opus", "gpt-4o"]

  # ═══════════════════════════════════════════════════════════════════════
  # THEME VALUE PROPERTIES
  # ═══════════════════════════════════════════════════════════════════════

  describe "display preference properties" do
    property "P-SET-001: any valid theme value produces a valid page" do
      forall theme <- PC.oneof(@valid_themes) do
        {:ok, view, _html} = live(build_conn(), "/cockpit/settings")
        html = render_click(view, "update_display", %{"theme" => theme})

        is_binary(html) and String.length(html) > 100
      end
    end

    property "P-SET-002: any valid refresh rate produces a valid page" do
      forall rate <- PC.oneof(@valid_refresh_rates) do
        {:ok, view, _html} = live(build_conn(), "/cockpit/settings")
        html = render_click(view, "update_display", %{"refresh_rate" => rate})

        is_binary(html) and String.length(html) > 100
      end
    end

    property "P-SET-003: any valid timezone produces a valid page" do
      forall tz <- PC.oneof(@valid_timezones) do
        {:ok, view, _html} = live(build_conn(), "/cockpit/settings")
        html = render_click(view, "update_display", %{"timezone" => tz})

        is_binary(html) and String.length(html) > 100
      end
    end

    property "P-SET-004: applying a display update sets the unsaved_changes flag" do
      forall {theme, rate, sparkline} <-
               {PC.oneof(@valid_themes), PC.oneof(@valid_refresh_rates),
                PC.oneof(@valid_sparkline_lengths)} do
        {:ok, view, _html} = live(build_conn(), "/cockpit/settings")

        render_click(view, "update_display", %{
          "theme" => theme,
          "refresh_rate" => rate,
          "sparkline_length" => sparkline
        })

        html = render(view)
        # unsaved_changes indicator must appear in the header
        String.contains?(html, "Unsaved changes")
      end
    end
  end

  # ═══════════════════════════════════════════════════════════════════════
  # ALARM THRESHOLD PROPERTIES
  # ═══════════════════════════════════════════════════════════════════════

  describe "alarm threshold properties" do
    property "P-SET-005: CPU threshold values in 0-100 range do not crash" do
      forall {warning, caution} <-
               {PC.integer(0, 100), PC.integer(0, 100)} do
        {:ok, view, _html} = live(build_conn(), "/cockpit/settings")

        html =
          render_click(view, "update_threshold", %{
            "cpu_warning" => to_string(warning),
            "cpu_caution" => to_string(caution)
          })

        is_binary(html) and String.length(html) > 100
      end
    end

    property "P-SET-006: memory threshold values in 0-100 range do not crash" do
      forall {warning, caution} <-
               {PC.integer(0, 100), PC.integer(0, 100)} do
        {:ok, view, _html} = live(build_conn(), "/cockpit/settings")

        html =
          render_click(view, "update_threshold", %{
            "mem_warning" => to_string(warning),
            "mem_caution" => to_string(caution)
          })

        is_binary(html) and String.length(html) > 100
      end
    end

    property "P-SET-007: latency threshold accepts positive integer values" do
      forall {warning_ms, caution_ms} <-
               {PC.pos_integer(), PC.pos_integer()} do
        {:ok, view, _html} = live(build_conn(), "/cockpit/settings")

        html =
          render_click(view, "update_threshold", %{
            "latency_warning" => to_string(warning_ms),
            "latency_caution" => to_string(caution_ms)
          })

        is_binary(html)
      end
    end
  end

  # ═══════════════════════════════════════════════════════════════════════
  # AI SETTINGS PROPERTIES
  # ═══════════════════════════════════════════════════════════════════════

  describe "AI settings properties" do
    property "P-SET-008: any valid provider and model combination is accepted" do
      forall {provider, model} <-
               {PC.oneof(@valid_providers), PC.oneof(@valid_models)} do
        {:ok, view, _html} = live(build_conn(), "/cockpit/settings")

        html =
          render_click(view, "update_ai", %{
            "provider" => provider,
            "model" => model
          })

        is_binary(html) and String.length(html) > 100
      end
    end

    property "P-SET-009: toggle_llm is an involution — two toggles restore original state" do
      forall _ <- PC.boolean() do
        {:ok, view, _html} = live(build_conn(), "/cockpit/settings")

        html_initial = render(view)
        render_click(view, "toggle_llm", %{})
        render_click(view, "toggle_llm", %{})
        html_after = render(view)

        # Both renders contain the same LLM enabled/disabled text
        has_enabled = &String.contains?(&1, "Enabled")
        has_disabled = &String.contains?(&1, "Disabled")

        (has_enabled.(html_initial) and has_enabled.(html_after)) or
          (has_disabled.(html_initial) and has_disabled.(html_after))
      end
    end
  end

  # ═══════════════════════════════════════════════════════════════════════
  # SAFETY ENVELOPE AUTH STATE MACHINE
  # ═══════════════════════════════════════════════════════════════════════

  describe "safety envelope auth state machine" do
    property "P-SET-010: modify_envelope transitions envelope_auth_step from 0 to 1" do
      forall _ <- PC.boolean() do
        {:ok, view, _html} = live(build_conn(), "/cockpit/settings")

        html_before = render(view)
        render_click(view, "modify_envelope", %{})
        html_after = render(view)

        # Before: no auth code prompt; after: auth step visible
        not String.contains?(html_before, "Enter authorization code") and
          String.contains?(html_after, "Enter authorization code")
      end
    end

    property "P-SET-011: cancel_envelope_edit always returns to display mode" do
      forall _ <- PC.boolean() do
        {:ok, view, _html} = live(build_conn(), "/cockpit/settings")

        # Open envelope edit
        render_click(view, "modify_envelope", %{})
        # Cancel it
        render_click(view, "cancel_envelope_edit", %{})

        html = render(view)
        # Cancel must hide the auth form and show the read-only envelope view
        not String.contains?(html, "Enter authorization code") and
          String.contains?(html, "MODIFY ENVELOPE")
      end
    end
  end

  # ═══════════════════════════════════════════════════════════════════════
  # RESET AND SAVE PROPERTIES
  # ═══════════════════════════════════════════════════════════════════════

  describe "reset and save properties" do
    property "P-SET-012: reset_defaults always clears unsaved_changes flag" do
      forall theme <- PC.oneof(@valid_themes) do
        {:ok, view, _html} = live(build_conn(), "/cockpit/settings")

        # Make a change to set unsaved_changes
        render_click(view, "update_display", %{"theme" => theme})
        # Reset
        render_click(view, "reset_defaults", %{})

        html = render(view)
        not String.contains?(html, "Unsaved changes")
      end
    end
  end

  # ═══════════════════════════════════════════════════════════════════════
  # STREAMDATA TESTS (ExUnitProperties)
  # ═══════════════════════════════════════════════════════════════════════

  describe "StreamData property tests" do
    @tag timeout: 30_000
    check all(
            theme <- SD.member_of(@valid_themes),
            rate <- SD.member_of(@valid_refresh_rates),
            max_runs: 10
          ) do
      {:ok, view, _html} = live(build_conn(), "/cockpit/settings")

      html =
        render_click(view, "update_display", %{"theme" => theme, "refresh_rate" => rate})

      assert is_binary(html)
      assert String.length(html) > 100
      assert String.contains?(render(view), "Unsaved changes")
    end

    @tag timeout: 30_000
    check all(
            cpu_warn <- SD.integer(50, 100),
            cpu_caut <- SD.integer(0, 50),
            max_runs: 10
          ) do
      {:ok, view, _html} = live(build_conn(), "/cockpit/settings")

      html =
        render_click(view, "update_threshold", %{
          "cpu_warning" => to_string(cpu_warn),
          "cpu_caution" => to_string(cpu_caut)
        })

      assert is_binary(html)
    end
  end
end
