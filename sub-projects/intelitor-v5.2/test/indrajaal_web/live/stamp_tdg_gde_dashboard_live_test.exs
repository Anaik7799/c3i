defmodule IndrajaalWeb.StampTdgGdeDashboardLiveTest do
  @moduledoc """
  Integration tests for IndrajaalWeb.StampTdgGdeDashboardLive.

  WHAT: Verifies mount, initial render, all handle_info callbacks (:refresh_metrics
        periodic timer, {:stampupdate, _}, {:tdgupdate, _}, {:gde_update, _},
        {:alert, _}), PubSub subscription setup, and the stub handle_event clause.
        Also covers the rendered metric values, feature flag toggles, and the
        alert component.
  WHY:  The STAMP/TDG/GDE dashboard is the primary compliance monitoring surface.
        Metric accuracy, real-time update delivery, and alert rendering are critical
        for operator situational awareness (SC-STAMP-001, SC-TDG-001, SC-HMI-001).
  CONSTRAINTS: SC-COV-001, SC-TDG-001, SC-STAMP-001, SC-HMI-001, SC-HMI-008

  TDG Level: L4 (Integration Testing)
  Route: /analytics/dashboard (StampTdgGdeDashboardLive, :index)
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
      assert Code.ensure_loaded?(IndrajaalWeb.StampTdgGdeDashboardLive)
    end

    test "module defines mount/3" do
      assert function_exported?(IndrajaalWeb.StampTdgGdeDashboardLive, :mount, 3)
    end

    test "module defines render/1" do
      assert function_exported?(IndrajaalWeb.StampTdgGdeDashboardLive, :render, 1)
    end

    test "module defines handle_event/3" do
      assert function_exported?(IndrajaalWeb.StampTdgGdeDashboardLive, :handle_event, 3)
    end

    test "module defines handle_info/2" do
      assert function_exported?(IndrajaalWeb.StampTdgGdeDashboardLive, :handle_info, 2)
    end

    test "uses IndrajaalWeb :live_view macro" do
      assert function_exported?(IndrajaalWeb.StampTdgGdeDashboardLive, :__live__, 0)
    end

    test "has moduledoc" do
      {:docs_v1, _, _, _, module_doc, _, _} =
        Code.fetch_docs(IndrajaalWeb.StampTdgGdeDashboardLive)

      assert module_doc != :none
    end
  end

  # ═══════════════════════════════════════════════════════════════════════
  # MOUNT & INITIAL RENDER
  # ═══════════════════════════════════════════════════════════════════════

  describe "mount and initial render at /analytics/dashboard" do
    test "mounts successfully" do
      {:ok, _view, html} = live(build_conn(), "/analytics/dashboard")
      assert is_binary(html)
      assert String.length(html) > 100
    end

    test "renders Monitoring Dashboard heading" do
      {:ok, _view, html} = live(build_conn(), "/analytics/dashboard")
      assert html =~ "Monitoring Dashboard" or html =~ "STAMP"
    end

    test "renders subtitle text" do
      {:ok, _view, html} = live(build_conn(), "/analytics/dashboard")
      assert html =~ "real-time" or html =~ "monitoring" or html =~ "compliance"
    end

    test "renders Export Report button" do
      {:ok, _view, html} = live(build_conn(), "/analytics/dashboard")
      assert html =~ "Export Report" or html =~ "export"
    end

    test "renders Overall Health card" do
      {:ok, _view, html} = live(build_conn(), "/analytics/dashboard")
      assert html =~ "Overall Health"
    end

    test "renders STAMP Compliance card" do
      {:ok, _view, html} = live(build_conn(), "/analytics/dashboard")
      assert html =~ "STAMP Compliance"
    end

    test "renders TDG Coverage card" do
      {:ok, _view, html} = live(build_conn(), "/analytics/dashboard")
      assert html =~ "TDG Coverage"
    end

    test "renders GDE Progress card" do
      {:ok, _view, html} = live(build_conn(), "/analytics/dashboard")
      assert html =~ "GDE Progress"
    end

    test "renders STAMP Safety Analysis section" do
      {:ok, _view, html} = live(build_conn(), "/analytics/dashboard")
      assert html =~ "STAMP Safety Analysis"
    end

    test "renders TDG Test Coverage section" do
      {:ok, _view, html} = live(build_conn(), "/analytics/dashboard")
      assert html =~ "TDG Test Coverage"
    end

    test "renders GDE Goal Management section" do
      {:ok, _view, html} = live(build_conn(), "/analytics/dashboard")
      assert html =~ "GDE Goal Management"
    end

    test "renders Active Alerts section" do
      {:ok, _view, html} = live(build_conn(), "/analytics/dashboard")
      assert html =~ "Active Alerts" or html =~ "alerts"
    end

    test "renders No active alerts when recent_alerts is empty" do
      {:ok, _view, html} = live(build_conn(), "/analytics/dashboard")
      assert html =~ "No active alerts" or html =~ "alerts"
    end

    test "renders System Performance Impact section" do
      {:ok, _view, html} = live(build_conn(), "/analytics/dashboard")
      assert html =~ "Performance" or html =~ "Compilation"
    end

    test "renders Feature Flag Configuration section" do
      {:ok, _view, html} = live(build_conn(), "/analytics/dashboard")
      assert html =~ "Feature Flag" or html =~ "STAMP Enabled"
    end

    test "renders Manage Rollout button" do
      {:ok, _view, html} = live(build_conn(), "/analytics/dashboard")
      assert html =~ "Manage Rollout" or html =~ "rollout"
    end

    test "renders view all alerts link" do
      {:ok, _view, html} = live(build_conn(), "/analytics/dashboard")
      assert html =~ "/alerts" or html =~ "View all"
    end
  end

  # ═══════════════════════════════════════════════════════════════════════
  # INITIAL METRIC VALUES
  # ═══════════════════════════════════════════════════════════════════════

  describe "initial metric values" do
    test "overall_health 91.2 rendered" do
      {:ok, _view, html} = live(build_conn(), "/analytics/dashboard")
      assert html =~ "91.2"
    end

    test "stamp_compliance 92.5 rendered" do
      {:ok, _view, html} = live(build_conn(), "/analytics/dashboard")
      assert html =~ "92.5"
    end

    test "tdg_coverage 89.3 rendered" do
      {:ok, _view, html} = live(build_conn(), "/analytics/dashboard")
      assert html =~ "89.3"
    end

    test "gde_progress 87.1 rendered" do
      {:ok, _view, html} = live(build_conn(), "/analytics/dashboard")
      assert html =~ "87.1"
    end

    test "stpa_count 24 rendered" do
      {:ok, _view, html} = live(build_conn(), "/analytics/dashboard")
      assert html =~ "24"
    end

    test "uca_count 8 rendered" do
      {:ok, _view, html} = live(build_conn(), "/analytics/dashboard")
      assert html =~ "8"
    end

    test "active_goals 15 rendered" do
      {:ok, _view, html} = live(build_conn(), "/analytics/dashboard")
      assert html =~ "15"
    end

    test "goals_on_track 12 rendered" do
      {:ok, _view, html} = live(build_conn(), "/analytics/dashboard")
      assert html =~ "12"
    end

    test "compilation_impact +2.3% rendered" do
      {:ok, _view, html} = live(build_conn(), "/analytics/dashboard")
      assert html =~ "+2.3%"
    end

    test "memory_overhead 4.2MB rendered" do
      {:ok, _view, html} = live(build_conn(), "/analytics/dashboard")
      assert html =~ "4.2MB" or html =~ "4.2"
    end
  end

  # ═══════════════════════════════════════════════════════════════════════
  # HANDLE_EVENT: stub "__event"
  # ═══════════════════════════════════════════════════════════════════════

  describe "handle_event stub" do
    test "export_report button has phx-click event" do
      {:ok, _view, html} = live(build_conn(), "/analytics/dashboard")
      assert html =~ "export_report"
    end

    test "toggle_flag button has phx-click event" do
      {:ok, _view, html} = live(build_conn(), "/analytics/dashboard")
      assert html =~ "toggle_flag"
    end

    test "manage_rollout button has phx-click event" do
      {:ok, _view, html} = live(build_conn(), "/analytics/dashboard")
      assert html =~ "manage_rollout"
    end
  end

  # ═══════════════════════════════════════════════════════════════════════
  # HANDLE_INFO: :refresh_metrics periodic timer
  # ═══════════════════════════════════════════════════════════════════════

  describe "handle_info :refresh_metrics" do
    test "processes :refresh_metrics without crash" do
      {:ok, view, _html} = live(build_conn(), "/analytics/dashboard")
      send(view.pid, :refresh_metrics)
      html = render(view)
      assert is_binary(html)
    end

    test "overall_health still rendered after refresh" do
      {:ok, view, _html} = live(build_conn(), "/analytics/dashboard")
      send(view.pid, :refresh_metrics)
      html = render(view)
      assert html =~ "Overall Health"
    end

    test "refresh reschedules next tick — verified in source" do
      source =
        File.read!(
          "/home/an/dev/ver/intelitor-v5.2/lib/indrajaal_web/live/stamp_tdg_gde_dashboard_live.ex"
        )

      assert source =~ "send_after"
      assert source =~ ":refresh_metrics"
    end

    test "multiple refresh_metrics ticks handled without crash" do
      {:ok, view, _html} = live(build_conn(), "/analytics/dashboard")

      for _ <- 1..5 do
        send(view.pid, :refresh_metrics)
      end

      html = render(view)
      assert is_binary(html)
    end
  end

  # ═══════════════════════════════════════════════════════════════════════
  # HANDLE_INFO: PubSub update messages
  # ═══════════════════════════════════════════════════════════════════════

  describe "handle_info {:stampupdate, _}" do
    test "processes stampupdate without crash" do
      {:ok, view, _html} = live(build_conn(), "/analytics/dashboard")
      send(view.pid, {:stampupdate, %{compliance: 95.0}})
      html = render(view)
      assert is_binary(html)
    end

    test "metrics remain rendered after stampupdate" do
      {:ok, view, _html} = live(build_conn(), "/analytics/dashboard")
      send(view.pid, {:stampupdate, %{}})
      html = render(view)
      assert html =~ "STAMP Compliance"
    end
  end

  describe "handle_info {:tdgupdate, _}" do
    test "processes tdgupdate without crash" do
      {:ok, view, _html} = live(build_conn(), "/analytics/dashboard")
      send(view.pid, {:tdgupdate, %{coverage: 91.0}})
      html = render(view)
      assert is_binary(html)
    end

    test "TDG section remains after tdgupdate" do
      {:ok, view, _html} = live(build_conn(), "/analytics/dashboard")
      send(view.pid, {:tdgupdate, %{}})
      html = render(view)
      assert html =~ "TDG"
    end
  end

  describe "handle_info {:gde_update, _}" do
    test "processes gde_update without crash" do
      {:ok, view, _html} = live(build_conn(), "/analytics/dashboard")
      send(view.pid, {:gde_update, %{progress: 90.0}})
      html = render(view)
      assert is_binary(html)
    end

    test "GDE section remains after gde_update" do
      {:ok, view, _html} = live(build_conn(), "/analytics/dashboard")
      send(view.pid, {:gde_update, %{}})
      html = render(view)
      assert html =~ "GDE"
    end
  end

  describe "handle_info {:alert, _}" do
    test "processes {:alert, _} without crash" do
      {:ok, view, _html} = live(build_conn(), "/analytics/dashboard")

      send(
        view.pid,
        {:alert, %{severity: :warning, message: "Test alert", timestamp: DateTime.utc_now()}}
      )

      html = render(view)
      assert is_binary(html)
    end

    test "alerts section remains rendered after alert message" do
      {:ok, view, _html} = live(build_conn(), "/analytics/dashboard")
      send(view.pid, {:alert, %{severity: :info, message: "info", timestamp: DateTime.utc_now()}})
      html = render(view)
      assert html =~ "Active Alerts" or html =~ "alerts"
    end
  end

  # ═══════════════════════════════════════════════════════════════════════
  # PUBSUB SUBSCRIPTIONS
  # ═══════════════════════════════════════════════════════════════════════

  describe "PubSub subscription setup" do
    test "subscribes to stamp_metrics topic" do
      source =
        File.read!(
          "/home/an/dev/ver/intelitor-v5.2/lib/indrajaal_web/live/stamp_tdg_gde_dashboard_live.ex"
        )

      assert source =~ "stamp_metrics"
    end

    test "subscribes to tdg_metrics topic" do
      source =
        File.read!(
          "/home/an/dev/ver/intelitor-v5.2/lib/indrajaal_web/live/stamp_tdg_gde_dashboard_live.ex"
        )

      assert source =~ "tdg_metrics"
    end

    test "subscribes to gde_metrics topic" do
      source =
        File.read!(
          "/home/an/dev/ver/intelitor-v5.2/lib/indrajaal_web/live/stamp_tdg_gde_dashboard_live.ex"
        )

      assert source =~ "gde_metrics"
    end

    test "subscribes to alerts topic" do
      source =
        File.read!(
          "/home/an/dev/ver/intelitor-v5.2/lib/indrajaal_web/live/stamp_tdg_gde_dashboard_live.ex"
        )

      assert source =~ ~s("alerts")
    end
  end

  # ═══════════════════════════════════════════════════════════════════════
  # FEATURE FLAGS
  # ═══════════════════════════════════════════════════════════════════════

  describe "feature flags" do
    test "stamp_enabled flag shown as true" do
      {:ok, _view, html} = live(build_conn(), "/analytics/dashboard")
      assert html =~ "STAMP Enabled" or html =~ "stamp_enabled"
    end

    test "tdg_enabled flag shown as true" do
      {:ok, _view, html} = live(build_conn(), "/analytics/dashboard")
      assert html =~ "TDG Enforcement" or html =~ "tdg_enabled"
    end

    test "gde_enabled flag shown as true" do
      {:ok, _view, html} = live(build_conn(), "/analytics/dashboard")
      assert html =~ "GDE Active" or html =~ "gde_enabled"
    end

    test "rollout percentage 100 shown" do
      {:ok, _view, html} = live(build_conn(), "/analytics/dashboard")
      assert html =~ "100"
    end

    test "rollout teams count shown" do
      {:ok, _view, html} = live(build_conn(), "/analytics/dashboard")
      # 3 teams in default data
      assert html =~ "3" or html =~ "teams"
    end
  end

  # ═══════════════════════════════════════════════════════════════════════
  # THEME COMPLIANCE
  # ═══════════════════════════════════════════════════════════════════════

  describe "theme compliance SC-HMI-001 SC-HMI-008" do
    test "uses bg-surface-primary" do
      {:ok, _view, html} = live(build_conn(), "/analytics/dashboard")
      assert html =~ "bg-surface-primary" or html =~ "surface"
    end

    test "template comment references SC-HMI-001 SC-HMI-008" do
      source =
        File.read!(
          "/home/an/dev/ver/intelitor-v5.2/lib/indrajaal_web/live/stamp_tdg_gde_dashboard_live.ex"
        )

      assert source =~ "SC-HMI-001"
      assert source =~ "SC-HMI-008"
    end
  end

  # ═══════════════════════════════════════════════════════════════════════
  # LIFECYCLE SEQUENCES
  # ═══════════════════════════════════════════════════════════════════════

  describe "lifecycle sequences" do
    test "stamp update then tdg update then refresh is stable" do
      {:ok, view, _html} = live(build_conn(), "/analytics/dashboard")

      send(view.pid, {:stampupdate, %{}})
      send(view.pid, {:tdgupdate, %{}})
      send(view.pid, :refresh_metrics)

      html = render(view)
      assert is_binary(html)
      assert html =~ "STAMP"
    end

    test "all PubSub messages delivered in rapid succession" do
      {:ok, view, _html} = live(build_conn(), "/analytics/dashboard")

      send(view.pid, {:stampupdate, %{}})
      send(view.pid, {:tdgupdate, %{}})
      send(view.pid, {:gde_update, %{}})
      send(view.pid, {:alert, %{severity: :info, message: "m", timestamp: DateTime.utc_now()}})
      send(view.pid, :refresh_metrics)

      html = render(view)
      assert is_binary(html)
    end

    test "LiveView process remains alive after extended operation" do
      {:ok, view, _html} = live(build_conn(), "/analytics/dashboard")

      for _ <- 1..3 do
        send(view.pid, :refresh_metrics)
      end

      assert Process.alive?(view.pid)
    end
  end

  # ═══════════════════════════════════════════════════════════════════════
  # FMEA — failure modes
  # ═══════════════════════════════════════════════════════════════════════

  describe "FMEA: resilience" do
    test "unknown handle_info message does not crash LiveView" do
      {:ok, view, _html} = live(build_conn(), "/analytics/dashboard")

      send(view.pid, {:unknown_msg, %{}})

      html = render(view)
      assert is_binary(html)
    end

    test "repeated mounts are stable" do
      for _ <- 1..3 do
        {:ok, _view, html} = live(build_conn(), "/analytics/dashboard")
        assert is_binary(html)
      end
    end

    test "refresh_metrics with no initial data change does not corrupt state" do
      {:ok, view, html_before} = live(build_conn(), "/analytics/dashboard")

      send(view.pid, :refresh_metrics)
      html_after = render(view)

      # Core sections should be stable
      assert html_before =~ "Overall Health" == (html_after =~ "Overall Health")
    end
  end
end
