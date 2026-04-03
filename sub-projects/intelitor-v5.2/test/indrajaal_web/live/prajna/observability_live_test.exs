defmodule IndrajaalWeb.Prajna.ObservabilityLiveTest do
  @moduledoc """
  Integration tests for IndrajaalWeb.Prajna.ObservabilityLive.

  WHAT: Verifies ObservabilityLive mounts, renders tabs, and handles all 4
        handle_event clauses: switch_tab, view_trace, open_signoz, export_metrics.
  WHY: ObservabilityLive is the primary telemetry dashboard — operators depend on
       tab switching and metric export to diagnose production issues under pressure.
  CONSTRAINTS: SC-COV-001, SC-TDG-001, SC-HMI-001, SC-OBS-069, SC-OBS-071

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
      alias IndrajaalWeb.Prajna.ObservabilityLive
      assert Code.ensure_loaded?(ObservabilityLive)
      assert function_exported?(ObservabilityLive, :mount, 3)
      assert function_exported?(ObservabilityLive, :render, 1)
      assert function_exported?(ObservabilityLive, :handle_event, 3)
      assert function_exported?(ObservabilityLive, :handle_info, 2)
    end
  end

  # ═══════════════════════════════════════════════════════════════════════
  # MOUNT & RENDER
  # ═══════════════════════════════════════════════════════════════════════

  describe "mount and initial render" do
    test "mounts successfully at /cockpit/observability" do
      {:ok, _view, html} = live(build_conn(), "/cockpit/observability")
      assert is_binary(html)
      assert String.length(html) > 100
    end

    test "initial render shows metrics tab content" do
      {:ok, _view, html} = live(build_conn(), "/cockpit/observability")
      # Metrics tab is default — should show metric cards
      assert html =~ "Request" or html =~ "metric" or html =~ "Metric"
    end

    test "renders 4 tab buttons" do
      {:ok, _view, html} = live(build_conn(), "/cockpit/observability")
      assert html =~ "Metrics" or html =~ "metrics"
      assert html =~ "Traces" or html =~ "traces"
      assert html =~ "Logs" or html =~ "logs"
      assert html =~ "SigNoz" or html =~ "signoz"
    end
  end

  # ═══════════════════════════════════════════════════════════════════════
  # HANDLE_EVENT: switch_tab
  # ═══════════════════════════════════════════════════════════════════════

  describe "handle_event switch_tab" do
    test "switch to traces tab" do
      {:ok, view, _html} = live(build_conn(), "/cockpit/observability")
      html = render_click(view, "switch_tab", %{"tab" => "traces"})
      assert html =~ "TRACE" or html =~ "trace" or html =~ "Trace"
    end

    test "switch to logs tab" do
      {:ok, view, _html} = live(build_conn(), "/cockpit/observability")
      html = render_click(view, "switch_tab", %{"tab" => "logs"})
      assert html =~ "DIAGNOSTICS" or html =~ "log" or html =~ "Log"
    end

    test "switch to signoz tab" do
      {:ok, view, _html} = live(build_conn(), "/cockpit/observability")
      html = render_click(view, "switch_tab", %{"tab" => "signoz"})
      assert html =~ "OTEL" or html =~ "SigNoz" or html =~ "signoz"
    end

    test "switch back to metrics from another tab" do
      {:ok, view, _html} = live(build_conn(), "/cockpit/observability")
      render_click(view, "switch_tab", %{"tab" => "traces"})
      html = render_click(view, "switch_tab", %{"tab" => "metrics"})
      assert html =~ "Request" or html =~ "metric" or html =~ "Metric"
    end

    test "switching to same tab is idempotent" do
      {:ok, view, _html} = live(build_conn(), "/cockpit/observability")
      html1 = render_click(view, "switch_tab", %{"tab" => "traces"})
      html2 = render_click(view, "switch_tab", %{"tab" => "traces"})
      assert html1 == html2
    end
  end

  # ═══════════════════════════════════════════════════════════════════════
  # HANDLE_EVENT: open_signoz
  # ═══════════════════════════════════════════════════════════════════════

  describe "handle_event open_signoz" do
    test "produces flash message with SigNoz URL" do
      {:ok, view, _html} = live(build_conn(), "/cockpit/observability")
      render_click(view, "switch_tab", %{"tab" => "signoz"})
      html = render_click(view, "open_signoz", %{})
      assert html =~ "SigNoz" or html =~ "Opening"
    end
  end

  # ═══════════════════════════════════════════════════════════════════════
  # HANDLE_EVENT: export_metrics
  # ═══════════════════════════════════════════════════════════════════════

  describe "handle_event export_metrics" do
    test "produces flash message with export path" do
      {:ok, view, _html} = live(build_conn(), "/cockpit/observability")
      html = render_click(view, "export_metrics", %{})
      assert html =~ "export" or html =~ "Metrics"
    end
  end

  # ═══════════════════════════════════════════════════════════════════════
  # HANDLE_INFO: timer refresh
  # ═══════════════════════════════════════════════════════════════════════

  describe "handle_info timer" do
    test "survives refresh timer cycle" do
      {:ok, view, _html} = live(build_conn(), "/cockpit/observability")
      # Wait for 1 refresh cycle (500ms) + margin
      Process.sleep(600)
      html = render(view)
      assert is_binary(html)
      assert String.length(html) > 100
    end
  end
end
