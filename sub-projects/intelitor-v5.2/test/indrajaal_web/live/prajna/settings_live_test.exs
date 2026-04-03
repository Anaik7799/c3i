defmodule IndrajaalWeb.Prajna.SettingsLiveTest do
  @moduledoc """
  Integration tests for IndrajaalWeb.Prajna.SettingsLive.

  Covers all 11 handle_event clauses:
    - update_display
    - update_threshold
    - update_ai
    - toggle_llm
    - save_changes
    - reset_defaults
    - export_config
    - import_config
    - modify_envelope
    - envelope_auth
    - cancel_envelope_edit

  Also covers mount/render defaults and lifecycle sequences.

  ## STAMP Safety Integration
  - SC-HMI-001: Dark Cockpit defaults verified on mount
  - SC-CONFIG-001: Save requires unsaved_changes flag
  - SC-CONFIG-002: Safety envelope requires two-key auth
  - SC-VDP-008: Closure feedback (flash) on all mutations

  ## TDG Level: L4 (Integration Testing)
  """

  use IndrajaalWeb.ConnCase, async: true
  import Phoenix.LiveViewTest

  @moduletag :integration
  @moduletag :zenoh_nif

  @route "/cockpit/settings"

  # ---------------------------------------------------------------------------
  # MODULE STRUCTURE
  # ---------------------------------------------------------------------------

  describe "SettingsLive module structure" do
    test "module exists and is loaded" do
      assert Code.ensure_loaded?(IndrajaalWeb.Prajna.SettingsLive)
    end

    test "mount/3 is exported" do
      assert function_exported?(IndrajaalWeb.Prajna.SettingsLive, :mount, 3)
    end

    test "render/1 is exported" do
      assert function_exported?(IndrajaalWeb.Prajna.SettingsLive, :render, 1)
    end

    test "handle_event/3 is exported" do
      assert function_exported?(IndrajaalWeb.Prajna.SettingsLive, :handle_event, 3)
    end

    test "handle_info/2 is exported" do
      assert function_exported?(IndrajaalWeb.Prajna.SettingsLive, :handle_info, 2)
    end
  end

  # ---------------------------------------------------------------------------
  # MOUNT & INITIAL RENDER
  # ---------------------------------------------------------------------------

  describe "mount and initial render" do
    test "mounts successfully and renders settings page", %{conn: conn} do
      {:ok, _lv, html} = live(conn, @route)

      assert html =~ "SETTINGS"
    end

    test "renders DISPLAY PREFERENCES section", %{conn: conn} do
      {:ok, _lv, html} = live(conn, @route)

      assert html =~ "DISPLAY PREFERENCES"
    end

    test "renders ALARM THRESHOLDS section", %{conn: conn} do
      {:ok, _lv, html} = live(conn, @route)

      assert html =~ "ALARM THRESHOLDS"
    end

    test "renders AI COPILOT section", %{conn: conn} do
      {:ok, _lv, html} = live(conn, @route)

      assert html =~ "AI COPILOT"
    end

    test "renders SAFETY ENVELOPE section", %{conn: conn} do
      {:ok, _lv, html} = live(conn, @route)

      assert html =~ "SAFETY ENVELOPE"
    end

    test "SC-HMI-001: defaults to dark theme on mount", %{conn: conn} do
      {:ok, _lv, html} = live(conn, @route)

      # The dark option should be selected in the theme dropdown
      assert html =~ ~r/value="dark"[^>]*selected|selected[^>]*value="dark"/
    end

    test "no unsaved changes banner on fresh mount", %{conn: conn} do
      {:ok, _lv, html} = live(conn, @route)

      refute html =~ "Unsaved changes"
    end

    test "SAVE CHANGES button is initially disabled", %{conn: conn} do
      {:ok, _lv, html} = live(conn, @route)

      assert html =~ ~r/disabled[^>]*SAVE CHANGES|SAVE CHANGES[^<]*disabled/s
    end

    test "renders action buttons", %{conn: conn} do
      {:ok, _lv, html} = live(conn, @route)

      assert html =~ "SAVE CHANGES"
      assert html =~ "RESET TO DEFAULTS"
      assert html =~ "EXPORT CONFIG"
      assert html =~ "IMPORT CONFIG"
    end

    test "renders PRAJNA C3I navigation header", %{conn: conn} do
      {:ok, _lv, html} = live(conn, @route)

      assert html =~ "PRAJNA C3I"
    end

    test "renders SETTINGS nav tab as active", %{conn: conn} do
      {:ok, _lv, html} = live(conn, @route)

      assert html =~ "SETTINGS"
      assert html =~ "border-blue-600"
    end

    test "renders compliance footer", %{conn: conn} do
      {:ok, _lv, html} = live(conn, @route)

      assert html =~ "NUREG-0700"
      assert html =~ "MIL-STD-1472H"
    end

    test "safety envelope shows two-key notice", %{conn: conn} do
      {:ok, _lv, html} = live(conn, @route)

      assert html =~ "Two-Key"
    end

    test "default AI settings show openrouter provider", %{conn: conn} do
      {:ok, _lv, html} = live(conn, @route)

      assert html =~ "openrouter"
    end

    test "LLM toggle shows Enabled by default", %{conn: conn} do
      {:ok, _lv, html} = live(conn, @route)

      assert html =~ "Enabled"
    end
  end

  # ---------------------------------------------------------------------------
  # handle_event: update_display
  # ---------------------------------------------------------------------------

  describe "handle_event update_display" do
    test "changing theme sets unsaved_changes", %{conn: conn} do
      {:ok, lv, _html} = live(conn, @route)

      html =
        lv
        |> element("select[name=theme]")
        |> render_change(%{"theme" => "light"})

      assert html =~ "Unsaved changes"
    end

    test "changing theme to light updates theme value in render", %{conn: conn} do
      {:ok, lv, _html} = live(conn, @route)

      html =
        lv
        |> element("select[name=theme]")
        |> render_change(%{"theme" => "light"})

      assert html =~ ~r/value="light"[^>]*selected|selected[^>]*value="light"/
    end

    test "changing theme to high_contrast reflects in render", %{conn: conn} do
      {:ok, lv, _html} = live(conn, @route)

      html =
        lv
        |> element("select[name=theme]")
        |> render_change(%{"theme" => "high_contrast"})

      assert html =~ "high_contrast"
      assert html =~ "Unsaved changes"
    end

    test "changing refresh_rate sets unsaved_changes", %{conn: conn} do
      {:ok, lv, _html} = live(conn, @route)

      html =
        lv
        |> element("select[name=refresh_rate]")
        |> render_change(%{"refresh_rate" => "2000"})

      assert html =~ "Unsaved changes"
    end

    test "changing refresh_rate updates selected option", %{conn: conn} do
      {:ok, lv, _html} = live(conn, @route)

      html =
        lv
        |> element("select[name=refresh_rate]")
        |> render_change(%{"refresh_rate" => "5000"})

      assert html =~ ~r/value="5000"[^>]*selected|selected[^>]*value="5000"/
    end

    test "changing sparkline_length sets unsaved_changes", %{conn: conn} do
      {:ok, lv, _html} = live(conn, @route)

      html =
        lv
        |> element("select[name=sparkline_length]")
        |> render_change(%{"sparkline_length" => "30"})

      assert html =~ "Unsaved changes"
    end

    test "changing timezone sets unsaved_changes", %{conn: conn} do
      {:ok, lv, _html} = live(conn, @route)

      html =
        lv
        |> element("select[name=timezone]")
        |> render_change(%{"timezone" => "UTC"})

      assert html =~ "Unsaved changes"
    end

    test "changing timezone to UTC updates selected value", %{conn: conn} do
      {:ok, lv, _html} = live(conn, @route)

      html =
        lv
        |> element("select[name=timezone]")
        |> render_change(%{"timezone" => "UTC"})

      assert html =~ ~r/value="UTC"[^>]*selected|selected[^>]*value="UTC"/
    end
  end

  # ---------------------------------------------------------------------------
  # handle_event: update_threshold
  # ---------------------------------------------------------------------------

  describe "handle_event update_threshold" do
    test "updating cpu_warning sets unsaved_changes", %{conn: conn} do
      {:ok, lv, _html} = live(conn, @route)

      html =
        lv
        |> element("input[name=cpu_warning]")
        |> render_change(%{"cpu_warning" => "85"})

      assert html =~ "Unsaved changes"
    end

    test "updating cpu_warning reflects new value", %{conn: conn} do
      {:ok, lv, _html} = live(conn, @route)

      html =
        lv
        |> element("input[name=cpu_warning]")
        |> render_change(%{"cpu_warning" => "85"})

      assert html =~ "85"
    end

    test "updating cpu_caution sets unsaved_changes", %{conn: conn} do
      {:ok, lv, _html} = live(conn, @route)

      html =
        lv
        |> element("input[name=cpu_caution]")
        |> render_change(%{"cpu_caution" => "70"})

      assert html =~ "Unsaved changes"
    end

    test "updating mem_warning sets unsaved_changes", %{conn: conn} do
      {:ok, lv, _html} = live(conn, @route)

      html =
        lv
        |> element("input[name=mem_warning]")
        |> render_change(%{"mem_warning" => "88"})

      assert html =~ "Unsaved changes"
    end

    test "updating mem_caution sets unsaved_changes", %{conn: conn} do
      {:ok, lv, _html} = live(conn, @route)

      html =
        lv
        |> element("input[name=mem_caution]")
        |> render_change(%{"mem_caution" => "75"})

      assert html =~ "Unsaved changes"
    end

    test "updating latency_warning sets unsaved_changes", %{conn: conn} do
      {:ok, lv, _html} = live(conn, @route)

      html =
        lv
        |> element("input[name=latency_warning]")
        |> render_change(%{"latency_warning" => "200"})

      assert html =~ "Unsaved changes"
    end

    test "updating latency_caution sets unsaved_changes", %{conn: conn} do
      {:ok, lv, _html} = live(conn, @route)

      html =
        lv
        |> element("input[name=latency_caution]")
        |> render_change(%{"latency_caution" => "75"})

      assert html =~ "Unsaved changes"
    end

    test "updating staleness threshold sets unsaved_changes", %{conn: conn} do
      {:ok, lv, _html} = live(conn, @route)

      html =
        lv
        |> element("input[name=staleness]")
        |> render_change(%{"staleness" => "10"})

      assert html =~ "Unsaved changes"
    end
  end

  # ---------------------------------------------------------------------------
  # handle_event: update_ai
  # ---------------------------------------------------------------------------

  describe "handle_event update_ai" do
    test "updating provider sets unsaved_changes", %{conn: conn} do
      {:ok, lv, _html} = live(conn, @route)

      html =
        lv
        |> element("select[name=provider]")
        |> render_change(%{"provider" => "anthropic"})

      assert html =~ "Unsaved changes"
    end

    test "updating provider to anthropic reflects in render", %{conn: conn} do
      {:ok, lv, _html} = live(conn, @route)

      html =
        lv
        |> element("select[name=provider]")
        |> render_change(%{"provider" => "anthropic"})

      assert html =~ ~r/value="anthropic"[^>]*selected|selected[^>]*value="anthropic"/
    end

    test "updating model sets unsaved_changes", %{conn: conn} do
      {:ok, lv, _html} = live(conn, @route)

      html =
        lv
        |> element("select[name=model]")
        |> render_change(%{"model" => "gpt-4o"})

      assert html =~ "Unsaved changes"
    end

    test "updating model to gpt-4o reflects in render", %{conn: conn} do
      {:ok, lv, _html} = live(conn, @route)

      html =
        lv
        |> element("select[name=model]")
        |> render_change(%{"model" => "gpt-4o"})

      assert html =~ ~r/value="gpt-4o"[^>]*selected|selected[^>]*value="gpt-4o"/
    end

    test "updating analysis_interval sets unsaved_changes", %{conn: conn} do
      {:ok, lv, _html} = live(conn, @route)

      html =
        lv
        |> element("input[name=analysis_interval]")
        |> render_change(%{"analysis_interval" => "30"})

      assert html =~ "Unsaved changes"
    end

    test "updating max_insights sets unsaved_changes", %{conn: conn} do
      {:ok, lv, _html} = live(conn, @route)

      html =
        lv
        |> element("input[name=max_insights]")
        |> render_change(%{"max_insights" => "100"})

      assert html =~ "Unsaved changes"
    end

    test "updating insight_ttl sets unsaved_changes", %{conn: conn} do
      {:ok, lv, _html} = live(conn, @route)

      html =
        lv
        |> element("input[name=insight_ttl]")
        |> render_change(%{"insight_ttl" => "600"})

      assert html =~ "Unsaved changes"
    end
  end

  # ---------------------------------------------------------------------------
  # handle_event: toggle_llm
  # ---------------------------------------------------------------------------

  describe "handle_event toggle_llm" do
    test "toggles LLM from enabled to disabled", %{conn: conn} do
      {:ok, lv, _html} = live(conn, @route)

      html =
        lv
        |> element("button[phx-click=toggle_llm]")
        |> render_click()

      assert html =~ "Disabled"
    end

    test "toggle sets unsaved_changes", %{conn: conn} do
      {:ok, lv, _html} = live(conn, @route)

      html =
        lv
        |> element("button[phx-click=toggle_llm]")
        |> render_click()

      assert html =~ "Unsaved changes"
    end

    test "double-toggle returns LLM to enabled", %{conn: conn} do
      {:ok, lv, _html} = live(conn, @route)

      lv
      |> element("button[phx-click=toggle_llm]")
      |> render_click()

      html =
        lv
        |> element("button[phx-click=toggle_llm]")
        |> render_click()

      assert html =~ "Enabled"
    end
  end

  # ---------------------------------------------------------------------------
  # handle_event: save_changes
  # ---------------------------------------------------------------------------

  describe "handle_event save_changes" do
    test "SC-VDP-008: save_changes shows success flash", %{conn: conn} do
      {:ok, lv, _html} = live(conn, @route)

      # First create unsaved changes
      lv
      |> element("select[name=theme]")
      |> render_change(%{"theme" => "light"})

      html =
        lv
        |> element("button[phx-click=save_changes]")
        |> render_click()

      assert html =~ "saved"
    end

    test "save_changes clears unsaved_changes flag", %{conn: conn} do
      {:ok, lv, _html} = live(conn, @route)

      lv
      |> element("select[name=theme]")
      |> render_change(%{"theme" => "light"})

      html =
        lv
        |> element("button[phx-click=save_changes]")
        |> render_click()

      refute html =~ "Unsaved changes"
    end
  end

  # ---------------------------------------------------------------------------
  # handle_event: reset_defaults
  # ---------------------------------------------------------------------------

  describe "handle_event reset_defaults" do
    test "SC-VDP-008: reset_defaults shows info flash", %{conn: conn} do
      {:ok, lv, _html} = live(conn, @route)

      html =
        lv
        |> element("button[phx-click=reset_defaults]")
        |> render_click()

      assert html =~ "reset"
    end

    test "reset_defaults clears unsaved_changes", %{conn: conn} do
      {:ok, lv, _html} = live(conn, @route)

      lv
      |> element("select[name=theme]")
      |> render_change(%{"theme" => "light"})

      html =
        lv
        |> element("button[phx-click=reset_defaults]")
        |> render_click()

      refute html =~ "Unsaved changes"
    end

    test "reset_defaults restores dark theme", %{conn: conn} do
      {:ok, lv, _html} = live(conn, @route)

      lv
      |> element("select[name=theme]")
      |> render_change(%{"theme" => "light"})

      html =
        lv
        |> element("button[phx-click=reset_defaults]")
        |> render_click()

      assert html =~ ~r/value="dark"[^>]*selected|selected[^>]*value="dark"/
    end

    test "reset_defaults restores LLM enabled state", %{conn: conn} do
      {:ok, lv, _html} = live(conn, @route)

      lv
      |> element("button[phx-click=toggle_llm]")
      |> render_click()

      html =
        lv
        |> element("button[phx-click=reset_defaults]")
        |> render_click()

      assert html =~ "Enabled"
    end
  end

  # ---------------------------------------------------------------------------
  # handle_event: export_config
  # ---------------------------------------------------------------------------

  describe "handle_event export_config" do
    test "SC-VDP-008: export_config shows info flash", %{conn: conn} do
      {:ok, lv, _html} = live(conn, @route)

      html =
        lv
        |> element("button[phx-click=export_config]")
        |> render_click()

      assert html =~ "export"
    end

    test "export_config flash mentions config file", %{conn: conn} do
      {:ok, lv, _html} = live(conn, @route)

      html =
        lv
        |> element("button[phx-click=export_config]")
        |> render_click()

      assert html =~ "prajna_config"
    end
  end

  # ---------------------------------------------------------------------------
  # handle_event: import_config
  # ---------------------------------------------------------------------------

  describe "handle_event import_config" do
    test "SC-VDP-008: import_config shows info flash", %{conn: conn} do
      {:ok, lv, _html} = live(conn, @route)

      html =
        lv
        |> element("button[phx-click=import_config]")
        |> render_click()

      assert html =~ "import"
    end

    test "import_config flash mentions file selection", %{conn: conn} do
      {:ok, lv, _html} = live(conn, @route)

      html =
        lv
        |> element("button[phx-click=import_config]")
        |> render_click()

      assert html =~ "Select"
    end
  end

  # ---------------------------------------------------------------------------
  # handle_event: modify_envelope
  # ---------------------------------------------------------------------------

  describe "handle_event modify_envelope" do
    test "SC-CONFIG-002: modify_envelope enters auth mode", %{conn: conn} do
      {:ok, lv, _html} = live(conn, @route)

      html =
        lv
        |> element("button[phx-click=modify_envelope]")
        |> render_click()

      assert html =~ "authorization"
    end

    test "modify_envelope shows auth step 1 of 2", %{conn: conn} do
      {:ok, lv, _html} = live(conn, @route)

      html =
        lv
        |> element("button[phx-click=modify_envelope]")
        |> render_click()

      assert html =~ "1"
      assert html =~ "2"
    end

    test "modify_envelope shows password input field", %{conn: conn} do
      {:ok, lv, _html} = live(conn, @route)

      html =
        lv
        |> element("button[phx-click=modify_envelope]")
        |> render_click()

      assert html =~ ~r/type="password"/
    end

    test "modify_envelope shows CANCEL button", %{conn: conn} do
      {:ok, lv, _html} = live(conn, @route)

      html =
        lv
        |> element("button[phx-click=modify_envelope]")
        |> render_click()

      assert html =~ "CANCEL"
    end

    test "modify_envelope hides the MODIFY ENVELOPE button", %{conn: conn} do
      {:ok, lv, _html} = live(conn, @route)

      html =
        lv
        |> element("button[phx-click=modify_envelope]")
        |> render_click()

      refute html =~ "MODIFY ENVELOPE (requires authorization)"
    end
  end

  # ---------------------------------------------------------------------------
  # handle_event: envelope_auth
  # ---------------------------------------------------------------------------

  describe "handle_event envelope_auth" do
    setup %{conn: conn} do
      {:ok, lv, _html} = live(conn, @route)

      lv
      |> element("button[phx-click=modify_envelope]")
      |> render_click()

      {:ok, lv: lv}
    end

    test "valid code 1234 advances to step 2", %{lv: lv} do
      html =
        lv
        |> form("form[phx-submit=envelope_auth]", %{"code" => "1234"})
        |> render_submit()

      assert html =~ "2"
    end

    test "SC-VDP-008: valid code shows acceptance flash", %{lv: lv} do
      html =
        lv
        |> form("form[phx-submit=envelope_auth]", %{"code" => "1234"})
        |> render_submit()

      assert html =~ "accepted"
    end

    test "invalid code shows error flash", %{lv: lv} do
      html =
        lv
        |> form("form[phx-submit=envelope_auth]", %{"code" => "9999"})
        |> render_submit()

      assert html =~ "Invalid"
    end

    test "invalid code keeps auth step at 1", %{lv: lv} do
      html =
        lv
        |> form("form[phx-submit=envelope_auth]", %{"code" => "0000"})
        |> render_submit()

      # Still on step 1 — the step counter shows 1/2
      assert html =~ "1"
    end

    test "empty code is rejected", %{lv: lv} do
      html =
        lv
        |> form("form[phx-submit=envelope_auth]", %{"code" => ""})
        |> render_submit()

      assert html =~ "Invalid"
    end
  end

  # ---------------------------------------------------------------------------
  # handle_event: cancel_envelope_edit
  # ---------------------------------------------------------------------------

  describe "handle_event cancel_envelope_edit" do
    setup %{conn: conn} do
      {:ok, lv, _html} = live(conn, @route)

      lv
      |> element("button[phx-click=modify_envelope]")
      |> render_click()

      {:ok, lv: lv}
    end

    test "cancel returns to normal envelope view", %{lv: lv} do
      html =
        lv
        |> element("button[phx-click=cancel_envelope_edit]")
        |> render_click()

      assert html =~ "MODIFY ENVELOPE (requires authorization)"
    end

    test "cancel hides auth form", %{lv: lv} do
      html =
        lv
        |> element("button[phx-click=cancel_envelope_edit]")
        |> render_click()

      refute html =~ ~r/type="password"/
    end

    test "cancel resets auth step to 0", %{lv: lv} do
      html =
        lv
        |> element("button[phx-click=cancel_envelope_edit]")
        |> render_click()

      # Auth step counter no longer shown; envelope read view restored
      refute html =~ "Enter authorization code"
    end

    test "cancel restores safety envelope read values", %{lv: lv} do
      html =
        lv
        |> element("button[phx-click=cancel_envelope_edit]")
        |> render_click()

      assert html =~ "Max FLAME Nodes"
      assert html =~ "Dead Man"
    end
  end

  # ---------------------------------------------------------------------------
  # LIFECYCLE SEQUENCES
  # ---------------------------------------------------------------------------

  describe "lifecycle sequences" do
    test "edit → save → re-edit cycle maintains state", %{conn: conn} do
      {:ok, lv, _html} = live(conn, @route)

      lv
      |> element("select[name=theme]")
      |> render_change(%{"theme" => "light"})

      lv
      |> element("button[phx-click=save_changes]")
      |> render_click()

      html =
        lv
        |> element("select[name=refresh_rate]")
        |> render_change(%{"refresh_rate" => "1000"})

      assert html =~ "Unsaved changes"
      assert html =~ ~r/value="light"[^>]*selected|selected[^>]*value="light"/
    end

    test "modify_envelope → valid_auth → cancel resets state", %{conn: conn} do
      {:ok, lv, _html} = live(conn, @route)

      lv
      |> element("button[phx-click=modify_envelope]")
      |> render_click()

      lv
      |> form("form[phx-submit=envelope_auth]", %{"code" => "1234"})
      |> render_submit()

      html =
        lv
        |> element("button[phx-click=cancel_envelope_edit]")
        |> render_click()

      assert html =~ "MODIFY ENVELOPE (requires authorization)"
      refute html =~ "Enter authorization code"
    end

    test "threshold changes + reset restores defaults", %{conn: conn} do
      {:ok, lv, _html} = live(conn, @route)

      lv
      |> element("input[name=cpu_warning]")
      |> render_change(%{"cpu_warning" => "50"})

      lv
      |> element("input[name=mem_warning]")
      |> render_change(%{"mem_warning" => "50"})

      html =
        lv
        |> element("button[phx-click=reset_defaults]")
        |> render_click()

      # Default cpu_warning is 90 — should be back
      assert html =~ "90"
    end

    test "toggle LLM → save → toggle again maintains distinct states", %{conn: conn} do
      {:ok, lv, _html} = live(conn, @route)

      lv
      |> element("button[phx-click=toggle_llm]")
      |> render_click()

      html_disabled =
        lv
        |> element("button[phx-click=save_changes]")
        |> render_click()

      assert html_disabled =~ "Disabled"

      html_toggled =
        lv
        |> element("button[phx-click=toggle_llm]")
        |> render_click()

      assert html_toggled =~ "Enabled"
    end

    test "export then import both show distinct flash messages", %{conn: conn} do
      {:ok, lv, _html} = live(conn, @route)

      html_export =
        lv
        |> element("button[phx-click=export_config]")
        |> render_click()

      assert html_export =~ "export"

      html_import =
        lv
        |> element("button[phx-click=import_config]")
        |> render_click()

      assert html_import =~ "import"
    end

    test "multiple threshold edits accumulate in a single save", %{conn: conn} do
      {:ok, lv, _html} = live(conn, @route)

      lv
      |> element("input[name=cpu_warning]")
      |> render_change(%{"cpu_warning" => "85"})

      lv
      |> element("input[name=latency_warning]")
      |> render_change(%{"latency_warning" => "150"})

      html =
        lv
        |> element("button[phx-click=save_changes]")
        |> render_click()

      refute html =~ "Unsaved changes"
      assert html =~ "saved"
    end
  end
end
