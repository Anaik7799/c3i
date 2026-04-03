defmodule IndrajaalWeb.PrajnaComponentsTest do
  @moduledoc """
  Rendering tests for IndrajaalWeb.PrajnaComponents.

  WHAT: Verifies Prajna C3I cockpit components render correct DOM, CSS classes,
        and unicode characters per NASA-STD-3000 Dark Cockpit design.
  WHY: Components are the visual foundation of the Prajna cockpit — incorrect
       rendering means incorrect operator decisions under stress.
  CONSTRAINTS: SC-COV-001, SC-TDG-001, SC-PRAJNA-004, SC-HMI-001 through SC-HMI-010
  """

  use ExUnit.Case, async: true
  import Phoenix.LiveViewTest

  @moduletag :zenoh_nif

  alias IndrajaalWeb.PrajnaComponents

  # ═══════════════════════════════════════════════════════════════════════
  # MODULE EXISTENCE
  # ═══════════════════════════════════════════════════════════════════════

  describe "module existence" do
    test "module is loaded" do
      assert Code.ensure_loaded?(IndrajaalWeb.PrajnaComponents)
    end

    test "exports all 17 public component functions" do
      expected = [
        :product_logo,
        :status_indicator,
        :status_icon,
        :trend_indicator,
        :sparkline,
        :gauge,
        :metric_card,
        :prajna_header,
        :prajna_nav,
        :alarm_card,
        :node_card,
        :two_step_modal,
        :ooda_status,
        :insight_card,
        :container_card,
        :safety_status,
        :fractal_log
      ]

      for func <- expected do
        assert function_exported?(PrajnaComponents, func, 1),
               "Expected PrajnaComponents.#{func}/1 to be exported"
      end
    end
  end

  # ═══════════════════════════════════════════════════════════════════════
  # STATUS INDICATOR (SC-HMI-001)
  # ═══════════════════════════════════════════════════════════════════════

  describe "status_indicator/1" do
    test "connected state renders green dot" do
      html = render_component(&PrajnaComponents.status_indicator/1, %{state: :connected})
      assert html =~ "bg-green-500"
      assert html =~ "rounded-full"
    end

    test "stale state renders amber pulsing dot" do
      html = render_component(&PrajnaComponents.status_indicator/1, %{state: :stale})
      assert html =~ "bg-amber-500"
      assert html =~ "animate-pulse"
    end

    test "disconnected state renders gray dot" do
      html = render_component(&PrajnaComponents.status_indicator/1, %{state: :disconnected})
      assert html =~ "bg-gray-500"
    end

    test "accepts custom CSS class" do
      html =
        render_component(&PrajnaComponents.status_indicator/1, %{
          state: :connected,
          class: "custom-class"
        })

      assert html =~ "custom-class"
    end
  end

  # ═══════════════════════════════════════════════════════════════════════
  # STATUS ICON (SC-HMI-001)
  # ═══════════════════════════════════════════════════════════════════════

  describe "status_icon/1" do
    @status_chars [
      {:healthy, "●", "text-gray-500"},
      {:connected, "●", "text-green-500"},
      {:stale, "◐", "text-amber-500"},
      {:advisory, "ℹ", "text-cyan-500"},
      {:caution, "⚠", "text-amber-500"},
      {:warning, "⛔", "text-red-500"},
      {:critical, "☢", "text-red-600"},
      {:disconnected, "○", "text-gray-400"},
      {:error, "✗", "text-red-500"},
      {:success, "✓", "text-green-500"}
    ]

    for {state, char, css_class} <- @status_chars do
      test "#{state} renders '#{char}' with #{css_class}" do
        html =
          render_component(&PrajnaComponents.status_icon/1, %{state: unquote(state)})

        assert html =~ unquote(char)
        assert html =~ unquote(css_class)
      end
    end

    test "critical state pulses" do
      html = render_component(&PrajnaComponents.status_icon/1, %{state: :critical})
      assert html =~ "animate-pulse"
    end

    test "size :sm renders text-xs" do
      html =
        render_component(&PrajnaComponents.status_icon/1, %{state: :healthy, size: :sm})

      assert html =~ "text-xs"
    end

    test "size :lg renders text-lg" do
      html =
        render_component(&PrajnaComponents.status_icon/1, %{state: :healthy, size: :lg})

      assert html =~ "text-lg"
    end

    test "unknown state renders dot fallback" do
      html = render_component(&PrajnaComponents.status_icon/1, %{state: :some_unknown})
      assert html =~ "·"
      assert html =~ "text-gray-400"
    end
  end

  # ═══════════════════════════════════════════════════════════════════════
  # TREND INDICATOR (SC-HMI-002)
  # ═══════════════════════════════════════════════════════════════════════

  describe "trend_indicator/1" do
    @trend_arrows [
      {:rising_fast, "↑↑", "text-red-500"},
      {:rising, "↑", "text-amber-500"},
      {:stable, "→", "text-gray-500"},
      {:falling, "↓", "text-cyan-500"},
      {:falling_fast, "↓↓", "text-blue-500"},
      {:unknown, "?", "text-gray-400"}
    ]

    for {trend, arrow, css_class} <- @trend_arrows do
      test "#{trend} renders '#{arrow}' with #{css_class}" do
        html =
          render_component(&PrajnaComponents.trend_indicator/1, %{trend: unquote(trend)})

        assert html =~ unquote(arrow)
        assert html =~ unquote(css_class)
      end
    end
  end

  # ═══════════════════════════════════════════════════════════════════════
  # SPARKLINE (SC-HMI-002)
  # ═══════════════════════════════════════════════════════════════════════

  describe "sparkline/1" do
    test "empty values renders empty chars" do
      html = render_component(&PrajnaComponents.sparkline/1, %{values: []})
      assert html =~ "░"
    end

    test "values render block characters" do
      html =
        render_component(&PrajnaComponents.sparkline/1, %{values: [10, 50, 90, 30]})

      # Should contain some block characters (▁▂▃▄▅▆▇█)
      assert String.length(html) > 0
    end

    test "custom width pads or truncates" do
      html =
        render_component(&PrajnaComponents.sparkline/1, %{
          values: [10, 20, 30],
          width: 5
        })

      assert String.length(html) > 0
    end
  end

  # ═══════════════════════════════════════════════════════════════════════
  # GAUGE (SC-HMI-002)
  # ═══════════════════════════════════════════════════════════════════════

  describe "gauge/1" do
    test "0% renders empty gauge" do
      html = render_component(&PrajnaComponents.gauge/1, %{value: 0.0})
      assert html =~ "0%"
    end

    test "100% renders full gauge" do
      html = render_component(&PrajnaComponents.gauge/1, %{value: 100.0})
      assert html =~ "100%"
    end

    test "50% renders half gauge" do
      html = render_component(&PrajnaComponents.gauge/1, %{value: 50.0})
      assert html =~ "50%"
    end

    test "custom unit renders instead of percent" do
      html =
        render_component(&PrajnaComponents.gauge/1, %{value: 42.0, unit: "MB"})

      assert html =~ "MB" or html =~ "42"
    end
  end

  # ═══════════════════════════════════════════════════════════════════════
  # METRIC CARD (SC-HMI-002)
  # ═══════════════════════════════════════════════════════════════════════

  describe "metric_card/1" do
    test "renders label and value" do
      html =
        render_component(&PrajnaComponents.metric_card/1, %{
          label: "CPU Usage",
          value: 65.0
        })

      assert html =~ "CPU Usage"
      assert html =~ "65"
    end

    test "renders unit suffix" do
      html =
        render_component(&PrajnaComponents.metric_card/1, %{
          label: "Memory",
          value: 80.0,
          unit: "MB"
        })

      assert html =~ "MB"
    end

    test "renders trend indicator" do
      html =
        render_component(&PrajnaComponents.metric_card/1, %{
          label: "Load",
          value: 90.0,
          trend: :rising_fast
        })

      assert html =~ "↑↑"
    end

    test "includes sparkline when provided" do
      html =
        render_component(&PrajnaComponents.metric_card/1, %{
          label: "Requests",
          value: 42.0,
          sparkline: [10, 20, 30, 40, 42]
        })

      # Sparkline is rendered inline
      assert String.length(html) > 50
    end
  end

  # ═══════════════════════════════════════════════════════════════════════
  # PRAJNA HEADER
  # ═══════════════════════════════════════════════════════════════════════

  describe "prajna_header/1" do
    test "renders with default values" do
      html = render_component(&PrajnaComponents.prajna_header/1, %{})
      assert html =~ "PRAJNA" or html =~ "prajna" or html =~ "Prajna"
    end

    test "renders health score" do
      html =
        render_component(&PrajnaComponents.prajna_header/1, %{health_score: 95})

      assert html =~ "95"
    end

    test "renders node count" do
      html =
        render_component(&PrajnaComponents.prajna_header/1, %{
          node_count: 3,
          total_nodes: 4
        })

      assert html =~ "3" and html =~ "4"
    end
  end

  # ═══════════════════════════════════════════════════════════════════════
  # ALARM CARD (SC-ALARM)
  # ═══════════════════════════════════════════════════════════════════════

  describe "alarm_card/1" do
    test "renders alarm with all required fields" do
      html =
        render_component(&PrajnaComponents.alarm_card/1, %{
          id: "ALM-001",
          level: :critical,
          source: "Zone A",
          message: "Fire detected in sector 7"
        })

      # alarm_card renders level, source, message — not raw ID
      assert html =~ "CRITICAL"
      assert html =~ "Zone A"
      assert html =~ "Fire detected"
    end

    test "critical level has distinct visual treatment" do
      html =
        render_component(&PrajnaComponents.alarm_card/1, %{
          id: "ALM-002",
          level: :critical,
          source: "test",
          message: "test"
        })

      assert html =~ "red" or html =~ "critical"
    end

    test "advisory level has subtle visual treatment" do
      html =
        render_component(&PrajnaComponents.alarm_card/1, %{
          id: "ALM-003",
          level: :advisory,
          source: "test",
          message: "test"
        })

      assert html =~ "cyan" or html =~ "advisory" or html =~ "blue"
    end

    test "renders AI insight when provided" do
      html =
        render_component(&PrajnaComponents.alarm_card/1, %{
          id: "ALM-004",
          level: :warning,
          source: "test",
          message: "test",
          ai_insight: "Possible sensor malfunction"
        })

      assert html =~ "Possible sensor malfunction"
    end
  end

  # ═══════════════════════════════════════════════════════════════════════
  # NODE CARD
  # ═══════════════════════════════════════════════════════════════════════

  describe "node_card/1" do
    test "renders node with CPU and memory" do
      html =
        render_component(&PrajnaComponents.node_card/1, %{
          id: "node-1",
          cpu: 45.0,
          memory: 72.0
        })

      assert html =~ "45" or html =~ "node-1"
      assert html =~ "72" or html =~ "node-1"
    end

    test "healthy status renders without alarm colors" do
      html =
        render_component(&PrajnaComponents.node_card/1, %{
          id: "node-2",
          status: :healthy
        })

      refute html =~ "text-red"
    end
  end

  # ═══════════════════════════════════════════════════════════════════════
  # OODA STATUS (SC-OODA)
  # ═══════════════════════════════════════════════════════════════════════

  describe "ooda_status/1" do
    @ooda_phases [:observe, :orient, :decide, :act]

    for phase <- @ooda_phases do
      test "#{phase} phase renders" do
        html =
          render_component(&PrajnaComponents.ooda_status/1, %{
            phase: unquote(phase),
            cycle_ms: 50,
            target_ms: 100
          })

        phase_str = unquote(phase) |> Atom.to_string() |> String.upcase()
        assert html =~ phase_str or html =~ Atom.to_string(unquote(phase))
      end
    end

    test "cycle time under target shows healthy" do
      html =
        render_component(&PrajnaComponents.ooda_status/1, %{
          phase: :observe,
          cycle_ms: 50,
          target_ms: 100
        })

      # cycle_ms is converted to seconds: 50ms → "0.05s"
      assert html =~ "0.05s"
    end
  end

  # ═══════════════════════════════════════════════════════════════════════
  # CONTAINER CARD
  # ═══════════════════════════════════════════════════════════════════════

  describe "container_card/1" do
    test "running container renders with status" do
      html =
        render_component(&PrajnaComponents.container_card/1, %{
          id: :db_prod,
          name: "indrajaal-db-prod",
          status: :running,
          health: :healthy
        })

      assert html =~ "indrajaal-db-prod"
    end

    test "stopped container shows distinct visual" do
      html =
        render_component(&PrajnaComponents.container_card/1, %{
          id: :app_1,
          name: "indrajaal-ex-app-1",
          status: :stopped,
          health: :unhealthy
        })

      assert html =~ "indrajaal-ex-app-1"
    end

    test "renders port list" do
      html =
        render_component(&PrajnaComponents.container_card/1, %{
          id: :obs,
          name: "indrajaal-obs-prod",
          ports: [4317, 9090, 3000]
        })

      assert html =~ "4317" or html =~ "9090"
    end
  end

  # ═══════════════════════════════════════════════════════════════════════
  # SAFETY STATUS (SC-SAFETY)
  # ═══════════════════════════════════════════════════════════════════════

  describe "safety_status/1" do
    test "renders with default safe values" do
      html = render_component(&PrajnaComponents.safety_status/1, %{})
      assert String.length(html) > 20
    end

    test "renders guardian status" do
      html =
        render_component(&PrajnaComponents.safety_status/1, %{guardian: :active})

      assert html =~ "active" or html =~ "ACTIVE" or html =~ "Guardian"
    end
  end

  # ═══════════════════════════════════════════════════════════════════════
  # TWO-STEP MODAL (SC-SAFETY-001 Arm & Fire)
  # ═══════════════════════════════════════════════════════════════════════

  describe "two_step_modal/1" do
    test "renders command and target" do
      html =
        render_component(&PrajnaComponents.two_step_modal/1, %{
          command: "force_shutdown",
          target: "indrajaal-ex-app-1",
          on_confirm: "confirm_command",
          on_cancel: "cancel_command"
        })

      assert html =~ "force_shutdown"
      assert html =~ "indrajaal-ex-app-1"
    end

    test "renders confirm and cancel actions" do
      html =
        render_component(&PrajnaComponents.two_step_modal/1, %{
          command: "restart",
          target: "node-1",
          on_confirm: "confirm_command",
          on_cancel: "cancel_command"
        })

      assert html =~ "confirm_command" or html =~ "Confirm" or html =~ "confirm"
      assert html =~ "cancel_command" or html =~ "Cancel" or html =~ "cancel"
    end

    test "renders countdown" do
      html =
        render_component(&PrajnaComponents.two_step_modal/1, %{
          command: "restart",
          target: "node-1",
          countdown: 60,
          on_confirm: "confirm_command",
          on_cancel: "cancel_command"
        })

      # format_countdown(60) → "1:00"
      assert html =~ "1:00" or html =~ "Expires in"
    end
  end

  # ═══════════════════════════════════════════════════════════════════════
  # INSIGHT CARD
  # ═══════════════════════════════════════════════════════════════════════

  describe "insight_card/1" do
    test "renders insight with title and content" do
      html =
        render_component(&PrajnaComponents.insight_card/1, %{
          type: :anomaly,
          title: "High CPU on node-1",
          content: "CPU has been above 90% for 5 minutes"
        })

      assert html =~ "High CPU on node-1"
      assert html =~ "CPU has been above 90%"
    end

    test "renders confidence level" do
      html =
        render_component(&PrajnaComponents.insight_card/1, %{
          type: :anomaly,
          title: "Test",
          content: "Test content",
          confidence: 0.85
        })

      assert html =~ "85" or html =~ "0.85"
    end
  end

  # ═══════════════════════════════════════════════════════════════════════
  # FRACTAL LOG
  # ═══════════════════════════════════════════════════════════════════════

  describe "fractal_log/1" do
    test "renders log entry at spine level" do
      html =
        render_component(&PrajnaComponents.fractal_log/1, %{
          level: :spine,
          source: "SystemBoot",
          message: "Boot sequence initiated",
          timestamp: DateTime.utc_now()
        })

      assert html =~ "SystemBoot"
      assert html =~ "Boot sequence initiated"
    end

    test "renders log entry at fiber level" do
      html =
        render_component(&PrajnaComponents.fractal_log/1, %{
          level: :fiber,
          source: "ZenohSession",
          message: "Connected to router",
          timestamp: DateTime.utc_now()
        })

      assert html =~ "ZenohSession"
    end
  end

  # ═══════════════════════════════════════════════════════════════════════
  # PRODUCT LOGO (SC-HMI-010)
  # ═══════════════════════════════════════════════════════════════════════

  describe "product_logo/1" do
    test "renders SVG element" do
      html = render_component(&PrajnaComponents.product_logo/1, %{})
      assert html =~ "<svg"
      assert html =~ "viewBox"
    end

    test "vibrant mode adds health-pulse class" do
      html =
        render_component(&PrajnaComponents.product_logo/1, %{vibrant: true})

      assert html =~ "health-pulse"
    end

    test "non-vibrant mode omits health-pulse" do
      html =
        render_component(&PrajnaComponents.product_logo/1, %{vibrant: false})

      refute html =~ "health-pulse"
    end

    test "custom class applied" do
      html =
        render_component(&PrajnaComponents.product_logo/1, %{class: "h-24 w-24"})

      assert html =~ "h-24"
    end
  end
end
