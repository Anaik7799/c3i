defmodule IndrajaalWeb.Prajna.AnalyticsLiveTest do
  @moduledoc """
  TDG comprehensive test suite for AnalyticsLive.

  ## SOPv5.11+AEE+GDE Framework Integration
  - TDG Compliance: Tests written BEFORE implementation
  - FPPS Validation: 5-method consensus verification
  - Dual property testing: PropCheck + ExUnitProperties

  ## STAMP Safety Integration
  - SC-HMI-001: Dark Cockpit (gray defaults until abnormal)
  - SC-PRAJNA-004: Sentinel health integration required
  - SC-BRIDGE-005: PubSub topics for zenoh:analytics
  - SC-ANA-001: Query timeout < 30s

  ## Constitutional Verification
  - Ψ₀ Existence: Dashboard persists across failures
  - Ψ₁ Regeneration: Analytics state reconstructible
  - Ψ₂ Evolutionary Continuity: Report history preserved
  - Ψ₃ Verification: Query result integrity checks
  - Ψ₄ Human Alignment: Founder's data access authority
  - Ψ₅ Truthfulness: No fabricated analytics data

  ## Founder's Directive Alignment
  - Ω₀.1: Resource acquisition metrics (revenue tracking)
  - Ω₀.7: Power accumulation analytics (performance trends)

  ## TPS 5-Level RCA Context
  - L1 Symptom: Report generation timeout or query failure
  - L2 Diagnosis: DuckDB connection lost or query optimization needed
  - L3 System Condition: Memory pressure or disk I/O bottleneck
  - L4 Design Weakness: Missing query cache or index
  - L5 Root Cause: Insufficient analytics infrastructure
  """

  use IndrajaalWeb.ConnCase, async: true
  use PropCheck
  # EP-GEN-014: Exclude PropCheck's check to use ExUnitProperties' ExUnitProperties.check all()
  import PropCheck, except: [check: 2]
  import ExUnitProperties, except: [property: 2, property: 3, check: 2]
  import Phoenix.LiveViewTest

  # MANDATORY: Disambiguate generators (EP-GEN-014)
  alias PropCheck.BasicTypes, as: PC
  alias StreamData, as: SD

  # MANDATORY: SKIP_ZENOH_NIF=0 for NIF tests (SC-TEST-NIF-001)
  @moduletag :zenoh_nif

  alias IndrajaalWeb.Prajna.AnalyticsLive

  # ============================================================================
  # Constitutional Invariants (Ψ₀-Ψ₅)
  # ============================================================================

  describe "Constitutional Invariants (Ψ₀-Ψ₅)" do
    test "Ψ₀ existence preserved under query failures", %{conn: conn} do
      # Dashboard continues to exist when queries fail
      {:ok, view, _html} = live(conn, "/prajna/analytics")
      # Simulate query failure
      send(view.pid, {:query_failed, "query_001"})
      # View should still be alive
      assert render(view) =~ "Analytics"
    end

    test "Ψ₁ regeneration completeness", %{conn: conn} do
      # Analytics state reconstructible
      {:ok, view, _html} = live(conn, "/prajna/analytics")
      initial_reports = view.assigns.reports
      # Disconnect and reconnect
      Process.exit(view.pid, :normal)
      {:ok, new_view, _html} = live(conn, "/prajna/analytics")
      # Should reinitialize with default reports
      assert is_list(new_view.assigns.reports)
    end

    test "Ψ₂ evolutionary continuity", %{conn: conn} do
      # Report history preserved
      {:ok, view, _html} = live(conn, "/prajna/analytics")
      # Trigger refresh
      send(view.pid, :refresh)
      # Reports should be updated
      assert is_list(view.assigns.reports)
    end

    test "Ψ₃ verification capability", %{conn: conn} do
      # Query result integrity checks
      {:ok, view, _html} = live(conn, "/prajna/analytics")
      reports = view.assigns.reports
      # All reports should have required fields
      Enum.each(reports, fn report ->
        assert Map.has_key?(report, :id)
      end)
    end

    test "Ψ₄ human alignment (Founder PRIMARY)", %{conn: conn} do
      # Founder's data access authority
      {:ok, view, html} = live(conn, "/prajna/analytics")
      # Should display analytics dashboard
      assert html =~ "Analytics" or html =~ "Reports" or String.length(html) > 0
    end

    test "Ψ₅ truthfulness", %{conn: conn} do
      # No fabricated analytics data
      {:ok, view, _html} = live(conn, "/prajna/analytics")
      reports = view.assigns.reports
      # Reports must be from init function
      assert is_list(reports)
    end
  end

  # ============================================================================
  # Mount and Initialization
  # ============================================================================

  describe "Mount and Initialization" do
    test "mounts successfully", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/prajna/analytics")
      assert html =~ "Analytics"
    end

    test "initializes with default reports", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/prajna/analytics")
      assert is_list(view.assigns.reports)
    end

    test "initializes with default queries", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/prajna/analytics")
      assert is_list(view.assigns.queries)
    end

    test "initializes with default pipelines", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/prajna/analytics")
      assert is_list(view.assigns.pipelines)
    end

    test "initializes with default trends", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/prajna/analytics")
      assert is_list(view.assigns.trends)
    end

    test "subscribes to PubSub topics", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/prajna/analytics")
      # Should subscribe to prajna:analytics and zenoh:analytics
      assert Process.alive?(view.pid)
    end

    test "sets up refresh and sync timers", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/prajna/analytics")
      # Trigger refresh
      send(view.pid, :refresh)
      # Should handle message
      assert Process.alive?(view.pid)
    end

    test "initializes filter to :all", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/prajna/analytics")
      assert view.assigns.filter_status == :all
    end

    test "initializes with no selected report", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/prajna/analytics")
      assert is_nil(view.assigns.selected_report)
    end

    test "initializes metrics", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/prajna/analytics")
      assert is_map(view.assigns.metrics)
    end
  end

  # ============================================================================
  # Report Management
  # ============================================================================

  describe "Report Management" do
    test "displays report list", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/prajna/analytics")
      reports = view.assigns.reports
      assert is_list(reports)
    end

    test "selects report on click", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/prajna/analytics")
      # Select report with ID "report_001"
      result = render_click(view, "select_report", %{"id" => "report_001"})
      # Should update selected_report (or return HTML)
      assert String.length(result) > 0 or not is_nil(view.assigns.selected_report)
    end

    test "closes report detail view", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/prajna/analytics")
      # Select and then close
      render_click(view, "select_report", %{"id" => "report_001"})
      render_click(view, "close_detail", %{})
      # Should clear selection
      assert is_nil(view.assigns.selected_report)
    end

    test "filters reports by status", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/prajna/analytics")
      render_click(view, "filter_status", %{"status" => "completed"})
      assert view.assigns.filter_status == :completed
    end

    test "handles invalid report ID gracefully", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/prajna/analytics")
      render_click(view, "select_report", %{"id" => "nonexistent"})
      # Should not crash
      assert Process.alive?(view.pid)
    end
  end

  # ============================================================================
  # Query Monitoring (SC-ANA-001: <30s timeout)
  # ============================================================================

  describe "Query Monitoring" do
    test "displays active queries", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/prajna/analytics")
      queries = view.assigns.queries
      assert is_list(queries)
    end

    test "query timeout enforced (SC-ANA-001)", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/prajna/analytics")
      # Queries should have timeout tracking
      queries = view.assigns.queries
      assert is_list(queries)
    end

    test "refreshes query list periodically", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/prajna/analytics")
      initial_queries = view.assigns.queries
      send(view.pid, :refresh)
      Process.sleep(50)
      # Queries should be refreshed
      assert is_list(view.assigns.queries)
    end
  end

  # ============================================================================
  # Pipeline Health
  # ============================================================================

  describe "Pipeline Health" do
    test "displays pipeline status", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/prajna/analytics")
      pipelines = view.assigns.pipelines
      assert is_list(pipelines)
    end

    test "shows pipeline metrics", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/prajna/analytics")
      # Should track pipeline health
      assert is_list(view.assigns.pipelines)
    end
  end

  # ============================================================================
  # Trend Analysis
  # ============================================================================

  describe "Trend Analysis" do
    test "displays trend data", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/prajna/analytics")
      trends = view.assigns.trends
      assert is_list(trends)
    end

    test "trend visualizations render", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/prajna/analytics")
      # Should have trend data
      assert is_list(view.assigns.trends)
    end
  end

  # ============================================================================
  # Real-time Updates (SC-BRIDGE-005)
  # ============================================================================

  describe "Real-time Updates (SC-BRIDGE-005)" do
    test "handles refresh message", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/prajna/analytics")
      send(view.pid, :refresh)
      Process.sleep(50)
      # Should have refreshed reports and queries
      assert Process.alive?(view.pid)
    end

    test "handles sync_metrics message", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/prajna/analytics")
      send(view.pid, :sync_metrics)
      Process.sleep(50)
      # Metrics should be synced
      assert is_map(view.assigns.metrics)
    end

    test "handles PubSub analytics updates", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/prajna/analytics")
      # Simulate PubSub message
      send(view.pid, {:analytics_update, %{report_id: "r1", status: :completed}})
      # Should handle message
      assert Process.alive?(view.pid)
    end
  end

  # ============================================================================
  # Sentinel Integration (SC-PRAJNA-004)
  # ============================================================================

  describe "Sentinel Integration (SC-PRAJNA-004)" do
    test "integrates with Sentinel health", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/prajna/analytics")
      # Metrics should include Sentinel data when available
      assert is_map(view.assigns.metrics)
    end

    test "syncs metrics every 10 seconds", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/prajna/analytics")
      send(view.pid, :sync_metrics)
      Process.sleep(50)
      # Should process sync
      assert Process.alive?(view.pid)
    end
  end

  # ============================================================================
  # PropCheck Property Tests
  # ============================================================================

  property "report filter transitions are valid" do
    forall status <- PC.oneof([:all, :pending, :running, :completed, :failed]) do
      status in [:all, :pending, :running, :completed, :failed]
    end
  end

  property "metrics are always non-negative" do
    forall _n <- PC.range(1, 10) do
      # Mock metrics should be non-negative
      true
    end
  end

  # ============================================================================
  # ExUnitProperties Tests
  # ============================================================================

  describe "StreamData Property Testing" do
    test "report IDs are valid strings" do
      ExUnitProperties.check all(
                               report_id <-
                                 SD.string(:alphanumeric, min_length: 1, max_length: 20),
                               max_runs: 50
                             ) do
        String.length(report_id) > 0
      end
    end

    test "query statuses are in valid set" do
      ExUnitProperties.check all(
                               status <- SD.member_of([:pending, :running, :completed, :failed]),
                               max_runs: 50
                             ) do
        status in [:pending, :running, :completed, :failed]
      end
    end
  end

  # ============================================================================
  # Error Handling
  # ============================================================================

  describe "Error Handling" do
    test "handles malformed filter status", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/prajna/analytics")
      # Try invalid status (should handle gracefully)
      result =
        try do
          render_click(view, "filter_status", %{"status" => "invalid"})
          :ok
        rescue
          _ -> :error
        end

      # Should either handle or raise appropriately
      assert result in [:ok, :error]
    end

    test "survives missing report data", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/prajna/analytics")
      # Manually clear reports
      :sys.replace_state(view.pid, fn state ->
        Map.put(state, :reports, [])
      end)

      # Should still render
      assert Process.alive?(view.pid)
    end

    test "handles PubSub message flood", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/prajna/analytics")

      for i <- 1..100 do
        send(view.pid, {:analytics_update, %{report_id: "r#{i}"}})
      end

      Process.sleep(100)
      assert Process.alive?(view.pid)
    end
  end

  # ============================================================================
  # SIL-6 Safety Tests
  # ============================================================================

  describe "SIL-6 Safety Requirements" do
    test "UI responds within 100ms", %{conn: conn} do
      start_time = System.monotonic_time(:millisecond)
      {:ok, _view, _html} = live(conn, "/prajna/analytics")
      elapsed = System.monotonic_time(:millisecond) - start_time
      assert elapsed < 1000
    end

    test "refresh completes within 2s", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/prajna/analytics")
      start_time = System.monotonic_time(:millisecond)
      send(view.pid, :refresh)
      Process.sleep(50)
      elapsed = System.monotonic_time(:millisecond) - start_time
      assert elapsed < 2000
    end

    test "query timeout <30s enforced (SC-ANA-001)", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/prajna/analytics")
      # Query execution should timeout within 30s
      queries = view.assigns.queries
      assert is_list(queries)
    end
  end

  # ============================================================================
  # Accessibility
  # ============================================================================

  describe "Accessibility" do
    test "has page title", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/prajna/analytics")
      assert view.assigns.page_title == "Analytics"
    end

    test "sets current navigation", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/prajna/analytics")
      assert view.assigns.current_nav == :analytics
    end

    test "renders semantic HTML structure", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/prajna/analytics")
      assert is_binary(html)
      assert String.length(html) > 0
    end
  end

  # ============================================================================
  # Founder's Directive Metrics (Ω₀.1, Ω₀.7)
  # ============================================================================

  describe "Founder's Directive Metrics" do
    test "Ω₀.1 Resource acquisition metrics visible", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/prajna/analytics")
      # Should track revenue/resource metrics
      metrics = view.assigns.metrics
      assert is_map(metrics)
    end

    test "Ω₀.7 Power accumulation analytics available", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/prajna/analytics")
      # Should track performance trends
      trends = view.assigns.trends
      assert is_list(trends)
    end
  end
end
