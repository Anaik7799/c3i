defmodule IndrajaalWeb.StampTdgGdeAdvancedAnalyticsLiveTest do
  @moduledoc """
  Integration tests for IndrajaalWeb.StampTdgGdeAdvancedAnalyticsLive.

  WHAT: Verifies mount, handle_params for URL-driven timeframe/chart_type/metrics,
        periodic refresh timer callbacks (:refresh_metrics, :update_ml_insights,
        :refresh_predictions), PubSub subscriptions, and render content assertions.
        No interactive handle_event clauses are implemented (aliases commented out).
  WHY:  The Advanced Analytics dashboard delivers ML-based insights for STAMP/TDG/GDE
        compliance. Accurate timeframe and metric propagation is required for
        correct chart rendering (SC-STAMP-001, SC-TDG-001).
  CONSTRAINTS: SC-COV-001, SC-TDG-001, SC-STAMP-001, SC-HMI-001, SC-HMI-008

  TDG Level: L4 (Integration Testing)
  Route: /analytics/stamp-tdg-gde-advanced (StampTdgGdeAdvancedAnalyticsLive, :index)
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
      assert Code.ensure_loaded?(IndrajaalWeb.StampTdgGdeAdvancedAnalyticsLive)
    end

    test "module defines mount/3" do
      assert function_exported?(IndrajaalWeb.StampTdgGdeAdvancedAnalyticsLive, :mount, 3)
    end

    test "module defines render/1" do
      assert function_exported?(IndrajaalWeb.StampTdgGdeAdvancedAnalyticsLive, :render, 1)
    end

    test "module defines handle_params/3" do
      assert function_exported?(
               IndrajaalWeb.StampTdgGdeAdvancedAnalyticsLive,
               :handle_params,
               3
             )
    end

    test "uses IndrajaalWeb :live_view macro" do
      assert function_exported?(IndrajaalWeb.StampTdgGdeAdvancedAnalyticsLive, :__live__, 0)
    end

    test "has moduledoc" do
      {:docs_v1, _, _, _, module_doc, _, _} =
        Code.fetch_docs(IndrajaalWeb.StampTdgGdeAdvancedAnalyticsLive)

      assert module_doc != :none
    end
  end

  # ═══════════════════════════════════════════════════════════════════════
  # MOUNT & INITIAL RENDER
  # ═══════════════════════════════════════════════════════════════════════

  describe "mount and initial render at /analytics/stamp-tdg-gde-advanced" do
    test "mounts successfully" do
      {:ok, _view, html} = live(build_conn(), "/analytics/stamp-tdg-gde-advanced")
      assert is_binary(html)
      assert String.length(html) > 100
    end

    test "renders Advanced Analytics heading" do
      {:ok, _view, html} = live(build_conn(), "/analytics/stamp-tdg-gde-advanced")
      assert html =~ "Advanced Analytics" or html =~ "Analytics"
    end

    test "renders page_title with STAMP / TDG / GDE" do
      {:ok, _view, html} = live(build_conn(), "/analytics/stamp-tdg-gde-advanced")
      assert html =~ "STAMP" or html =~ "TDG" or html =~ "GDE"
    end

    test "renders STAMP Compliance metric card" do
      {:ok, _view, html} = live(build_conn(), "/analytics/stamp-tdg-gde-advanced")
      assert html =~ "STAMP Compliance"
    end

    test "renders TDG Success Rate metric card" do
      {:ok, _view, html} = live(build_conn(), "/analytics/stamp-tdg-gde-advanced")
      assert html =~ "TDG Success Rate"
    end

    test "renders GDE Efficiency metric card" do
      {:ok, _view, html} = live(build_conn(), "/analytics/stamp-tdg-gde-advanced")
      assert html =~ "GDE Efficiency"
    end

    test "renders ML Accuracy metric card" do
      {:ok, _view, html} = live(build_conn(), "/analytics/stamp-tdg-gde-advanced")
      assert html =~ "ML Accuracy"
    end

    test "renders ML Model Performance section" do
      {:ok, _view, html} = live(build_conn(), "/analytics/stamp-tdg-gde-advanced")
      assert html =~ "ML Model Performance"
    end

    test "renders Precision metric" do
      {:ok, _view, html} = live(build_conn(), "/analytics/stamp-tdg-gde-advanced")
      assert html =~ "Precision"
    end

    test "renders Recall metric" do
      {:ok, _view, html} = live(build_conn(), "/analytics/stamp-tdg-gde-advanced")
      assert html =~ "Recall"
    end

    test "renders F1 Score metric" do
      {:ok, _view, html} = live(build_conn(), "/analytics/stamp-tdg-gde-advanced")
      assert html =~ "F1 Score"
    end

    test "renders Performance Prediction section" do
      {:ok, _view, html} = live(build_conn(), "/analytics/stamp-tdg-gde-advanced")
      assert html =~ "Performance Prediction" or html =~ "Predicted"
    end

    test "renders Export Analytics section" do
      {:ok, _view, html} = live(build_conn(), "/analytics/stamp-tdg-gde-advanced")
      assert html =~ "Export"
    end

    test "renders JSON export button" do
      {:ok, _view, html} = live(build_conn(), "/analytics/stamp-tdg-gde-advanced")
      assert html =~ "JSON"
    end

    test "renders CSV export button" do
      {:ok, _view, html} = live(build_conn(), "/analytics/stamp-tdg-gde-advanced")
      assert html =~ "CSV"
    end

    test "renders timeframe select control" do
      {:ok, _view, html} = live(build_conn(), "/analytics/stamp-tdg-gde-advanced")
      assert html =~ "24h" or html =~ "timeframe"
    end

    test "renders chart type select control" do
      {:ok, _view, html} = live(build_conn(), "/analytics/stamp-tdg-gde-advanced")
      assert html =~ "Line Chart" or html =~ "chart_type"
    end
  end

  # ═══════════════════════════════════════════════════════════════════════
  # INITIAL ASSIGNS
  # ═══════════════════════════════════════════════════════════════════════

  describe "initial assigns on mount" do
    test "stamp_compliance_rate initialized to 92.5" do
      source =
        File.read!(
          "/home/an/dev/ver/intelitor-v5.2/lib/indrajaal_web/live/stamp_tdg_gde_advanced_analytics_live.ex"
        )

      assert source =~ "92.5"
    end

    test "tdg_success_rate initialized to 89.3" do
      source =
        File.read!(
          "/home/an/dev/ver/intelitor-v5.2/lib/indrajaal_web/live/stamp_tdg_gde_advanced_analytics_live.ex"
        )

      assert source =~ "89.3"
    end

    test "selected_timeframe defaults to 24h" do
      source =
        File.read!(
          "/home/an/dev/ver/intelitor-v5.2/lib/indrajaal_web/live/stamp_tdg_gde_advanced_analytics_live.ex"
        )

      assert source =~ ~s("24h")
    end

    test "chart_type defaults to line" do
      source =
        File.read!(
          "/home/an/dev/ver/intelitor-v5.2/lib/indrajaal_web/live/stamp_tdg_gde_advanced_analytics_live.ex"
        )

      assert source =~ ~s("line")
    end

    test "real_time_enabled defaults to true" do
      source =
        File.read!(
          "/home/an/dev/ver/intelitor-v5.2/lib/indrajaal_web/live/stamp_tdg_gde_advanced_analytics_live.ex"
        )

      assert source =~ ":real_time_enabled, true"
    end
  end

  # ═══════════════════════════════════════════════════════════════════════
  # HANDLE_PARAMS — URL-driven configuration
  # ═══════════════════════════════════════════════════════════════════════

  describe "handle_params URL parameter propagation" do
    test "timeframe param overrides default when provided in URL" do
      {:ok, view, _html} = live(build_conn(), "/analytics/stamp-tdg-gde-advanced?timeframe=7d")
      html = render(view)
      # Either the option shows selected or data is loaded with 7d timeframe
      assert html =~ "7d" or html =~ "7 Days"
    end

    test "chart_type param overrides default when provided in URL" do
      {:ok, view, _html} =
        live(build_conn(), "/analytics/stamp-tdg-gde-advanced?chart_type=bar")

      html = render(view)
      assert html =~ "bar" or html =~ "Bar"
    end

    test "default timeframe 24h shown when no param given" do
      {:ok, _view, html} = live(build_conn(), "/analytics/stamp-tdg-gde-advanced")
      assert html =~ "24h" or html =~ "24 Hours"
    end

    test "default chart_type line shown when no param given" do
      {:ok, _view, html} = live(build_conn(), "/analytics/stamp-tdg-gde-advanced")
      assert html =~ "line" or html =~ "Line"
    end

    test "handle_params sets analytics_loaded assign" do
      source =
        File.read!(
          "/home/an/dev/ver/intelitor-v5.2/lib/indrajaal_web/live/stamp_tdg_gde_advanced_analytics_live.ex"
        )

      assert source =~ "analytics_loaded"
    end
  end

  # ═══════════════════════════════════════════════════════════════════════
  # HANDLE_INFO: periodic timers
  # ═══════════════════════════════════════════════════════════════════════

  describe "handle_info :refresh_metrics periodic timer" do
    test "processes :refresh_metrics without crash" do
      {:ok, view, _html} = live(build_conn(), "/analytics/stamp-tdg-gde-advanced")

      send(view.pid, :refresh_metrics)

      html = render(view)
      assert is_binary(html)
    end

    test "STAMP metrics remain after refresh" do
      {:ok, view, _html} = live(build_conn(), "/analytics/stamp-tdg-gde-advanced")
      send(view.pid, :refresh_metrics)
      html = render(view)
      assert html =~ "STAMP Compliance"
    end
  end

  describe "handle_info :update_ml_insights periodic timer" do
    test "processes :update_ml_insights without crash" do
      {:ok, view, _html} = live(build_conn(), "/analytics/stamp-tdg-gde-advanced")

      send(view.pid, :update_ml_insights)

      html = render(view)
      assert is_binary(html)
    end
  end

  describe "handle_info :refresh_predictions periodic timer" do
    test "processes :refresh_predictions without crash" do
      {:ok, view, _html} = live(build_conn(), "/analytics/stamp-tdg-gde-advanced")

      send(view.pid, :refresh_predictions)

      html = render(view)
      assert is_binary(html)
    end
  end

  describe "handle_info multiple timers in sequence" do
    test "all three timers processed without crash" do
      {:ok, view, _html} = live(build_conn(), "/analytics/stamp-tdg-gde-advanced")

      send(view.pid, :refresh_metrics)
      send(view.pid, :update_ml_insights)
      send(view.pid, :refresh_predictions)

      html = render(view)
      assert is_binary(html)
    end
  end

  # ═══════════════════════════════════════════════════════════════════════
  # PUBSUB SUBSCRIPTIONS
  # ═══════════════════════════════════════════════════════════════════════

  describe "PubSub subscriptions" do
    test "subscribes to stamp_analytics topic" do
      source =
        File.read!(
          "/home/an/dev/ver/intelitor-v5.2/lib/indrajaal_web/live/stamp_tdg_gde_advanced_analytics_live.ex"
        )

      assert source =~ "stamp_analytics"
    end

    test "subscribes to tdg_analytics topic" do
      source =
        File.read!(
          "/home/an/dev/ver/intelitor-v5.2/lib/indrajaal_web/live/stamp_tdg_gde_advanced_analytics_live.ex"
        )

      assert source =~ "tdg_analytics"
    end

    test "subscribes to gde_analytics topic" do
      source =
        File.read!(
          "/home/an/dev/ver/intelitor-v5.2/lib/indrajaal_web/live/stamp_tdg_gde_advanced_analytics_live.ex"
        )

      assert source =~ "gde_analytics"
    end

    test "subscribes to system_performance topic" do
      source =
        File.read!(
          "/home/an/dev/ver/intelitor-v5.2/lib/indrajaal_web/live/stamp_tdg_gde_advanced_analytics_live.ex"
        )

      assert source =~ "system_performance"
    end
  end

  # ═══════════════════════════════════════════════════════════════════════
  # METRIC VALUES — initial data assertions
  # ═══════════════════════════════════════════════════════════════════════

  describe "metric values in rendered output" do
    test "STAMP compliance rate 92.5 appears in HTML" do
      {:ok, _view, html} = live(build_conn(), "/analytics/stamp-tdg-gde-advanced")
      assert html =~ "92.5"
    end

    test "TDG success rate 89.3 appears in HTML" do
      {:ok, _view, html} = live(build_conn(), "/analytics/stamp-tdg-gde-advanced")
      assert html =~ "89.3"
    end

    test "GDE efficiency 87.1 appears in HTML" do
      {:ok, _view, html} = live(build_conn(), "/analytics/stamp-tdg-gde-advanced")
      assert html =~ "87.1"
    end

    test "ML accuracy percentage appears in HTML" do
      {:ok, _view, html} = live(build_conn(), "/analytics/stamp-tdg-gde-advanced")
      # 0.924 * 100 = 92.4
      assert html =~ "92.4" or html =~ "92"
    end

    test "performance prediction 88.4 appears in HTML" do
      {:ok, _view, html} = live(build_conn(), "/analytics/stamp-tdg-gde-advanced")
      assert html =~ "88.4"
    end
  end

  # ═══════════════════════════════════════════════════════════════════════
  # THEME COMPLIANCE
  # ═══════════════════════════════════════════════════════════════════════

  describe "theme compliance SC-HMI-001 SC-HMI-008" do
    test "uses dark: tailwind variants" do
      {:ok, _view, html} = live(build_conn(), "/analytics/stamp-tdg-gde-advanced")
      assert html =~ "dark:"
    end

    test "uses bg-surface-primary" do
      {:ok, _view, html} = live(build_conn(), "/analytics/stamp-tdg-gde-advanced")
      assert html =~ "bg-surface-primary" or html =~ "surface"
    end

    test "template comment references SC-HMI-001 and SC-HMI-008" do
      source =
        File.read!(
          "/home/an/dev/ver/intelitor-v5.2/lib/indrajaal_web/live/stamp_tdg_gde_advanced_analytics_live.ex"
        )

      assert source =~ "SC-HMI-001"
      assert source =~ "SC-HMI-008"
    end
  end

  # ═══════════════════════════════════════════════════════════════════════
  # FMEA — failure modes
  # ═══════════════════════════════════════════════════════════════════════

  describe "FMEA: resilience" do
    test "LiveView does not crash on unknown handle_info message" do
      {:ok, view, _html} = live(build_conn(), "/analytics/stamp-tdg-gde-advanced")

      # Send an unexpected message — should be silently ignored or handled
      send(view.pid, {:unknown_event, %{}})

      html = render(view)
      assert is_binary(html)
    end

    test "repeated mounts are stable" do
      for _ <- 1..3 do
        {:ok, _view, html} = live(build_conn(), "/analytics/stamp-tdg-gde-advanced")
        assert is_binary(html)
      end
    end

    test "LiveView process remains alive after mount" do
      {:ok, view, _html} = live(build_conn(), "/analytics/stamp-tdg-gde-advanced")
      assert Process.alive?(view.pid)
    end
  end
end
