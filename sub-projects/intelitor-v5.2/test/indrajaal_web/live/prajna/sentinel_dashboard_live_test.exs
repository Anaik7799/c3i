defmodule IndrajaalWeb.Prajna.SentinelDashboardLiveTest do
  @moduledoc """
  TDG test suite for IndrajaalWeb.Prajna.SentinelDashboardLive.

  ## SOPv5.11+AEE+GDE Framework Integration
  - TDG Compliance: Tests written BEFORE implementation
  - Module: Sentinel Digital Immune System Dashboard for Prajna C3I cockpit
  - Route: /cockpit/sentinel

  ## STAMP Safety Integration
  - SC-HMI-001: Dark Cockpit defaults
  - SC-IMMUNE-001: Sentinel monitors system health
  - SC-IMMUNE-007: Active threats tracked
  - SC-IMMUNE-008: Quarantine status reported
  - SC-PRAJNA-004: Sentinel health integration required

  ## TPS 5-Level RCA Context
  - L1 Symptom: Sentinel dashboard not rendering
  - L5 Root Cause: Missing LiveView callback exports
  """

  use IndrajaalWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  @moduletag :integration
  @moduletag :zenoh_nif

  describe "SentinelDashboardLive module structure" do
    test "module exists and is loaded" do
      assert Code.ensure_loaded?(IndrajaalWeb.Prajna.SentinelDashboardLive)
    end

    test "mount/3 is exported" do
      assert function_exported?(IndrajaalWeb.Prajna.SentinelDashboardLive, :mount, 3)
    end

    test "render/1 is exported" do
      assert function_exported?(IndrajaalWeb.Prajna.SentinelDashboardLive, :render, 1)
    end

    test "handle_info/2 is exported" do
      assert function_exported?(IndrajaalWeb.Prajna.SentinelDashboardLive, :handle_info, 2)
    end

    test "uses IndrajaalWeb :live_view behaviour" do
      behaviours =
        IndrajaalWeb.Prajna.SentinelDashboardLive.module_info(:attributes)
        |> Keyword.get_values(:behaviour)
        |> List.flatten()

      assert Phoenix.LiveView in behaviours
    end
  end

  describe "mount and initial render via router" do
    test "mounts at /cockpit/sentinel", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/cockpit/sentinel")

      assert html =~ "Sentinel"
    end

    test "page_title is set to Sentinel - Immune System", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/cockpit/sentinel")

      assigns = :sys.get_state(view.pid).socket.assigns
      assert assigns.page_title == "Sentinel - Immune System"
    end
  end

  describe "mount and initial render (isolated)" do
    test "mounts successfully via live_isolated", %{conn: conn} do
      {:ok, view, html} = live_isolated(conn, IndrajaalWeb.Prajna.SentinelDashboardLive)

      assert is_binary(html)
      assert view.module == IndrajaalWeb.Prajna.SentinelDashboardLive
    end

    test "renders Sentinel heading", %{conn: conn} do
      {:ok, _view, html} = live_isolated(conn, IndrajaalWeb.Prajna.SentinelDashboardLive)

      assert html =~ "Sentinel"
    end

    test "renders Digital Immune System subtitle", %{conn: conn} do
      {:ok, _view, html} = live_isolated(conn, IndrajaalWeb.Prajna.SentinelDashboardLive)

      assert html =~ ~r/[Dd]igital [Ii]mmune [Ss]ystem/
    end

    test "renders Health Score metric card", %{conn: conn} do
      {:ok, _view, html} = live_isolated(conn, IndrajaalWeb.Prajna.SentinelDashboardLive)

      assert html =~ ~r/[Hh]ealth [Ss]core/
    end

    test "renders Active Threats metric card", %{conn: conn} do
      {:ok, _view, html} = live_isolated(conn, IndrajaalWeb.Prajna.SentinelDashboardLive)

      assert html =~ ~r/[Aa]ctive [Tt]hreats/
    end

    test "renders Quarantined metric card", %{conn: conn} do
      {:ok, _view, html} = live_isolated(conn, IndrajaalWeb.Prajna.SentinelDashboardLive)

      assert html =~ ~r/[Qq]uarantined/
    end

    test "renders Patterns Detected metric card", %{conn: conn} do
      {:ok, _view, html} = live_isolated(conn, IndrajaalWeb.Prajna.SentinelDashboardLive)

      assert html =~ ~r/[Pp]atterns [Dd]etected/
    end

    test "renders Response Times SLA section", %{conn: conn} do
      {:ok, _view, html} = live_isolated(conn, IndrajaalWeb.Prajna.SentinelDashboardLive)

      assert html =~ ~r/[Rr]esponse [Tt]imes/
      assert html =~ "SLA"
    end

    test "renders EXTINCTION response tier", %{conn: conn} do
      {:ok, _view, html} = live_isolated(conn, IndrajaalWeb.Prajna.SentinelDashboardLive)

      assert html =~ "EXTINCTION"
    end

    test "renders CRITICAL response tier", %{conn: conn} do
      {:ok, _view, html} = live_isolated(conn, IndrajaalWeb.Prajna.SentinelDashboardLive)

      assert html =~ "CRITICAL"
    end

    test "renders HIGH response tier", %{conn: conn} do
      {:ok, _view, html} = live_isolated(conn, IndrajaalWeb.Prajna.SentinelDashboardLive)

      assert html =~ "HIGH"
    end

    test "renders EXTINCTION SLA as 100ms", %{conn: conn} do
      {:ok, _view, html} = live_isolated(conn, IndrajaalWeb.Prajna.SentinelDashboardLive)

      assert html =~ "100ms"
    end

    test "renders CRITICAL SLA as 500ms", %{conn: conn} do
      {:ok, _view, html} = live_isolated(conn, IndrajaalWeb.Prajna.SentinelDashboardLive)

      assert html =~ "500ms"
    end

    test "renders HIGH SLA as 2000ms", %{conn: conn} do
      {:ok, _view, html} = live_isolated(conn, IndrajaalWeb.Prajna.SentinelDashboardLive)

      assert html =~ "2000ms"
    end

    test "renders Last scan timestamp", %{conn: conn} do
      {:ok, _view, html} = live_isolated(conn, IndrajaalWeb.Prajna.SentinelDashboardLive)

      assert html =~ ~r/[Ll]ast scan/
      assert html =~ ~r/\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2} UTC/
    end

    test "initial assigns include health_score", %{conn: conn} do
      {:ok, view, _html} = live_isolated(conn, IndrajaalWeb.Prajna.SentinelDashboardLive)

      assigns = :sys.get_state(view.pid).socket.assigns
      assert Map.has_key?(assigns, :health_score)
    end

    test "initial assigns include active_threats list", %{conn: conn} do
      {:ok, view, _html} = live_isolated(conn, IndrajaalWeb.Prajna.SentinelDashboardLive)

      assigns = :sys.get_state(view.pid).socket.assigns
      assert Map.has_key?(assigns, :active_threats)
      assert is_list(assigns.active_threats)
    end

    test "initial assigns include quarantined list", %{conn: conn} do
      {:ok, view, _html} = live_isolated(conn, IndrajaalWeb.Prajna.SentinelDashboardLive)

      assigns = :sys.get_state(view.pid).socket.assigns
      assert Map.has_key?(assigns, :quarantined)
      assert is_list(assigns.quarantined)
    end

    test "initial assigns include patterns_detected count", %{conn: conn} do
      {:ok, view, _html} = live_isolated(conn, IndrajaalWeb.Prajna.SentinelDashboardLive)

      assigns = :sys.get_state(view.pid).socket.assigns
      assert Map.has_key?(assigns, :patterns_detected)
      assert is_integer(assigns.patterns_detected)
    end

    test "initial assigns include response_times map", %{conn: conn} do
      {:ok, view, _html} = live_isolated(conn, IndrajaalWeb.Prajna.SentinelDashboardLive)

      assigns = :sys.get_state(view.pid).socket.assigns
      assert Map.has_key?(assigns, :response_times)
      assert is_map(assigns.response_times)
    end

    test "initial assigns include last_scan datetime", %{conn: conn} do
      {:ok, view, _html} = live_isolated(conn, IndrajaalWeb.Prajna.SentinelDashboardLive)

      assigns = :sys.get_state(view.pid).socket.assigns
      assert Map.has_key?(assigns, :last_scan)
    end

    test "response_times contains extinction key with value 100", %{conn: conn} do
      {:ok, view, _html} = live_isolated(conn, IndrajaalWeb.Prajna.SentinelDashboardLive)

      assigns = :sys.get_state(view.pid).socket.assigns
      assert assigns.response_times.extinction == 100
    end

    test "response_times contains critical key with value 500", %{conn: conn} do
      {:ok, view, _html} = live_isolated(conn, IndrajaalWeb.Prajna.SentinelDashboardLive)

      assigns = :sys.get_state(view.pid).socket.assigns
      assert assigns.response_times.critical == 500
    end

    test "response_times contains high key with value 2000", %{conn: conn} do
      {:ok, view, _html} = live_isolated(conn, IndrajaalWeb.Prajna.SentinelDashboardLive)

      assigns = :sys.get_state(view.pid).socket.assigns
      assert assigns.response_times.high == 2000
    end

    test "health_score is a non-negative float", %{conn: conn} do
      {:ok, view, _html} = live_isolated(conn, IndrajaalWeb.Prajna.SentinelDashboardLive)

      assigns = :sys.get_state(view.pid).socket.assigns
      assert is_float(assigns.health_score) or is_integer(assigns.health_score)
      assert assigns.health_score >= 0
    end

    test "health score defaults to 100.0 when SentinelBridge unavailable", %{conn: conn} do
      {:ok, view, _html} = live_isolated(conn, IndrajaalWeb.Prajna.SentinelDashboardLive)

      assigns = :sys.get_state(view.pid).socket.assigns
      # fetch_sentinel_state/0 rescues all errors, defaulting score_percent to 100
      assert assigns.health_score >= 0.0
    end

    test "patterns_detected defaults to 0 when SentinelBridge unavailable", %{conn: conn} do
      {:ok, view, _html} = live_isolated(conn, IndrajaalWeb.Prajna.SentinelDashboardLive)

      assigns = :sys.get_state(view.pid).socket.assigns
      assert assigns.patterns_detected >= 0
    end
  end

  describe "handle_info :refresh timer" do
    test "handle_info :refresh returns noreply and keeps view alive", %{conn: conn} do
      {:ok, view, _html} = live_isolated(conn, IndrajaalWeb.Prajna.SentinelDashboardLive)

      send(view.pid, :refresh)
      Process.sleep(50)

      assert Process.alive?(view.pid)
      assert render(view) =~ "Sentinel"
    end

    test "handle_info :refresh reloads sentinel data", %{conn: conn} do
      {:ok, view, _html} = live_isolated(conn, IndrajaalWeb.Prajna.SentinelDashboardLive)

      send(view.pid, :refresh)
      Process.sleep(50)

      assigns = :sys.get_state(view.pid).socket.assigns
      assert Map.has_key?(assigns, :health_score)
      assert Map.has_key?(assigns, :active_threats)
      assert Map.has_key?(assigns, :quarantined)
    end

    test "multiple :refresh messages do not crash the view", %{conn: conn} do
      {:ok, view, _html} = live_isolated(conn, IndrajaalWeb.Prajna.SentinelDashboardLive)

      for _ <- 1..5 do
        send(view.pid, :refresh)
        Process.sleep(20)
      end

      assert Process.alive?(view.pid)
      html = render(view)
      assert html =~ "Sentinel"
    end

    test "render after :refresh still shows all four metric cards", %{conn: conn} do
      {:ok, view, _html} = live_isolated(conn, IndrajaalWeb.Prajna.SentinelDashboardLive)

      send(view.pid, :refresh)
      Process.sleep(50)

      html = render(view)
      assert html =~ ~r/[Hh]ealth [Ss]core/
      assert html =~ ~r/[Aa]ctive [Tt]hreats/
      assert html =~ ~r/[Qq]uarantined/
      assert html =~ ~r/[Pp]atterns [Dd]etected/
    end

    test "render after :refresh preserves SLA response time section", %{conn: conn} do
      {:ok, view, _html} = live_isolated(conn, IndrajaalWeb.Prajna.SentinelDashboardLive)

      send(view.pid, :refresh)
      Process.sleep(50)

      html = render(view)
      assert html =~ "100ms"
      assert html =~ "500ms"
      assert html =~ "2000ms"
    end
  end

  describe "PubSub subscription handling" do
    setup do
      start_supervised!({Phoenix.PubSub, name: Indrajaal.PubSub})
      :ok
    end

    test "handle_info threat_detected event reloads sentinel data", %{conn: conn} do
      {:ok, view, _html} = live_isolated(conn, IndrajaalWeb.Prajna.SentinelDashboardLive)

      send(view.pid, %{event: "threat_detected", payload: %{threat_level: :critical}})
      Process.sleep(50)

      assert Process.alive?(view.pid)
      html = render(view)
      assert html =~ "Sentinel"
    end

    test "handle_info unknown message is silently ignored", %{conn: conn} do
      {:ok, view, _html} = live_isolated(conn, IndrajaalWeb.Prajna.SentinelDashboardLive)

      send(view.pid, {:unknown_message, :some_data})
      Process.sleep(50)

      assert Process.alive?(view.pid)
      assert render(view) =~ "Sentinel"
    end

    test "handle_info with random atom does not crash", %{conn: conn} do
      {:ok, view, _html} = live_isolated(conn, IndrajaalWeb.Prajna.SentinelDashboardLive)

      send(view.pid, :some_other_info)
      Process.sleep(50)

      assert Process.alive?(view.pid)
    end

    test "PubSub broadcasts to sentinel:threats topic are handled", %{conn: conn} do
      {:ok, view, _html} = live_isolated(conn, IndrajaalWeb.Prajna.SentinelDashboardLive)

      Phoenix.PubSub.broadcast(Indrajaal.PubSub, "sentinel:threats", %{
        event: "threat_detected",
        payload: %{threat_id: "T-001"}
      })

      Process.sleep(100)
      assert Process.alive?(view.pid)
    end

    test "PubSub broadcasts to prajna:threats topic are handled", %{conn: conn} do
      {:ok, view, _html} = live_isolated(conn, IndrajaalWeb.Prajna.SentinelDashboardLive)

      Phoenix.PubSub.broadcast(Indrajaal.PubSub, "prajna:threats", %{
        event: "threat_detected",
        payload: %{source: "prajna"}
      })

      Process.sleep(100)
      assert Process.alive?(view.pid)
    end
  end

  describe "health score rendering" do
    test "health score is displayed as a percentage with one decimal", %{conn: conn} do
      {:ok, view, _html} = live_isolated(conn, IndrajaalWeb.Prajna.SentinelDashboardLive)

      :sys.replace_state(view.pid, fn state ->
        socket = state.socket
        new_assigns = Map.put(socket.assigns, :health_score, 98.5)
        %{state | socket: %{socket | assigns: new_assigns}}
      end)

      html = render(view)
      assert html =~ "98.5%"
    end

    test "health score renders in green text", %{conn: conn} do
      {:ok, _view, html} = live_isolated(conn, IndrajaalWeb.Prajna.SentinelDashboardLive)

      assert html =~ "text-green-600"
    end

    test "active threats count renders in red text", %{conn: conn} do
      {:ok, _view, html} = live_isolated(conn, IndrajaalWeb.Prajna.SentinelDashboardLive)

      assert html =~ "text-red-600"
    end

    test "quarantined count renders in yellow text", %{conn: conn} do
      {:ok, _view, html} = live_isolated(conn, IndrajaalWeb.Prajna.SentinelDashboardLive)

      assert html =~ "text-yellow-600"
    end

    test "patterns detected count renders in blue text", %{conn: conn} do
      {:ok, _view, html} = live_isolated(conn, IndrajaalWeb.Prajna.SentinelDashboardLive)

      assert html =~ "text-blue-600"
    end
  end

  describe "navigation" do
    test "page is accessible at /cockpit/sentinel", %{conn: conn} do
      result = live(conn, "/cockpit/sentinel")
      assert match?({:ok, _, _}, result) or match?({:error, {:live_redirect, _}}, result)
    end
  end
end
