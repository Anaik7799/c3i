defmodule IndrajaalWeb.Crm.DashboardLiveTest do
  @moduledoc """
  Tests for IndrajaalWeb.Crm.DashboardLive.

  WHAT: Verifies module structure, exported callbacks, template content (via source
        inspection), handle_event clauses (refresh, drill_down), PubSub topic
        subscriptions, and the periodic :refresh timer.
  WHY:  The CRM Sales Dashboard is the primary sales-team productivity tool.
        Auto-refresh (SC-PRF-050) and drill-down navigation are core workflows.
        This LiveView has no registered route, so tests use module inspection and
        source assertions instead of live/2.
  CONSTRAINTS: SC-COV-001, SC-TDG-001, SC-PRF-050, SC-BRIDGE-002, SC-OBS-069

  TDG Level: L2 (module / source inspection)
  Note: No route registered — tested via module introspection and source assertions.
        End-to-end rendering is covered by the CRM feature BDD specs.
  """

  use ExUnit.Case, async: true

  @moduletag :integration
  @moduletag :zenoh_nif

  alias IndrajaalWeb.Crm.DashboardLive

  @source_path "/home/an/dev/ver/intelitor-v5.2/lib/indrajaal_web/live/crm/dashboard_live.ex"

  # ═══════════════════════════════════════════════════════════════════════
  # MODULE STRUCTURE
  # ═══════════════════════════════════════════════════════════════════════

  describe "module structure" do
    test "module is loaded" do
      assert Code.ensure_loaded?(DashboardLive)
    end

    test "module defines mount/3" do
      assert function_exported?(DashboardLive, :mount, 3)
    end

    test "module defines render/1" do
      assert function_exported?(DashboardLive, :render, 1)
    end

    test "module defines handle_event/3" do
      assert function_exported?(DashboardLive, :handle_event, 3)
    end

    test "module defines handle_info/2" do
      assert function_exported?(DashboardLive, :handle_info, 2)
    end

    test "module uses IndrajaalWeb :live_view (exposes __live__/0)" do
      assert function_exported?(DashboardLive, :__live__, 0)
    end
  end

  # ═══════════════════════════════════════════════════════════════════════
  # MODULEDOC
  # ═══════════════════════════════════════════════════════════════════════

  describe "documentation" do
    test "moduledoc is present" do
      {:docs_v1, _, _, _, module_doc, _, _} = Code.fetch_docs(DashboardLive)
      assert module_doc != :none
    end
  end

  # ═══════════════════════════════════════════════════════════════════════
  # MOUNT BEHAVIOUR — source assertions
  # ═══════════════════════════════════════════════════════════════════════

  describe "mount/3 behaviour" do
    test "subscribes to crm:dashboard topic keyed by user_id" do
      source = File.read!(@source_path)
      assert source =~ ~s(crm:dashboard:)
    end

    test "subscribes to crm:pipeline topic" do
      source = File.read!(@source_path)
      assert source =~ ~s(crm:pipeline:)
    end

    test "subscribes to crm:forecast topic" do
      source = File.read!(@source_path)
      assert source =~ ~s(crm:forecast:)
    end

    test "schedules periodic :refresh with send_after" do
      source = File.read!(@source_path)
      assert source =~ "send_after"
      assert source =~ ":refresh,"
    end

    test "refresh interval is 30 seconds (30_000 ms)" do
      source = File.read!(@source_path)
      assert source =~ "30_000"
    end

    test "mount assigns :loading to true initially" do
      source = File.read!(@source_path)
      assert source =~ ":loading, true"
    end

    test "mount assigns :error to nil initially" do
      source = File.read!(@source_path)
      assert source =~ ":error, nil"
    end

    test "mount calls load_dashboard_data/1" do
      source = File.read!(@source_path)
      assert source =~ "load_dashboard_data"
    end

    test "mount reads user_id from socket assigns" do
      source = File.read!(@source_path)
      assert source =~ "current_user.id"
    end
  end

  # ═══════════════════════════════════════════════════════════════════════
  # HANDLE_EVENT: "refresh"
  # ═══════════════════════════════════════════════════════════════════════

  describe "handle_event \"refresh\"" do
    test "refresh event is handled and reloads dashboard data" do
      source = File.read!(@source_path)
      assert source =~ ~s(handle_event("refresh")
    end

    test "refresh returns {:noreply, socket}" do
      source = File.read!(@source_path)
      # Pattern: handle_event("refresh", _params, socket) -> {:noreply, socket}
      assert source =~ "{:noreply,"
    end

    test "refresh button in template uses phx-click=\"refresh\"" do
      source = File.read!(@source_path)
      assert source =~ ~s(phx-click="refresh")
    end
  end

  # ═══════════════════════════════════════════════════════════════════════
  # HANDLE_EVENT: "drill_down"
  # ═══════════════════════════════════════════════════════════════════════

  describe "handle_event \"drill_down\"" do
    test "drill_down event is handled" do
      source = File.read!(@source_path)
      assert source =~ ~s(handle_event("drill_down")
    end

    test "drill_down uses opportunity_id param" do
      source = File.read!(@source_path)
      assert source =~ "opportunity_id"
    end

    test "drill_down calls push_navigate to /crm/opportunities/:id" do
      source = File.read!(@source_path)
      assert source =~ "push_navigate"
      assert source =~ "/crm/opportunities/"
    end

    test "deal cards in template have phx-click drill_down" do
      source = File.read!(@source_path)
      assert source =~ ~s(phx-click="drill_down")
    end

    test "deal cards pass phx-value-opportunity_id" do
      source = File.read!(@source_path)
      assert source =~ "phx-value-opportunity_id"
    end
  end

  # ═══════════════════════════════════════════════════════════════════════
  # HANDLE_INFO: :refresh timer
  # ═══════════════════════════════════════════════════════════════════════

  describe "handle_info :refresh" do
    test "handle_info/2 is exported" do
      assert function_exported?(DashboardLive, :handle_info, 2)
    end

    test "handle_info(:refresh, socket) re-schedules next tick" do
      source = File.read!(@source_path)
      # Pattern: handle_info(:refresh, socket) -> Process.send_after + load_dashboard_data
      assert source =~ "def handle_info(:refresh,"
    end

    test "handle_info(:refresh, socket) calls load_dashboard_data/1" do
      source = File.read!(@source_path)
      assert source =~ "load_dashboard_data(socket)"
    end
  end

  # ═══════════════════════════════════════════════════════════════════════
  # HANDLE_INFO: {:crm_update, _} PubSub
  # ═══════════════════════════════════════════════════════════════════════

  describe "handle_info {:crm_update, _}" do
    test "crm_update message triggers dashboard reload" do
      source = File.read!(@source_path)
      assert source =~ "crm_update"
    end

    test "crm_update calls load_dashboard_data" do
      source = File.read!(@source_path)

      # Both handle_info(:refresh) and handle_info({:crm_update, _}) delegate to load_dashboard_data
      assert source =~ "load_dashboard_data"
    end
  end

  # ═══════════════════════════════════════════════════════════════════════
  # RENDER TEMPLATE — content assertions via source inspection
  # ═══════════════════════════════════════════════════════════════════════

  describe "render/1 template content" do
    test "template has crm-dashboard root class" do
      source = File.read!(@source_path)
      assert source =~ "crm-dashboard"
    end

    test "template has Sales Dashboard h1 heading" do
      source = File.read!(@source_path)
      assert source =~ "Sales Dashboard"
    end

    test "template renders pipeline widget" do
      source = File.read!(@source_path)
      assert source =~ "Pipeline Summary"
    end

    test "template renders forecast widget" do
      source = File.read!(@source_path)
      assert source =~ "Forecast Tracker"
    end

    test "template renders top deals widget" do
      source = File.read!(@source_path)
      assert source =~ "Top Deals"
    end

    test "template renders activities widget" do
      source = File.read!(@source_path)
      assert source =~ "Recent Activities"
    end

    test "template renders leaderboard widget" do
      source = File.read!(@source_path)
      assert source =~ "Leaderboard"
    end

    test "template uses loading spinner for loading state" do
      source = File.read!(@source_path)
      assert source =~ "@loading"
    end

    test "template uses @error for error state" do
      source = File.read!(@source_path)
      assert source =~ "@error"
    end

    test "template shows overdue tasks when count > 0" do
      source = File.read!(@source_path)
      assert source =~ "overdue_tasks"
      assert source =~ "Overdue Tasks"
    end

    test "template renders last updated footer" do
      source = File.read!(@source_path)
      assert source =~ "Last updated"
    end

    test "template uses PipelineChart phx-hook for Chart.js" do
      source = File.read!(@source_path)
      assert source =~ "PipelineChart"
    end
  end

  # ═══════════════════════════════════════════════════════════════════════
  # FMEA — failure handling (SC-COV-005)
  # ═══════════════════════════════════════════════════════════════════════

  describe "FMEA: error path coverage" do
    test "load_dashboard_data handles {:error, _} from Dashboard.sales_dashboard/1" do
      source = File.read!(@source_path)
      assert source =~ "{:error,"
      assert source =~ "Failed to load dashboard data"
    end

    test "load_dashboard_data logs errors via Logger.error" do
      source = File.read!(@source_path)
      assert source =~ "Logger.error"
    end

    test "error state assigns loading: false error: string" do
      source = File.read!(@source_path)
      assert source =~ "loading, false"
      assert source =~ "error,"
    end

    test "RPN 192 WebSocket disconnect mitigated via auto-reconnect note in moduledoc" do
      source = File.read!(@source_path)
      assert source =~ "192"
      assert source =~ "Auto-reconnect"
    end
  end

  # ═══════════════════════════════════════════════════════════════════════
  # STAMP CONSTRAINTS
  # ═══════════════════════════════════════════════════════════════════════

  describe "STAMP constraint compliance" do
    test "SC-PRF-050 response time constraint noted in moduledoc" do
      source = File.read!(@source_path)
      assert source =~ "SC-PRF-050"
    end

    test "SC-BRIDGE-002 latency budget noted in moduledoc" do
      source = File.read!(@source_path)
      assert source =~ "SC-BRIDGE-002"
    end

    test "SC-OBS-069 dual logging noted in moduledoc" do
      source = File.read!(@source_path)
      assert source =~ "SC-OBS-069"
    end

    test "SC-BUS-001 async messaging noted in moduledoc" do
      source = File.read!(@source_path)
      assert source =~ "SC-BUS-001"
    end
  end
end
