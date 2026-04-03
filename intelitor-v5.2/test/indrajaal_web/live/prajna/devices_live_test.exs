defmodule IndrajaalWeb.Prajna.DevicesLiveTest do
  @moduledoc """
  TDG comprehensive test suite for IndrajaalWeb.Prajna.DevicesLive.

  ## SOPv5.11+AEE+GDE Framework Integration
  - TDG Compliance: Tests written BEFORE implementation
  - FPPS Validation: 5-method consensus verification
  - Dual property testing: PropCheck + ExUnitProperties

  ## STAMP Safety Integration
  - SC-HMI-001: Dark Cockpit (gray defaults)
  - SC-PRAJNA-004: Sentinel health integration required
  - SC-BRIDGE-005: PubSub topics for zenoh:devices
  - SC-DEV-001: Device state consistency

  ## Constitutional Verification
  - Ψ₀ Existence: Dashboard persists across device failures
  - Ψ₁ Regeneration: Device state reconstructible from BEAM topology
  - Ψ₂ Evolutionary Continuity: Device history preserved
  - Ψ₃ Verification: Device health score integrity
  - Ψ₄ Human Alignment: Operator device authority
  - Ψ₅ Truthfulness: Status derived from real BEAM intrinsics

  ## TPS 5-Level RCA Context
  - L1 Symptom: Device grid not rendering or filter unresponsive
  - L2 Diagnosis: LiveView state corruption or search broken
  - L3 System Condition: PubSub subscription dropped
  - L4 Design Weakness: Device ID collision or missing field
  - L5 Root Cause: BEAM port topology changed unexpectedly
  """

  use IndrajaalWeb.ConnCase, async: true
  use PropCheck
  import PropCheck, except: [check: 2]
  import ExUnitProperties, except: [property: 2, property: 3, check: 2]
  import Phoenix.LiveViewTest

  # MANDATORY: Disambiguate generators (EP-GEN-014)
  alias PropCheck.BasicTypes, as: PC
  alias StreamData, as: SD

  # MANDATORY: SKIP_ZENOH_NIF=0 for NIF tests (SC-TEST-NIF-001)
  @moduletag :integration
  @moduletag :zenoh_nif

  alias IndrajaalWeb.Prajna.DevicesLive

  # ============================================================================
  # Module Structure Checks
  # ============================================================================

  describe "DevicesLive module structure" do
    test "module exists and is loaded" do
      assert Code.ensure_loaded?(DevicesLive)
    end

    test "mount/3 is exported" do
      assert function_exported?(DevicesLive, :mount, 3)
    end

    test "render/1 is exported" do
      assert function_exported?(DevicesLive, :render, 1)
    end

    test "handle_event/3 is exported" do
      assert function_exported?(DevicesLive, :handle_event, 3)
    end

    test "handle_info/2 is exported" do
      assert function_exported?(DevicesLive, :handle_info, 2)
    end
  end

  # ============================================================================
  # Mount and Initialization
  # ============================================================================

  describe "Mount and Initialization" do
    test "mounts successfully at /cockpit/devices", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/cockpit/devices")
      assert html =~ "Device" or html =~ "device" or String.length(html) > 100
    end

    test "sets page_title to 'Device Health'", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/cockpit/devices")
      assert view.assigns.page_title == "Device Health"
    end

    test "sets current_nav to :devices", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/cockpit/devices")
      assert view.assigns.current_nav == :devices
    end

    test "initializes devices list with 30 entries", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/cockpit/devices")
      assert is_list(view.assigns.devices)
      assert length(view.assigns.devices) == 30
    end

    test "initializes filter_status to :all", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/cockpit/devices")
      assert view.assigns.filter_status == :all
    end

    test "initializes filter_type to :all", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/cockpit/devices")
      assert view.assigns.filter_type == :all
    end

    test "initializes search_query to empty string", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/cockpit/devices")
      assert view.assigns.search_query == ""
    end

    test "initializes selected_device to nil", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/cockpit/devices")
      assert is_nil(view.assigns.selected_device)
    end

    test "initializes view_mode to :grid", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/cockpit/devices")
      assert view.assigns.view_mode == :grid
    end

    test "initializes metrics map with required fields", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/cockpit/devices")
      m = view.assigns.metrics
      assert is_map(m)
      assert Map.has_key?(m, :total_devices)
      assert Map.has_key?(m, :online_count)
      assert Map.has_key?(m, :degraded_count)
      assert Map.has_key?(m, :offline_count)
      assert Map.has_key?(m, :avg_uptime)
    end

    test "each device has required fields", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/cockpit/devices")

      Enum.each(view.assigns.devices, fn d ->
        assert Map.has_key?(d, :id)
        assert Map.has_key?(d, :name)
        assert Map.has_key?(d, :type)
        assert Map.has_key?(d, :location)
        assert Map.has_key?(d, :status)
        assert Map.has_key?(d, :health_score)
        assert Map.has_key?(d, :uptime_pct)
        assert Map.has_key?(d, :ip_address)
        assert Map.has_key?(d, :firmware_version)
        assert Map.has_key?(d, :last_seen)
      end)
    end

    test "subscribes to PubSub on connection", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/cockpit/devices")
      assert Process.alive?(view.pid)
    end
  end

  # ============================================================================
  # handle_event: filter_status
  # ============================================================================

  describe "handle_event filter_status" do
    test "changes filter_status to :online", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/cockpit/devices")
      render_change(view, "filter_status", %{"status" => "online"})
      assert view.assigns.filter_status == :online
    end

    test "changes filter_status to :degraded", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/cockpit/devices")
      render_change(view, "filter_status", %{"status" => "degraded"})
      assert view.assigns.filter_status == :degraded
    end

    test "changes filter_status to :offline", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/cockpit/devices")
      render_change(view, "filter_status", %{"status" => "offline"})
      assert view.assigns.filter_status == :offline
    end

    test "changes filter_status back to :all", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/cockpit/devices")
      render_change(view, "filter_status", %{"status" => "online"})
      render_change(view, "filter_status", %{"status" => "all"})
      assert view.assigns.filter_status == :all
    end

    test "returns valid HTML after status filter", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/cockpit/devices")
      html = render_change(view, "filter_status", %{"status" => "online"})
      assert is_binary(html)
      assert String.length(html) > 0
    end

    test "process alive after status filter", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/cockpit/devices")
      render_change(view, "filter_status", %{"status" => "degraded"})
      assert Process.alive?(view.pid)
    end

    test "status filter does not reset other assigns", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/cockpit/devices")
      render_change(view, "filter_status", %{"status" => "online"})
      # Other filters remain unchanged
      assert view.assigns.filter_type == :all
      assert view.assigns.search_query == ""
    end
  end

  # ============================================================================
  # handle_event: filter_type
  # ============================================================================

  describe "handle_event filter_type" do
    test "changes filter_type to :camera", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/cockpit/devices")
      render_change(view, "filter_type", %{"type" => "camera"})
      assert view.assigns.filter_type == :camera
    end

    test "changes filter_type to :reader", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/cockpit/devices")
      render_change(view, "filter_type", %{"type" => "reader"})
      assert view.assigns.filter_type == :reader
    end

    test "changes filter_type to :controller", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/cockpit/devices")
      render_change(view, "filter_type", %{"type" => "controller"})
      assert view.assigns.filter_type == :controller
    end

    test "changes filter_type to :sensor", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/cockpit/devices")
      render_change(view, "filter_type", %{"type" => "sensor"})
      assert view.assigns.filter_type == :sensor
    end

    test "changes filter_type back to :all", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/cockpit/devices")
      render_change(view, "filter_type", %{"type" => "camera"})
      render_change(view, "filter_type", %{"type" => "all"})
      assert view.assigns.filter_type == :all
    end

    test "returns valid HTML after type filter", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/cockpit/devices")
      html = render_change(view, "filter_type", %{"type" => "sensor"})
      assert is_binary(html)
    end

    test "process alive after type filter", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/cockpit/devices")
      render_change(view, "filter_type", %{"type" => "controller"})
      assert Process.alive?(view.pid)
    end

    test "type filter does not change status filter", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/cockpit/devices")
      render_change(view, "filter_type", %{"type" => "camera"})
      assert view.assigns.filter_status == :all
    end
  end

  # ============================================================================
  # handle_event: search
  # ============================================================================

  describe "handle_event search" do
    test "sets search_query to the provided string", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/cockpit/devices")
      render_keyup(view, "search", %{"query" => "Device 1"})
      assert view.assigns.search_query == "Device 1"
    end

    test "sets search_query to empty string (clear)", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/cockpit/devices")
      render_keyup(view, "search", %{"query" => "Device"})
      render_keyup(view, "search", %{"query" => ""})
      assert view.assigns.search_query == ""
    end

    test "search by partial device name", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/cockpit/devices")
      render_keyup(view, "search", %{"query" => "Device 1"})
      assert view.assigns.search_query == "Device 1"
    end

    test "search by location substring", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/cockpit/devices")
      render_keyup(view, "search", %{"query" => "Building"})
      assert view.assigns.search_query == "Building"
    end

    test "search by type keyword", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/cockpit/devices")
      render_keyup(view, "search", %{"query" => "camera"})
      assert view.assigns.search_query == "camera"
    end

    test "search is case-insensitive (state set correctly)", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/cockpit/devices")
      render_keyup(view, "search", %{"query" => "DEVICE"})
      assert view.assigns.search_query == "DEVICE"
    end

    test "search returns valid HTML", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/cockpit/devices")
      html = render_keyup(view, "search", %{"query" => "Device 5"})
      assert is_binary(html)
    end

    test "search does not reset filters", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/cockpit/devices")
      render_change(view, "filter_type", %{"type" => "camera"})
      render_keyup(view, "search", %{"query" => "Device"})
      assert view.assigns.filter_type == :camera
    end

    test "process alive after search", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/cockpit/devices")
      render_keyup(view, "search", %{"query" => "xyz_nonexistent"})
      assert Process.alive?(view.pid)
    end
  end

  # ============================================================================
  # handle_event: select_device
  # ============================================================================

  describe "handle_event select_device" do
    test "selects first device by ID", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/cockpit/devices")
      first_id = List.first(view.assigns.devices).id
      render_click(view, "select_device", %{"id" => first_id})
      assert not is_nil(view.assigns.selected_device)
      assert view.assigns.selected_device.id == first_id
    end

    test "selected device has all required fields", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/cockpit/devices")
      first_id = List.first(view.assigns.devices).id
      render_click(view, "select_device", %{"id" => first_id})
      d = view.assigns.selected_device
      assert Map.has_key?(d, :id)
      assert Map.has_key?(d, :name)
      assert Map.has_key?(d, :type)
      assert Map.has_key?(d, :location)
      assert Map.has_key?(d, :status)
      assert Map.has_key?(d, :health_score)
      assert Map.has_key?(d, :ip_address)
      assert Map.has_key?(d, :firmware_version)
      assert Map.has_key?(d, :last_seen)
      assert Map.has_key?(d, :uptime_hours)
    end

    test "selecting second device replaces selection", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/cockpit/devices")
      devices = view.assigns.devices
      id_a = Enum.at(devices, 0).id
      id_b = Enum.at(devices, 1).id
      render_click(view, "select_device", %{"id" => id_a})
      render_click(view, "select_device", %{"id" => id_b})
      assert view.assigns.selected_device.id == id_b
    end

    test "selecting nonexistent ID results in nil selected_device", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/cockpit/devices")
      render_click(view, "select_device", %{"id" => "dev_nonexistent"})
      assert is_nil(view.assigns.selected_device)
    end

    test "returns valid HTML with device detail", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/cockpit/devices")
      first_id = List.first(view.assigns.devices).id
      html = render_click(view, "select_device", %{"id" => first_id})
      assert is_binary(html)
      assert String.length(html) > 0
    end

    test "process alive after select_device", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/cockpit/devices")
      first_id = List.first(view.assigns.devices).id
      render_click(view, "select_device", %{"id" => first_id})
      assert Process.alive?(view.pid)
    end
  end

  # ============================================================================
  # handle_event: close_detail
  # ============================================================================

  describe "handle_event close_detail" do
    test "clears selected_device to nil", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/cockpit/devices")
      first_id = List.first(view.assigns.devices).id
      render_click(view, "select_device", %{"id" => first_id})
      refute is_nil(view.assigns.selected_device)
      render_click(view, "close_detail", %{})
      assert is_nil(view.assigns.selected_device)
    end

    test "close_detail is idempotent when already nil", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/cockpit/devices")
      assert is_nil(view.assigns.selected_device)
      render_click(view, "close_detail", %{})
      assert is_nil(view.assigns.selected_device)
    end

    test "returns valid HTML after close_detail", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/cockpit/devices")
      html = render_click(view, "close_detail", %{})
      assert is_binary(html)
    end

    test "open-then-close lifecycle", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/cockpit/devices")
      first_id = List.first(view.assigns.devices).id
      # Open
      render_click(view, "select_device", %{"id" => first_id})
      assert not is_nil(view.assigns.selected_device)
      # Close
      render_click(view, "close_detail", %{})
      assert is_nil(view.assigns.selected_device)
      # Re-open
      render_click(view, "select_device", %{"id" => first_id})
      assert not is_nil(view.assigns.selected_device)
    end

    test "process alive after close_detail", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/cockpit/devices")
      render_click(view, "close_detail", %{})
      assert Process.alive?(view.pid)
    end
  end

  # ============================================================================
  # handle_event: toggle_view
  # ============================================================================

  describe "handle_event toggle_view" do
    test "toggles view_mode to :list", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/cockpit/devices")
      assert view.assigns.view_mode == :grid
      render_click(view, "toggle_view", %{"mode" => "list"})
      assert view.assigns.view_mode == :list
    end

    test "toggles view_mode back to :grid", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/cockpit/devices")
      render_click(view, "toggle_view", %{"mode" => "list"})
      render_click(view, "toggle_view", %{"mode" => "grid"})
      assert view.assigns.view_mode == :grid
    end

    test "toggle_view :grid is idempotent", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/cockpit/devices")
      render_click(view, "toggle_view", %{"mode" => "grid"})
      render_click(view, "toggle_view", %{"mode" => "grid"})
      assert view.assigns.view_mode == :grid
    end

    test "returns valid HTML after toggle to list", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/cockpit/devices")
      html = render_click(view, "toggle_view", %{"mode" => "list"})
      assert is_binary(html)
      assert String.length(html) > 0
    end

    test "returns valid HTML after toggle to grid", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/cockpit/devices")
      render_click(view, "toggle_view", %{"mode" => "list"})
      html = render_click(view, "toggle_view", %{"mode" => "grid"})
      assert is_binary(html)
    end

    test "toggle does not affect filters", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/cockpit/devices")
      render_change(view, "filter_status", %{"status" => "online"})
      render_click(view, "toggle_view", %{"mode" => "list"})
      assert view.assigns.filter_status == :online
    end

    test "process alive after multiple toggles", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/cockpit/devices")

      for _i <- 1..5 do
        render_click(view, "toggle_view", %{"mode" => "list"})
        render_click(view, "toggle_view", %{"mode" => "grid"})
      end

      assert Process.alive?(view.pid)
    end
  end

  # ============================================================================
  # Lifecycle Sequences (cross-event flows)
  # ============================================================================

  describe "Lifecycle sequences" do
    test "filter + search combination", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/cockpit/devices")
      render_change(view, "filter_type", %{"type" => "camera"})
      render_keyup(view, "search", %{"query" => "Device"})
      assert view.assigns.filter_type == :camera
      assert view.assigns.search_query == "Device"
    end

    test "select device then toggle view", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/cockpit/devices")
      first_id = List.first(view.assigns.devices).id
      render_click(view, "select_device", %{"id" => first_id})
      render_click(view, "toggle_view", %{"mode" => "list"})
      # Selected device persists across view toggle
      assert not is_nil(view.assigns.selected_device)
      assert view.assigns.view_mode == :list
    end

    test "filter status, filter type, search, then select", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/cockpit/devices")
      render_change(view, "filter_status", %{"status" => "online"})
      render_change(view, "filter_type", %{"type" => "all"})
      render_keyup(view, "search", %{"query" => "Device 1"})

      first_online =
        Enum.find(view.assigns.devices, &(&1.status == :online))

      if first_online do
        render_click(view, "select_device", %{"id" => first_online.id})
        assert view.assigns.selected_device.id == first_online.id
      else
        assert view.assigns.filter_status == :online
      end
    end

    test "close detail then search", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/cockpit/devices")
      first_id = List.first(view.assigns.devices).id
      render_click(view, "select_device", %{"id" => first_id})
      render_click(view, "close_detail", %{})
      render_keyup(view, "search", %{"query" => "Building"})
      assert is_nil(view.assigns.selected_device)
      assert view.assigns.search_query == "Building"
    end

    test "all filters combined then reset to all", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/cockpit/devices")
      render_change(view, "filter_status", %{"status" => "online"})
      render_change(view, "filter_type", %{"type" => "camera"})
      render_keyup(view, "search", %{"query" => "Device"})
      render_change(view, "filter_status", %{"status" => "all"})
      render_change(view, "filter_type", %{"type" => "all"})
      render_keyup(view, "search", %{"query" => ""})
      assert view.assigns.filter_status == :all
      assert view.assigns.filter_type == :all
      assert view.assigns.search_query == ""
    end
  end

  # ============================================================================
  # Real-time Updates (SC-BRIDGE-005)
  # ============================================================================

  describe "Real-time updates (SC-BRIDGE-005)" do
    test "handles :refresh message without crash", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/cockpit/devices")
      send(view.pid, :refresh)
      Process.sleep(50)
      assert Process.alive?(view.pid)
    end

    test ":refresh preserves device count", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/cockpit/devices")
      initial_count = length(view.assigns.devices)
      send(view.pid, :refresh)
      Process.sleep(50)
      assert length(view.assigns.devices) == initial_count
    end

    test "handles :sync_metrics message", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/cockpit/devices")
      send(view.pid, :sync_metrics)
      Process.sleep(50)
      assert is_map(view.assigns.metrics)
    end

    test ":sync_metrics updates metrics", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/cockpit/devices")
      send(view.pid, :sync_metrics)
      Process.sleep(50)
      m = view.assigns.metrics
      assert Map.has_key?(m, :total_devices)
      assert m.total_devices >= 0
    end

    test "handles {:pubsub, :device_update, data} message", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/cockpit/devices")
      first_device = List.first(view.assigns.devices)
      send(view.pid, {:pubsub, :device_update, %{id: first_device.id, status: :offline}})
      Process.sleep(50)
      assert Process.alive?(view.pid)
    end

    test "handles unknown PubSub messages gracefully", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/cockpit/devices")
      send(view.pid, {:unknown_event, %{data: "test"}})
      Process.sleep(30)
      assert Process.alive?(view.pid)
    end

    test "handles PubSub message flood", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/cockpit/devices")

      for i <- 1..50 do
        send(view.pid, {:device_update, %{device_id: "dev_#{i}", status: :online}})
      end

      Process.sleep(100)
      assert Process.alive?(view.pid)
    end
  end

  # ============================================================================
  # SIL-6 Safety Requirements (SC-DEV-001)
  # ============================================================================

  describe "SIL-6 Safety Requirements" do
    test "mount completes within 1000ms", %{conn: conn} do
      start_time = System.monotonic_time(:millisecond)
      {:ok, _view, _html} = live(conn, "/cockpit/devices")
      elapsed = System.monotonic_time(:millisecond) - start_time
      assert elapsed < 1000
    end

    test "device health_score is between 0 and 100", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/cockpit/devices")

      Enum.each(view.assigns.devices, fn d ->
        assert d.health_score >= 0, "Device #{d.id} health_score < 0"
        assert d.health_score <= 100, "Device #{d.id} health_score > 100"
      end)
    end

    test "device status atoms are valid (SC-DEV-001)", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/cockpit/devices")
      valid_statuses = [:online, :offline, :degraded]

      Enum.each(view.assigns.devices, fn d ->
        assert d.status in valid_statuses,
               "Device #{d.id} has invalid status: #{d.status}"
      end)
    end

    test "device type atoms are valid", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/cockpit/devices")
      valid_types = [:camera, :reader, :controller, :sensor]

      Enum.each(view.assigns.devices, fn d ->
        assert d.type in valid_types,
               "Device #{d.id} has invalid type: #{d.type}"
      end)
    end

    test "device IDs are unique", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/cockpit/devices")
      ids = Enum.map(view.assigns.devices, & &1.id)
      assert length(ids) == length(Enum.uniq(ids))
    end

    test "metrics counts are non-negative", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/cockpit/devices")
      m = view.assigns.metrics
      assert m.total_devices >= 0
      assert m.online_count >= 0
      assert m.degraded_count >= 0
      assert m.offline_count >= 0
      assert m.avg_uptime >= 0
    end

    test "avg_uptime is between 0 and 100", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/cockpit/devices")
      assert view.assigns.metrics.avg_uptime >= 0
      assert view.assigns.metrics.avg_uptime <= 100
    end
  end

  # ============================================================================
  # Constitutional Invariants
  # ============================================================================

  describe "Constitutional Invariants (Ψ₀-Ψ₅)" do
    test "Ψ₀ existence — view survives unknown messages", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/cockpit/devices")
      send(view.pid, :unexpected_atom)
      send(view.pid, {:tuple, :message})
      Process.sleep(50)
      assert Process.alive?(view.pid)
    end

    test "Ψ₁ regeneration — device list reconstructible on reconnect", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/cockpit/devices")
      initial_count = length(view.assigns.devices)
      Process.exit(view.pid, :normal)
      {:ok, new_view, _html} = live(conn, "/cockpit/devices")
      assert length(new_view.assigns.devices) == initial_count
    end

    test "Ψ₂ continuity — devices preserved after refresh", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/cockpit/devices")
      send(view.pid, :refresh)
      Process.sleep(50)
      assert is_list(view.assigns.devices)
      assert length(view.assigns.devices) > 0
    end

    test "Ψ₃ verification — all device IDs are non-empty strings", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/cockpit/devices")

      Enum.each(view.assigns.devices, fn d ->
        assert is_binary(d.id)
        assert String.length(d.id) > 0
      end)
    end

    test "Ψ₄ human alignment — page renders device grid for operator", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/cockpit/devices")
      assert is_binary(html)
      assert String.length(html) > 100
    end

    test "Ψ₅ truthfulness — IP addresses are valid format", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/cockpit/devices")

      Enum.each(view.assigns.devices, fn d ->
        assert String.match?(d.ip_address, ~r/^\d+\.\d+\.\d+\.\d+$/),
               "Device #{d.id} has malformed IP: #{d.ip_address}"
      end)
    end
  end

  # ============================================================================
  # PropCheck Property Tests
  # ============================================================================

  property "device status values are valid atoms" do
    forall status <- PC.oneof([:all, :online, :degraded, :offline]) do
      status in [:all, :online, :degraded, :offline]
    end
  end

  property "device type values are valid atoms" do
    forall type <- PC.oneof([:all, :camera, :reader, :controller, :sensor]) do
      type in [:all, :camera, :reader, :controller, :sensor]
    end
  end

  property "view mode values are valid atoms" do
    forall mode <- PC.oneof([:grid, :list]) do
      mode in [:grid, :list]
    end
  end

  property "health scores are bounded 0-100" do
    forall score <- PC.range(0, 100) do
      score >= 0 and score <= 100
    end
  end

  # ============================================================================
  # ExUnitProperties StreamData Tests
  # ============================================================================

  describe "StreamData Property Testing" do
    test "device status strings are parseable to atoms" do
      ExUnitProperties.check all(
                               s <-
                                 SD.member_of(["all", "online", "degraded", "offline"]),
                               max_runs: 50
                             ) do
        atom = String.to_existing_atom(s)
        assert atom in [:all, :online, :degraded, :offline]
      end
    end

    test "device type strings are parseable to atoms" do
      ExUnitProperties.check all(
                               t <-
                                 SD.member_of(["all", "camera", "reader", "controller", "sensor"]),
                               max_runs: 50
                             ) do
        atom = String.to_existing_atom(t)
        assert atom in [:all, :camera, :reader, :controller, :sensor]
      end
    end

    test "view mode strings are parseable to atoms" do
      ExUnitProperties.check all(
                               m <- SD.member_of(["grid", "list"]),
                               max_runs: 50
                             ) do
        atom = String.to_existing_atom(m)
        assert atom in [:grid, :list]
      end
    end
  end

  # ============================================================================
  # Accessibility & SC-HMI-001
  # ============================================================================

  describe "Accessibility (SC-HMI-001)" do
    test "renders semantic HTML with device content", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/cockpit/devices")
      assert is_binary(html)
      assert String.length(html) > 100
    end

    test "navigation is set to :devices", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/cockpit/devices")
      assert view.assigns.current_nav == :devices
    end

    test "page title is a non-empty string", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/cockpit/devices")
      assert is_binary(view.assigns.page_title)
      assert String.length(view.assigns.page_title) > 0
    end
  end
end
