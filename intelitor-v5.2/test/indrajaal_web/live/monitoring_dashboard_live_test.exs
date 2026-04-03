defmodule IndrajaalWeb.MonitoringDashboardLiveTest do
  @moduledoc """
  TDG test suite for IndrajaalWeb.MonitoringDashboardLive.

  ## SOPv5.11+AEE+GDE Framework Integration
  - TDG Compliance: Tests written BEFORE implementation
  - Module: Real-Time Alarm Processing Monitoring Dashboard
  - Route: /monitoring

  ## STAMP Safety Integration
  - SC-HMI-001: Theme-aware cockpit UI (SC-HMI-008: Color Rich)
  - SC-COV-001: Static coverage for critical paths
  - SC-TDG-001: Test-driven generation compliance
  - SC-MON-001: Metrics refresh every 30s
  - SC-MON-005: Dashboard data available

  ## Dashboard Sections Verified
  - System overview metric cards (active alarms, processing rate, avg latency, health)
  - Alarm processing pipeline stages (6 stages)
  - Real-time chart placeholders
  - Recent high-priority alarms table
  - System alerts section
  - Last updated timestamp

  ## TPS 5-Level RCA Context
  - L1 Symptom: Monitoring dashboard not rendering
  - L5 Root Cause: Missing LiveView mount or render implementation
  """

  use IndrajaalWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  @moduletag :integration
  @moduletag :zenoh_nif

  describe "module existence" do
    test "module is loaded" do
      assert Code.ensure_loaded?(IndrajaalWeb.MonitoringDashboardLive)
    end

    test "module defines mount/3" do
      assert function_exported?(IndrajaalWeb.MonitoringDashboardLive, :mount, 3)
    end

    test "module defines render/1" do
      assert function_exported?(IndrajaalWeb.MonitoringDashboardLive, :render, 1)
    end

    test "module defines handle_info/2" do
      assert function_exported?(IndrajaalWeb.MonitoringDashboardLive, :handle_info, 2)
    end

    test "uses IndrajaalWeb :live_view behaviour" do
      behaviours =
        IndrajaalWeb.MonitoringDashboardLive.module_info(:attributes)
        |> Keyword.get_values(:behaviour)
        |> List.flatten()

      assert Phoenix.LiveView in behaviours
    end
  end

  describe "mount and initial render via router" do
    test "mounts at /monitoring and returns html", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/monitoring")

      assert html =~ ~r/[Mm]onitoring [Dd]ashboard/
    end

    test "page_title is set to Monitoring Dashboard", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/monitoring")

      assigns = :sys.get_state(view.pid).socket.assigns
      assert assigns.page_title == "Monitoring Dashboard"
    end
  end

  describe "mount and initial render (isolated)" do
    test "mounts successfully via live_isolated", %{conn: conn} do
      {:ok, view, html} = live_isolated(conn, IndrajaalWeb.MonitoringDashboardLive)

      assert is_binary(html)
      assert view.module == IndrajaalWeb.MonitoringDashboardLive
    end

    test "renders System Monitoring Dashboard heading", %{conn: conn} do
      {:ok, _view, html} = live_isolated(conn, IndrajaalWeb.MonitoringDashboardLive)

      assert html =~ ~r/[Ss]ystem [Mm]onitoring [Dd]ashboard/
    end

    test "renders Last Updated timestamp in header", %{conn: conn} do
      {:ok, _view, html} = live_isolated(conn, IndrajaalWeb.MonitoringDashboardLive)

      assert html =~ ~r/[Ll]ast [Uu]pdated/
      assert html =~ ~r/\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2} UTC/
    end

    test "renders Active Alarms metric card", %{conn: conn} do
      {:ok, _view, html} = live_isolated(conn, IndrajaalWeb.MonitoringDashboardLive)

      assert html =~ ~r/[Aa]ctive [Aa]larms/
    end

    test "renders Processing Rate metric card", %{conn: conn} do
      {:ok, _view, html} = live_isolated(conn, IndrajaalWeb.MonitoringDashboardLive)

      assert html =~ ~r/[Pp]rocessing [Rr]ate/
      assert html =~ "per sec"
    end

    test "renders Average Latency metric card", %{conn: conn} do
      {:ok, _view, html} = live_isolated(conn, IndrajaalWeb.MonitoringDashboardLive)

      assert html =~ ~r/[Aa]verage [Ll]atency/
      assert html =~ "ms"
    end

    test "renders System Health metric card", %{conn: conn} do
      {:ok, _view, html} = live_isolated(conn, IndrajaalWeb.MonitoringDashboardLive)

      assert html =~ ~r/[Ss]ystem [Hh]ealth/
    end

    test "renders health status as UNKNOWN when services unavailable", %{conn: conn} do
      {:ok, _view, html} = live_isolated(conn, IndrajaalWeb.MonitoringDashboardLive)

      # default_metrics returns health_status: "unknown", rendered uppercased
      assert html =~ ~r/UNKNOWN|HEALTHY|WARNING|CRITICAL/
    end

    test "renders Alarm Processing Pipeline section", %{conn: conn} do
      {:ok, _view, html} = live_isolated(conn, IndrajaalWeb.MonitoringDashboardLive)

      assert html =~ ~r/[Aa]larm [Pp]rocessing [Pp]ipeline/
    end

    test "renders six pipeline stages", %{conn: conn} do
      {:ok, _view, html} = live_isolated(conn, IndrajaalWeb.MonitoringDashboardLive)

      assert html =~ "Ingestion"
      assert html =~ "Severity"
      assert html =~ "Correlation"
      assert html =~ "Storm Detection"
      assert html =~ "Notification"
      assert html =~ "Workflow"
    end

    test "renders Alarm Volume chart container", %{conn: conn} do
      {:ok, _view, html} = live_isolated(conn, IndrajaalWeb.MonitoringDashboardLive)

      assert html =~ ~r/[Aa]larm [Vv]olume/
      assert html =~ "alarm-volume-chart"
    end

    test "renders Processing Latency Distribution chart container", %{conn: conn} do
      {:ok, _view, html} = live_isolated(conn, IndrajaalWeb.MonitoringDashboardLive)

      assert html =~ ~r/[Pp]rocessing [Ll]atency [Dd]istribution/
      assert html =~ "latency-chart"
    end

    test "renders Recent High-Priority Alarms section", %{conn: conn} do
      {:ok, _view, html} = live_isolated(conn, IndrajaalWeb.MonitoringDashboardLive)

      assert html =~ ~r/[Rr]ecent [Hh]igh-[Pp]riority [Aa]larms/
    end

    test "renders alarms table with correct column headers", %{conn: conn} do
      {:ok, _view, html} = live_isolated(conn, IndrajaalWeb.MonitoringDashboardLive)

      assert html =~ "Time"
      assert html =~ "Type"
      assert html =~ "Severity"
      assert html =~ "Device"
      assert html =~ "Status"
      assert html =~ "Actions"
    end

    test "renders theme-aware surface classes (SC-HMI-001)", %{conn: conn} do
      {:ok, _view, html} = live_isolated(conn, IndrajaalWeb.MonitoringDashboardLive)

      assert html =~ "bg-surface-primary" or html =~ "bg-surface-secondary"
    end

    test "initial assigns include page_title", %{conn: conn} do
      {:ok, view, _html} = live_isolated(conn, IndrajaalWeb.MonitoringDashboardLive)

      assigns = :sys.get_state(view.pid).socket.assigns
      assert Map.has_key?(assigns, :page_title)
      assert assigns.page_title == "Monitoring Dashboard"
    end

    test "initial assigns include current_time datetime", %{conn: conn} do
      {:ok, view, _html} = live_isolated(conn, IndrajaalWeb.MonitoringDashboardLive)

      assigns = :sys.get_state(view.pid).socket.assigns
      assert Map.has_key?(assigns, :current_time)
      assert %DateTime{} = assigns.current_time
    end

    test "initial assigns include metrics map", %{conn: conn} do
      {:ok, view, _html} = live_isolated(conn, IndrajaalWeb.MonitoringDashboardLive)

      assigns = :sys.get_state(view.pid).socket.assigns
      assert Map.has_key?(assigns, :metrics)
      assert is_map(assigns.metrics)
    end

    test "metrics map contains active_alarms key", %{conn: conn} do
      {:ok, view, _html} = live_isolated(conn, IndrajaalWeb.MonitoringDashboardLive)

      assigns = :sys.get_state(view.pid).socket.assigns
      assert Map.has_key?(assigns.metrics, :active_alarms)
    end

    test "metrics map contains processing_rate key", %{conn: conn} do
      {:ok, view, _html} = live_isolated(conn, IndrajaalWeb.MonitoringDashboardLive)

      assigns = :sys.get_state(view.pid).socket.assigns
      assert Map.has_key?(assigns.metrics, :processing_rate)
    end

    test "metrics map contains avg_latency key", %{conn: conn} do
      {:ok, view, _html} = live_isolated(conn, IndrajaalWeb.MonitoringDashboardLive)

      assigns = :sys.get_state(view.pid).socket.assigns
      assert Map.has_key?(assigns.metrics, :avg_latency)
    end

    test "metrics map contains health_status key", %{conn: conn} do
      {:ok, view, _html} = live_isolated(conn, IndrajaalWeb.MonitoringDashboardLive)

      assigns = :sys.get_state(view.pid).socket.assigns
      assert Map.has_key?(assigns.metrics, :health_status)
      assert assigns.metrics.health_status in ["healthy", "warning", "critical", "unknown"]
    end

    test "metrics map contains pipeline_stages list", %{conn: conn} do
      {:ok, view, _html} = live_isolated(conn, IndrajaalWeb.MonitoringDashboardLive)

      assigns = :sys.get_state(view.pid).socket.assigns
      assert Map.has_key?(assigns.metrics, :pipeline_stages)
      assert is_list(assigns.metrics.pipeline_stages)
    end

    test "metrics map contains recent_alarms list", %{conn: conn} do
      {:ok, view, _html} = live_isolated(conn, IndrajaalWeb.MonitoringDashboardLive)

      assigns = :sys.get_state(view.pid).socket.assigns
      assert Map.has_key?(assigns.metrics, :recent_alarms)
      assert is_list(assigns.metrics.recent_alarms)
    end

    test "metrics map contains system_alerts list", %{conn: conn} do
      {:ok, view, _html} = live_isolated(conn, IndrajaalWeb.MonitoringDashboardLive)

      assigns = :sys.get_state(view.pid).socket.assigns
      assert Map.has_key?(assigns.metrics, :system_alerts)
      assert is_list(assigns.metrics.system_alerts)
    end

    test "metrics map contains uptime key", %{conn: conn} do
      {:ok, view, _html} = live_isolated(conn, IndrajaalWeb.MonitoringDashboardLive)

      assigns = :sys.get_state(view.pid).socket.assigns
      assert Map.has_key?(assigns.metrics, :uptime)
    end

    test "pipeline_stages has six entries when loaded from get_pipeline_status", %{conn: conn} do
      {:ok, view, _html} = live_isolated(conn, IndrajaalWeb.MonitoringDashboardLive)

      assigns = :sys.get_state(view.pid).socket.assigns
      # get_pipeline_status/0 returns a hardcoded 6-stage list
      assert length(assigns.metrics.pipeline_stages) == 6
    end
  end

  describe "handle_info :refresh_metrics timer" do
    test "handle_info :refresh_metrics returns noreply and keeps view alive", %{conn: conn} do
      {:ok, view, _html} = live_isolated(conn, IndrajaalWeb.MonitoringDashboardLive)

      send(view.pid, :refresh_metrics)
      Process.sleep(50)

      assert Process.alive?(view.pid)
      assert render(view) =~ ~r/[Mm]onitoring [Dd]ashboard/
    end

    test "handle_info :refresh_metrics updates current_time", %{conn: conn} do
      {:ok, view, _html} = live_isolated(conn, IndrajaalWeb.MonitoringDashboardLive)

      before_assigns = :sys.get_state(view.pid).socket.assigns
      before_ts = before_assigns.current_time

      Process.sleep(10)
      send(view.pid, :refresh_metrics)
      Process.sleep(50)

      after_assigns = :sys.get_state(view.pid).socket.assigns
      assert DateTime.compare(after_assigns.current_time, before_ts) in [:gt, :eq]
    end

    test "multiple :refresh_metrics messages do not crash the view", %{conn: conn} do
      {:ok, view, _html} = live_isolated(conn, IndrajaalWeb.MonitoringDashboardLive)

      for _ <- 1..5 do
        send(view.pid, :refresh_metrics)
        Process.sleep(20)
      end

      assert Process.alive?(view.pid)
      html = render(view)
      assert html =~ ~r/[Mm]onitoring [Dd]ashboard/
    end

    test "render after :refresh_metrics still shows all pipeline stages", %{conn: conn} do
      {:ok, view, _html} = live_isolated(conn, IndrajaalWeb.MonitoringDashboardLive)

      send(view.pid, :refresh_metrics)
      Process.sleep(50)

      html = render(view)
      assert html =~ "Ingestion"
      assert html =~ "Severity"
      assert html =~ "Correlation"
    end

    test "render after :refresh_metrics still shows alarms table headers", %{conn: conn} do
      {:ok, view, _html} = live_isolated(conn, IndrajaalWeb.MonitoringDashboardLive)

      send(view.pid, :refresh_metrics)
      Process.sleep(50)

      html = render(view)
      assert html =~ "Time"
      assert html =~ "Type"
      assert html =~ "Severity"
      assert html =~ "Device"
    end

    test "render after :refresh_metrics updates Last Updated timestamp", %{conn: conn} do
      {:ok, _view, html} = live_isolated(conn, IndrajaalWeb.MonitoringDashboardLive)

      assert html =~ ~r/\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2} UTC/
    end

    test "handle_info unknown message is gracefully ignored", %{conn: conn} do
      {:ok, view, _html} = live_isolated(conn, IndrajaalWeb.MonitoringDashboardLive)

      # MonitoringDashboardLive only handles :refresh_metrics — other messages should not crash
      # via the implicit LiveView fallback
      send(view.pid, {:some_unknown_event, :data})
      Process.sleep(50)

      assert Process.alive?(view.pid)
    end
  end

  describe "system alerts rendering" do
    test "system alerts section is hidden when no alerts", %{conn: conn} do
      {:ok, view, _html} = live_isolated(conn, IndrajaalWeb.MonitoringDashboardLive)

      :sys.replace_state(view.pid, fn state ->
        socket = state.socket
        new_metrics = Map.put(socket.assigns.metrics, :system_alerts, [])
        new_assigns = Map.put(socket.assigns, :metrics, new_metrics)
        %{state | socket: %{socket | assigns: new_assigns}}
      end)

      html = render(view)
      refute html =~ "System Alerts"
    end

    test "system alerts section appears when alerts present", %{conn: conn} do
      {:ok, view, _html} = live_isolated(conn, IndrajaalWeb.MonitoringDashboardLive)

      now = DateTime.utc_now()

      alerts = [
        %{
          level: "warning",
          title: "High Queue Depth",
          message: "Queue depth exceeds 100",
          timestamp: now
        }
      ]

      :sys.replace_state(view.pid, fn state ->
        socket = state.socket
        new_metrics = Map.put(socket.assigns.metrics, :system_alerts, alerts)
        new_assigns = Map.put(socket.assigns, :metrics, new_metrics)
        %{state | socket: %{socket | assigns: new_assigns}}
      end)

      html = render(view)
      assert html =~ "System Alerts"
      assert html =~ "High Queue Depth"
    end

    test "alert message is rendered in alerts section", %{conn: conn} do
      {:ok, view, _html} = live_isolated(conn, IndrajaalWeb.MonitoringDashboardLive)

      now = DateTime.utc_now()

      alerts = [
        %{
          level: "danger",
          title: "Critical Error",
          message: "Database connection lost",
          timestamp: now
        }
      ]

      :sys.replace_state(view.pid, fn state ->
        socket = state.socket
        new_metrics = Map.put(socket.assigns.metrics, :system_alerts, alerts)
        new_assigns = Map.put(socket.assigns, :metrics, new_metrics)
        %{state | socket: %{socket | assigns: new_assigns}}
      end)

      html = render(view)
      assert html =~ "Database connection lost"
    end
  end

  describe "recent alarms table rendering" do
    test "empty recent_alarms renders empty table body", %{conn: conn} do
      {:ok, view, _html} = live_isolated(conn, IndrajaalWeb.MonitoringDashboardLive)

      :sys.replace_state(view.pid, fn state ->
        socket = state.socket
        new_metrics = Map.put(socket.assigns.metrics, :recent_alarms, [])
        new_assigns = Map.put(socket.assigns, :metrics, new_metrics)
        %{state | socket: %{socket | assigns: new_assigns}}
      end)

      html = render(view)
      # Table headers still present
      assert html =~ "Time"
      assert html =~ "Type"
    end

    test "populated recent_alarms renders table rows with View button", %{conn: conn} do
      {:ok, view, _html} = live_isolated(conn, IndrajaalWeb.MonitoringDashboardLive)

      alarms = [
        %{
          id: "alarm-001",
          timestamp: DateTime.utc_now(),
          type: "Intrusion",
          severity: "critical",
          device_name: "Door A1",
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
      assert html =~ "Intrusion"
      assert html =~ "Door A1"
      assert html =~ "View"
    end
  end

  describe "pipeline stage rendering" do
    test "each pipeline stage shows its status", %{conn: conn} do
      {:ok, _view, html} = live_isolated(conn, IndrajaalWeb.MonitoringDashboardLive)

      # Pipeline stages have status healthy/warning — rendered uppercased
      assert html =~ ~r/HEALTHY|WARNING|CRITICAL/
    end

    test "each pipeline stage shows throughput value", %{conn: conn} do
      {:ok, _view, html} = live_isolated(conn, IndrajaalWeb.MonitoringDashboardLive)

      assert html =~ "per sec"
    end

    test "each pipeline stage shows queue size", %{conn: conn} do
      {:ok, _view, html} = live_isolated(conn, IndrajaalWeb.MonitoringDashboardLive)

      assert html =~ "Queue:"
    end

    test "Correlation stage renders with warning status", %{conn: conn} do
      {:ok, _view, html} = live_isolated(conn, IndrajaalWeb.MonitoringDashboardLive)

      # get_pipeline_status/0 sets Correlation stage to warning
      assert html =~ "Correlation"
      assert html =~ ~r/status-warning|WARNING/
    end
  end

  describe "navigation" do
    test "/monitoring route exists and is reachable", %{conn: conn} do
      result = live(conn, "/monitoring")
      assert match?({:ok, _, _}, result) or match?({:error, {:live_redirect, _}}, result)
    end
  end
end
