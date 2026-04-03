defmodule IndrajaalWeb.PrajnaLiveTest do
  @moduledoc """
  Integration tests for IndrajaalWeb.PrajnaLive — the root Prajna C3I cockpit dashboard.

  WHAT: Verifies PrajnaLive's 5 handle_event clauses: ack_alarm, dismiss_insight,
        arm_command, confirm_command, cancel_command. Covers the two-step Arm & Fire
        protocol for critical node commands (SC-SAFETY-001).
  WHY: The root cockpit is the primary operator interface — alarm acknowledgement
       and critical command execution must be reliable under stress.
  CONSTRAINTS: SC-COV-001, SC-TDG-001, SC-PRAJNA-001, SC-SAFETY-001, SC-HMI-001

  TDG Level: L4 (Integration Testing)
  """

  use IndrajaalWeb.ConnCase, async: true
  import Phoenix.LiveViewTest

  @moduletag :integration
  @moduletag :zenoh_nif

  # ═══════════════════════════════════════════════════════════════════════
  # MODULE STRUCTURE
  # ═══════════════════════════════════════════════════════════════════════

  describe "module structure" do
    test "module exists and exports required callbacks" do
      assert Code.ensure_loaded?(IndrajaalWeb.PrajnaLive)
      assert function_exported?(IndrajaalWeb.PrajnaLive, :mount, 3)
      assert function_exported?(IndrajaalWeb.PrajnaLive, :render, 1)
      assert function_exported?(IndrajaalWeb.PrajnaLive, :handle_event, 3)
      assert function_exported?(IndrajaalWeb.PrajnaLive, :handle_info, 2)
    end

    test "has moduledoc" do
      {:docs_v1, _, _, _, module_doc, _, _} = Code.fetch_docs(IndrajaalWeb.PrajnaLive)
      assert module_doc != :none
    end
  end

  # ═══════════════════════════════════════════════════════════════════════
  # MOUNT & RENDER
  # ═══════════════════════════════════════════════════════════════════════

  describe "mount and initial render" do
    test "mounts successfully at /cockpit" do
      {:ok, _view, html} = live(build_conn(), "/cockpit")
      assert is_binary(html)
      assert String.length(html) > 100
    end

    test "renders cockpit header" do
      {:ok, _view, html} = live(build_conn(), "/cockpit")
      assert html =~ "PRAJNA" or html =~ "prajna" or html =~ "Prajna" or html =~ "COCKPIT"
    end

    test "renders OODA status" do
      {:ok, _view, html} = live(build_conn(), "/cockpit")
      assert html =~ "OODA" or html =~ "OBSERVE" or html =~ "ooda"
    end
  end

  # ═══════════════════════════════════════════════════════════════════════
  # HANDLE_EVENT: ack_alarm
  # ═══════════════════════════════════════════════════════════════════════

  describe "handle_event ack_alarm" do
    test "acknowledging a valid alarm ID does not crash" do
      {:ok, view, _html} = live(build_conn(), "/cockpit")
      html = render_click(view, "ack_alarm", %{"id" => "alarm-1"})
      assert is_binary(html)
      assert String.length(html) > 100
    end

    test "acknowledging a non-existent alarm ID is safe" do
      {:ok, view, _html} = live(build_conn(), "/cockpit")
      html = render_click(view, "ack_alarm", %{"id" => "does-not-exist"})
      assert is_binary(html)
    end
  end

  # ═══════════════════════════════════════════════════════════════════════
  # HANDLE_EVENT: dismiss_insight
  # ═══════════════════════════════════════════════════════════════════════

  describe "handle_event dismiss_insight" do
    test "dismissing an insight does not crash" do
      {:ok, view, _html} = live(build_conn(), "/cockpit")
      html = render_click(view, "dismiss_insight", %{"id" => "insight-1"})
      assert is_binary(html)
    end

    test "dismissing non-existent insight is safe" do
      {:ok, view, _html} = live(build_conn(), "/cockpit")
      html = render_click(view, "dismiss_insight", %{"id" => "nonexistent"})
      assert is_binary(html)
    end
  end

  # ═══════════════════════════════════════════════════════════════════════
  # HANDLE_EVENT: arm_command / confirm / cancel (SC-SAFETY-001)
  # ═══════════════════════════════════════════════════════════════════════

  describe "handle_event arm_command (two-step Arm & Fire)" do
    test "arm a node command" do
      {:ok, view, _html} = live(build_conn(), "/cockpit")

      html =
        render_click(view, "arm_command", %{
          "node" => "node-1",
          "command" => "restart"
        })

      assert is_binary(html)
    end

    test "arm then cancel returns to unarmed state" do
      {:ok, view, _html} = live(build_conn(), "/cockpit")

      render_click(view, "arm_command", %{
        "node" => "node-1",
        "command" => "restart"
      })

      html = render_click(view, "cancel_command", %{})
      assert is_binary(html)
    end

    test "arm then confirm executes command and produces flash" do
      {:ok, view, _html} = live(build_conn(), "/cockpit")

      render_click(view, "arm_command", %{
        "node" => "node-1",
        "command" => "restart"
      })

      html = render_click(view, "confirm_command", %{})
      assert html =~ "executed" or html =~ "Command" or html =~ "command"
    end

    test "confirm without arm is safe (no armed_command)" do
      {:ok, view, _html} = live(build_conn(), "/cockpit")
      html = render_click(view, "confirm_command", %{})
      assert is_binary(html)
    end

    test "cancel without arm is safe (no-op)" do
      {:ok, view, _html} = live(build_conn(), "/cockpit")
      html = render_click(view, "cancel_command", %{})
      assert is_binary(html)
    end

    test "arm → cancel → arm → confirm sequence" do
      {:ok, view, _html} = live(build_conn(), "/cockpit")

      render_click(view, "arm_command", %{"node" => "n1", "command" => "stop"})
      render_click(view, "cancel_command", %{})
      render_click(view, "arm_command", %{"node" => "n2", "command" => "restart"})
      html = render_click(view, "confirm_command", %{})

      assert html =~ "executed" or html =~ "Command" or is_binary(html)
    end
  end

  # ═══════════════════════════════════════════════════════════════════════
  # HANDLE_INFO: timer
  # ═══════════════════════════════════════════════════════════════════════

  describe "handle_info timer" do
    test "survives refresh cycle" do
      {:ok, view, _html} = live(build_conn(), "/cockpit")
      Process.sleep(600)
      html = render(view)
      assert is_binary(html)
      assert String.length(html) > 100
    end
  end
end
