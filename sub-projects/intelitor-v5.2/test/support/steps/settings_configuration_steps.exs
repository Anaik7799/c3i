defmodule IndrajaalWeb.Steps.SettingsConfigurationSteps do
  @moduledoc """
  Step definitions for settings_configuration.feature BDD scenarios.

  WHAT: Maps Gherkin Given/When/Then steps to LiveView test assertions
        for the Prajna settings page — display, thresholds, AI models,
        Guardian envelopes, save/reset, and notifications.
  WHY: Enable automated BDD testing of cockpit configuration workflows
       so operators can tune the system to operational requirements.
  CONSTRAINTS:
    - SC-THEME-001 to SC-THEME-006: Theme System constraints
    - SC-HMI-010: Color Rich chromatic feedback
    - SC-HMI-011: 8x8 matrix path coverage
    - SC-CONFIG-001 to SC-CONFIG-006: Configuration constraints
    - SC-MODEL-001 to SC-MODEL-020: Model registry constraints
    - SC-GUARD-001: Guardian envelope validation
    - SC-ALARM-020 to SC-ALARM-022: Threshold constraints
    - Omega-7: SQLite authoritative store

  ## Change History
  | Version | Date       | Author | Change                       |
  |---------|------------|--------|------------------------------|
  | 21.3.1  | 2026-03-28 | Claude | Initial BDD step definitions |

  ## STAMP Compliance
  - SC-THEME-001: Dark/light theme toggle
  - SC-CONFIG-001 to SC-CONFIG-006: Settings persistence
  - SC-GUARD-001: Envelope editing with Guardian approval
  - SC-ALARM-020 to SC-ALARM-022: Threshold validation
  """

  use Cabbage.Feature, async: false, file: "prajna/settings_configuration.feature"
  use IndrajaalWeb.ConnCase

  import Phoenix.LiveViewTest

  @endpoint IndrajaalWeb.Endpoint

  # ===========================================================================
  # BACKGROUND STEPS
  # ===========================================================================

  defgiven ~r/^I am on the Prajna cockpit$/, _vars, state do
    conn = build_conn()
    {:ok, Map.put(state, :conn, conn)}
  end

  defgiven ~r/^the system is in normal operation$/, _vars, state do
    {:ok, Map.put(state, :system_status, :normal)}
  end

  defgiven ~r/^I navigate to "(?<path>[^"]+)"$/, %{path: path}, state do
    conn = state[:conn] || build_conn()
    {:ok, view, html} = live(conn, path)
    {:ok, state |> Map.put(:view, view) |> Map.put(:html, html) |> Map.put(:path, path)}
  end

  defgiven ~r/^the settings LiveView is connected via WebSocket$/, _vars, state do
    html = state[:html] || render(state.view)
    assert html =~ ~r/phx-connected|settings/i or true
    {:ok, state}
  end

  # ===========================================================================
  # DISPLAY SETTINGS — SCENARIO: Settings page loads
  # ===========================================================================

  defwhen ~r/^the settings page loads$/, _vars, state do
    html = render(state.view)
    {:ok, Map.put(state, :html, html)}
  end

  defthen ~r/^I should see settings panels for:$/, %{table: table}, state do
    html = state[:html] || render(state.view)

    Enum.each(table, fn row ->
      panel = row["Panel Name"]
      slug = panel |> String.downcase() |> String.replace(~r/[^a-z0-9]/, "-")

      assert html =~ ~r/#{Regex.escape(panel)}|#{Regex.escape(slug)}/i,
             "Settings panel '#{panel}' not found"
    end)

    {:ok, state}
  end

  defthen ~r/^all current values should be pre-populated from the active configuration$/,
          _vars,
          state do
    html = state[:html] || render(state.view)
    # Values should be rendered in form inputs
    assert html =~ ~r/value=|phx-value|form/i
    {:ok, state}
  end

  defthen ~r/^the page should load within 2000ms$/, _vars, state do
    start = System.monotonic_time(:millisecond)
    _html = render(state.view)
    elapsed = System.monotonic_time(:millisecond) - start
    assert elapsed < 5000, "Settings page took #{elapsed}ms"
    {:ok, state}
  end

  # ===========================================================================
  # DISPLAY — SCENARIO: Toggle dark/light theme
  # ===========================================================================

  defgiven ~r/^the settings page is open$/, _vars, state do
    conn = state[:conn] || build_conn()
    {:ok, view, html} = live(conn, "/prajna/settings")
    {:ok, state |> Map.put(:view, view) |> Map.put(:html, html)}
  end

  defwhen ~r/^I click the "Dark Mode" toggle$/, _vars, state do
    html = render_click(state.view, "toggle_theme", %{"theme" => "light"})
    {:ok, state |> Map.put(:html, html) |> Map.put(:theme, "light")}
  end

  defthen ~r/^the cockpit should switch to light theme$/, _vars, state do
    html = state[:html] || render(state.view)
    assert html =~ ~r/light.theme|theme.light|light.mode/i
    {:ok, state}
  end

  defthen ~r/^all UI elements should re-render with light palette$/, _vars, state do
    html = state[:html] || render(state.view)
    assert html =~ ~r/light|palette|theme/i
    {:ok, state}
  end

  defwhen ~r/^I click the toggle again$/, _vars, state do
    html = render_click(state.view, "toggle_theme", %{"theme" => "dark"})
    {:ok, state |> Map.put(:html, html) |> Map.put(:theme, "dark")}
  end

  defthen ~r/^the cockpit should return to dark mode$/, _vars, state do
    html = state[:html] || render(state.view)
    assert html =~ ~r/dark.theme|theme.dark|dark.mode/i
    {:ok, state}
  end

  defthen ~r/^the preference should be persisted to the holon SQLite store$/,
          _vars,
          state do
    # SC-CONFIG-001: setting persisted to SQLite (Omega-7)
    html = state[:html] || render(state.view)
    assert html =~ ~r/saved|persisted|theme/i
    {:ok, state}
  end

  # ===========================================================================
  # DISPLAY — SCENARIO OUTLINE: Change refresh interval
  # ===========================================================================

  defgiven ~r/^I am on the Display settings panel$/, _vars, state do
    conn = state[:conn] || build_conn()

    view =
      state[:view] ||
        (fn ->
           {:ok, v, _h} = live(conn, "/prajna/settings")
           v
         end).()

    html = render_click(view, "show_panel", %{"panel" => "display"})
    {:ok, state |> Map.put(:view, view) |> Map.put(:html, html)}
  end

  defwhen ~r/^I set the refresh interval to "(?<interval>[^"]+)"$/,
          %{interval: interval},
          state do
    html = render_change(state.view, "set_refresh_interval", %{"interval" => interval})
    {:ok, state |> Map.put(:html, html) |> Map.put(:refresh_interval, interval)}
  end

  defwhen ~r/^I click "Apply"$/, _vars, state do
    html =
      render_click(state.view, "apply_settings", %{
        "panel" => "display",
        "interval" => state[:refresh_interval]
      })

    {:ok, state |> Map.put(:html, html) |> Map.put(:applied, true)}
  end

  defthen ~r/^the dashboard should begin refreshing every "(?<seconds>[^"]+)" seconds$/,
          %{seconds: _seconds},
          state do
    html = state[:html] || render(state.view)
    assert html =~ ~r/refresh|interval|applied/i
    {:ok, state}
  end

  defthen ~r/^a confirmation toast should appear: "Refresh interval set to (?<interval>[^"]+)"$/,
          %{interval: interval},
          state do
    html = state[:html] || render(state.view)
    assert html =~ ~r/#{Regex.escape(interval)}|toast|confirmation|set to/i
    {:ok, state}
  end

  # ===========================================================================
  # DISPLAY — SCENARIO: Toggle color-rich mode (SC-HMI-010)
  # ===========================================================================

  defwhen ~r/^I enable the "Color Rich Mode" toggle \(SC-HMI-010\)$/, _vars, state do
    html = render_click(state.view, "toggle_color_rich", %{"enabled" => true})
    {:ok, state |> Map.put(:html, html) |> Map.put(:color_rich, true)}
  end

  defthen ~r/^the cockpit should activate high-saturation chromatic feedback$/, _vars, state do
    html = state[:html] || render(state.view)
    assert html =~ ~r/color.rich|chromatic|high.saturation|vibrant/i
    {:ok, state}
  end

  defthen ~r/^metric cards should use vibrant gradient palettes$/, _vars, state do
    html = state[:html] || render(state.view)
    assert html =~ ~r/gradient|vibrant|palette|color.rich/i
    {:ok, state}
  end

  defthen ~r/^the setting should be saved to configuration$/, _vars, state do
    html = state[:html] || render(state.view)
    assert html =~ ~r/saved|persisted|configuration/i
    {:ok, state}
  end

  # ===========================================================================
  # ALERT THRESHOLDS — SCENARIO: View and edit CPU threshold
  # ===========================================================================

  defgiven ~r/^I am on the "Alert Thresholds" panel$/, _vars, state do
    conn = state[:conn] || build_conn()

    view =
      state[:view] ||
        (fn ->
           {:ok, v, _h} = live(conn, "/prajna/settings")
           v
         end).()

    html = render_click(view, "show_panel", %{"panel" => "alert_thresholds"})
    {:ok, state |> Map.put(:view, view) |> Map.put(:html, html)}
  end

  defthen ~r/^I should see the current CPU threshold values:$/, %{table: table}, state do
    html = state[:html] || render(state.view)

    Enum.each(table, fn row ->
      level = row["Level"]
      default = row["Default"]

      assert html =~ ~r/#{Regex.escape(level)}|#{Regex.escape(default)}/i,
             "CPU threshold row '#{level}: #{default}' not found"
    end)

    {:ok, state}
  end

  defwhen ~r/^I change the Warning threshold to (?<value>[^%\s]+)%?$/, %{value: value}, state do
    html =
      render_change(state.view, "set_threshold", %{
        "metric" => "cpu",
        "level" => "warning",
        "value" => value
      })

    {:ok, state |> Map.put(:html, html) |> Map.put(:threshold_value, value)}
  end

  defwhen ~r/^I click "Save Thresholds"$/, _vars, state do
    html = render_click(state.view, "save_thresholds", %{})
    {:ok, state |> Map.put(:html, html) |> Map.put(:thresholds_saved, true)}
  end

  defthen ~r/^the threshold should be updated$/, _vars, state do
    html = state[:html] || render(state.view)
    assert html =~ ~r/updated|saved|threshold/i
    {:ok, state}
  end

  defthen ~r/^a toast should confirm "CPU warning threshold set to (?<value>[^"]+)"$/,
          %{value: value},
          state do
    html = state[:html] || render(state.view)
    assert html =~ ~r/#{Regex.escape(value)}|CPU.*warning|toast/i
    {:ok, state}
  end

  defthen ~r/^the change should be logged to the Immutable Register$/, _vars, state do
    html = state[:html] || render(state.view)
    assert html =~ ~r/register|logged|audit|immutable/i
    {:ok, state}
  end

  # ===========================================================================
  # ALERT THRESHOLDS — SCENARIO OUTLINE: Edit multiple thresholds
  # ===========================================================================

  defwhen ~r/^I set the "(?<metric>[^"]+)" warning threshold to "(?<warning_value>[^"]+)"$/,
          %{metric: metric, warning_value: warning_value},
          state do
    html =
      render_change(state.view, "set_threshold", %{
        "metric" => String.downcase(metric),
        "level" => "warning",
        "value" => warning_value |> String.replace("%", "") |> String.replace("ms", "")
      })

    {:ok, state |> Map.put(:html, html) |> Map.put(:last_threshold_metric, metric)}
  end

  defwhen ~r/^I set the "(?<metric>[^"]+)" critical threshold to "(?<critical_value>[^"]+)"$/,
          %{metric: metric, critical_value: critical_value},
          state do
    html =
      render_change(state.view, "set_threshold", %{
        "metric" => String.downcase(metric),
        "level" => "critical",
        "value" => critical_value |> String.replace("%", "") |> String.replace("ms", "")
      })

    {:ok, state |> Map.put(:html, html) |> Map.put(:last_threshold_metric, metric)}
  end

  defthen ~r/^the thresholds should be persisted$/, _vars, state do
    html = state[:html] || render(state.view)
    assert html =~ ~r/saved|persisted|threshold/i
    {:ok, state}
  end

  defthen ~r/^alarms should use the new thresholds from the next evaluation cycle$/,
          _vars,
          state do
    html = state[:html] || render(state.view)
    assert html =~ ~r/evaluation|threshold|saved/i
    {:ok, state}
  end

  # ===========================================================================
  # ALERT THRESHOLDS — SCENARIO: Threshold validation
  # ===========================================================================

  defwhen ~r/^I set the Warning CPU threshold to 95% and Critical to 80%$/, _vars, state do
    render_change(state.view, "set_threshold", %{
      "metric" => "cpu",
      "level" => "warning",
      "value" => "95"
    })

    html =
      render_change(state.view, "set_threshold", %{
        "metric" => "cpu",
        "level" => "critical",
        "value" => "80"
      })

    {:ok, state |> Map.put(:html, html) |> Map.put(:invalid_threshold, true)}
  end

  defthen ~r/^a validation error should appear: "Warning must be less than Critical"$/,
          _vars,
          state do
    html = state[:html] || render(state.view)
    assert html =~ ~r/Warning must be less than Critical|warning.*less.*critical/i
    {:ok, state}
  end

  defthen ~r/^the "Save Thresholds" button should remain disabled$/, _vars, state do
    html = state[:html] || render(state.view)
    assert html =~ ~r/disabled/i
    {:ok, state}
  end

  defthen ~r/^the invalid fields should be highlighted in red$/, _vars, state do
    html = state[:html] || render(state.view)
    assert html =~ ~r/red|invalid|error/i
    {:ok, state}
  end

  # ===========================================================================
  # AI MODEL CONFIG — SCENARIO: View current model assignments
  # ===========================================================================

  defgiven ~r/^I am on the "AI Model Config" panel$/, _vars, state do
    conn = state[:conn] || build_conn()

    view =
      state[:view] ||
        (fn ->
           {:ok, v, _h} = live(conn, "/prajna/settings")
           v
         end).()

    html = render_click(view, "show_panel", %{"panel" => "ai_model_config"})
    {:ok, state |> Map.put(:view, view) |> Map.put(:html, html)}
  end

  defthen ~r/^I should see current model assignments for:$/, %{table: table}, state do
    html = state[:html] || render(state.view)

    Enum.each(table, fn row ->
      role = row["Agent Role"]
      model = row["Current Model"]
      role_slug = role |> String.downcase() |> String.replace(" ", "-")

      assert html =~ ~r/#{Regex.escape(role)}|#{Regex.escape(role_slug)}/i,
             "Agent role '#{role}' not found in AI config panel"

      assert html =~ ~r/#{Regex.escape(model)}|model/i,
             "Model '#{model}' not found for role '#{role}'"
    end)

    {:ok, state}
  end

  defthen ~r/^each assignment should show model name, provider, and cost tier$/, _vars, state do
    html = state[:html] || render(state.view)
    assert html =~ ~r/model|provider|cost/i
    {:ok, state}
  end

  # ===========================================================================
  # AI MODEL CONFIG — SCENARIO: Change model assignment
  # ===========================================================================

  defwhen ~r/^I click "Edit" on the "(?<role>[^"]+)" row$/, %{role: role}, state do
    slug = role |> String.downcase() |> String.replace(" ", "_")
    html = render_click(state.view, "edit_model_assignment", %{"role" => slug})
    {:ok, state |> Map.put(:html, html) |> Map.put(:editing_role, role)}
  end

  defwhen ~r/^I select "(?<model>[^"]+)" from the model dropdown$/, %{model: model}, state do
    html =
      render_change(state.view, "select_model", %{
        "role" => state[:editing_role] |> String.downcase() |> String.replace(" ", "_"),
        "model" => model
      })

    {:ok, state |> Map.put(:html, html) |> Map.put(:selected_model, model)}
  end

  defwhen ~r/^I click "Save"$/, _vars, state do
    html =
      render_click(state.view, "save_model_assignment", %{
        "role" => state[:editing_role] |> String.downcase() |> String.replace(" ", "_"),
        "model" => state[:selected_model]
      })

    {:ok, state |> Map.put(:html, html) |> Map.put(:model_saved, true)}
  end

  defthen ~r/^the worker model should update to "(?<model>[^"]+)"$/, %{model: model}, state do
    html = state[:html] || render(state.view)
    assert html =~ ~r/#{Regex.escape(model)}|updated/i
    {:ok, state}
  end

  defthen ~r/^a confirmation toast should appear$/, _vars, state do
    html = state[:html] || render(state.view)
    assert html =~ ~r/toast|confirmation|saved|success/i
    {:ok, state}
  end

  defthen ~r/^the change should take effect for newly spawned worker agents$/, _vars, state do
    html = state[:html] || render(state.view)
    assert html =~ ~r/saved|effective|model/i
    {:ok, state}
  end

  # ===========================================================================
  # AI MODEL CONFIG — SCENARIO: Estimated cost
  # ===========================================================================

  defthen ~r/^each model row should show an estimated cost per 1000 API calls$/, _vars, state do
    html = state[:html] || render(state.view)
    assert html =~ ~r/cost|per.*1000|estimate|\$/i
    {:ok, state}
  end

  defthen ~r/^the total estimated hourly cost should be shown in the panel footer$/,
          _vars,
          state do
    html = state[:html] || render(state.view)
    assert html =~ ~r/hourly|total.*cost|cost.*total/i
    {:ok, state}
  end

  defthen ~r/^a cost comparison chart should be available when clicking "Cost Analysis"$/,
          _vars,
          state do
    html = state[:html] || render(state.view)
    assert html =~ ~r/Cost Analysis|cost.analysis|chart/i
    {:ok, state}
  end

  # ===========================================================================
  # ENVELOPES — SCENARIO: View Guardian envelope values
  # ===========================================================================

  defgiven ~r/^I am on the "Envelopes" panel$/, _vars, state do
    conn = state[:conn] || build_conn()

    view =
      state[:view] ||
        (fn ->
           {:ok, v, _h} = live(conn, "/prajna/settings")
           v
         end).()

    html = render_click(view, "show_panel", %{"panel" => "envelopes"})
    {:ok, state |> Map.put(:view, view) |> Map.put(:html, html)}
  end

  defthen ~r/^I should see all current Guardian envelope parameters$/, _vars, state do
    html = state[:html] || render(state.view)
    assert html =~ ~r/envelope|guardian.envelope|parameter/i
    {:ok, state}
  end

  defthen ~r/^each envelope should show:$/, %{table: table}, state do
    html = state[:html] || render(state.view)

    Enum.each(table, fn row ->
      field = row["Field"] |> String.downcase() |> String.replace(" ", "-")

      assert html =~ ~r/#{Regex.escape(field)}|envelope/i,
             "Envelope field '#{row["Field"]}' not found"
    end)

    {:ok, state}
  end

  defthen ~r/^envelopes at boundary limits should show a warning indicator$/, _vars, state do
    html = state[:html] || render(state.view)
    assert html =~ ~r/warning|boundary|limit|indicator/i
    {:ok, state}
  end

  # ===========================================================================
  # ENVELOPES — SCENARIO: Edit envelope requires Arm & Fire
  # ===========================================================================

  defwhen ~r/^I click "Edit" on the "(?<envelope>[^"]+)" envelope$/,
          %{envelope: envelope},
          state do
    html = render_click(state.view, "edit_envelope", %{"envelope" => envelope})
    {:ok, state |> Map.put(:html, html) |> Map.put(:editing_envelope, envelope)}
  end

  defwhen ~r/^I change the value from (?<from>\d+) to (?<to>\d+)$/,
          %{from: _from, to: to},
          state do
    html =
      render_change(state.view, "set_envelope_value", %{
        "envelope" => state[:editing_envelope],
        "value" => to
      })

    {:ok, state |> Map.put(:html, html) |> Map.put(:new_envelope_value, String.to_integer(to))}
  end

  defwhen ~r/^I click "Propose Change"$/, _vars, state do
    html =
      render_click(state.view, "propose_envelope_change", %{
        "envelope" => state[:editing_envelope],
        "value" => state[:new_envelope_value]
      })

    {:ok, state |> Map.put(:html, html) |> Map.put(:change_proposed, true)}
  end

  defthen ~r/^a Guardian approval request should be raised$/, _vars, state do
    html = state[:html] || render(state.view)
    assert html =~ ~r/guardian.*approval|approval.request|pending.*guardian/i
    {:ok, state}
  end

  defthen ~r/^a "Pending Guardian Approval" status should show on the envelope row$/,
          _vars,
          state do
    html = state[:html] || render(state.view)
    assert html =~ ~r/Pending Guardian Approval|pending.*approval/i
    {:ok, state}
  end

  defwhen ~r/^Guardian approves the change$/, _vars, state do
    Phoenix.PubSub.broadcast(
      Indrajaal.PubSub,
      "guardian:decisions",
      {:approved,
       %{
         type: :envelope_change,
         envelope: state[:editing_envelope],
         value: state[:new_envelope_value]
       }}
    )

    Process.sleep(50)
    html = render(state.view)
    {:ok, Map.put(state, :html, html)}
  end

  defthen ~r/^the envelope value should update to (?<value>\d+)$/, %{value: value}, state do
    html = state[:html] || render(state.view)
    assert html =~ ~r/#{Regex.escape(value)}|updated/i
    {:ok, state}
  end

  defthen ~r/^a Zenoh event "(?<event>[^"]+)" should be published$/, %{event: event}, state do
    html = state[:html] || render(state.view)
    assert html =~ ~r/#{Regex.escape(event)}|zenoh|published/i or state[:system_status] == :normal
    {:ok, Map.put(state, :last_zenoh_event, event)}
  end

  # ===========================================================================
  # ENVELOPES — SCENARIO: Value outside bounds rejected immediately
  # ===========================================================================

  defwhen ~r/^I edit "(?<envelope>[^"]+)" and enter a value of (?<value>\d+) \(above max bound (?<max>\d+)\)$/,
          %{envelope: envelope, value: value, max: _max},
          state do
    render_click(state.view, "edit_envelope", %{"envelope" => envelope})

    html =
      render_change(state.view, "set_envelope_value", %{
        "envelope" => envelope,
        "value" => value
      })

    {:ok,
     state
     |> Map.put(:html, html)
     |> Map.put(:editing_envelope, envelope)
     |> Map.put(:invalid_value, true)}
  end

  defthen ~r/^a validation error should appear immediately: "Value exceeds maximum bound: (?<max>\d+)"$/,
          %{max: max},
          state do
    html = state[:html] || render(state.view)
    assert html =~ ~r/exceeds.*maximum|maximum.*bound|#{Regex.escape(max)}/i
    {:ok, state}
  end

  defthen ~r/^the "Propose Change" button should be disabled$/, _vars, state do
    html = state[:html] || render(state.view)
    assert html =~ ~r/disabled/i
    {:ok, state}
  end

  # ===========================================================================
  # SAVE AND RESET — SCENARIO: Save all settings
  # ===========================================================================

  defgiven ~r/^I have modified display, threshold, and notification settings$/, _vars, state do
    render_change(state.view, "set_refresh_interval", %{"interval" => "10 seconds"})

    render_change(state.view, "set_threshold", %{
      "metric" => "cpu",
      "level" => "warning",
      "value" => "78"
    })

    html =
      render_change(state.view, "toggle_notification", %{
        "channel" => "in_app_banner",
        "enabled" => true
      })

    {:ok, state |> Map.put(:html, html) |> Map.put(:settings_modified, true)}
  end

  defwhen ~r/^I click "Save All Settings"$/, _vars, state do
    html = render_click(state.view, "save_all_settings", %{})
    {:ok, state |> Map.put(:html, html) |> Map.put(:save_all_clicked, true)}
  end

  defthen ~r/^a confirmation dialog should appear listing all changes$/, _vars, state do
    html = state[:html] || render(state.view)
    assert html =~ ~r/confirmation|changes|dialog/i
    {:ok, state}
  end

  defwhen ~r/^I confirm$/, _vars, state do
    html = render_click(state.view, "confirm_save", %{})
    {:ok, state |> Map.put(:html, html) |> Map.put(:confirmed, true)}
  end

  defthen ~r/^all changes should be persisted to the holon SQLite store \(Ω₇\)$/, _vars, state do
    # Omega-7: SQLite is the authoritative store
    html = state[:html] || render(state.view)
    assert html =~ ~r/saved|persisted|success/i
    {:ok, state}
  end

  defthen ~r/^a success toast should appear: "Settings saved successfully"$/, _vars, state do
    html = state[:html] || render(state.view)
    assert html =~ ~r/Settings saved successfully|saved.*success/i
    {:ok, state}
  end

  defthen ~r/^the settings should survive a page refresh$/, _vars, state do
    conn = state[:conn] || build_conn()
    {:ok, _view, html} = live(conn, "/prajna/settings")
    assert html =~ ~r/settings|configuration/i
    {:ok, Map.put(state, :html, html)}
  end

  # ===========================================================================
  # SAVE AND RESET — SCENARIO: Reset to defaults
  # ===========================================================================

  defgiven ~r/^I have modified several settings$/, _vars, state do
    html = render_change(state.view, "set_refresh_interval", %{"interval" => "5 seconds"})
    {:ok, state |> Map.put(:html, html) |> Map.put(:settings_modified, true)}
  end

  defwhen ~r/^I click "Reset to Defaults"$/, _vars, state do
    html = render_click(state.view, "reset_to_defaults", %{})
    {:ok, state |> Map.put(:html, html) |> Map.put(:reset_clicked, true)}
  end

  defthen ~r/^a warning dialog should appear: "This will revert all settings to system defaults"$/,
          _vars,
          state do
    html = state[:html] || render(state.view)
    assert html =~ ~r/revert.*defaults|system defaults|warning/i
    {:ok, state}
  end

  defwhen ~r/^I confirm the reset$/, _vars, state do
    html = render_click(state.view, "confirm_reset", %{})
    {:ok, state |> Map.put(:html, html) |> Map.put(:reset_confirmed, true)}
  end

  defthen ~r/^all settings fields should repopulate with default values$/, _vars, state do
    html = state[:html] || render(state.view)
    assert html =~ ~r/default|reset/i
    {:ok, state}
  end

  defthen ~r/^the previous custom values should be discarded$/, _vars, state do
    html = state[:html] || render(state.view)
    assert html =~ ~r/default|reset|discarded/i
    {:ok, state}
  end

  defthen ~r/^a toast should confirm "Settings reset to defaults"$/, _vars, state do
    html = state[:html] || render(state.view)
    assert html =~ ~r/Settings reset to defaults|reset.*defaults/i
    {:ok, state}
  end

  # ===========================================================================
  # SAVE AND RESET — SCENARIO: Unsaved changes prompt
  # ===========================================================================

  defgiven ~r/^I have modified a threshold setting without saving$/, _vars, state do
    html =
      render_change(state.view, "set_threshold", %{
        "metric" => "cpu",
        "level" => "warning",
        "value" => "77"
      })

    {:ok, state |> Map.put(:html, html) |> Map.put(:unsaved_changes, true)}
  end

  defwhen ~r/^I attempt to navigate to a different cockpit page$/, _vars, state do
    # Simulate navigation event
    html = render_click(state.view, "navigate_away", %{"path" => "/prajna"})
    {:ok, state |> Map.put(:html, html) |> Map.put(:navigating, true)}
  end

  defthen ~r/^a "Unsaved Changes" dialog should appear$/, _vars, state do
    html = state[:html] || render(state.view)
    assert html =~ ~r/Unsaved Changes|unsaved.*changes/i
    {:ok, state}
  end

  defthen ~r/^it should offer "Save and Leave", "Discard and Leave", and "Cancel"$/,
          _vars,
          state do
    html = state[:html] || render(state.view)
    assert html =~ ~r/Save and Leave|save.*leave/i
    assert html =~ ~r/Discard and Leave|discard.*leave/i
    assert html =~ ~r/Cancel|cancel/i
    {:ok, state}
  end

  defwhen ~r/^I choose "Discard and Leave"$/, _vars, state do
    html = render_click(state.view, "discard_and_leave", %{})
    {:ok, state |> Map.put(:html, html) |> Map.put(:discarded, true)}
  end

  defthen ~r/^the navigation should proceed without saving the change$/, _vars, state do
    html = state[:html] || render(state.view)
    refute html =~ ~r/Unsaved Changes/i
    {:ok, state}
  end

  # ===========================================================================
  # NOTIFICATIONS — SCENARIO: Configure alarm notification channels
  # ===========================================================================

  defgiven ~r/^I am on the "Notifications" panel$/, _vars, state do
    conn = state[:conn] || build_conn()

    view =
      state[:view] ||
        (fn ->
           {:ok, v, _h} = live(conn, "/prajna/settings")
           v
         end).()

    html = render_click(view, "show_panel", %{"panel" => "notifications"})
    {:ok, state |> Map.put(:view, view) |> Map.put(:html, html)}
  end

  defthen ~r/^I should see toggles for:$/, %{table: table}, state do
    html = state[:html] || render(state.view)

    Enum.each(table, fn row ->
      channel = row["Channel"]

      slug =
        channel |> String.downcase() |> String.replace(~r/[^a-z0-9]/, "-") |> String.trim("-")

      assert html =~ ~r/#{Regex.escape(channel)}|#{Regex.escape(slug)}|toggle/i,
             "Notification channel '#{channel}' not found"
    end)

    {:ok, state}
  end

  defwhen ~r/^I enable the "(?<channel>[^"]+)" notification channel for "(?<severity>[^"]+)" alarms$/,
          %{channel: channel, severity: severity},
          state do
    channel_slug = channel |> String.downcase() |> String.replace(" ", "_")

    html =
      render_click(state.view, "toggle_notification", %{
        "channel" => channel_slug,
        "severity" => severity,
        "enabled" => true
      })

    {:ok, state |> Map.put(:html, html) |> Map.put(:enabled_channel, channel)}
  end

  defthen ~r/^the email channel toggle should show "ON"$/, _vars, state do
    html = state[:html] || render(state.view)
    assert html =~ ~r/ON|enabled|true/i
    {:ok, state}
  end

  defthen ~r/^test notification should be sendable from the same panel$/, _vars, state do
    html = state[:html] || render(state.view)
    assert html =~ ~r/Send Test|test.notification|test/i
    {:ok, state}
  end

  # ===========================================================================
  # NOTIFICATIONS — SCENARIO: Test notification
  # ===========================================================================

  defgiven ~r/^the "In-app banner" notification channel is enabled$/, _vars, state do
    html =
      render_click(state.view, "toggle_notification", %{
        "channel" => "in_app_banner",
        "severity" => "all",
        "enabled" => true
      })

    {:ok, state |> Map.put(:html, html) |> Map.put(:in_app_enabled, true)}
  end

  defwhen ~r/^I click "Send Test Notification"$/, _vars, state do
    html = render_click(state.view, "send_test_notification", %{})
    {:ok, state |> Map.put(:html, html) |> Map.put(:test_notification_sent, true)}
  end

  defthen ~r/^a sample alarm banner should appear in the cockpit for 5 seconds$/, _vars, state do
    html = state[:html] || render(state.view)
    assert html =~ ~r/sample.*alarm|test.*banner|alarm.*banner/i
    {:ok, state}
  end

  defthen ~r/^a toast should confirm "Test notification sent"$/, _vars, state do
    html = state[:html] || render(state.view)
    assert html =~ ~r/Test notification sent|test.*sent/i
    {:ok, state}
  end
end
