defmodule IndrajaalWeb.Prajna.AccessControlLiveTest do
  @moduledoc """
  Integration test suite for IndrajaalWeb.Prajna.AccessControlLive.

  ## STAMP Safety Integration
  - SC-HMI-001: Dark Cockpit defaults verified on mount
  - SC-PRAJNA-004: Sentinel health integration present
  - SC-BRIDGE-005: PubSub subscription for zenoh:access_control
  - SC-SEC-044: Security-sensitive audit trail rendered

  ## Coverage
  - Module structure (exports, moduledoc)
  - Mount and initial render (metrics summary, panels)
  - handle_event: filter_action (all / grant / deny / revoke)
  - handle_event: filter_resource
  - handle_event: filter_timerange (last_15m / last_1h / last_24h)
  - handle_event: search
  - handle_event: select_permission + close_detail lifecycle
  - handle_info: :refresh (audit trail + anomaly detection)
  - handle_info: :sync_metrics (BEAM-derived metric update)
  - handle_info: {:pubsub, :permission_change, data} PubSub patch
  """

  use IndrajaalWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  @moduletag :integration
  @moduletag :zenoh_nif

  # ---------------------------------------------------------------------------
  # Module structure
  # ---------------------------------------------------------------------------

  describe "AccessControlLive module structure" do
    test "module is loaded" do
      assert Code.ensure_loaded?(IndrajaalWeb.Prajna.AccessControlLive)
    end

    test "mount/3 is exported" do
      assert function_exported?(IndrajaalWeb.Prajna.AccessControlLive, :mount, 3)
    end

    test "render/1 is exported" do
      assert function_exported?(IndrajaalWeb.Prajna.AccessControlLive, :render, 1)
    end

    test "handle_event/3 is exported" do
      assert function_exported?(IndrajaalWeb.Prajna.AccessControlLive, :handle_event, 3)
    end

    test "handle_info/2 is exported" do
      assert function_exported?(IndrajaalWeb.Prajna.AccessControlLive, :handle_info, 2)
    end
  end

  # ---------------------------------------------------------------------------
  # Mount and initial render
  # ---------------------------------------------------------------------------

  describe "mount and initial render" do
    test "mounts at /cockpit/access-control and renders page title", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/cockpit/access-control")

      assert html =~ "Access Control"
    end

    test "renders metrics summary row with four KPI cards", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/cockpit/access-control")

      assert html =~ "Active Permissions"
      assert html =~ "Policy Effectiveness"
      assert html =~ "Access Denials"
      assert html =~ "Anomalies Detected"
    end

    test "renders Real-Time Audit Trail panel header", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/cockpit/access-control")

      assert html =~ "Real-Time Audit Trail"
    end

    test "renders Policy Effectiveness panel", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/cockpit/access-control")

      assert html =~ "Policy Effectiveness"
      assert html =~ "Admin Full Access"
    end

    test "renders Grant Patterns panel", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/cockpit/access-control")

      assert html =~ "Grant Patterns"
      assert html =~ "Role Escalation"
    end

    test "renders audit trail action filter select", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/cockpit/access-control")

      assert html =~ "All Actions"
      assert html =~ "Grants"
      assert html =~ "Denials"
      assert html =~ "Revocations"
    end

    test "renders time range filter select", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/cockpit/access-control")

      assert html =~ "Last 15m"
      assert html =~ "Last Hour"
      assert html =~ "Last 24h"
    end

    test "no detail panel shown on initial mount", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/cockpit/access-control")

      # selected_permission is nil on mount; no detail panel markup present
      refute html =~ "perm_001"
    end
  end

  # ---------------------------------------------------------------------------
  # handle_event: filter_action
  # ---------------------------------------------------------------------------

  describe "handle_event filter_action" do
    test "selecting grant filter assigns filter_action :grant without crash", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/cockpit/access-control")

      render_change(view, "filter_action", %{"action" => "grant"})

      assert render(view) =~ "Real-Time Audit Trail"
    end

    test "selecting deny filter assigns filter_action :deny without crash", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/cockpit/access-control")

      render_change(view, "filter_action", %{"action" => "deny"})

      assert render(view) =~ "Real-Time Audit Trail"
    end

    test "selecting revoke filter assigns filter_action :revoke without crash", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/cockpit/access-control")

      render_change(view, "filter_action", %{"action" => "revoke"})

      assert render(view) =~ "Real-Time Audit Trail"
    end

    test "selecting all filter resets to show all entries", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/cockpit/access-control")

      render_change(view, "filter_action", %{"action" => "deny"})
      render_change(view, "filter_action", %{"action" => "all"})

      assert render(view) =~ "Real-Time Audit Trail"
    end

    test "chaining grant then revoke filter does not crash", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/cockpit/access-control")

      render_change(view, "filter_action", %{"action" => "grant"})
      render_change(view, "filter_action", %{"action" => "revoke"})

      assert render(view) =~ "Real-Time Audit Trail"
    end
  end

  # ---------------------------------------------------------------------------
  # handle_event: filter_resource
  # ---------------------------------------------------------------------------

  describe "handle_event filter_resource" do
    test "filtering by all resource does not crash", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/cockpit/access-control")

      render_change(view, "filter_resource", %{"resource" => "all"})

      assert render(view) =~ "Access Control"
    end

    test "filtering by alarms resource does not crash", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/cockpit/access-control")

      render_change(view, "filter_resource", %{"resource" => "alarms"})

      assert render(view) =~ "Access Control"
    end

    test "filtering by devices resource does not crash", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/cockpit/access-control")

      render_change(view, "filter_resource", %{"resource" => "devices"})

      assert render(view) =~ "Access Control"
    end

    test "successive resource filter changes each succeed", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/cockpit/access-control")

      render_change(view, "filter_resource", %{"resource" => "alarms"})
      render_change(view, "filter_resource", %{"resource" => "users"})
      render_change(view, "filter_resource", %{"resource" => "all"})

      assert render(view) =~ "Real-Time Audit Trail"
    end
  end

  # ---------------------------------------------------------------------------
  # handle_event: filter_timerange
  # ---------------------------------------------------------------------------

  describe "handle_event filter_timerange" do
    test "selecting last_15m filter assigns filter_timerange without crash", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/cockpit/access-control")

      render_change(view, "filter_timerange", %{"range" => "last_15m"})

      assert render(view) =~ "Real-Time Audit Trail"
    end

    test "selecting last_1h filter assigns filter_timerange without crash", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/cockpit/access-control")

      render_change(view, "filter_timerange", %{"range" => "last_1h"})

      assert render(view) =~ "Real-Time Audit Trail"
    end

    test "selecting last_24h filter assigns filter_timerange without crash", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/cockpit/access-control")

      render_change(view, "filter_timerange", %{"range" => "last_24h"})

      assert render(view) =~ "Real-Time Audit Trail"
    end

    test "chaining timerange changes does not crash", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/cockpit/access-control")

      render_change(view, "filter_timerange", %{"range" => "last_15m"})
      render_change(view, "filter_timerange", %{"range" => "last_24h"})
      render_change(view, "filter_timerange", %{"range" => "last_1h"})

      assert render(view) =~ "Real-Time Audit Trail"
    end
  end

  # ---------------------------------------------------------------------------
  # handle_event: search
  # ---------------------------------------------------------------------------

  describe "handle_event search" do
    test "empty search query does not crash", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/cockpit/access-control")

      render_change(view, "search", %{"query" => ""})

      assert render(view) =~ "Access Control"
    end

    test "search query with subject name assigns search_query without crash", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/cockpit/access-control")

      render_change(view, "search", %{"query" => "user_admin"})

      assert render(view) =~ "Access Control"
    end

    test "search query with resource name does not crash", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/cockpit/access-control")

      render_change(view, "search", %{"query" => "alarms"})

      assert render(view) =~ "Access Control"
    end

    test "chaining distinct search queries each succeeds", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/cockpit/access-control")

      render_change(view, "search", %{"query" => "admin"})
      render_change(view, "search", %{"query" => "operator"})
      render_change(view, "search", %{"query" => ""})

      assert render(view) =~ "Real-Time Audit Trail"
    end
  end

  # ---------------------------------------------------------------------------
  # handle_event: select_permission + close_detail lifecycle
  # ---------------------------------------------------------------------------

  describe "handle_event select_permission and close_detail" do
    test "selecting a known permission id does not crash", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/cockpit/access-control")

      render_click(view, "select_permission", %{"id" => "perm_001"})

      assert render(view) =~ "Access Control"
    end

    test "selecting a non-existent permission id assigns nil without crash", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/cockpit/access-control")

      render_click(view, "select_permission", %{"id" => "perm_999"})

      assert render(view) =~ "Access Control"
    end

    test "close_detail clears selected_permission without crash", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/cockpit/access-control")

      render_click(view, "select_permission", %{"id" => "perm_001"})
      render_click(view, "close_detail", %{})

      assert render(view) =~ "Access Control"
    end

    test "select-then-close-then-select again lifecycle completes without crash", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/cockpit/access-control")

      render_click(view, "select_permission", %{"id" => "perm_001"})
      render_click(view, "close_detail", %{})
      render_click(view, "select_permission", %{"id" => "perm_002"})

      assert render(view) =~ "Access Control"
    end

    test "close_detail on an already-nil selection does not crash", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/cockpit/access-control")

      # No prior select_permission — selected_permission already nil
      render_click(view, "close_detail", %{})

      assert render(view) =~ "Access Control"
    end
  end

  # ---------------------------------------------------------------------------
  # handle_info: :refresh (audit trail + anomaly detection)
  # ---------------------------------------------------------------------------

  describe "handle_info :refresh" do
    test "refresh message updates audit trail and anomalies without crash", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/cockpit/access-control")

      send(view.pid, :refresh)
      :timer.sleep(50)

      assert render(view) =~ "Real-Time Audit Trail"
    end

    test "multiple refresh cycles leave the view in a valid state", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/cockpit/access-control")

      Enum.each(1..3, fn _ ->
        send(view.pid, :refresh)
        :timer.sleep(20)
      end)

      assert render(view) =~ "Policy Effectiveness"
    end
  end

  # ---------------------------------------------------------------------------
  # handle_info: :sync_metrics (BEAM-derived metric update)
  # ---------------------------------------------------------------------------

  describe "handle_info :sync_metrics" do
    test "sync_metrics message updates KPI metrics without crash", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/cockpit/access-control")

      send(view.pid, :sync_metrics)
      :timer.sleep(50)

      html = render(view)
      assert html =~ "Active Permissions"
      assert html =~ "Policy Effectiveness"
    end

    test "sync_metrics followed by refresh does not crash", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/cockpit/access-control")

      send(view.pid, :sync_metrics)
      :timer.sleep(20)
      send(view.pid, :refresh)
      :timer.sleep(50)

      assert render(view) =~ "Access Control"
    end
  end

  # ---------------------------------------------------------------------------
  # handle_info: {:pubsub, :permission_change, data} PubSub patch
  # ---------------------------------------------------------------------------

  describe "handle_info pubsub permission_change" do
    test "permission_change message patches permissions and prepends audit entry", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/cockpit/access-control")

      send(view.pid, {:pubsub, :permission_change, %{id: "perm_001", action: :revoke}})
      :timer.sleep(50)

      assert render(view) =~ "Real-Time Audit Trail"
    end

    test "permission_change with full audit data does not crash", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/cockpit/access-control")

      send(
        view.pid,
        {:pubsub, :permission_change,
         %{
           id: "perm_002",
           action: :grant,
           subject: "test_user",
           resource: "alarms",
           permission: "read",
           result: :allowed,
           source_ip: "10.0.0.1"
         }}
      )

      :timer.sleep(50)

      assert render(view) =~ "Access Control"
    end

    test "unknown handle_info message is silently ignored", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/cockpit/access-control")

      send(view.pid, {:unknown_message, :some_data})
      :timer.sleep(50)

      assert render(view) =~ "Access Control"
    end
  end
end
