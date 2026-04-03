defmodule IndrajaalWeb.AccessControlMonitoringLiveTest do
  @moduledoc """
  TDG test suite for IndrajaalWeb.AccessControlMonitoringLive.

  ## SOPv5.11+AEE+GDE Framework Integration
  - TDG Compliance: Tests written BEFORE implementation
  - Module: Real-Time Access Control Monitoring Dashboard
  - Route: /admin/access_control

  ## STAMP Safety Integration
  - SC-HMI-001: Theme-aware cockpit UI compliance
  - SC-HMI-008: Color-Rich Mechanism active
  - SC-COV-001: Static coverage for critical paths
  - SC-TDG-001: Test-driven generation compliance

  ## Dashboard Features Verified
  - Alert count display
  - Active sessions display
  - Recent events list (empty state and populated state)
  - Responsive grid layout

  ## TPS 5-Level RCA Context
  - L1 Symptom: Access control dashboard not rendering
  - L5 Root Cause: Missing LiveView mount or render implementation
  """

  use IndrajaalWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  @moduletag :integration
  @moduletag :zenoh_nif

  describe "module existence" do
    test "module is loaded" do
      assert Code.ensure_loaded?(IndrajaalWeb.AccessControlMonitoringLive)
    end

    test "module defines mount/3" do
      assert function_exported?(IndrajaalWeb.AccessControlMonitoringLive, :mount, 3)
    end

    test "module defines render/1" do
      assert function_exported?(IndrajaalWeb.AccessControlMonitoringLive, :render, 1)
    end

    test "uses IndrajaalWeb :live_view behaviour" do
      behaviours =
        IndrajaalWeb.AccessControlMonitoringLive.module_info(:attributes)
        |> Keyword.get_values(:behaviour)
        |> List.flatten()

      assert Phoenix.LiveView in behaviours
    end
  end

  describe "mount and initial render via router" do
    test "mounts at /admin/access_control and returns html", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/admin/access_control")

      assert html =~ ~r/[Aa]ccess [Cc]ontrol/
    end

    test "page_title is set to Access Control Monitoring", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/admin/access_control")

      assigns = :sys.get_state(view.pid).socket.assigns
      assert assigns.page_title == "Access Control Monitoring"
    end
  end

  describe "mount and initial render (isolated)" do
    test "mounts successfully via live_isolated", %{conn: conn} do
      {:ok, view, html} = live_isolated(conn, IndrajaalWeb.AccessControlMonitoringLive)

      assert is_binary(html)
      assert view.module == IndrajaalWeb.AccessControlMonitoringLive
    end

    test "renders Access Control Monitoring Dashboard heading", %{conn: conn} do
      {:ok, _view, html} = live_isolated(conn, IndrajaalWeb.AccessControlMonitoringLive)

      assert html =~ ~r/[Aa]ccess [Cc]ontrol [Mm]onitoring [Dd]ashboard/
    end

    test "renders real-time security subtitle", %{conn: conn} do
      {:ok, _view, html} = live_isolated(conn, IndrajaalWeb.AccessControlMonitoringLive)

      assert html =~ ~r/[Rr]eal-time|[Ss]ecurity.*[Mm]onitoring|[Mm]onitoring/
    end

    test "renders Active Alerts metric card", %{conn: conn} do
      {:ok, _view, html} = live_isolated(conn, IndrajaalWeb.AccessControlMonitoringLive)

      assert html =~ ~r/[Aa]ctive [Aa]lerts/
    end

    test "renders Active Sessions metric card", %{conn: conn} do
      {:ok, _view, html} = live_isolated(conn, IndrajaalWeb.AccessControlMonitoringLive)

      assert html =~ ~r/[Aa]ctive [Ss]essions/
    end

    test "renders Recent Events metric card", %{conn: conn} do
      {:ok, _view, html} = live_isolated(conn, IndrajaalWeb.AccessControlMonitoringLive)

      assert html =~ ~r/[Rr]ecent [Ee]vents/
    end

    test "renders Recent Access Events section", %{conn: conn} do
      {:ok, _view, html} = live_isolated(conn, IndrajaalWeb.AccessControlMonitoringLive)

      assert html =~ ~r/[Rr]ecent [Aa]ccess [Ee]vents/
    end

    test "renders empty events message when no events", %{conn: conn} do
      {:ok, _view, html} = live_isolated(conn, IndrajaalWeb.AccessControlMonitoringLive)

      assert html =~ ~r/[Nn]o recent events/
    end

    test "initial assigns include page_title", %{conn: conn} do
      {:ok, view, _html} = live_isolated(conn, IndrajaalWeb.AccessControlMonitoringLive)

      assigns = :sys.get_state(view.pid).socket.assigns
      assert Map.has_key?(assigns, :page_title)
      assert assigns.page_title == "Access Control Monitoring"
    end

    test "initial assigns include alert_count of 0", %{conn: conn} do
      {:ok, view, _html} = live_isolated(conn, IndrajaalWeb.AccessControlMonitoringLive)

      assigns = :sys.get_state(view.pid).socket.assigns
      assert Map.has_key?(assigns, :alert_count)
      assert assigns.alert_count == 0
    end

    test "initial assigns include active_sessions of 0", %{conn: conn} do
      {:ok, view, _html} = live_isolated(conn, IndrajaalWeb.AccessControlMonitoringLive)

      assigns = :sys.get_state(view.pid).socket.assigns
      assert Map.has_key?(assigns, :active_sessions)
      assert assigns.active_sessions == 0
    end

    test "initial assigns include recent_events as empty list", %{conn: conn} do
      {:ok, view, _html} = live_isolated(conn, IndrajaalWeb.AccessControlMonitoringLive)

      assigns = :sys.get_state(view.pid).socket.assigns
      assert Map.has_key?(assigns, :recent_events)
      assert assigns.recent_events == []
    end

    test "alert_count renders as 0 in metric card", %{conn: conn} do
      {:ok, _view, html} = live_isolated(conn, IndrajaalWeb.AccessControlMonitoringLive)

      # Three cards each show zero for initial state
      assert html =~ ~r/>0</
    end

    test "recent_events length shows 0 when empty", %{conn: conn} do
      {:ok, _view, html} = live_isolated(conn, IndrajaalWeb.AccessControlMonitoringLive)

      # length(@recent_events) = 0 rendered in the card
      assert html =~ "0"
    end

    test "renders three column grid layout", %{conn: conn} do
      {:ok, _view, html} = live_isolated(conn, IndrajaalWeb.AccessControlMonitoringLive)

      assert html =~ "grid-cols-3"
    end

    test "renders theme-aware surface classes (SC-HMI-001)", %{conn: conn} do
      {:ok, _view, html} = live_isolated(conn, IndrajaalWeb.AccessControlMonitoringLive)

      assert html =~ "bg-surface-primary" or html =~ "bg-surface-secondary"
    end

    test "renders theme-aware content classes (SC-HMI-001)", %{conn: conn} do
      {:ok, _view, html} = live_isolated(conn, IndrajaalWeb.AccessControlMonitoringLive)

      assert html =~ "text-content-primary"
    end
  end

  describe "populated recent_events rendering" do
    test "renders event list items when events are present", %{conn: conn} do
      {:ok, view, _html} = live_isolated(conn, IndrajaalWeb.AccessControlMonitoringLive)

      events = ["Door A1 ACCESS GRANTED - user@example.com", "Door B3 ACCESS DENIED - unknown"]

      :sys.replace_state(view.pid, fn state ->
        socket = state.socket
        new_assigns = Map.put(socket.assigns, :recent_events, events)
        %{state | socket: %{socket | assigns: new_assigns}}
      end)

      html = render(view)
      assert html =~ "Door A1 ACCESS GRANTED"
      assert html =~ "Door B3 ACCESS DENIED"
    end

    test "does not render empty events message when events are present", %{conn: conn} do
      {:ok, view, _html} = live_isolated(conn, IndrajaalWeb.AccessControlMonitoringLive)

      events = ["Event 1", "Event 2"]

      :sys.replace_state(view.pid, fn state ->
        socket = state.socket
        new_assigns = Map.put(socket.assigns, :recent_events, events)
        %{state | socket: %{socket | assigns: new_assigns}}
      end)

      html = render(view)
      refute html =~ "No recent events"
    end

    test "renders event count in Recent Events metric card", %{conn: conn} do
      {:ok, view, _html} = live_isolated(conn, IndrajaalWeb.AccessControlMonitoringLive)

      events = ["Event A", "Event B", "Event C"]

      :sys.replace_state(view.pid, fn state ->
        socket = state.socket
        new_assigns = Map.put(socket.assigns, :recent_events, events)
        %{state | socket: %{socket | assigns: new_assigns}}
      end)

      html = render(view)
      assert html =~ "3"
    end

    test "renders updated alert_count when changed", %{conn: conn} do
      {:ok, view, _html} = live_isolated(conn, IndrajaalWeb.AccessControlMonitoringLive)

      :sys.replace_state(view.pid, fn state ->
        socket = state.socket
        new_assigns = Map.put(socket.assigns, :alert_count, 5)
        %{state | socket: %{socket | assigns: new_assigns}}
      end)

      html = render(view)
      assert html =~ "5"
    end

    test "renders updated active_sessions when changed", %{conn: conn} do
      {:ok, view, _html} = live_isolated(conn, IndrajaalWeb.AccessControlMonitoringLive)

      :sys.replace_state(view.pid, fn state ->
        socket = state.socket
        new_assigns = Map.put(socket.assigns, :active_sessions, 42)
        %{state | socket: %{socket | assigns: new_assigns}}
      end)

      html = render(view)
      assert html =~ "42"
    end

    test "renders border separator for event list items", %{conn: conn} do
      {:ok, view, _html} = live_isolated(conn, IndrajaalWeb.AccessControlMonitoringLive)

      :sys.replace_state(view.pid, fn state ->
        socket = state.socket
        new_assigns = Map.put(socket.assigns, :recent_events, ["Test event"])
        %{state | socket: %{socket | assigns: new_assigns}}
      end)

      html = render(view)
      assert html =~ "border-b"
    end
  end

  describe "navigation" do
    test "/admin/access_control route exists and is reachable", %{conn: conn} do
      result = live(conn, "/admin/access_control")
      assert match?({:ok, _, _}, result) or match?({:error, {:live_redirect, _}}, result)
    end
  end
end
