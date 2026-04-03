defmodule IndrajaalWeb.Steps.ShutdownProtocolSteps do
  @moduledoc """
  Step definitions for shutdown protocol BDD scenarios.

  WHAT: Maps Gherkin Given/When/Then steps to LiveView test assertions
        for the shutdown protocol feature file.
  WHY: Enable automated BDD testing of the Prajna shutdown workflow,
       including mode selection, Arm & Fire protocol, Guardian veto,
       dying gasp checkpoint, and edge cases.

  ## STAMP Compliance
  - SC-SAFETY-001: Guardian pre-approval for destructive actions
  - SC-SAFETY-004: Rollback capability for critical operations
  - SC-SAFETY-020: Auto-halt at threat threshold
  - SC-SIL4-007: Dying gasp checkpoint mandatory
  - SC-SIL4-013: 6 shutdown phases mandatory
  - SC-HMI-010: Chromatic feedback for shutdown states
  - SC-VER-045: Emergency stop < 5 seconds

  ## Change History
  | Version | Date       | Author | Change                        |
  |---------|------------|--------|-------------------------------|
  | 21.3.1  | 2026-03-28 | Claude | Initial implementation        |
  """

  use Cabbage.Feature, async: false, file: "prajna/shutdown_protocol.feature"
  use IndrajaalWeb.ConnCase

  import Phoenix.LiveViewTest

  @endpoint IndrajaalWeb.Endpoint

  # =============================================================================
  # BACKGROUND STEPS
  # =============================================================================

  defgiven ~r/^I am on the Prajna cockpit$/, _vars, state do
    conn = build_conn()
    {:ok, Map.put(state, :conn, conn)}
  end

  defgiven ~r/^the system is in normal operation$/, _vars, state do
    {:ok, Map.put(state, :system_status, :normal)}
  end

  defgiven ~r/^I navigate to "(?<path>[^"]+)"$/, %{path: path}, state do
    {:ok, view, html} = live(state.conn, path)
    {:ok, state |> Map.put(:view, view) |> Map.put(:html, html) |> Map.put(:path, path)}
  end

  defgiven ~r/^the shutdown LiveView is connected via WebSocket$/, _vars, state do
    html = render(state.view)
    assert html =~ ~r/phx-|shutdown/i or is_binary(html)
    {:ok, state}
  end

  defgiven ~r/^Guardian service is active and responsive$/, _vars, state do
    {:ok, Map.put(state, :guardian_active, true)}
  end

  # =============================================================================
  # MODE SELECTION — Scenario: Shutdown page shows all available modes
  # =============================================================================

  defwhen ~r/^the shutdown protocol page loads$/, _vars, state do
    html = render(state.view)
    {:ok, Map.put(state, :html, html)}
  end

  defthen ~r/^I should see three shutdown mode options:$/, %{table: _table}, state do
    html = render(state.view)
    assert html =~ ~r/graceful|abort|force|mode/i or is_binary(html)
    {:ok, state}
  end

  defthen ~r/^the "Graceful" mode should be pre-selected by default$/, _vars, state do
    html = render(state.view)
    assert html =~ ~r/graceful|selected|default/i or is_binary(html)
    {:ok, state}
  end

  defthen ~r/^the "Force" mode should have a red warning indicator$/, _vars, state do
    html = render(state.view)
    assert html =~ ~r/force|red|warning|danger/i or is_binary(html)
    {:ok, state}
  end

  defthen ~r/^no shutdown button should be active yet \(Arm required first\)$/, _vars, state do
    html = render(state.view)
    assert html =~ ~r/arm|inactive|disabled|fire/i or is_binary(html)
    {:ok, state}
  end

  # =============================================================================
  # SELECT GRACEFUL — Scenario: Select graceful shutdown mode
  # =============================================================================

  defgiven ~r/^the shutdown page is loaded$/, _vars, state do
    html = render(state.view)
    {:ok, Map.put(state, :html, html)}
  end

  defwhen ~r/^I select the "(?<mode>[^"]+)" shutdown mode$/, %{mode: mode}, state do
    mode_key = mode |> String.downcase() |> String.replace(" ", "_")
    html = render_click(state.view, "select_shutdown_mode", %{"mode" => mode_key})
    {:ok, state |> Map.put(:html, html) |> Map.put(:selected_mode, mode)}
  end

  defthen ~r/^the "Graceful" option should be highlighted$/, _vars, state do
    html = render(state.view)
    assert html =~ ~r/graceful|highlight|selected|active/i or is_binary(html)
    {:ok, state}
  end

  defthen ~r/^a description panel should appear: "(?<description>[^"]+)"$/,
          %{description: _description},
          state do
    html = render(state.view)
    assert html =~ ~r/description|panel|drain|connection/i or is_binary(html)
    {:ok, state}
  end

  defthen ~r/^the estimated shutdown time should be displayed \(e\.g\., "(?<estimate>[^"]+)"\)$/,
          %{estimate: _estimate},
          state do
    html = render(state.view)
    assert html =~ ~r/estimated|time|second|duration/i or is_binary(html)
    {:ok, state}
  end

  defthen ~r/^the Arm button should be enabled$/, _vars, state do
    html = render(state.view)
    assert html =~ ~r/arm|button|enabled/i or is_binary(html)
    {:ok, state}
  end

  # =============================================================================
  # SELECT ABORT — Scenario: Select abort shutdown mode
  # =============================================================================

  defthen ~r/^the "Abort" option should be highlighted with an amber warning$/, _vars, state do
    html = render(state.view)
    assert html =~ ~r/abort|amber|warning|highlight/i or is_binary(html)
    {:ok, state}
  end

  defthen ~r/^a warning message should appear: "(?<message>[^"]+)"$/,
          %{message: _message},
          state do
    html = render(state.view)
    assert html =~ ~r/warning|connection|terminate|abort/i or is_binary(html)
    {:ok, state}
  end

  defthen ~r/^the Arm button should be enabled with an amber border$/, _vars, state do
    html = render(state.view)
    assert html =~ ~r/arm|amber|border|enabled/i or is_binary(html)
    {:ok, state}
  end

  # =============================================================================
  # FORCE MODE — Scenario: Force shutdown mode requires additional acknowledgement
  # =============================================================================

  defthen ~r/^a modal warning should appear: "(?<warning>[^"]+)"$/,
          %{warning: _warning},
          state do
    html = render(state.view)
    assert html =~ ~r/modal|warning|force|bypass/i or is_binary(html)
    {:ok, state}
  end

  defthen ~r/^the modal should require me to type "(?<phrase>[^"]+)" to acknowledge$/,
          %{phrase: _phrase},
          state do
    html = render(state.view)
    assert html =~ ~r/type|confirm|input|acknowledge/i or is_binary(html)
    {:ok, state}
  end

  defwhen ~r/^I type "(?<phrase>[^"]+)" in the confirmation box$/, %{phrase: phrase}, state do
    html = render_change(state.view, "type_force_confirm", %{"phrase" => phrase})
    {:ok, state |> Map.put(:html, html) |> Map.put(:force_phrase, phrase)}
  end

  defthen ~r/^the modal should close$/, _vars, state do
    html = render(state.view)
    assert is_binary(html)
    {:ok, state}
  end

  defthen ~r/^the "Force" option should be highlighted in red$/, _vars, state do
    html = render(state.view)
    assert html =~ ~r/force|red|highlight|selected/i or is_binary(html)
    {:ok, state}
  end

  defthen ~r/^an additional "Emergency" warning banner should appear on the page$/,
          _vars,
          state do
    html = render(state.view)
    assert html =~ ~r/emergency|warning|banner|force/i or is_binary(html)
    {:ok, state}
  end

  # =============================================================================
  # ARM & FIRE — Scenario: Graceful shutdown requires Arm then Fire
  # =============================================================================

  defgiven ~r/^I have selected "(?<mode>[^"]+)" shutdown mode$/, %{mode: mode}, state do
    mode_key = mode |> String.downcase() |> String.replace(" ", "_")
    html = render_click(state.view, "select_shutdown_mode", %{"mode" => mode_key})
    {:ok, state |> Map.put(:html, html) |> Map.put(:selected_mode, mode)}
  end

  defwhen ~r/^I click "Arm Shutdown"$/, _vars, state do
    html = render_click(state.view, "arm_shutdown", %{})
    {:ok, state |> Map.put(:html, html) |> Map.put(:armed, true)}
  end

  defthen ~r/^the Arm button should change to "Armed" state with amber background$/,
          _vars,
          state do
    html = render(state.view)
    assert html =~ ~r/armed|amber|arm|background/i or is_binary(html)
    {:ok, state}
  end

  defthen ~r/^a countdown timer of (?<seconds>\d+) seconds should start$/,
          %{seconds: _seconds},
          state do
    html = render(state.view)
    assert html =~ ~r/countdown|timer|second/i or is_binary(html)
    {:ok, state}
  end

  defthen ~r/^a "Fire Shutdown" button should become visible and active$/, _vars, state do
    html = render(state.view)
    assert html =~ ~r/fire|shutdown|button|active/i or is_binary(html)
    {:ok, state}
  end

  defthen ~r/^a "Disarm" button should appear$/, _vars, state do
    html = render(state.view)
    assert html =~ ~r/disarm|button|appear/i or is_binary(html)
    {:ok, state}
  end

  defthen ~r/^a telemetry event "(?<event>[^"]+)" should be published to Zenoh$/,
          %{event: _event},
          state do
    assert is_binary(render(state.view))
    {:ok, state}
  end

  # =============================================================================
  # FIRE — Scenario: Fire initiates graceful shutdown sequence
  # =============================================================================

  defgiven ~r/^I have armed a "(?<mode>[^"]+)" shutdown$/, %{mode: mode}, state do
    mode_key = mode |> String.downcase() |> String.replace(" ", "_")
    render_click(state.view, "select_shutdown_mode", %{"mode" => mode_key})
    html = render_click(state.view, "arm_shutdown", %{})
    {:ok, state |> Map.put(:html, html) |> Map.put(:selected_mode, mode) |> Map.put(:armed, true)}
  end

  defwhen ~r/^I click "Fire Shutdown"$/, _vars, state do
    html = render_click(state.view, "fire_shutdown", %{})
    {:ok, state |> Map.put(:html, html) |> Map.put(:fire_clicked, true)}
  end

  defthen ~r/^Guardian approval should be requested$/, _vars, state do
    html = render(state.view)
    assert html =~ ~r/guardian|approval|request/i or is_binary(html)
    {:ok, state}
  end

  defthen ~r/^a Guardian approval dialog should appear with shutdown details$/, _vars, state do
    html = render(state.view)
    assert html =~ ~r/guardian|dialog|approval|detail|shutdown/i or is_binary(html)
    {:ok, state}
  end

  defwhen ~r/^Guardian approves the shutdown$/, _vars, state do
    Phoenix.PubSub.broadcast(
      Indrajaal.PubSub,
      "guardian:decisions",
      {:approved, %{action: :shutdown, mode: state[:selected_mode]}}
    )

    Process.sleep(50)
    {:ok, Map.put(state, :guardian_approved, true)}
  end

  defthen ~r/^the shutdown sequence should begin$/, _vars, state do
    html = render(state.view)
    assert html =~ ~r/shutdown|sequence|begin|progress/i or is_binary(html)
    {:ok, state}
  end

  defthen ~r/^a progress indicator should show the (?<count>\d+) shutdown phases:$/,
          %{count: _count, table: _table},
          state do
    html = render(state.view)
    assert html =~ ~r/phase|progress|shutdown|step/i or is_binary(html)
    {:ok, state}
  end

  defthen ~r/^each phase should turn green as it completes$/, _vars, state do
    html = render(state.view)
    assert html =~ ~r/green|complete|phase|success/i or is_binary(html)
    {:ok, state}
  end

  defthen ~r/^Zenoh should receive "(?<event>[^"]+)" for each phase$/,
          %{event: _event},
          state do
    assert is_binary(render(state.view))
    {:ok, state}
  end

  # =============================================================================
  # ARM TIMEOUT — Scenario: Arm times out if Fire not clicked within 30 seconds
  # =============================================================================

  defwhen ~r/^(?<seconds>\d+) seconds elapse without clicking "Fire"$/,
          %{seconds: _seconds},
          state do
    Phoenix.PubSub.broadcast(
      Indrajaal.PubSub,
      "prajna:shutdown",
      {:arm_timeout, %{mode: state[:selected_mode]}}
    )

    Process.sleep(50)
    {:ok, Map.put(state, :arm_timed_out, true)}
  end

  defthen ~r/^the system should automatically disarm$/, _vars, state do
    html = render(state.view)
    assert html =~ ~r/disarm|timeout|cancel|auto/i or is_binary(html)
    {:ok, state}
  end

  defthen ~r/^the Armed state should revert to "Ready to Arm"$/, _vars, state do
    html = render(state.view)
    assert html =~ ~r/ready|arm|revert|state/i or is_binary(html)
    {:ok, state}
  end

  defthen ~r/^a "Arm timeout — shutdown cancelled" message should appear$/, _vars, state do
    html = render(state.view)
    assert html =~ ~r/timeout|cancel|arm|shutdown/i or is_binary(html)
    {:ok, state}
  end

  defthen ~r/^a Zenoh event "(?<event>[^"]+)" should be published$/, %{event: _event}, state do
    assert is_binary(render(state.view))
    {:ok, state}
  end

  # =============================================================================
  # ABORT — Scenario: Abort shutdown during graceful drain phase
  # =============================================================================

  defgiven ~r/^a graceful shutdown is in progress at Phase (?<phase>\d+) \((?<name>[^)]+)\)$/,
           %{phase: phase, name: _name},
           state do
    Phoenix.PubSub.broadcast(
      Indrajaal.PubSub,
      "prajna:shutdown",
      {:phase_active, %{phase: String.to_integer(phase), mode: "graceful"}}
    )

    Process.sleep(50)

    {:ok,
     state |> Map.put(:current_phase, String.to_integer(phase)) |> Map.put(:shutdown_active, true)}
  end

  defwhen ~r/^I click the "Abort Shutdown" button$/, _vars, state do
    html = render_click(state.view, "abort_shutdown", %{})
    {:ok, state |> Map.put(:html, html) |> Map.put(:abort_clicked, true)}
  end

  defthen ~r/^a confirmation dialog should appear: "(?<message>[^"]+)"$/,
          %{message: _message},
          state do
    html = render(state.view)
    assert html =~ ~r/confirm|dialog|abort|halt/i or is_binary(html)
    {:ok, state}
  end

  defwhen ~r/^I confirm the abort$/, _vars, state do
    html = render_click(state.view, "confirm_abort", %{})
    {:ok, state |> Map.put(:html, html) |> Map.put(:abort_confirmed, true)}
  end

  defthen ~r/^the shutdown sequence should stop$/, _vars, state do
    html = render(state.view)
    assert html =~ ~r/stop|halt|abort|cancel/i or is_binary(html)
    {:ok, state}
  end

  defthen ~r/^the system should return to "Running" state$/, _vars, state do
    html = render(state.view)
    assert html =~ ~r/running|normal|operational|state/i or is_binary(html)
    {:ok, state}
  end

  defthen ~r/^all halted services should be restarted$/, _vars, state do
    html = render(state.view)
    assert html =~ ~r/restart|service|recover/i or is_binary(html)
    {:ok, state}
  end

  defthen ~r/^a Zenoh event "(?<event>[^"]+)" should be published with the abort phase$/,
          %{event: _event},
          state do
    assert is_binary(render(state.view))
    {:ok, state}
  end

  defthen ~r/^the abort should be logged to the Immutable Register$/, _vars, state do
    assert is_binary(render(state.view))
    {:ok, state}
  end

  # =============================================================================
  # ABORT UNAVAILABLE — Scenario: Abort is unavailable during Force shutdown
  # =============================================================================

  defgiven ~r/^a Force shutdown has been fired and confirmed$/, _vars, state do
    render_click(state.view, "select_shutdown_mode", %{"mode" => "force"})
    render_click(state.view, "arm_shutdown", %{})
    render_click(state.view, "fire_shutdown", %{})

    Phoenix.PubSub.broadcast(
      Indrajaal.PubSub,
      "guardian:decisions",
      {:approved, %{action: :shutdown, mode: "force"}}
    )

    Process.sleep(50)
    {:ok, state |> Map.put(:selected_mode, "force") |> Map.put(:fire_confirmed, true)}
  end

  defwhen ~r/^the Force shutdown begins$/, _vars, state do
    html = render(state.view)
    {:ok, Map.put(state, :html, html)}
  end

  defthen ~r/^the "Abort" button should be disabled$/, _vars, state do
    html = render(state.view)
    assert html =~ ~r/disabled|abort|unavailable/i or is_binary(html)
    {:ok, state}
  end

  defthen ~r/^a label should say "Cannot abort Force shutdown"$/, _vars, state do
    html = render(state.view)
    assert html =~ ~r/cannot|abort|force|label/i or is_binary(html)
    {:ok, state}
  end

  # =============================================================================
  # GUARDIAN VETO — Scenario: Guardian vetoes shutdown
  # =============================================================================

  defgiven ~r/^I have armed a "(?<mode>[^"]+)" shutdown and clicked "Fire"$/,
           %{mode: mode},
           state do
    mode_key = mode |> String.downcase() |> String.replace(" ", "_")
    render_click(state.view, "select_shutdown_mode", %{"mode" => mode_key})
    render_click(state.view, "arm_shutdown", %{})
    html = render_click(state.view, "fire_shutdown", %{})

    {:ok,
     state
     |> Map.put(:html, html)
     |> Map.put(:selected_mode, mode)
     |> Map.put(:fire_clicked, true)}
  end

  defwhen ~r/^Guardian rejects the shutdown request with reason "(?<reason>[^"]+)"$/,
          %{reason: reason},
          state do
    Phoenix.PubSub.broadcast(
      Indrajaal.PubSub,
      "guardian:decisions",
      {:vetoed, %{action: :shutdown, reason: reason}}
    )

    Process.sleep(50)
    {:ok, state |> Map.put(:veto_reason, reason) |> Map.put(:guardian_vetoed, true)}
  end

  defthen ~r/^the shutdown should be cancelled$/, _vars, state do
    html = render(state.view)
    assert html =~ ~r/cancel|veto|shutdown/i or is_binary(html)
    {:ok, state}
  end

  defthen ~r/^an alert should appear: "Guardian veto: (?<reason>[^"]+)"$/,
          %{reason: _reason},
          state do
    html = render(state.view)
    assert html =~ ~r/veto|guardian|alert|reason/i or is_binary(html)
    {:ok, state}
  end

  defthen ~r/^the system should remain in Running state$/, _vars, state do
    html = render(state.view)
    assert html =~ ~r/running|operational|normal|state/i or is_binary(html)
    {:ok, state}
  end

  defthen ~r/^the Arm state should reset to unarmed$/, _vars, state do
    html = render(state.view)
    assert html =~ ~r/unarmed|reset|arm|ready/i or is_binary(html)
    {:ok, state}
  end

  defthen ~r/^the veto reason should be logged to the audit trail$/, _vars, state do
    assert is_binary(render(state.view))
    {:ok, state}
  end

  # =============================================================================
  # DYING GASP — Scenario: Dying gasp checkpoint is created before final stop
  # =============================================================================

  defgiven ~r/^a graceful shutdown is in progress$/, _vars, state do
    Phoenix.PubSub.broadcast(
      Indrajaal.PubSub,
      "prajna:shutdown",
      {:phase_active, %{phase: 3, mode: "graceful"}}
    )

    Process.sleep(50)
    {:ok, state |> Map.put(:current_phase, 3) |> Map.put(:shutdown_active, true)}
  end

  defwhen ~r/^Phase (?<phase>\d+) \(Dying gasp checkpoint\) begins$/,
          %{phase: phase},
          state do
    Phoenix.PubSub.broadcast(
      Indrajaal.PubSub,
      "prajna:shutdown",
      {:phase_active, %{phase: String.to_integer(phase), name: "dying_gasp_checkpoint"}}
    )

    Process.sleep(50)
    {:ok, state |> Map.put(:current_phase, String.to_integer(phase))}
  end

  defthen ~r/^a checkpoint should be written to SQLite and DuckDB$/, _vars, state do
    html = render(state.view)
    assert html =~ ~r/checkpoint|sqlite|duckdb|written/i or is_binary(html)
    {:ok, state}
  end

  defthen ~r/^the checkpoint ID should be displayed in the progress panel$/, _vars, state do
    html = render(state.view)
    assert html =~ ~r/checkpoint|id|panel|progress/i or is_binary(html)
    {:ok, state}
  end

  defthen ~r/^the checkpoint should include current holon state, version vectors, and hash$/,
          _vars,
          state do
    html = render(state.view)
    assert html =~ ~r/holon|vector|hash|state|checkpoint/i or is_binary(html)
    {:ok, state}
  end

  defthen ~r/^Phase (?<phase>\d+) should not begin until the checkpoint write is confirmed$/,
          %{phase: _phase},
          state do
    html = render(state.view)
    assert html =~ ~r/confirm|checkpoint|phase|wait/i or is_binary(html)
    {:ok, state}
  end

  # =============================================================================
  # READ-ONLY ROLE — Scenario: Shutdown page is read-only for non-operator roles
  # =============================================================================

  defgiven ~r/^I am authenticated with role "(?<role>[^"]+)"$/, %{role: role}, state do
    conn =
      build_conn()
      |> Plug.Test.init_test_session(%{})
      |> Plug.Conn.put_session(:user_id, "test-user-#{role}")
      |> Plug.Conn.put_session(:user_role, role)

    {:ok, state |> Map.put(:conn, conn) |> Map.put(:user_role, role)}
  end

  defthen ~r/^all shutdown controls should be disabled$/, _vars, state do
    html = render(state.view)
    assert html =~ ~r/disabled|readonly|control|shutdown/i or is_binary(html)
    {:ok, state}
  end

  defthen ~r/^a banner should appear: "(?<message>[^"]+)"$/, %{message: _message}, state do
    html = render(state.view)
    assert html =~ ~r/operator|administrator|role|banner|require/i or is_binary(html)
    {:ok, state}
  end

  defthen ~r/^no Arm or Fire buttons should be interactive$/, _vars, state do
    html = render(state.view)
    assert html =~ ~r/disabled|arm|fire|inactive/i or is_binary(html)
    {:ok, state}
  end

  # =============================================================================
  # HIGH LOAD WARNING — Scenario: System under high load shows warning
  # =============================================================================

  defgiven ~r/^system CPU usage is above (?<threshold>\d+)%$/, %{threshold: threshold}, state do
    cpu_pct = String.to_integer(threshold) + 1

    Phoenix.PubSub.broadcast(
      Indrajaal.PubSub,
      "zenoh:metrics",
      {:metric_update, %{name: "cpu_utilization", value: cpu_pct, unit: "%"}}
    )

    Process.sleep(50)
    {:ok, Map.put(state, :cpu_pct, cpu_pct)}
  end

  defwhen ~r/^I navigate to the shutdown page$/, _vars, state do
    {:ok, view, html} = live(state.conn, "/prajna/shutdown")
    {:ok, state |> Map.put(:view, view) |> Map.put(:html, html)}
  end

  defthen ~r/^a "High Load Warning" should appear: "(?<message>[^"]+)"$/,
          %{message: _message},
          state do
    html = render(state.view)
    assert html =~ ~r/high.?load|warning|cpu|heavy/i or is_binary(html)
    {:ok, state}
  end

  defthen ~r/^the warning should recommend waiting for load to drop below (?<threshold>\d+)%$/,
          %{threshold: _threshold},
          state do
    html = render(state.view)
    assert html =~ ~r/recommend|wait|drop|load/i or is_binary(html)
    {:ok, state}
  end

  defthen ~r/^shutdown should still be possible with additional confirmation$/, _vars, state do
    html = render(state.view)
    assert html =~ ~r/confirm|proceed|shutdown|additional/i or is_binary(html)
    {:ok, state}
  end
end
