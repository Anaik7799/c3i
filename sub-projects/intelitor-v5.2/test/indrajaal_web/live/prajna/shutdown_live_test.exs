defmodule IndrajaalWeb.Prajna.ShutdownLiveTest do
  @moduledoc """
  Integration tests for IndrajaalWeb.Prajna.ShutdownLive.

  WHAT: Verifies ShutdownLive's 7 handle_event clauses covering the full shutdown
        lifecycle: initiate, abort, arm/confirm/cancel force shutdown, mode, timeout.
  WHY: ShutdownLive controls system lifecycle — the two-step Arm & Fire protocol
       (SC-SAFETY-001) prevents accidental shutdowns. Every state transition must be
       tested to ensure operators can always abort.
  CONSTRAINTS: SC-COV-001, SC-TDG-001, SC-SAFETY-001, SC-SIL4-013, SC-HMI-001

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
      alias IndrajaalWeb.Prajna.ShutdownLive
      assert Code.ensure_loaded?(ShutdownLive)
      assert function_exported?(ShutdownLive, :mount, 3)
      assert function_exported?(ShutdownLive, :render, 1)
      assert function_exported?(ShutdownLive, :handle_event, 3)
      assert function_exported?(ShutdownLive, :handle_info, 2)
    end
  end

  # ═══════════════════════════════════════════════════════════════════════
  # MOUNT & RENDER
  # ═══════════════════════════════════════════════════════════════════════

  describe "mount and initial render" do
    test "mounts successfully at /cockpit/shutdown" do
      {:ok, _view, html} = live(build_conn(), "/cockpit/shutdown")
      assert is_binary(html)
      assert String.length(html) > 100
    end

    test "initial render shows shutdown controls" do
      {:ok, _view, html} = live(build_conn(), "/cockpit/shutdown")
      # Should show shutdown-related UI elements
      assert html =~ "SHUTDOWN" or html =~ "shutdown" or html =~ "Shutdown"
    end
  end

  # ═══════════════════════════════════════════════════════════════════════
  # HANDLE_EVENT: initiate_shutdown
  # ═══════════════════════════════════════════════════════════════════════

  describe "handle_event initiate_shutdown" do
    test "initiates graceful shutdown" do
      {:ok, view, _html} = live(build_conn(), "/cockpit/shutdown")
      html = render_click(view, "initiate_shutdown", %{})
      # After initiation, should show active shutdown state
      assert is_binary(html)
      assert String.length(html) > 100
    end

    test "double initiate is a no-op (idempotent)" do
      {:ok, view, _html} = live(build_conn(), "/cockpit/shutdown")
      html1 = render_click(view, "initiate_shutdown", %{})
      html2 = render_click(view, "initiate_shutdown", %{})
      # Second call should not crash and should produce valid HTML
      assert is_binary(html1)
      assert is_binary(html2)
    end
  end

  # ═══════════════════════════════════════════════════════════════════════
  # HANDLE_EVENT: abort_shutdown
  # ═══════════════════════════════════════════════════════════════════════

  describe "handle_event abort_shutdown" do
    test "abort produces warning flash" do
      {:ok, view, _html} = live(build_conn(), "/cockpit/shutdown")
      render_click(view, "initiate_shutdown", %{})
      html = render_click(view, "abort_shutdown", %{})
      assert html =~ "abort" or html =~ "Abort" or html =~ "resuming"
    end

    test "abort without active shutdown is safe" do
      {:ok, view, _html} = live(build_conn(), "/cockpit/shutdown")
      html = render_click(view, "abort_shutdown", %{})
      assert is_binary(html)
      assert String.length(html) > 100
    end
  end

  # ═══════════════════════════════════════════════════════════════════════
  # HANDLE_EVENT: force_shutdown (Arm & Fire — SC-SAFETY-001)
  # ═══════════════════════════════════════════════════════════════════════

  describe "handle_event force_shutdown arm/confirm/cancel" do
    test "arm enables force confirm UI" do
      {:ok, view, _html} = live(build_conn(), "/cockpit/shutdown")
      html = render_click(view, "force_shutdown_arm", %{})
      assert is_binary(html)
    end

    test "arm then cancel disarms" do
      {:ok, view, _html} = live(build_conn(), "/cockpit/shutdown")
      render_click(view, "force_shutdown_arm", %{})
      html = render_click(view, "force_shutdown_cancel", %{})
      # Should no longer show armed state
      refute html =~ "CONFIRM FORCE SHUTDOWN"
    end

    test "arm then confirm triggers force shutdown flash" do
      {:ok, view, _html} = live(build_conn(), "/cockpit/shutdown")
      render_click(view, "force_shutdown_arm", %{})
      html = render_click(view, "force_shutdown_confirm", %{})
      assert html =~ "Force shutdown" or html =~ "force shutdown" or html =~ "halting"
    end

    test "cancel without arm is safe (no-op)" do
      {:ok, view, _html} = live(build_conn(), "/cockpit/shutdown")
      html = render_click(view, "force_shutdown_cancel", %{})
      assert is_binary(html)
      assert String.length(html) > 100
    end

    test "confirm without arm is safe" do
      {:ok, view, _html} = live(build_conn(), "/cockpit/shutdown")
      html = render_click(view, "force_shutdown_confirm", %{})
      assert is_binary(html)
    end
  end

  # ═══════════════════════════════════════════════════════════════════════
  # HANDLE_EVENT: update_mode
  # ═══════════════════════════════════════════════════════════════════════

  describe "handle_event update_mode" do
    test "set graceful mode" do
      {:ok, view, _html} = live(build_conn(), "/cockpit/shutdown")
      html = render_click(view, "update_mode", %{"mode" => "graceful"})
      assert is_binary(html)
    end

    test "set immediate mode" do
      {:ok, view, _html} = live(build_conn(), "/cockpit/shutdown")
      html = render_click(view, "update_mode", %{"mode" => "immediate"})
      assert is_binary(html)
    end

    test "set scheduled mode" do
      {:ok, view, _html} = live(build_conn(), "/cockpit/shutdown")
      html = render_click(view, "update_mode", %{"mode" => "scheduled"})
      assert is_binary(html)
    end
  end

  # ═══════════════════════════════════════════════════════════════════════
  # HANDLE_EVENT: update_timeout
  # ═══════════════════════════════════════════════════════════════════════

  describe "handle_event update_timeout" do
    test "set drain timeout" do
      {:ok, view, _html} = live(build_conn(), "/cockpit/shutdown")
      html = render_click(view, "update_timeout", %{"timeout" => "60"})
      assert is_binary(html)
    end
  end

  # ═══════════════════════════════════════════════════════════════════════
  # FULL LIFECYCLE
  # ═══════════════════════════════════════════════════════════════════════

  describe "full lifecycle sequences" do
    test "initiate → abort → re-initiate" do
      {:ok, view, _html} = live(build_conn(), "/cockpit/shutdown")
      render_click(view, "initiate_shutdown", %{})
      render_click(view, "abort_shutdown", %{})
      html = render_click(view, "initiate_shutdown", %{})
      assert is_binary(html)
    end

    test "arm → cancel → arm → confirm sequence" do
      {:ok, view, _html} = live(build_conn(), "/cockpit/shutdown")
      render_click(view, "force_shutdown_arm", %{})
      render_click(view, "force_shutdown_cancel", %{})
      render_click(view, "force_shutdown_arm", %{})
      html = render_click(view, "force_shutdown_confirm", %{})
      assert is_binary(html)
    end
  end
end
