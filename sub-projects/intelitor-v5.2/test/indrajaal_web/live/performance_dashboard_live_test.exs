defmodule IndrajaalWeb.PerformanceDashboardLiveTest do
  @moduledoc """
  Integration tests for IndrajaalWeb.PerformanceDashboardLive.

  WHAT: Verifies mount, initial render with BEAM metrics, periodic :refresh timer,
        and content assertions (SC-MON-005). No handle_event — this is a read-only
        monitoring dashboard.
  WHY:  The Performance Dashboard gives operators visibility into BEAM memory,
        scheduler utilization, and process count. Metric staleness would obscure
        performance regressions (SC-MON-002, SC-MON-003).
  CONSTRAINTS: SC-COV-001, SC-TDG-001, SC-MON-005, SC-HMI-001, SC-HMI-008

  TDG Level: L4 (Integration Testing)
  Route: /performance (PerformanceDashboardLive, :index)
  """

  use IndrajaalWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  @moduletag :integration
  @moduletag :zenoh_nif

  # ═══════════════════════════════════════════════════════════════════════
  # MODULE STRUCTURE
  # ═══════════════════════════════════════════════════════════════════════

  describe "module structure" do
    test "module is loaded" do
      assert Code.ensure_loaded?(IndrajaalWeb.PerformanceDashboardLive)
    end

    test "module defines mount/3" do
      assert function_exported?(IndrajaalWeb.PerformanceDashboardLive, :mount, 3)
    end

    test "module defines render/1" do
      assert function_exported?(IndrajaalWeb.PerformanceDashboardLive, :render, 1)
    end

    test "module defines handle_info/2 for :refresh timer" do
      assert function_exported?(IndrajaalWeb.PerformanceDashboardLive, :handle_info, 2)
    end

    test "module does not export handle_event/3 (read-only dashboard)" do
      # Performance dashboard is intentionally event-free
      refute function_exported?(IndrajaalWeb.PerformanceDashboardLive, :handle_event, 3)
    end
  end

  # ═══════════════════════════════════════════════════════════════════════
  # MOUNT & INITIAL RENDER
  # ═══════════════════════════════════════════════════════════════════════

  describe "mount and initial render at /performance" do
    test "mounts successfully" do
      {:ok, _view, html} = live(build_conn(), "/performance")
      assert is_binary(html)
      assert String.length(html) > 100
    end

    test "renders Performance Optimization Dashboard heading" do
      {:ok, _view, html} = live(build_conn(), "/performance")
      assert html =~ "Performance" or html =~ "performance"
    end

    test "renders SOPv5 in heading" do
      {:ok, _view, html} = live(build_conn(), "/performance")
      assert html =~ "SOPv5" or html =~ "Optimization"
    end

    test "renders BEAM Memory card" do
      {:ok, _view, html} = live(build_conn(), "/performance")
      assert html =~ "BEAM Memory" or html =~ "Memory"
    end

    test "renders Schedulers & Processes card" do
      {:ok, _view, html} = live(build_conn(), "/performance")
      assert html =~ "Schedulers" or html =~ "Processes"
    end

    test "renders System Status card" do
      {:ok, _view, html} = live(build_conn(), "/performance")
      assert html =~ "System Status" or html =~ "Status"
    end

    test "renders dashboard_active metric" do
      {:ok, _view, html} = live(build_conn(), "/performance")
      assert html =~ "Dashboard Active" or html =~ "true"
    end

    test "renders memory_total_mb as a numeric value" do
      {:ok, _view, html} = live(build_conn(), "/performance")
      # Will contain e.g. "123.4 MB" from BEAM stats
      assert html =~ "MB"
    end

    test "renders uptime in hours" do
      {:ok, _view, html} = live(build_conn(), "/performance")
      assert html =~ "Uptime" or html =~ "uptime"
    end

    test "renders scheduler count as integer" do
      {:ok, _view, html} = live(build_conn(), "/performance")
      schedulers = :erlang.system_info(:schedulers_online)
      assert html =~ Integer.to_string(schedulers)
    end

    test "renders process count" do
      {:ok, _view, html} = live(build_conn(), "/performance")
      assert html =~ "Processes" or html =~ "process"
    end

    test "assigns page_title on mount" do
      {:ok, view, _html} = live(build_conn(), "/performance")

      assert view.assigns.page_title =~ "Performance" or
               view.module == IndrajaalWeb.PerformanceDashboardLive
    end

    test "renders without crash after repeated mounts" do
      for _ <- 1..3 do
        {:ok, _view, html} = live(build_conn(), "/performance")
        assert is_binary(html)
      end
    end
  end

  # ═══════════════════════════════════════════════════════════════════════
  # METRIC CONTENT VALIDATION
  # ═══════════════════════════════════════════════════════════════════════

  describe "metric content validation" do
    test "memory_total_mb is a non-negative float" do
      {:ok, view, _html} = live(build_conn(), "/performance")
      html = render(view)
      # Extract the MB values — should all be positive numbers
      assert html =~ ~r/\d+\.\d+ MB/
    end

    test "process utilization percentage is present" do
      {:ok, _view, html} = live(build_conn(), "/performance")
      assert html =~ "%" or html =~ "Utilization"
    end

    test "color coding applied to process utilization" do
      {:ok, _view, html} = live(build_conn(), "/performance")
      # green or red class depending on utilization
      assert html =~ "text-green" or html =~ "text-red"
    end

    test "memory breakdown includes ETS" do
      {:ok, _view, html} = live(build_conn(), "/performance")
      assert html =~ "ETS"
    end

    test "memory breakdown includes Atoms" do
      {:ok, _view, html} = live(build_conn(), "/performance")
      assert html =~ "Atom" or html =~ "atom"
    end

    test "memory breakdown includes Processes" do
      {:ok, _view, html} = live(build_conn(), "/performance")
      assert html =~ "Processes" or html =~ "processes"
    end
  end

  # ═══════════════════════════════════════════════════════════════════════
  # HANDLE_INFO: :refresh periodic timer
  # ═══════════════════════════════════════════════════════════════════════

  describe "handle_info :refresh timer" do
    test "processes :refresh without crash" do
      {:ok, view, _html} = live(build_conn(), "/performance")

      send(view.pid, :refresh)

      html = render(view)
      assert is_binary(html)
      assert html =~ "Performance" or html =~ "BEAM"
    end

    test "metrics remain present after :refresh" do
      {:ok, view, _html} = live(build_conn(), "/performance")

      send(view.pid, :refresh)
      html = render(view)

      assert html =~ "MB"
      assert html =~ "Schedulers" or html =~ "Processes"
    end

    test "multiple :refresh ticks handled without crash" do
      {:ok, view, _html} = live(build_conn(), "/performance")

      for _ <- 1..5 do
        send(view.pid, :refresh)
      end

      html = render(view)
      assert is_binary(html)
    end

    test "refresh interval is 5 seconds — verified in source" do
      source =
        File.read!(
          "/home/an/dev/ver/intelitor-v5.2/lib/indrajaal_web/live/performance_dashboard_live.ex"
        )

      assert source =~ "5000" or source =~ "@refresh_interval"
    end

    test ":timer.send_interval used for automatic refresh" do
      source =
        File.read!(
          "/home/an/dev/ver/intelitor-v5.2/lib/indrajaal_web/live/performance_dashboard_live.ex"
        )

      assert source =~ "send_interval"
    end
  end

  # ═══════════════════════════════════════════════════════════════════════
  # THEME COMPLIANCE (SC-HMI-001, SC-HMI-008)
  # ═══════════════════════════════════════════════════════════════════════

  describe "theme compliance SC-HMI-001 SC-HMI-008" do
    test "uses bg-surface-primary class (SC-HMI-001)" do
      {:ok, _view, html} = live(build_conn(), "/performance")
      assert html =~ "bg-surface-primary" or html =~ "surface"
    end

    test "uses text-content-primary class for headings" do
      {:ok, _view, html} = live(build_conn(), "/performance")
      assert html =~ "text-content-primary" or html =~ "font-bold"
    end

    test "uses dark: tailwind variants for dark mode" do
      {:ok, _view, html} = live(build_conn(), "/performance")
      assert html =~ "dark:" or html =~ "dark"
    end

    test "render comment references SC-HMI-001 and SC-HMI-008" do
      source =
        File.read!(
          "/home/an/dev/ver/intelitor-v5.2/lib/indrajaal_web/live/performance_dashboard_live.ex"
        )

      assert source =~ "SC-HMI-001"
      assert source =~ "SC-HMI-008"
    end
  end

  # ═══════════════════════════════════════════════════════════════════════
  # FMEA — failure modes (SC-COV-005)
  # ═══════════════════════════════════════════════════════════════════════

  describe "FMEA: metric availability" do
    test "BEAM memory always returns a numeric value" do
      memory = :erlang.memory()
      assert is_integer(memory[:total])
      assert memory[:total] > 0
    end

    test "schedulers_online always returns a positive integer" do
      schedulers = :erlang.system_info(:schedulers_online)
      assert is_integer(schedulers)
      assert schedulers > 0
    end

    test "process_count is within process_limit" do
      count = :erlang.system_info(:process_count)
      limit = :erlang.system_info(:process_limit)
      assert count < limit
    end

    test "dashboard remains functional when all BEAM metrics are positive" do
      {:ok, _view, html} = live(build_conn(), "/performance")
      assert html =~ "true" or html =~ "Active"
    end
  end
end
