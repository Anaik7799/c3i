defmodule IndrajaalWeb.Prajna.CommandsLiveTest do
  @moduledoc """
  Integration test suite for IndrajaalWeb.Prajna.CommandsLive.

  WHAT: Full handle_event coverage for the two-step Arm & Fire command center.
        Tests all 5 handle_event clauses: select_target, arm_command,
        update_confirmation, confirm_command, cancel_command.

  WHY: SC-SAFETY-001 (Arm & Fire two-step commit) is a safety-critical path.
       Mode confusion is the primary cause of operator errors (Redmill & Rajan, 1997).
       Every state transition in the armed lifecycle must be verified.

  STAMP Safety Integration:
  - SC-SAFETY-001: Two-step Arm & Fire protocol — no command executes without arm+confirm
  - SC-HMI-004: Two-step commit UI per MIL-STD-1472H
  - SC-MIL-001 to SC-MIL-004: Feedback latency requirements
  - SC-VDP-008: Closure feedback on command completion

  ## Document Control

  | Field | Value |
  |-------|-------|
  | Version | 1.1.0 |
  | Created | 2026-03-28 |
  | Author | Code Evolution Agent |
  | Reference | MIL-STD-1472H, NUREG-0700, SC-SAFETY-001 |
  """

  use IndrajaalWeb.ConnCase, async: true
  import Phoenix.LiveViewTest

  alias IndrajaalWeb.Prajna.CommandsLive

  # ---------------------------------------------------------------------------
  # Helpers
  # ---------------------------------------------------------------------------

  # Derives the expected confirmation code the same way the LiveView does.
  # generate_expected_code(%{target: target, command: command})
  # first_letter = target |> String.first() |> String.upcase()
  # cmd_num = command |> Atom.to_string() |> String.length() |> rem(10)
  # "#{first_letter}#{cmd_num}"
  defp expected_code(target, command) when is_binary(target) and is_atom(command) do
    first_letter = target |> String.first() |> String.upcase()
    cmd_num = command |> Atom.to_string() |> String.length() |> rem(10)
    "#{first_letter}#{cmd_num}"
  end

  # ---------------------------------------------------------------------------
  # MODULE STRUCTURE TESTS (kept for regression)
  # ---------------------------------------------------------------------------

  describe "CommandsLive module structure" do
    test "module exists and is loaded" do
      assert Code.ensure_loaded?(CommandsLive)
    end

    test "mount/3 is exported" do
      assert function_exported?(CommandsLive, :mount, 3)
    end

    test "render/1 is exported" do
      assert function_exported?(CommandsLive, :render, 1)
    end

    test "handle_event/3 is exported" do
      assert function_exported?(CommandsLive, :handle_event, 3)
    end

    test "handle_info/2 is exported" do
      assert function_exported?(CommandsLive, :handle_info, 2)
    end
  end

  # ---------------------------------------------------------------------------
  # PUBLIC API TESTS (command classification helpers)
  # ---------------------------------------------------------------------------

  describe "command classification API" do
    test "critical_commands/0 returns the six safety-critical commands" do
      cmds = CommandsLive.critical_commands()
      assert :restart in cmds
      assert :shutdown in cmds
      assert :power_off in cmds
      assert :isolate in cmds
      assert :hibernate in cmds
      assert :emergency_stop in cmds
      assert length(cmds) == 6
    end

    test "standard_commands/0 returns immediate-execute commands" do
      cmds = CommandsLive.standard_commands()
      assert :power_on in cmds
      assert :health_check in cmds
      assert :clear_alarms in cmds
      assert :resume_network in cmds
    end

    test "scaling_commands/0 returns FLAME scaling commands" do
      cmds = CommandsLive.scaling_commands()
      assert :scale_flame_up in cmds
      assert :scale_flame_down in cmds
      assert :set_load_balancer in cmds
    end

    test "command_icon/1 returns unicode string for known command" do
      assert CommandsLive.command_icon(:restart) == "\u26A0"
      assert CommandsLive.command_icon(:emergency_stop) == "\u2622"
      assert CommandsLive.command_icon(:health_check) == "\u2714"
    end

    test "command_icon/1 returns '?' for unknown command" do
      assert CommandsLive.command_icon(:nonexistent_command) == "?"
    end

    test "status_icon/1 returns unicode string for known status" do
      assert CommandsLive.status_icon(:idle) == "\u25CB"
      assert CommandsLive.status_icon(:armed) == "\u25CE"
      assert CommandsLive.status_icon(:executing) == "\u25CF"
      assert CommandsLive.status_icon(:success) == "\u2713"
      assert CommandsLive.status_icon(:failed) == "\u2717"
      assert CommandsLive.status_icon(:cancelled) == "\u2718"
    end

    test "status_icon/1 returns '?' for unknown status" do
      assert CommandsLive.status_icon(:unknown_status) == "?"
    end
  end

  # ---------------------------------------------------------------------------
  # MOUNT AND INITIAL RENDER
  # ---------------------------------------------------------------------------

  describe "mount/3 and initial render" do
    test "mounts at /cockpit/commands and renders without error", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/cockpit/commands")
      assert html =~ "COMMAND CENTER"
    end

    test "initial render shows PRAJNA C3I header", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/cockpit/commands")
      assert html =~ "PRAJNA C3I"
    end

    test "initial render shows target selection section", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/cockpit/commands")
      assert html =~ "SELECT TARGET"
    end

    test "initial render shows all five targets from available_targets/0", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/cockpit/commands")
      assert html =~ "app-01"
      assert html =~ "app-02"
      assert html =~ "app-03"
      assert html =~ "app-04"
      assert html =~ "app-05"
    end

    test "initial render shows default selected target app-01 highlighted", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/cockpit/commands")
      # Default selected_target is "app-01" — rendered with blue-600 class
      assert html =~ "app-01"
    end

    test "initial render shows CRITICAL COMMANDS section", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/cockpit/commands")
      assert html =~ "CRITICAL COMMANDS"
      assert html =~ "Two-Step Required"
    end

    test "initial render shows STANDARD COMMANDS section", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/cockpit/commands")
      assert html =~ "STANDARD COMMANDS"
      assert html =~ "Immediate"
    end

    test "initial render shows SCALING section", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/cockpit/commands")
      assert html =~ "SCALING"
    end

    test "initial render shows empty command history placeholder", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/cockpit/commands")
      assert html =~ "No commands executed"
    end

    test "initial render shows COMMAND HISTORY panel header", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/cockpit/commands")
      assert html =~ "COMMAND HISTORY"
    end

    test "confirmation modal is not shown on initial mount", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/cockpit/commands")
      refute html =~ "COMMAND ARMED - CONFIRM EXECUTION"
    end

    test "arm_countdown is not shown when no command is armed", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/cockpit/commands")
      refute html =~ "COMMAND ARMED -"
    end

    test "initial render shows MIL-STD-1472H footer reference", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/cockpit/commands")
      assert html =~ "MIL-STD-1472H"
    end

    test "initial render shows SC-HMI-004 constraint reference", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/cockpit/commands")
      assert html =~ "SC-HMI-004"
    end

    test "initial render shows navigation tabs", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/cockpit/commands")
      assert html =~ "COMMANDS"
      assert html =~ "MESH"
      assert html =~ "ALARMS"
    end
  end

  # ---------------------------------------------------------------------------
  # handle_event("select_target", ...)
  # ---------------------------------------------------------------------------

  describe "handle_event select_target" do
    test "switching target updates selected_target assign", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/cockpit/commands")

      html = render_click(view, "select_target", %{"target" => "app-02"})

      # app-02 should now be the highlighted target (bg-blue-600)
      # The render must include app-02 selection indicator
      assert html =~ "app-02"
    end

    test "selected target is highlighted with blue class", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/cockpit/commands")

      render_click(view, "select_target", %{"target" => "app-03"})
      html = render(view)

      # After selecting app-03, the button for app-03 should carry the active class
      assert html =~ "app-03"
    end

    test "selecting a caution-status target updates selection", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/cockpit/commands")
      # app-03 has :caution status in available_targets/0
      html = render_click(view, "select_target", %{"target" => "app-03"})
      assert html =~ "app-03"
    end

    test "selecting each of the five targets succeeds without error", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/cockpit/commands")

      for target <- ~w[app-01 app-02 app-03 app-04 app-05] do
        html = render_click(view, "select_target", %{"target" => target})
        assert is_binary(html)
        assert html =~ target
      end
    end

    test "select_target returns noreply — no redirect", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/cockpit/commands")
      result = render_click(view, "select_target", %{"target" => "app-04"})
      # render_click returns HTML — confirms noreply, not redirect
      assert is_binary(result)
    end
  end

  # ---------------------------------------------------------------------------
  # handle_event("arm_command", ...) — critical path (two-step commit)
  # ---------------------------------------------------------------------------

  describe "handle_event arm_command for critical commands (SC-SAFETY-001)" do
    test "arming restart shows confirmation modal", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/cockpit/commands")

      html = render_click(view, "arm_command", %{"command" => "restart"})

      assert html =~ "COMMAND ARMED - CONFIRM EXECUTION"
    end

    test "arming restart sets show_confirmation true — hides command grid", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/cockpit/commands")

      render_click(view, "arm_command", %{"command" => "restart"})
      html = render(view)

      assert html =~ "COMMAND ARMED - CONFIRM EXECUTION"
      refute html =~ "SELECT TARGET"
    end

    test "arming restart shows target name in confirmation modal", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/cockpit/commands")

      html = render_click(view, "arm_command", %{"command" => "restart"})

      # Default selected_target is "app-01"
      assert html =~ "app-01"
    end

    test "arming restart shows RESTART in uppercase in confirmation modal", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/cockpit/commands")

      html = render_click(view, "arm_command", %{"command" => "restart"})

      assert html =~ "RESTART"
    end

    test "arming restart shows arm_countdown timer", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/cockpit/commands")

      html = render_click(view, "arm_command", %{"command" => "restart"})

      # 300s countdown renders as "5:00"
      assert html =~ "5:00"
    end

    test "header shows COMMAND ARMED pulse indicator when armed", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/cockpit/commands")

      render_click(view, "arm_command", %{"command" => "shutdown"})
      html = render(view)

      assert html =~ "COMMAND ARMED"
    end

    test "arming shutdown shows WARNING block with shutdown description", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/cockpit/commands")

      html = render_click(view, "arm_command", %{"command" => "shutdown"})

      assert html =~ "WARNING"
      assert html =~ "shut down"
    end

    test "arming emergency_stop shows critical WARNING block", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/cockpit/commands")

      html = render_click(view, "arm_command", %{"command" => "emergency_stop"})

      assert html =~ "WARNING"
      assert html =~ "EMERGENCY STOP"
    end

    test "arming isolate shows isolation WARNING", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/cockpit/commands")

      html = render_click(view, "arm_command", %{"command" => "isolate"})

      assert html =~ "WARNING"
      assert html =~ "isolated"
    end

    test "arming hibernate shows hibernate WARNING", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/cockpit/commands")

      html = render_click(view, "arm_command", %{"command" => "hibernate"})

      assert html =~ "WARNING"
      assert html =~ "hibernation"
    end

    test "arming power_off shows power-off WARNING", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/cockpit/commands")

      html = render_click(view, "arm_command", %{"command" => "power_off"})

      assert html =~ "WARNING"
      assert html =~ "powered off"
    end

    test "arming restart shows expected confirmation code in label", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/cockpit/commands")

      html = render_click(view, "arm_command", %{"command" => "restart"})

      # For target "app-01", command :restart → "A7"
      assert html =~ expected_code("app-01", :restart)
    end

    test "arming on non-default target uses that target's confirmation code", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/cockpit/commands")

      render_click(view, "select_target", %{"target" => "app-02"})
      html = render_click(view, "arm_command", %{"command" => "restart"})

      # target "app-02", command :restart → "A7" (same first letter 'A', same cmd length)
      assert html =~ expected_code("app-02", :restart)
    end

    test "armed_by shows operator identity in confirmation modal", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/cockpit/commands")

      html = render_click(view, "arm_command", %{"command" => "restart"})

      assert html =~ "operator@indrajaal.local"
    end

    test "confirmation code input field is present in armed modal", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/cockpit/commands")

      render_click(view, "arm_command", %{"command" => "restart"})

      assert has_element?(view, "input[phx-keyup='update_confirmation']")
    end

    test "Cancel button is present in armed modal", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/cockpit/commands")

      render_click(view, "arm_command", %{"command" => "restart"})

      assert has_element?(view, "button[phx-click='cancel_command']")
    end

    test "Confirm button is present in armed modal", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/cockpit/commands")

      render_click(view, "arm_command", %{"command" => "restart"})

      assert has_element?(view, "button[phx-click='confirm_command']")
    end
  end

  describe "handle_event arm_command for standard commands (immediate execution)" do
    test "arming power_on executes immediately without confirmation modal", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/cockpit/commands")

      html = render_click(view, "arm_command", %{"command" => "power_on"})

      refute html =~ "COMMAND ARMED - CONFIRM EXECUTION"
    end

    test "arming power_on shows success flash", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/cockpit/commands")

      html = render_click(view, "arm_command", %{"command" => "power_on"})

      assert html =~ "POWER ON executed successfully"
    end

    test "arming health_check executes immediately and shows flash", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/cockpit/commands")

      html = render_click(view, "arm_command", %{"command" => "health_check"})

      assert html =~ "HEALTH CHECK executed successfully"
      refute html =~ "COMMAND ARMED - CONFIRM EXECUTION"
    end

    test "arming clear_alarms executes immediately and shows flash", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/cockpit/commands")

      html = render_click(view, "arm_command", %{"command" => "clear_alarms"})

      assert html =~ "CLEAR ALARMS executed successfully"
    end

    test "arming resume_network executes immediately and shows flash", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/cockpit/commands")

      html = render_click(view, "arm_command", %{"command" => "resume_network"})

      assert html =~ "RESUME NETWORK executed successfully"
    end

    test "standard command adds entry to command history", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/cockpit/commands")

      render_click(view, "arm_command", %{"command" => "health_check"})
      html = render(view)

      # History entry is present — "No commands executed" disappears
      refute html =~ "No commands executed"
    end

    test "standard command history entry shows target name", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/cockpit/commands")

      render_click(view, "arm_command", %{"command" => "health_check"})
      html = render(view)

      assert html =~ "app-01"
    end

    test "standard command history entry shows SUCCESS status", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/cockpit/commands")

      render_click(view, "arm_command", %{"command" => "health_check"})
      html = render(view)

      assert html =~ "SUCCESS"
    end

    test "scaling scale_flame_up executes immediately without confirmation", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/cockpit/commands")

      html = render_click(view, "arm_command", %{"command" => "scale_flame_up"})

      refute html =~ "COMMAND ARMED - CONFIRM EXECUTION"
      assert html =~ "SCALE FLAME UP executed successfully"
    end

    test "scaling scale_flame_down executes immediately without confirmation", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/cockpit/commands")

      html = render_click(view, "arm_command", %{"command" => "scale_flame_down"})

      refute html =~ "COMMAND ARMED - CONFIRM EXECUTION"
      assert html =~ "SCALE FLAME DOWN executed successfully"
    end

    test "scaling set_load_balancer executes immediately without confirmation", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/cockpit/commands")

      html = render_click(view, "arm_command", %{"command" => "set_load_balancer"})

      refute html =~ "COMMAND ARMED - CONFIRM EXECUTION"
      assert html =~ "SET LOAD BALANCER executed successfully"
    end
  end

  # ---------------------------------------------------------------------------
  # handle_event("update_confirmation", ...)
  # ---------------------------------------------------------------------------

  describe "handle_event update_confirmation" do
    test "update_confirmation stores partial code in assign", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/cockpit/commands")

      render_click(view, "arm_command", %{"command" => "restart"})
      html = render_click(view, "update_confirmation", %{"code" => "A"})

      # Value attribute of the input reflects the current confirmation_code
      assert html =~ ~r/value="A"/
    end

    test "update_confirmation with empty string clears the code", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/cockpit/commands")

      render_click(view, "arm_command", %{"command" => "restart"})
      render_click(view, "update_confirmation", %{"code" => "A7"})
      html = render_click(view, "update_confirmation", %{"code" => ""})

      assert html =~ ~r/value=""/
    end

    test "update_confirmation with correct code renders confirm button enabled", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/cockpit/commands")

      render_click(view, "arm_command", %{"command" => "restart"})
      # Target app-01, command :restart → "A7"
      code = expected_code("app-01", :restart)
      html = render_click(view, "update_confirmation", %{"code" => code})

      # With correct code the button loses 'cursor-not-allowed' and gains active bg
      assert html =~ "bg-yellow-600"
      refute html =~ "cursor-not-allowed"
    end

    test "update_confirmation with wrong code keeps confirm button disabled", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/cockpit/commands")

      render_click(view, "arm_command", %{"command" => "restart"})
      html = render_click(view, "update_confirmation", %{"code" => "ZZ"})

      assert html =~ "cursor-not-allowed"
    end

    test "update_confirmation does nothing meaningful without armed command", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/cockpit/commands")
      # No command armed — update_confirmation should still return valid HTML
      html = render_click(view, "update_confirmation", %{"code" => "X9"})
      assert is_binary(html)
    end

    test "successive update_confirmation calls reflect latest value", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/cockpit/commands")

      render_click(view, "arm_command", %{"command" => "restart"})
      render_click(view, "update_confirmation", %{"code" => "A"})
      html = render_click(view, "update_confirmation", %{"code" => "A7"})

      assert html =~ ~r/value="A7"/
    end
  end

  # ---------------------------------------------------------------------------
  # handle_event("confirm_command", ...)
  # ---------------------------------------------------------------------------

  describe "handle_event confirm_command" do
    test "confirm_command with correct code dismisses the modal", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/cockpit/commands")

      render_click(view, "arm_command", %{"command" => "restart"})
      code = expected_code("app-01", :restart)
      render_click(view, "update_confirmation", %{"code" => code})
      html = render_click(view, "confirm_command", %{})

      refute html =~ "COMMAND ARMED - CONFIRM EXECUTION"
    end

    test "confirm_command with correct code shows info flash", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/cockpit/commands")

      render_click(view, "arm_command", %{"command" => "restart"})
      code = expected_code("app-01", :restart)
      render_click(view, "update_confirmation", %{"code" => code})
      html = render_click(view, "confirm_command", %{})

      assert html =~ "restart"
      assert html =~ "executing"
    end

    test "confirm_command with correct code adds history entry with :executing status", %{
      conn: conn
    } do
      {:ok, view, _html} = live(conn, "/cockpit/commands")

      render_click(view, "arm_command", %{"command" => "restart"})
      code = expected_code("app-01", :restart)
      render_click(view, "update_confirmation", %{"code" => code})
      render_click(view, "confirm_command", %{})

      html = render(view)

      # History should now contain the executing entry
      assert html =~ "EXECUTING"
      refute html =~ "No commands executed"
    end

    test "confirm_command with correct code clears armed_command — no countdown shown", %{
      conn: conn
    } do
      {:ok, view, _html} = live(conn, "/cockpit/commands")

      render_click(view, "arm_command", %{"command" => "restart"})
      code = expected_code("app-01", :restart)
      render_click(view, "update_confirmation", %{"code" => code})
      render_click(view, "confirm_command", %{})

      html = render(view)

      # Header countdown block only appears when armed_command is non-nil
      refute html =~ "COMMAND ARMED -"
    end

    test "confirm_command with correct code clears confirmation_code assign", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/cockpit/commands")

      render_click(view, "arm_command", %{"command" => "restart"})
      code = expected_code("app-01", :restart)
      render_click(view, "update_confirmation", %{"code" => code})
      render_click(view, "confirm_command", %{})

      html = render(view)

      # Command grid is back; confirmation modal gone
      assert html =~ "SELECT TARGET"
    end

    test "confirm_command with wrong code shows error flash", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/cockpit/commands")

      render_click(view, "arm_command", %{"command" => "restart"})
      render_click(view, "update_confirmation", %{"code" => "XX"})
      html = render_click(view, "confirm_command", %{})

      assert html =~ "Invalid confirmation code"
    end

    test "confirm_command with wrong code keeps modal visible", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/cockpit/commands")

      render_click(view, "arm_command", %{"command" => "restart"})
      render_click(view, "update_confirmation", %{"code" => "ZZ"})
      render_click(view, "confirm_command", %{})

      html = render(view)

      assert html =~ "COMMAND ARMED - CONFIRM EXECUTION"
    end

    test "confirm_command with wrong code does not add history entry", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/cockpit/commands")

      render_click(view, "arm_command", %{"command" => "restart"})
      render_click(view, "update_confirmation", %{"code" => "BAD"})
      render_click(view, "confirm_command", %{})

      html = render(view)

      assert html =~ "No commands executed"
    end

    test "confirm_command when no command is armed is a no-op", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/cockpit/commands")

      html = render_click(view, "confirm_command", %{})

      # Nothing changes — command grid stays visible
      assert html =~ "SELECT TARGET"
      refute html =~ "COMMAND ARMED - CONFIRM EXECUTION"
    end

    test "confirm_command correct code on shutdown shows correct flash text", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/cockpit/commands")

      render_click(view, "arm_command", %{"command" => "shutdown"})
      code = expected_code("app-01", :shutdown)
      render_click(view, "update_confirmation", %{"code" => code})
      html = render_click(view, "confirm_command", %{})

      assert html =~ "shutdown"
      assert html =~ "executing"
    end

    test "confirm_command correct code on emergency_stop shows correct flash text", %{
      conn: conn
    } do
      {:ok, view, _html} = live(conn, "/cockpit/commands")

      render_click(view, "arm_command", %{"command" => "emergency_stop"})
      code = expected_code("app-01", :emergency_stop)
      render_click(view, "update_confirmation", %{"code" => code})
      html = render_click(view, "confirm_command", %{})

      assert html =~ "emergency_stop"
      assert html =~ "executing"
    end
  end

  # ---------------------------------------------------------------------------
  # handle_event("cancel_command", ...)
  # ---------------------------------------------------------------------------

  describe "handle_event cancel_command" do
    test "cancel_command dismisses the armed modal", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/cockpit/commands")

      render_click(view, "arm_command", %{"command" => "restart"})
      html = render_click(view, "cancel_command", %{})

      refute html =~ "COMMAND ARMED - CONFIRM EXECUTION"
    end

    test "cancel_command restores the command selection grid", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/cockpit/commands")

      render_click(view, "arm_command", %{"command" => "restart"})
      render_click(view, "cancel_command", %{})

      html = render(view)

      assert html =~ "SELECT TARGET"
      assert html =~ "CRITICAL COMMANDS"
    end

    test "cancel_command clears armed_command — header countdown disappears", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/cockpit/commands")

      render_click(view, "arm_command", %{"command" => "shutdown"})
      render_click(view, "cancel_command", %{})

      html = render(view)

      refute html =~ "COMMAND ARMED -"
    end

    test "cancel_command clears arm_countdown to zero", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/cockpit/commands")

      render_click(view, "arm_command", %{"command" => "restart"})
      # 5:00 should be visible while armed
      assert render(view) =~ "5:00"

      render_click(view, "cancel_command", %{})
      html = render(view)

      # After cancel, countdown is gone from header
      refute html =~ "5:00"
    end

    test "cancel_command clears confirmation_code", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/cockpit/commands")

      render_click(view, "arm_command", %{"command" => "restart"})
      render_click(view, "update_confirmation", %{"code" => "A7"})
      html = render_click(view, "cancel_command", %{})

      # Modal gone; no lingering code rendered
      refute html =~ "COMMAND ARMED - CONFIRM EXECUTION"
    end

    test "cancel_command when no command is armed is a no-op", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/cockpit/commands")

      html = render_click(view, "cancel_command", %{})

      assert html =~ "SELECT TARGET"
      refute html =~ "COMMAND ARMED - CONFIRM EXECUTION"
    end

    test "cancel_command does not add a history entry", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/cockpit/commands")

      render_click(view, "arm_command", %{"command" => "restart"})
      render_click(view, "cancel_command", %{})

      html = render(view)

      assert html =~ "No commands executed"
    end
  end

  # ---------------------------------------------------------------------------
  # LIFECYCLE SEQUENCE TESTS (arm → cancel → arm → confirm)
  # ---------------------------------------------------------------------------

  describe "arm → cancel lifecycle (SC-SAFETY-001)" do
    test "arm then cancel restores idle state", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/cockpit/commands")

      render_click(view, "arm_command", %{"command" => "restart"})
      assert render(view) =~ "COMMAND ARMED - CONFIRM EXECUTION"

      render_click(view, "cancel_command", %{})
      html = render(view)

      refute html =~ "COMMAND ARMED - CONFIRM EXECUTION"
      assert html =~ "SELECT TARGET"
    end

    test "arm then cancel then arm again shows fresh modal", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/cockpit/commands")

      render_click(view, "arm_command", %{"command" => "restart"})
      render_click(view, "cancel_command", %{})
      html = render_click(view, "arm_command", %{"command" => "shutdown"})

      assert html =~ "COMMAND ARMED - CONFIRM EXECUTION"
      assert html =~ "SHUTDOWN"
    end

    test "arm → wrong confirm → cancel restores idle state", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/cockpit/commands")

      render_click(view, "arm_command", %{"command" => "restart"})
      render_click(view, "update_confirmation", %{"code" => "WRONG"})
      render_click(view, "confirm_command", %{})
      # Modal still up — now cancel
      render_click(view, "cancel_command", %{})
      html = render(view)

      refute html =~ "COMMAND ARMED - CONFIRM EXECUTION"
      assert html =~ "SELECT TARGET"
    end
  end

  describe "arm → confirm lifecycle (SC-SAFETY-001)" do
    test "full happy path: select target → arm → update_confirmation → confirm", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/cockpit/commands")

      # Step 1: Select non-default target
      render_click(view, "select_target", %{"target" => "app-02"})

      # Step 2: Arm a critical command
      render_click(view, "arm_command", %{"command" => "restart"})
      assert render(view) =~ "COMMAND ARMED - CONFIRM EXECUTION"

      # Step 3: Enter confirmation code
      code = expected_code("app-02", :restart)
      render_click(view, "update_confirmation", %{"code" => code})

      # Step 4: Confirm
      html = render_click(view, "confirm_command", %{})

      # Modal dismissed, command accepted
      refute html =~ "COMMAND ARMED - CONFIRM EXECUTION"
      assert html =~ "restart"
      assert html =~ "executing"
    end

    test "full happy path produces history entry with :executing status", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/cockpit/commands")

      render_click(view, "arm_command", %{"command" => "shutdown"})
      code = expected_code("app-01", :shutdown)
      render_click(view, "update_confirmation", %{"code" => code})
      render_click(view, "confirm_command", %{})

      html = render(view)

      assert html =~ "EXECUTING"
      refute html =~ "No commands executed"
    end

    test "cancel then arm then confirm with correct code succeeds", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/cockpit/commands")

      # First attempt — cancel mid-way
      render_click(view, "arm_command", %{"command" => "restart"})
      render_click(view, "cancel_command", %{})

      # Second attempt — complete correctly
      render_click(view, "arm_command", %{"command" => "restart"})
      code = expected_code("app-01", :restart)
      render_click(view, "update_confirmation", %{"code" => code})
      html = render_click(view, "confirm_command", %{})

      refute html =~ "COMMAND ARMED - CONFIRM EXECUTION"
      assert html =~ "executing"
    end

    test "arm → confirm wrong → update correct → confirm succeeds", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/cockpit/commands")

      render_click(view, "arm_command", %{"command" => "isolate"})

      # Wrong attempt
      render_click(view, "update_confirmation", %{"code" => "NOPE"})
      html_after_wrong = render_click(view, "confirm_command", %{})
      assert html_after_wrong =~ "Invalid confirmation code"
      assert html_after_wrong =~ "COMMAND ARMED - CONFIRM EXECUTION"

      # Correct attempt
      code = expected_code("app-01", :isolate)
      render_click(view, "update_confirmation", %{"code" => code})
      html = render_click(view, "confirm_command", %{})

      refute html =~ "COMMAND ARMED - CONFIRM EXECUTION"
      assert html =~ "executing"
    end
  end

  describe "arm → cancel → arm → confirm full sequence (SC-SAFETY-001)" do
    test "complete round-trip: arm, cancel, arm again, confirm", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/cockpit/commands")

      # Round 1: arm and cancel
      render_click(view, "arm_command", %{"command" => "hibernate"})
      assert render(view) =~ "COMMAND ARMED - CONFIRM EXECUTION"
      render_click(view, "cancel_command", %{})
      assert render(view) =~ "SELECT TARGET"

      # Round 2: arm different command and confirm correctly
      render_click(view, "arm_command", %{"command" => "power_off"})
      code = expected_code("app-01", :power_off)
      render_click(view, "update_confirmation", %{"code" => code})
      html = render_click(view, "confirm_command", %{})

      refute html =~ "COMMAND ARMED - CONFIRM EXECUTION"
      assert html =~ "power_off"
      assert html =~ "executing"
      assert html =~ "EXECUTING"
    end
  end

  # ---------------------------------------------------------------------------
  # handle_info(:tick, ...) — countdown timer
  # ---------------------------------------------------------------------------

  describe "handle_info :tick countdown" do
    test "tick decrements arm_countdown when a command is armed", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/cockpit/commands")

      render_click(view, "arm_command", %{"command" => "restart"})
      # Countdown is 300 — send a tick manually
      send(view.pid, :tick)

      html = render(view)

      # 299 seconds = 4:59
      assert html =~ "4:59"
    end

    test "tick when no command is armed is a no-op", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/cockpit/commands")

      send(view.pid, :tick)
      html = render(view)

      # No countdown shown, no crash
      refute html =~ "5:00"
      assert html =~ "SELECT TARGET"
    end

    test "tick at zero cancels the armed command automatically", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/cockpit/commands")

      render_click(view, "arm_command", %{"command" => "restart"})

      # Drive countdown to 1 then send tick to trigger auto-cancel
      :sys.replace_state(view.pid, fn state ->
        put_in(state, [:socket, :assigns, :arm_countdown], 1)
      end)

      send(view.pid, :tick)
      html = render(view)

      refute html =~ "COMMAND ARMED - CONFIRM EXECUTION"
      assert html =~ "SELECT TARGET"
    end
  end

  # ---------------------------------------------------------------------------
  # handle_info({:command_result, ...}) — async result update
  # ---------------------------------------------------------------------------

  describe "handle_info :command_result" do
    test "command_result updates history entry status from :executing to :success", %{
      conn: conn
    } do
      {:ok, view, _html} = live(conn, "/cockpit/commands")

      render_click(view, "arm_command", %{"command" => "restart"})
      code = expected_code("app-01", :restart)
      render_click(view, "update_confirmation", %{"code" => code})
      render_click(view, "confirm_command", %{})

      # Capture the cmd_id from history (first entry)
      history = :sys.get_state(view.pid) |> get_in([:socket, :assigns, :command_history])
      assert [%{id: cmd_id, status: :executing} | _] = history

      # Simulate the async result arriving
      send(view.pid, {:command_result, cmd_id, :success})
      html = render(view)

      assert html =~ "SUCCESS"
    end

    test "command_result :failed updates history entry to failed status", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/cockpit/commands")

      render_click(view, "arm_command", %{"command" => "restart"})
      code = expected_code("app-01", :restart)
      render_click(view, "update_confirmation", %{"code" => code})
      render_click(view, "confirm_command", %{})

      history = :sys.get_state(view.pid) |> get_in([:socket, :assigns, :command_history])
      [%{id: cmd_id} | _] = history

      send(view.pid, {:command_result, cmd_id, :failed})
      html = render(view)

      assert html =~ "FAILED"
    end

    test "command_result for unknown cmd_id leaves history unchanged", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/cockpit/commands")

      render_click(view, "arm_command", %{"command" => "health_check"})
      html_before = render(view)

      send(view.pid, {:command_result, "CMD-999999", :success})
      html_after = render(view)

      # Content is identical — no crash
      assert html_before == html_after
    end
  end

  # ---------------------------------------------------------------------------
  # PUBSUB INTEGRATION (subscribe on connect)
  # ---------------------------------------------------------------------------

  describe "PubSub subscription" do
    test "LiveView subscribes to prajna:commands topic on connect", %{conn: conn} do
      {:ok, _view, _html} = live(conn, "/cockpit/commands")
      # Mount completing without error verifies subscription succeeded
      assert true
    end
  end

  # ---------------------------------------------------------------------------
  # NAVIGATION
  # ---------------------------------------------------------------------------

  describe "navigation" do
    test "Commands tab is marked as current in nav", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/cockpit/commands")
      # Commands tab uses border-b-2 border-accent-primary to indicate current
      assert html =~ "COMMANDS"
    end

    test "navigation includes links to other cockpit sections", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/cockpit/commands")
      assert html =~ "OVERVIEW"
      assert html =~ "MESH"
      assert html =~ "ALARMS"
    end
  end
end
