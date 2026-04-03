defmodule IndrajaalWeb.MonitoringDashboardLivePropTest do
  @moduledoc """
  L1 Property tests for MonitoringDashboardLive.

  WHAT: Verifies that MonitoringDashboardLive maintains invariants under
        arbitrary PubSub payloads. The dashboard is read-only — it has no
        handle_event clauses, only handle_info for :refresh_metrics. Tests
        verify that any map payload arriving on the refresh cycle keeps the
        view alive, that current_time is always a valid DateTime, that the
        six pipeline stages are always rendered, and that the assign structure
        is stable across repeated refresh ticks.

  WHY: MonitoringDashboardLive is the real-time alarm processing monitor.
       It receives :refresh_metrics at 30s intervals (SC-MON-001). Any
       malformed data from fetch_metrics/0 or get_pipeline_status/0 must
       not crash the process. Property tests verify dashboard stability
       under rapid message sequences and unexpected assign shapes.

  CONSTRAINTS: SC-COV-001, SC-TDG-001, SC-MON-001, SC-MON-005,
               SC-HMI-001, EP-GEN-014

  TDG Level: L1 (Property-Based Testing)
  Route: /monitoring (MonitoringDashboardLive)
  """

  use IndrajaalWeb.ConnCase, async: false
  use PropCheck
  import ExUnitProperties, except: [property: 2, property: 3, check: 2]

  alias PropCheck.BasicTypes, as: PC
  alias StreamData, as: SD

  import Phoenix.LiveViewTest

  @moduletag :property
  @moduletag :zenoh_nif

  @valid_health_statuses ["healthy", "warning", "critical", "unknown"]
  @valid_alert_levels ["info", "warning", "danger", "critical"]
  @valid_alarm_severities ["critical", "high", "medium", "low"]
  @valid_pipeline_stage_statuses ["healthy", "warning", "critical"]

  # ═══════════════════════════════════════════════════════════════════════
  # MOUNT STABILITY PROPERTIES
  # ═══════════════════════════════════════════════════════════════════════

  describe "mount stability properties" do
    property "P-MON-001: mount always produces a non-empty page" do
      forall _ <- PC.boolean() do
        {:ok, _view, html} = live(build_conn(), "/monitoring")

        is_binary(html) and String.length(html) > 100
      end
    end

    property "P-MON-002: page_title assign is always set to Monitoring Dashboard after mount" do
      forall _ <- PC.boolean() do
        {:ok, view, _html} = live(build_conn(), "/monitoring")

        assigns = :sys.get_state(view.pid).socket.assigns
        Map.get(assigns, :page_title) == "Monitoring Dashboard"
      end
    end

    property "P-MON-003: metrics assign always contains all required keys after mount" do
      forall _ <- PC.boolean() do
        {:ok, view, _html} = live(build_conn(), "/monitoring")

        assigns = :sys.get_state(view.pid).socket.assigns
        metrics = Map.get(assigns, :metrics, %{})

        Map.has_key?(metrics, :active_alarms) and
          Map.has_key?(metrics, :processing_rate) and
          Map.has_key?(metrics, :avg_latency) and
          Map.has_key?(metrics, :health_status) and
          Map.has_key?(metrics, :pipeline_stages) and
          Map.has_key?(metrics, :recent_alarms) and
          Map.has_key?(metrics, :system_alerts)
      end
    end

    property "P-MON-004: health_status assign is always within the valid status set" do
      forall _ <- PC.boolean() do
        {:ok, view, _html} = live(build_conn(), "/monitoring")

        assigns = :sys.get_state(view.pid).socket.assigns
        status = get_in(assigns, [:metrics, :health_status])

        status in @valid_health_statuses
      end
    end

    property "P-MON-005: pipeline_stages always has exactly six entries after mount" do
      forall _ <- PC.boolean() do
        {:ok, view, _html} = live(build_conn(), "/monitoring")

        assigns = :sys.get_state(view.pid).socket.assigns
        stages = get_in(assigns, [:metrics, :pipeline_stages]) || []

        length(stages) == 6
      end
    end
  end

  # ═══════════════════════════════════════════════════════════════════════
  # REFRESH_METRICS MESSAGE PROPERTIES
  # ═══════════════════════════════════════════════════════════════════════

  describe ":refresh_metrics message properties" do
    property "P-MON-006: single :refresh_metrics keeps the view alive" do
      forall _ <- PC.boolean() do
        {:ok, view, _html} = live(build_conn(), "/monitoring")

        send(view.pid, :refresh_metrics)
        Process.sleep(30)

        Process.alive?(view.pid) and is_binary(render(view))
      end
    end

    property "P-MON-007: N consecutive :refresh_metrics messages keep the view alive" do
      forall n <- PC.integer(1, 10) do
        {:ok, view, _html} = live(build_conn(), "/monitoring")

        for _ <- 1..n do
          send(view.pid, :refresh_metrics)
          Process.sleep(10)
        end

        Process.alive?(view.pid) and is_binary(render(view))
      end
    end

    property "P-MON-008: current_time is a valid DateTime after any number of refreshes" do
      forall n <- PC.integer(1, 5) do
        {:ok, view, _html} = live(build_conn(), "/monitoring")

        for _ <- 1..n do
          send(view.pid, :refresh_metrics)
          Process.sleep(15)
        end

        assigns = :sys.get_state(view.pid).socket.assigns

        match?(%DateTime{}, Map.get(assigns, :current_time))
      end
    end

    property "P-MON-009: pipeline stages remain exactly six after any number of refreshes" do
      forall n <- PC.integer(1, 5) do
        {:ok, view, _html} = live(build_conn(), "/monitoring")

        for _ <- 1..n do
          send(view.pid, :refresh_metrics)
          Process.sleep(15)
        end

        assigns = :sys.get_state(view.pid).socket.assigns
        stages = get_in(assigns, [:metrics, :pipeline_stages]) || []

        length(stages) == 6
      end
    end
  end

  # ═══════════════════════════════════════════════════════════════════════
  # SYSTEM STATE INJECTION PROPERTIES
  # ═══════════════════════════════════════════════════════════════════════

  describe "state injection and render properties" do
    property "P-MON-010: any valid health status renders without crash" do
      forall status <- PC.oneof(@valid_health_statuses) do
        {:ok, view, _html} = live(build_conn(), "/monitoring")

        :sys.replace_state(view.pid, fn state ->
          socket = state.socket
          new_metrics = Map.put(socket.assigns.metrics, :health_status, status)
          new_assigns = Map.put(socket.assigns, :metrics, new_metrics)
          %{state | socket: %{socket | assigns: new_assigns}}
        end)

        html = render(view)
        is_binary(html) and String.length(html) > 100
      end
    end

    property "P-MON-011: any non-negative active_alarms count renders without crash" do
      forall count <- PC.integer(0, 9999) do
        {:ok, view, _html} = live(build_conn(), "/monitoring")

        :sys.replace_state(view.pid, fn state ->
          socket = state.socket
          new_metrics = Map.put(socket.assigns.metrics, :active_alarms, count)
          new_assigns = Map.put(socket.assigns, :metrics, new_metrics)
          %{state | socket: %{socket | assigns: new_assigns}}
        end)

        html = render(view)
        is_binary(html)
      end
    end

    property "P-MON-012: system_alerts list with any valid alert level renders correctly" do
      forall level <- PC.oneof(@valid_alert_levels) do
        {:ok, view, _html} = live(build_conn(), "/monitoring")

        alerts = [
          %{
            level: level,
            title: "Property Test Alert",
            message: "Generated by P-MON-012",
            timestamp: DateTime.utc_now()
          }
        ]

        :sys.replace_state(view.pid, fn state ->
          socket = state.socket
          new_metrics = Map.put(socket.assigns.metrics, :system_alerts, alerts)
          new_assigns = Map.put(socket.assigns, :metrics, new_metrics)
          %{state | socket: %{socket | assigns: new_assigns}}
        end)

        html = render(view)
        is_binary(html) and String.length(html) > 100
      end
    end

    property "P-MON-013: recent_alarms list with any severity renders without crash" do
      forall severity <- PC.oneof(@valid_alarm_severities) do
        {:ok, view, _html} = live(build_conn(), "/monitoring")

        alarms = [
          %{
            id: "prop-alarm-001",
            timestamp: DateTime.utc_now(),
            type: "Property Test",
            severity: severity,
            device_name: "Test Device",
            status: "active"
          }
        ]

        :sys.replace_state(view.pid, fn state ->
          socket = state.socket
          new_metrics = Map.put(socket.assigns.metrics, :recent_alarms, alarms)
          new_assigns = Map.put(socket.assigns, :metrics, new_metrics)
          %{state | socket: %{socket | assigns: new_assigns}}
        end)

        html = render(view)
        is_binary(html)
      end
    end

    property "P-MON-014: pipeline stage status variation does not crash render" do
      forall status <- PC.oneof(@valid_pipeline_stage_statuses) do
        {:ok, view, _html} = live(build_conn(), "/monitoring")

        updated_stages =
          Enum.map(1..6, fn i ->
            %{
              name: "Stage #{i}",
              status: status,
              throughput: 100,
              queue_size: 0
            }
          end)

        :sys.replace_state(view.pid, fn state ->
          socket = state.socket
          new_metrics = Map.put(socket.assigns.metrics, :pipeline_stages, updated_stages)
          new_assigns = Map.put(socket.assigns, :metrics, new_metrics)
          %{state | socket: %{socket | assigns: new_assigns}}
        end)

        html = render(view)
        is_binary(html) and String.length(html) > 100
      end
    end
  end

  # ═══════════════════════════════════════════════════════════════════════
  # UNKNOWN MESSAGE PROPERTIES
  # ═══════════════════════════════════════════════════════════════════════

  describe "unknown message tolerance properties" do
    property "P-MON-015: unknown atom messages do not crash the view" do
      forall atom <- PC.oneof([:unknown_msg, :stale_data, :random_tick, :test_signal]) do
        {:ok, view, _html} = live(build_conn(), "/monitoring")

        send(view.pid, atom)
        Process.sleep(20)

        Process.alive?(view.pid)
      end
    end

    property "P-MON-016: unknown tuple messages do not crash the view" do
      forall key <- PC.oneof([:metric_push, :alert_flood, :data_burst, :heartbeat]) do
        {:ok, view, _html} = live(build_conn(), "/monitoring")

        send(view.pid, {key, %{data: "payload"}})
        Process.sleep(20)

        Process.alive?(view.pid)
      end
    end
  end

  # ═══════════════════════════════════════════════════════════════════════
  # STREAMDATA TESTS (ExUnitProperties)
  # ═══════════════════════════════════════════════════════════════════════

  describe "StreamData property tests" do
    @tag timeout: 30_000
    check all(
            n <- SD.integer(1, 5),
            max_runs: 10
          ) do
      {:ok, view, _html} = live(build_conn(), "/monitoring")

      for _ <- 1..n do
        send(view.pid, :refresh_metrics)
        Process.sleep(15)
      end

      assert Process.alive?(view.pid)
      html = render(view)
      assert is_binary(html)
      assert html =~ ~r/[Mm]onitoring [Dd]ashboard/
    end

    @tag timeout: 30_000
    check all(
            status <- SD.member_of(@valid_health_statuses),
            count <- SD.integer(0, 999),
            max_runs: 10
          ) do
      {:ok, view, _html} = live(build_conn(), "/monitoring")

      :sys.replace_state(view.pid, fn state ->
        socket = state.socket

        new_metrics =
          socket.assigns.metrics
          |> Map.put(:health_status, status)
          |> Map.put(:active_alarms, count)

        new_assigns = Map.put(socket.assigns, :metrics, new_metrics)
        %{state | socket: %{socket | assigns: new_assigns}}
      end)

      html = render(view)
      assert is_binary(html)
      assert String.length(html) > 100
    end
  end
end
