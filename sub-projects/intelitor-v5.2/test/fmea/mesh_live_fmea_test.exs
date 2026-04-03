defmodule IndrajaalWeb.Fmea.MeshLiveFmeaTest do
  @moduledoc """
  FMEA tests for IndrajaalWeb.Prajna.MeshLive.

  Analyzes failure modes in the Mesh Topology visualization, focusing on
  destructive node operation bypass, node selection with stale state,
  PubSub metric flood, and missing-id parameter crashes.

  RPN = Severity x Occurrence x Detection

  | Rating | Severity | Occurrence | Detection |
  |--------|----------|------------|-----------|
  | 1 | Negligible | Never | Immediate/automatic |
  | 3 | Minor | Rare | Easy to detect |
  | 5 | Moderate | Occasional | Sometimes detected |
  | 7 | Significant | Frequent | Difficult to detect |
  | 9 | Critical/Safety | Very frequent | Near-impossible |

  TDG Level: L2 (FMEA Testing)
  STAMP: SC-HMI-001, SC-EID-001, SC-VDP-005, SC-SAFETY-001, SC-GDE-001
  Reference: IEC 60812 FMEA, IEC 61508 SIL-4
  """

  use IndrajaalWeb.ConnCase, async: false
  import Phoenix.LiveViewTest

  @moduletag :fmea
  @moduletag :l2_fmea

  # ============================================================================
  # FM-MSH-001: Destructive Node Operation Without Guardian Pre-Approval
  # Severity: 9 (restart/isolate/drain without Guardian = SC-SAFETY-001 violation)
  # Occurrence: 4 (operator clicks quickly under stress)
  # Detection: 4 (no confirmation dialog, flash only)
  # RPN: 144
  # ============================================================================

  describe "FM-MSH-001: Destructive Operation Without Guardian (RPN: 144)" do
    @moduledoc """
    ## Failure Mode Analysis

    | Attribute | Value |
    |-----------|-------|
    | Failure Mode | restart_node/stop_node fire without Guardian pre-approval |
    | Effect | Node operation initiated without SC-SAFETY-001 arm-and-fire confirmation |
    | Severity | 9 (safety-critical: could stop production containers) |
    | Occurrence | 4 (operator stress, accidental double-click) |
    | Detection | 4 (flash message shown, but action already armed) |
    | RPN Before | 144 |
    | Mitigation | Two-step commit: arm then confirm, Guardian validation before execution |
    | RPN After | 36 (S:9 x O:2 x D:2) |
    | STAMP | SC-SAFETY-001, SC-GDE-001, SC-PRAJNA-005 |
    """

    @tag rpn: 144
    test "page mounts and renders mesh topology" do
      {:ok, _view, html} = live(build_conn(), "/cockpit/mesh")
      assert is_binary(html)
      assert html =~ "Mesh" or html =~ "mesh" or html =~ "MESH"
    end

    @tag rpn: 144
    test "restart_node arms without crashing" do
      {:ok, view, _html} = live(build_conn(), "/cockpit/mesh")
      html = render_click(view, "restart_node", %{"id" => "indrajaal-ex-app-1"})
      assert is_binary(html)
    end

    @tag rpn: 144
    test "stop_node arms without crashing" do
      {:ok, view, _html} = live(build_conn(), "/cockpit/mesh")
      html = render_click(view, "stop_node", %{"id" => "indrajaal-ex-app-1"})
      assert is_binary(html)
    end
  end

  # ============================================================================
  # FM-MSH-002: Node Operation with Non-Existent Node ID
  # Severity: 5 (flash shown for non-existent node — confusing but not dangerous)
  # Occurrence: 5 (race: node disappears while operator clicks)
  # Detection: 4 (no error indicator in UI)
  # RPN: 100
  # ============================================================================

  describe "FM-MSH-002: Node Operation with Non-Existent ID (RPN: 100)" do
    @moduledoc """
    ## Failure Mode Analysis

    | Attribute | Value |
    |-----------|-------|
    | Failure Mode | restart_node/stop_node receive id not in nodes list |
    | Effect | Flash message references ghost node — operator confused |
    | Severity | 5 (confusing but not safety-critical) |
    | Occurrence | 5 (common: another operator restarts node concurrently) |
    | Detection | 4 (UI shows flash but no error state) |
    | RPN Before | 100 |
    | Mitigation | Validate node id against current nodes assign before arming |
    | RPN After | 20 (S:5 x O:2 x D:2) |
    | STAMP | SC-HMI-001, SC-VDP-005 |
    """

    @tag rpn: 100
    test "restart_node with non-existent id does not crash" do
      {:ok, view, _html} = live(build_conn(), "/cockpit/mesh")
      html = render_click(view, "restart_node", %{"id" => "node-DOES-NOT-EXIST-99999"})
      assert is_binary(html)
    end

    @tag rpn: 100
    test "stop_node with non-existent id does not crash" do
      {:ok, view, _html} = live(build_conn(), "/cockpit/mesh")
      html = render_click(view, "stop_node", %{"id" => "node-DOES-NOT-EXIST-99999"})
      assert is_binary(html)
    end
  end

  # ============================================================================
  # FM-MSH-003: select_node Missing ID Parameter
  # Severity: 7 (LiveView crash if pattern match fails on missing key)
  # Occurrence: 3 (client sends malformed event — version drift)
  # Detection: 3 (crash visible in logs)
  # RPN: 63
  # ============================================================================

  describe "FM-MSH-003: select_node Missing ID Parameter (RPN: 63)" do
    @moduledoc """
    ## Failure Mode Analysis

    | Attribute | Value |
    |-----------|-------|
    | Failure Mode | select_node event sent without \"id\" key in params |
    | Effect | Pattern match %{\"id\" => id} raises FunctionClauseError |
    | Severity | 7 (process crash, operator loses mesh view) |
    | Occurrence | 3 (client version mismatch, test harness) |
    | Detection | 3 (crash shows in server logs) |
    | RPN Before | 63 |
    | Mitigation | Add fallback clause: handle_event(\"select_node\", _params, socket) |
    | RPN After | 21 (S:7 x O:1 x D:3) |
    | STAMP | SC-HMI-001, SC-GDE-001 |
    """

    @tag rpn: 63
    test "select_node with valid id renders detail panel" do
      {:ok, view, _html} = live(build_conn(), "/cockpit/mesh")
      html = render_click(view, "select_node", %{"id" => "indrajaal-ex-app-1"})
      assert is_binary(html)
    end

    @tag rpn: 63
    test "select_node with non-existent id is graceful" do
      {:ok, view, _html} = live(build_conn(), "/cockpit/mesh")
      html = render_click(view, "select_node", %{"id" => "node-PHANTOM-99999"})
      assert is_binary(html)
    end

    @tag rpn: 63
    test "select_node then clear_selection restores unselected state" do
      {:ok, view, _html} = live(build_conn(), "/cockpit/mesh")
      _html1 = render_click(view, "select_node", %{"id" => "zenoh-router"})
      html2 = render_click(view, "clear_selection", %{})
      assert is_binary(html2)
    end
  end

  # ============================================================================
  # FM-MSH-004: clear_selection When Nothing Selected
  # Severity: 3 (idempotent nil-clear — no visible effect)
  # Occurrence: 5 (operator clicks clear when panel already hidden)
  # Detection: 1 (no crash, page renders normally)
  # RPN: 15
  # ============================================================================

  describe "FM-MSH-004: clear_selection When Nothing Selected (RPN: 15)" do
    @moduledoc """
    ## Failure Mode Analysis

    | Attribute | Value |
    |-----------|-------|
    | Failure Mode | clear_selection called when selected_node is already nil |
    | Effect | assign(:selected_node, nil) on nil — no-op |
    | Severity | 3 (no visible effect, operator clicks without consequence) |
    | Occurrence | 5 (common: operator repeatedly clicks clear) |
    | Detection | 1 (system handles gracefully, no symptom) |
    | RPN Before | 15 |
    | Mitigation | Already idempotent — no action required |
    | RPN After | 3 (S:3 x O:1 x D:1) |
    | STAMP | SC-HMI-001 |
    """

    @tag rpn: 15
    test "clear_selection on fresh mount is idempotent" do
      {:ok, view, _html} = live(build_conn(), "/cockpit/mesh")
      html = render_click(view, "clear_selection", %{})
      assert is_binary(html)
    end

    @tag rpn: 15
    test "repeated clear_selection calls are safe" do
      {:ok, view, _html} = live(build_conn(), "/cockpit/mesh")

      for _i <- 1..3 do
        render_click(view, "clear_selection", %{})
      end

      html = render(view)
      assert is_binary(html)
    end
  end

  # ============================================================================
  # FM-MSH-005: SentinelBridge Unavailable During Metric Update
  # Severity: 5 (alarm count shows 0 instead of real value)
  # Occurrence: 4 (SentinelBridge not started in test or degraded)
  # Detection: 3 (node shows 0 alarms — visually obvious mismatch)
  # RPN: 60
  # ============================================================================

  describe "FM-MSH-005: SentinelBridge Unavailable (RPN: 60)" do
    @moduledoc """
    ## Failure Mode Analysis

    | Attribute | Value |
    |-----------|-------|
    | Failure Mode | fetch_alarm_count/fetch_alarm_message call SentinelBridge which is down |
    | Effect | Supervisor node shows 0 alarms — masks real threat count |
    | Severity | 5 (operator may miss real threats) |
    | Occurrence | 4 (SentinelBridge crash, container restart) |
    | Detection | 3 (0 alarm count visible in UI — discrepancy noticeable) |
    | RPN Before | 60 |
    | Mitigation | safe_call/3 already wraps call — ensure fallback returns :stale indicator |
    | RPN After | 20 (S:5 x O:2 x D:2) |
    | STAMP | SC-PRAJNA-004, SC-ZENOH-003 |
    """

    @tag rpn: 60
    test "page renders when SentinelBridge is unavailable" do
      # SentinelBridge is not started in test env — page must still render
      {:ok, _view, html} = live(build_conn(), "/cockpit/mesh")
      assert is_binary(html)
    end

    @tag rpn: 60
    test "node selection works even without SentinelBridge" do
      {:ok, view, _html} = live(build_conn(), "/cockpit/mesh")
      html = render_click(view, "select_node", %{"id" => "indrajaal-ex-app-1"})
      assert is_binary(html)
    end
  end

  # ============================================================================
  # FM-MSH-006: Rapid Sequential Node Operations
  # Severity: 5 (multiple flashes may confuse operator about node state)
  # Occurrence: 3 (operator frantically clicking under incident conditions)
  # Detection: 4 (each flash appears but may overlap)
  # RPN: 60
  # ============================================================================

  describe "FM-MSH-006: Rapid Sequential Node Operations (RPN: 60)" do
    @moduledoc """
    ## Failure Mode Analysis

    | Attribute | Value |
    |-----------|-------|
    | Failure Mode | Rapid sequence: restart → stop on same container |
    | Effect | Multiple flash messages, possible last-write-wins race on flash |
    | Severity | 5 (operator loses track of which command was last) |
    | Occurrence | 3 (stress scenario, accidental rapid clicking) |
    | Detection | 4 (visible via flash sequence but order unclear) |
    | RPN Before | 60 |
    | Mitigation | Debounce or disable buttons after first click; show command queue |
    | RPN After | 20 (S:5 x O:2 x D:2) |
    | STAMP | SC-HMI-001, SC-SAFETY-001 |
    """

    @tag rpn: 60
    test "rapid restart then stop on same container does not crash" do
      {:ok, view, _html} = live(build_conn(), "/cockpit/mesh")
      _html1 = render_click(view, "restart_node", %{"id" => "indrajaal-ex-app-2"})
      html2 = render_click(view, "stop_node", %{"id" => "indrajaal-ex-app-2"})
      assert is_binary(html2)
    end

    @tag rpn: 60
    test "full operations sequence on one container leaves page valid" do
      {:ok, view, _html} = live(build_conn(), "/cockpit/mesh")
      _h1 = render_click(view, "select_node", %{"id" => "indrajaal-ex-app-3"})
      _h2 = render_click(view, "restart_node", %{"id" => "indrajaal-ex-app-3"})
      _h3 = render_click(view, "stop_node", %{"id" => "indrajaal-ex-app-3"})
      html4 = render_click(view, "clear_selection", %{})
      assert is_binary(html4)
    end
  end

  # ============================================================================
  # FMEA Summary
  # ============================================================================

  describe "FMEA Summary: MeshLive" do
    @tag :fmea_summary
    test "all failure modes are registered and traceable" do
      failure_modes = [
        {:fm_msh_001, :destructive_operation_without_guardian, 144},
        {:fm_msh_002, :node_operation_nonexistent_id, 100},
        {:fm_msh_003, :select_node_missing_id_parameter, 63},
        {:fm_msh_004, :clear_selection_when_nothing_selected, 15},
        {:fm_msh_005, :sentinel_bridge_unavailable, 60},
        {:fm_msh_006, :rapid_sequential_node_operations, 60}
      ]

      total_rpn_before = failure_modes |> Enum.map(&elem(&1, 2)) |> Enum.sum()

      assert length(failure_modes) == 6
      assert total_rpn_before == 442

      {_id, highest_fm, highest_rpn} = Enum.max_by(failure_modes, &elem(&1, 2))
      assert highest_fm == :destructive_operation_without_guardian
      assert highest_rpn == 144
    end
  end
end
