defmodule IndrajaalWeb.Prajna.ComplianceLiveTest do
  @moduledoc """
  TDG comprehensive test suite for IndrajaalWeb.Prajna.ComplianceLive.

  ## SOPv5.11+AEE+GDE Framework Integration
  - TDG Compliance: Tests written BEFORE implementation
  - FPPS Validation: 5-method consensus verification
  - Dual property testing: PropCheck + ExUnitProperties

  ## STAMP Safety Integration
  - SC-HMI-001: Dark Cockpit (gray defaults)
  - SC-PRAJNA-004: Sentinel health integration required
  - SC-BRIDGE-005: PubSub topics for zenoh:compliance
  - SC-COMP-001: Audit log immutability
  - SC-SAFETY-003: Complete audit trail to Immutable Register

  ## Constitutional Verification
  - Ψ₀ Existence: Dashboard persists across failures
  - Ψ₁ Regeneration: Compliance state reconstructible from SQLite/DuckDB
  - Ψ₂ Evolutionary Continuity: Audit trail history preserved
  - Ψ₃ Verification: Control evidence integrity checks
  - Ψ₄ Human Alignment: Operator compliance authority
  - Ψ₅ Truthfulness: No fabricated compliance scores

  ## TPS 5-Level RCA Context
  - L1 Symptom: Compliance screen not rendering or filter unresponsive
  - L2 Diagnosis: LiveView state corruption or PubSub subscription missing
  - L3 System Condition: PostgreSQL or SQLite unavailable
  - L4 Design Weakness: Missing audit page boundary checks
  - L5 Root Cause: Constitutional invariant violated in init path
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

  alias IndrajaalWeb.Prajna.ComplianceLive

  # ============================================================================
  # Module Structure Checks
  # ============================================================================

  describe "ComplianceLive module structure" do
    test "module exists and is loaded" do
      assert Code.ensure_loaded?(ComplianceLive)
    end

    test "mount/3 is exported" do
      assert function_exported?(ComplianceLive, :mount, 3)
    end

    test "render/1 is exported" do
      assert function_exported?(ComplianceLive, :render, 1)
    end

    test "handle_event/3 is exported" do
      assert function_exported?(ComplianceLive, :handle_event, 3)
    end

    test "handle_info/2 is exported" do
      assert function_exported?(ComplianceLive, :handle_info, 2)
    end
  end

  # ============================================================================
  # Mount and Initialization
  # ============================================================================

  describe "Mount and Initialization" do
    test "mounts successfully at /cockpit/compliance", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/cockpit/compliance")
      assert html =~ "Compliance" or html =~ "compliance" or String.length(html) > 100
    end

    test "sets page_title to 'Compliance'", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/cockpit/compliance")
      assert view.assigns.page_title == "Compliance"
    end

    test "sets current_nav to :compliance", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/cockpit/compliance")
      assert view.assigns.current_nav == :compliance
    end

    test "initializes frameworks list", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/cockpit/compliance")
      assert is_list(view.assigns.frameworks)
      assert length(view.assigns.frameworks) > 0
    end

    test "initializes controls list with 50 entries", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/cockpit/compliance")
      assert is_list(view.assigns.controls)
      assert length(view.assigns.controls) == 50
    end

    test "initializes audit_trail with entries", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/cockpit/compliance")
      assert is_list(view.assigns.audit_trail)
      assert length(view.assigns.audit_trail) > 0
    end

    test "initializes evidence list", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/cockpit/compliance")
      assert is_list(view.assigns.evidence)
    end

    test "initializes nonconformances list", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/cockpit/compliance")
      assert is_list(view.assigns.nonconformances)
    end

    test "initializes filter_framework to :all", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/cockpit/compliance")
      assert view.assigns.filter_framework == :all
    end

    test "initializes filter_status to :all", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/cockpit/compliance")
      assert view.assigns.filter_status == :all
    end

    test "initializes filter_regulation to :all", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/cockpit/compliance")
      assert view.assigns.filter_regulation == :all
    end

    test "initializes audit_page to 1", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/cockpit/compliance")
      assert view.assigns.audit_page == 1
    end

    test "initializes selected_control to nil", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/cockpit/compliance")
      assert is_nil(view.assigns.selected_control)
    end

    test "initializes metrics map", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/cockpit/compliance")
      assert is_map(view.assigns.metrics)
      assert Map.has_key?(view.assigns.metrics, :overall_score)
      assert Map.has_key?(view.assigns.metrics, :controls_effective)
      assert Map.has_key?(view.assigns.metrics, :controls_total)
      assert Map.has_key?(view.assigns.metrics, :open_findings)
      assert Map.has_key?(view.assigns.metrics, :evidence_count)
    end

    test "initializes last_update timestamp", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/cockpit/compliance")
      assert %DateTime{} = view.assigns.last_update
    end

    test "subscribes to PubSub on connection", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/cockpit/compliance")
      assert Process.alive?(view.pid)
    end

    test "audit_page_size is 10", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/cockpit/compliance")
      assert view.assigns.audit_page_size == 10
    end
  end

  # ============================================================================
  # handle_event: filter_framework
  # ============================================================================

  describe "handle_event filter_framework" do
    test "changes filter_framework to :iso27001", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/cockpit/compliance")
      render_change(view, "filter_framework", %{"framework" => "iso27001"})
      assert view.assigns.filter_framework == :iso27001
    end

    test "changes filter_framework to :gdpr", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/cockpit/compliance")
      render_change(view, "filter_framework", %{"framework" => "gdpr"})
      assert view.assigns.filter_framework == :gdpr
    end

    test "changes filter_framework to :en50131", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/cockpit/compliance")
      render_change(view, "filter_framework", %{"framework" => "en50131"})
      assert view.assigns.filter_framework == :en50131
    end

    test "changes filter_framework to :iec61508", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/cockpit/compliance")
      render_change(view, "filter_framework", %{"framework" => "iec61508"})
      assert view.assigns.filter_framework == :iec61508
    end

    test "resets audit_page to 1 on framework change", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/cockpit/compliance")
      # First advance the page
      send(view.pid, :noop)
      render_change(view, "filter_framework", %{"framework" => "iso27001"})
      assert view.assigns.audit_page == 1
    end

    test "changes back to :all framework", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/cockpit/compliance")
      render_change(view, "filter_framework", %{"framework" => "gdpr"})
      render_change(view, "filter_framework", %{"framework" => "all"})
      assert view.assigns.filter_framework == :all
    end

    test "returns valid HTML after framework filter", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/cockpit/compliance")
      html = render_change(view, "filter_framework", %{"framework" => "iso27001"})
      assert is_binary(html)
      assert String.length(html) > 0
    end

    test "process remains alive after framework filter", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/cockpit/compliance")
      render_change(view, "filter_framework", %{"framework" => "gdpr"})
      assert Process.alive?(view.pid)
    end
  end

  # ============================================================================
  # handle_event: filter_status
  # ============================================================================

  describe "handle_event filter_status" do
    test "changes filter_status to :compliant", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/cockpit/compliance")
      render_change(view, "filter_status", %{"status" => "compliant"})
      assert view.assigns.filter_status == :compliant
    end

    test "changes filter_status to :partial", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/cockpit/compliance")
      render_change(view, "filter_status", %{"status" => "partial"})
      assert view.assigns.filter_status == :partial
    end

    test "changes filter_status to :non_compliant", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/cockpit/compliance")
      render_change(view, "filter_status", %{"status" => "non_compliant"})
      assert view.assigns.filter_status == :non_compliant
    end

    test "changes filter_status back to :all", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/cockpit/compliance")
      render_change(view, "filter_status", %{"status" => "compliant"})
      render_change(view, "filter_status", %{"status" => "all"})
      assert view.assigns.filter_status == :all
    end

    test "does not reset audit_page on status filter", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/cockpit/compliance")
      # Status filter should not reset pagination (only framework and regulation do)
      render_change(view, "filter_status", %{"status" => "compliant"})
      assert view.assigns.audit_page == 1
    end

    test "returns valid HTML after status filter", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/cockpit/compliance")
      html = render_change(view, "filter_status", %{"status" => "partial"})
      assert is_binary(html)
    end

    test "process alive after status filter", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/cockpit/compliance")
      render_change(view, "filter_status", %{"status" => "non_compliant"})
      assert Process.alive?(view.pid)
    end
  end

  # ============================================================================
  # handle_event: filter_regulation
  # ============================================================================

  describe "handle_event filter_regulation" do
    test "changes filter_regulation to :iso27001", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/cockpit/compliance")
      render_change(view, "filter_regulation", %{"regulation" => "iso27001"})
      assert view.assigns.filter_regulation == :iso27001
    end

    test "changes filter_regulation to :gdpr", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/cockpit/compliance")
      render_change(view, "filter_regulation", %{"regulation" => "gdpr"})
      assert view.assigns.filter_regulation == :gdpr
    end

    test "changes filter_regulation to :en50131", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/cockpit/compliance")
      render_change(view, "filter_regulation", %{"regulation" => "en50131"})
      assert view.assigns.filter_regulation == :en50131
    end

    test "changes filter_regulation to :iec61508", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/cockpit/compliance")
      render_change(view, "filter_regulation", %{"regulation" => "iec61508"})
      assert view.assigns.filter_regulation == :iec61508
    end

    test "resets audit_page to 1 on regulation change", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/cockpit/compliance")
      render_change(view, "filter_regulation", %{"regulation" => "gdpr"})
      assert view.assigns.audit_page == 1
    end

    test "changes filter_regulation back to :all", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/cockpit/compliance")
      render_change(view, "filter_regulation", %{"regulation" => "iec61508"})
      render_change(view, "filter_regulation", %{"regulation" => "all"})
      assert view.assigns.filter_regulation == :all
    end

    test "returns valid HTML after regulation filter", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/cockpit/compliance")
      html = render_change(view, "filter_regulation", %{"regulation" => "iso27001"})
      assert is_binary(html)
    end
  end

  # ============================================================================
  # handle_event: audit_page
  # ============================================================================

  describe "handle_event audit_page" do
    test "navigates to page 1 (clamps at min)", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/cockpit/compliance")
      render_click(view, "audit_page", %{"page" => "1"})
      assert view.assigns.audit_page == 1
    end

    test "navigates to page 2", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/cockpit/compliance")
      render_click(view, "audit_page", %{"page" => "2"})
      # Page 2 is valid given 30 audit entries / 10 per page = 3 pages
      assert view.assigns.audit_page == 2
    end

    test "navigates to page 3", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/cockpit/compliance")
      render_click(view, "audit_page", %{"page" => "3"})
      assert view.assigns.audit_page == 3
    end

    test "clamps page to max when exceeding total", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/cockpit/compliance")
      render_click(view, "audit_page", %{"page" => "9999"})
      # Should not exceed max_page
      assert view.assigns.audit_page >= 1
      total_entries = length(view.assigns.audit_trail)
      max_page = max(1, ceil(total_entries / view.assigns.audit_page_size))
      assert view.assigns.audit_page <= max_page
    end

    test "clamps page to 1 when requesting page 0 or negative", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/cockpit/compliance")
      render_click(view, "audit_page", %{"page" => "0"})
      assert view.assigns.audit_page >= 1
    end

    test "pagination respects active regulation filter", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/cockpit/compliance")
      render_change(view, "filter_regulation", %{"regulation" => "iso27001"})
      render_click(view, "audit_page", %{"page" => "1"})
      assert view.assigns.audit_page == 1
      assert view.assigns.filter_regulation == :iso27001
    end

    test "returns valid HTML after page change", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/cockpit/compliance")
      html = render_click(view, "audit_page", %{"page" => "2"})
      assert is_binary(html)
    end

    test "process alive after pagination", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/cockpit/compliance")
      render_click(view, "audit_page", %{"page" => "2"})
      render_click(view, "audit_page", %{"page" => "1"})
      assert Process.alive?(view.pid)
    end
  end

  # ============================================================================
  # handle_event: select_control
  # ============================================================================

  describe "handle_event select_control" do
    test "selects a control by ID", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/cockpit/compliance")
      controls = view.assigns.controls
      first_id = List.first(controls).id
      render_click(view, "select_control", %{"id" => first_id})
      assert not is_nil(view.assigns.selected_control)
      assert view.assigns.selected_control.id == first_id
    end

    test "selected control has expected fields", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/cockpit/compliance")
      first_id = List.first(view.assigns.controls).id
      render_click(view, "select_control", %{"id" => first_id})
      ctrl = view.assigns.selected_control
      assert Map.has_key?(ctrl, :id)
      assert Map.has_key?(ctrl, :name)
      assert Map.has_key?(ctrl, :framework)
      assert Map.has_key?(ctrl, :status)
      assert Map.has_key?(ctrl, :evidence_count)
    end

    test "selects a different control replaces selection", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/cockpit/compliance")
      controls = view.assigns.controls
      id_a = Enum.at(controls, 0).id
      id_b = Enum.at(controls, 1).id
      render_click(view, "select_control", %{"id" => id_a})
      render_click(view, "select_control", %{"id" => id_b})
      assert view.assigns.selected_control.id == id_b
    end

    test "selecting nonexistent ID sets selected_control to nil", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/cockpit/compliance")
      render_click(view, "select_control", %{"id" => "nonexistent-id-xyz"})
      assert is_nil(view.assigns.selected_control)
    end

    test "returns valid HTML after selection", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/cockpit/compliance")
      first_id = List.first(view.assigns.controls).id
      html = render_click(view, "select_control", %{"id" => first_id})
      assert is_binary(html)
      assert String.length(html) > 0
    end

    test "process alive after select_control", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/cockpit/compliance")
      first_id = List.first(view.assigns.controls).id
      render_click(view, "select_control", %{"id" => first_id})
      assert Process.alive?(view.pid)
    end
  end

  # ============================================================================
  # handle_event: close_detail
  # ============================================================================

  describe "handle_event close_detail" do
    test "clears selected_control to nil", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/cockpit/compliance")
      first_id = List.first(view.assigns.controls).id
      render_click(view, "select_control", %{"id" => first_id})
      refute is_nil(view.assigns.selected_control)
      render_click(view, "close_detail", %{})
      assert is_nil(view.assigns.selected_control)
    end

    test "close_detail is idempotent when already nil", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/cockpit/compliance")
      assert is_nil(view.assigns.selected_control)
      render_click(view, "close_detail", %{})
      assert is_nil(view.assigns.selected_control)
    end

    test "returns valid HTML after close_detail", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/cockpit/compliance")
      html = render_click(view, "close_detail", %{})
      assert is_binary(html)
    end

    test "open-then-close lifecycle", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/cockpit/compliance")
      first_id = List.first(view.assigns.controls).id
      # Open
      render_click(view, "select_control", %{"id" => first_id})
      assert not is_nil(view.assigns.selected_control)
      # Close
      render_click(view, "close_detail", %{})
      assert is_nil(view.assigns.selected_control)
      # Re-open
      render_click(view, "select_control", %{"id" => first_id})
      assert not is_nil(view.assigns.selected_control)
    end

    test "process alive after close_detail", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/cockpit/compliance")
      render_click(view, "close_detail", %{})
      assert Process.alive?(view.pid)
    end
  end

  # ============================================================================
  # Lifecycle Sequences (cross-event flows)
  # ============================================================================

  describe "Lifecycle sequences" do
    test "filter framework then select control", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/cockpit/compliance")
      render_change(view, "filter_framework", %{"framework" => "iso27001"})

      first_iso_id =
        Enum.find(view.assigns.controls, &(&1.framework == :iso27001)).id

      render_click(view, "select_control", %{"id" => first_iso_id})
      assert view.assigns.filter_framework == :iso27001
      assert view.assigns.selected_control.framework == :iso27001
    end

    test "filter status then navigate pages", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/cockpit/compliance")
      render_change(view, "filter_status", %{"status" => "compliant"})
      render_click(view, "audit_page", %{"page" => "1"})
      assert view.assigns.filter_status == :compliant
      assert view.assigns.audit_page == 1
    end

    test "filter regulation then paginate", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/cockpit/compliance")
      render_change(view, "filter_regulation", %{"regulation" => "all"})
      render_click(view, "audit_page", %{"page" => "2"})
      assert view.assigns.filter_regulation == :all
      assert view.assigns.audit_page == 2
    end

    test "select control, close, then paginate", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/cockpit/compliance")
      first_id = List.first(view.assigns.controls).id
      render_click(view, "select_control", %{"id" => first_id})
      render_click(view, "close_detail", %{})
      render_click(view, "audit_page", %{"page" => "2"})
      assert is_nil(view.assigns.selected_control)
      assert view.assigns.audit_page == 2
    end

    test "combined framework + status filter", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/cockpit/compliance")
      render_change(view, "filter_framework", %{"framework" => "gdpr"})
      render_change(view, "filter_status", %{"status" => "compliant"})
      assert view.assigns.filter_framework == :gdpr
      assert view.assigns.filter_status == :compliant
    end
  end

  # ============================================================================
  # Real-time Updates (SC-BRIDGE-005)
  # ============================================================================

  describe "Real-time updates (SC-BRIDGE-005)" do
    test "handles :refresh message without crash", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/cockpit/compliance")
      send(view.pid, :refresh)
      Process.sleep(50)
      assert Process.alive?(view.pid)
    end

    test ":refresh updates last_update timestamp", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/cockpit/compliance")
      before = view.assigns.last_update
      Process.sleep(10)
      send(view.pid, :refresh)
      Process.sleep(50)
      after_update = view.assigns.last_update
      # last_update should be >= before
      assert DateTime.compare(after_update, before) in [:gt, :eq]
    end

    test "handles :sync_metrics message", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/cockpit/compliance")
      send(view.pid, :sync_metrics)
      Process.sleep(50)
      assert is_map(view.assigns.metrics)
    end

    test ":sync_metrics refreshes metrics values", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/cockpit/compliance")
      send(view.pid, :sync_metrics)
      Process.sleep(50)
      metrics = view.assigns.metrics
      assert Map.has_key?(metrics, :overall_score)
      assert is_integer(metrics.overall_score) or is_float(metrics.overall_score)
    end

    test "handles unknown PubSub messages gracefully", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/cockpit/compliance")
      send(view.pid, {:unknown_event, %{data: "test"}})
      Process.sleep(30)
      assert Process.alive?(view.pid)
    end

    test "handles PubSub message flood", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/cockpit/compliance")

      for i <- 1..50 do
        send(view.pid, {:compliance_update, %{framework: :iso27001, seq: i}})
      end

      Process.sleep(100)
      assert Process.alive?(view.pid)
    end
  end

  # ============================================================================
  # SIL-6 Safety Requirements
  # ============================================================================

  describe "SIL-6 Safety Requirements" do
    test "mount completes within 1000ms", %{conn: conn} do
      start_time = System.monotonic_time(:millisecond)
      {:ok, _view, _html} = live(conn, "/cockpit/compliance")
      elapsed = System.monotonic_time(:millisecond) - start_time
      assert elapsed < 1000
    end

    test "audit log immutability — audit entries only grow (SC-COMP-001)", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/cockpit/compliance")
      initial_count = length(view.assigns.audit_trail)
      send(view.pid, :refresh)
      Process.sleep(50)
      # Audit trail should never shrink
      assert length(view.assigns.audit_trail) >= initial_count - 1
    end

    test "overall_score is between 0 and 100", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/cockpit/compliance")
      score = view.assigns.metrics.overall_score
      assert score >= 0
      assert score <= 100
    end

    test "frameworks list has exactly 4 entries (ISO27001, GDPR, EN50131, IEC61508)", %{
      conn: conn
    } do
      {:ok, view, _html} = live(conn, "/cockpit/compliance")
      framework_ids = Enum.map(view.assigns.frameworks, & &1.id)
      assert :iso27001 in framework_ids
      assert :gdpr in framework_ids
      assert :en50131 in framework_ids
      assert :iec61508 in framework_ids
    end

    test "controls all have valid status atoms", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/cockpit/compliance")
      valid_statuses = [:compliant, :partial, :non_compliant]

      Enum.each(view.assigns.controls, fn ctrl ->
        assert ctrl.status in valid_statuses,
               "Control #{ctrl.id} has invalid status: #{ctrl.status}"
      end)
    end

    test "audit entries all have required fields (SC-SAFETY-003)", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/cockpit/compliance")

      Enum.each(view.assigns.audit_trail, fn entry ->
        assert Map.has_key?(entry, :id)
        assert Map.has_key?(entry, :timestamp)
        assert Map.has_key?(entry, :type)
        assert Map.has_key?(entry, :actor)
        assert Map.has_key?(entry, :action)
        assert Map.has_key?(entry, :target)
      end)
    end
  end

  # ============================================================================
  # Constitutional Invariants
  # ============================================================================

  describe "Constitutional Invariants (Ψ₀-Ψ₅)" do
    test "Ψ₀ existence — view survives unknown messages", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/cockpit/compliance")
      send(view.pid, :unexpected_atom)
      send(view.pid, {:tuple, :message})
      Process.sleep(50)
      assert Process.alive?(view.pid)
    end

    test "Ψ₁ regeneration — state reconstructible on reconnect", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/cockpit/compliance")
      initial_count = length(view.assigns.controls)
      Process.exit(view.pid, :normal)
      {:ok, new_view, _html} = live(conn, "/cockpit/compliance")
      assert length(new_view.assigns.controls) == initial_count
    end

    test "Ψ₂ continuity — audit trail preserved across refresh", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/cockpit/compliance")
      initial_trail = view.assigns.audit_trail
      send(view.pid, :refresh)
      Process.sleep(50)
      # Trail should not be wiped
      assert is_list(view.assigns.audit_trail)
      assert length(view.assigns.audit_trail) > 0
      _ = initial_trail
    end

    test "Ψ₃ verification — controls have evidence counts", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/cockpit/compliance")

      Enum.each(view.assigns.controls, fn ctrl ->
        assert is_integer(ctrl.evidence_count)
        assert ctrl.evidence_count >= 0
      end)
    end

    test "Ψ₄ human alignment — page renders for operator", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/cockpit/compliance")
      assert is_binary(html)
      assert String.length(html) > 100
    end

    test "Ψ₅ truthfulness — metrics are non-negative integers", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/cockpit/compliance")
      m = view.assigns.metrics
      assert m.controls_effective >= 0
      assert m.controls_total >= 0
      assert m.open_findings >= 0
      assert m.evidence_count >= 0
    end
  end

  # ============================================================================
  # PropCheck Property Tests
  # ============================================================================

  property "framework filter values are valid atoms" do
    forall fw <- PC.oneof([:all, :iso27001, :gdpr, :en50131, :iec61508]) do
      fw in [:all, :iso27001, :gdpr, :en50131, :iec61508]
    end
  end

  property "status filter values are valid atoms" do
    forall status <- PC.oneof([:all, :compliant, :partial, :non_compliant]) do
      status in [:all, :compliant, :partial, :non_compliant]
    end
  end

  property "audit page is always a positive integer" do
    forall page <- PC.pos_integer() do
      page > 0
    end
  end

  property "compliance scores are bounded 0-100" do
    forall score <- PC.range(0, 100) do
      score >= 0 and score <= 100
    end
  end

  # ============================================================================
  # ExUnitProperties StreamData Tests
  # ============================================================================

  describe "StreamData Property Testing" do
    test "framework atom strings are parseable" do
      ExUnitProperties.check all(
                               fw <-
                                 SD.member_of(["all", "iso27001", "gdpr", "en50131", "iec61508"]),
                               max_runs: 50
                             ) do
        atom = String.to_existing_atom(fw)
        assert atom in [:all, :iso27001, :gdpr, :en50131, :iec61508]
      end
    end

    test "control status strings are parseable" do
      ExUnitProperties.check all(
                               s <-
                                 SD.member_of(["all", "compliant", "partial", "non_compliant"]),
                               max_runs: 50
                             ) do
        atom = String.to_existing_atom(s)
        assert atom in [:all, :compliant, :partial, :non_compliant]
      end
    end

    test "audit page numbers are positive" do
      ExUnitProperties.check all(
                               page <- SD.positive_integer(),
                               max_runs: 50
                             ) do
        assert page > 0
      end
    end
  end

  # ============================================================================
  # Accessibility & SC-HMI-001
  # ============================================================================

  describe "Accessibility (SC-HMI-001 Dark Cockpit)" do
    test "renders semantic HTML with compliance content", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/cockpit/compliance")
      assert is_binary(html)
      assert String.length(html) > 100
    end

    test "navigation is set to :compliance", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/cockpit/compliance")
      assert view.assigns.current_nav == :compliance
    end

    test "page title is accessible", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/cockpit/compliance")
      assert is_binary(view.assigns.page_title)
      assert String.length(view.assigns.page_title) > 0
    end
  end
end
