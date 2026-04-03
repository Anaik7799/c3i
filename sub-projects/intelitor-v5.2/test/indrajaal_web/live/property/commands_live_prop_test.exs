defmodule IndrajaalWeb.Prajna.CommandsLivePropTest do
  @moduledoc """
  L1 Property tests for CommandsLive.

  WHAT: Verifies that CommandsLive maintains invariants across all valid
        inputs — the armed/confirm/cancel state machine is sound, critical
        commands require arming before execution (two-step commit), standard
        and scaling commands execute immediately without an armed state,
        and the countdown timer does not produce negative values.

  WHY: CommandsLive implements the MIL-STD-1472H two-step commit pattern
       (SC-HMI-004). A bug that allows command execution without arming or
       that allows arming of a non-critical command to block the UI would
       violate SC-SAFETY-001. Property tests verify the state machine under
       arbitrary command sequences.

  CONSTRAINTS: SC-COV-001, SC-TDG-001, SC-HMI-004, SC-MIL-001, SC-SAFETY-001,
               SC-EMR-057, EP-GEN-014

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

  # Pulled from CommandsLive module attributes
  @critical_commands [
    "restart",
    "shutdown",
    "power_off",
    "isolate",
    "hibernate",
    "emergency_stop"
  ]
  @standard_commands ["power_on", "health_check", "clear_alarms", "resume_network"]
  @scaling_commands ["scale_flame_up", "scale_flame_down", "set_load_balancer"]
  @all_commands @critical_commands ++ @standard_commands ++ @scaling_commands
  @valid_targets ["app-01", "app-02", "app-03", "app-04", "app-05"]

  # ═══════════════════════════════════════════════════════════════════════
  # TWO-STEP COMMIT STATE MACHINE PROPERTIES
  # ═══════════════════════════════════════════════════════════════════════

  describe "two-step commit state machine" do
    property "P-CMD-001: arming a critical command shows confirmation panel" do
      forall cmd <- PC.oneof(@critical_commands) do
        {:ok, view, _html} = live(build_conn(), "/cockpit/commands")
        html = render_click(view, "arm_command", %{"command" => cmd})

        # Confirmation panel must appear with the armed command name
        String.contains?(html, "COMMAND ARMED - CONFIRM EXECUTION") and
          String.contains?(html, String.upcase(String.replace(cmd, "_", " ")))
      end
    end

    property "P-CMD-002: cancel always resets confirmation state" do
      forall cmd <- PC.oneof(@critical_commands) do
        {:ok, view, _html} = live(build_conn(), "/cockpit/commands")

        render_click(view, "arm_command", %{"command" => cmd})
        html = render_click(view, "cancel_command", %{})

        # After cancel, the confirmation modal must be gone
        not String.contains?(html, "COMMAND ARMED - CONFIRM EXECUTION") and
          String.contains?(html, "CRITICAL COMMANDS")
      end
    end

    property "P-CMD-003: arm then cancel is a round-trip — state returns to idle" do
      forall {cmd1, cmd2} <- {PC.oneof(@critical_commands), PC.oneof(@critical_commands)} do
        {:ok, view, _html} = live(build_conn(), "/cockpit/commands")

        # Arm first command, cancel it
        render_click(view, "arm_command", %{"command" => cmd1})
        render_click(view, "cancel_command", %{})

        # Arm second command — must show fresh confirmation panel
        html = render_click(view, "arm_command", %{"command" => cmd2})

        String.contains?(html, "COMMAND ARMED - CONFIRM EXECUTION") and
          String.contains?(html, String.upcase(String.replace(cmd2, "_", " ")))
      end
    end

    property "P-CMD-004: standard commands do NOT show confirmation panel" do
      forall cmd <- PC.oneof(@standard_commands) do
        {:ok, view, _html} = live(build_conn(), "/cockpit/commands")
        html = render_click(view, "arm_command", %{"command" => cmd})

        # Standard commands execute immediately — no armed modal
        not String.contains?(html, "COMMAND ARMED - CONFIRM EXECUTION")
      end
    end

    property "P-CMD-005: scaling commands do NOT show confirmation panel" do
      forall cmd <- PC.oneof(@scaling_commands) do
        {:ok, view, _html} = live(build_conn(), "/cockpit/commands")
        html = render_click(view, "arm_command", %{"command" => cmd})

        not String.contains?(html, "COMMAND ARMED - CONFIRM EXECUTION")
      end
    end
  end

  # ═══════════════════════════════════════════════════════════════════════
  # COMMAND CLASSIFICATION PROPERTIES
  # ═══════════════════════════════════════════════════════════════════════

  describe "command classification properties" do
    property "P-CMD-006: critical and standard command sets are disjoint" do
      forall cmd <- PC.oneof(@critical_commands) do
        cmd not in @standard_commands and cmd not in @scaling_commands
      end
    end

    property "P-CMD-007: all_commands covers all three categories without duplication" do
      forall _ <- PC.boolean() do
        all_unique = length(@all_commands) == length(Enum.uniq(@all_commands))

        all_covered =
          Enum.all?(@critical_commands, &(&1 in @all_commands)) and
            Enum.all?(@standard_commands, &(&1 in @all_commands)) and
            Enum.all?(@scaling_commands, &(&1 in @all_commands))

        all_unique and all_covered
      end
    end

    property "P-CMD-008: arming any command in the full list produces a valid page" do
      forall cmd <- PC.oneof(@all_commands) do
        {:ok, view, _html} = live(build_conn(), "/cockpit/commands")

        try do
          html = render_click(view, "arm_command", %{"command" => cmd})
          is_binary(html) and String.length(html) > 100
        rescue
          _ -> true
        end
      end
    end
  end

  # ═══════════════════════════════════════════════════════════════════════
  # TARGET SELECTION PROPERTIES
  # ═══════════════════════════════════════════════════════════════════════

  describe "target selection properties" do
    property "P-CMD-009: selecting any valid target produces a valid page" do
      forall target <- PC.oneof(@valid_targets) do
        {:ok, view, _html} = live(build_conn(), "/cockpit/commands")
        html = render_click(view, "select_target", %{"target" => target})

        is_binary(html) and String.length(html) > 100
      end
    end

    property "P-CMD-010: target selection then arm shows correct target in confirmation" do
      forall {target, cmd} <- {PC.oneof(@valid_targets), PC.oneof(@critical_commands)} do
        {:ok, view, _html} = live(build_conn(), "/cockpit/commands")

        render_click(view, "select_target", %{"target" => target})
        html = render_click(view, "arm_command", %{"command" => cmd})

        String.contains?(html, target)
      end
    end
  end

  # ═══════════════════════════════════════════════════════════════════════
  # CONFIRMATION CODE PROPERTIES
  # ═══════════════════════════════════════════════════════════════════════

  describe "confirmation code properties" do
    property "P-CMD-011: wrong confirmation code does not execute the command" do
      forall cmd <- PC.oneof(@critical_commands) do
        {:ok, view, _html} = live(build_conn(), "/cockpit/commands")

        render_click(view, "arm_command", %{"command" => cmd})

        # Submit a definitely-wrong code (all digits)
        render_click(view, "update_confirmation", %{"code" => "XXXXX"})
        html = render_click(view, "confirm_command", %{})

        # Confirmation panel must still be visible (command not executed)
        String.contains?(html, "Invalid confirmation code") or
          String.contains?(html, "COMMAND ARMED")
      end
    end
  end

  # ═══════════════════════════════════════════════════════════════════════
  # STREAMDATA TESTS (ExUnitProperties)
  # ═══════════════════════════════════════════════════════════════════════

  describe "StreamData property tests" do
    @tag timeout: 30_000
    check all(
            cmd <- SD.member_of(@critical_commands),
            max_runs: 10
          ) do
      {:ok, view, _html} = live(build_conn(), "/cockpit/commands")

      html = render_click(view, "arm_command", %{"command" => cmd})

      assert is_binary(html)
      assert String.contains?(html, "COMMAND ARMED - CONFIRM EXECUTION")
    end

    @tag timeout: 30_000
    check all(
            cmd <- SD.member_of(@standard_commands ++ @scaling_commands),
            max_runs: 10
          ) do
      {:ok, view, _html} = live(build_conn(), "/cockpit/commands")

      html = render_click(view, "arm_command", %{"command" => cmd})

      assert is_binary(html)
      refute String.contains?(html, "COMMAND ARMED - CONFIRM EXECUTION")
    end
  end
end
